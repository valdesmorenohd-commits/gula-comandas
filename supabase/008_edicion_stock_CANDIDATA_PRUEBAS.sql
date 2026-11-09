-- 008 - EDICIÓN ATÓMICA DE COMANDAS CON DIFERENCIAS DE STOCK
-- CANDIDATA SOLO PARA PRUEBAS AISLADAS; NO EJECUTAR EN PRODUCCIÓN.
-- Requiere 001, 006 y 007, esquema verificado y pruebas de concurrencia.
-- Solo permite editar pedidos sin pagos documentados ni estados históricos
-- Pagado/Abono. No concede EXECUTE a clientes.
begin;
create or replace function public.gula_editar_comanda_segura(
 p_comanda_id uuid, p_cliente text, p_telefono text,
 p_fecha_entrega timestamptz, p_tipo_entrega text,
 p_notas text, p_items jsonb
) returns jsonb
language plpgsql security definer set search_path=''
as $$
declare
 v_uid uuid:=auth.uid();
 v_order public.gula_comandas%rowtype;
 v_newdate date;
 v_olddate date;
 v_prod record;
 v_line record;
 v_item jsonb;
 v_id uuid;
 v_qty integer;
 v_total bigint:=0;
 v_items jsonb:='[]'::jsonb;
 v_paid bigint;
 v_rows integer;
begin
 if v_uid is null or not exists (
   select 1 from public.gula_usuarios
   where user_id=v_uid and activo=true and rol='admin'
 ) then raise exception 'Solo administrador' using errcode='42501'; end if;
 if p_comanda_id is null or p_cliente is null or btrim(p_cliente)=''
   or p_fecha_entrega is null or p_tipo_entrega not in ('Retiro','Despacho')
   or p_items is null or jsonb_typeof(p_items)<>'array'
   or jsonb_array_length(p_items)=0 or jsonb_array_length(p_items)>100
 then raise exception 'Datos de comanda inválidos' using errcode='22023'; end if;

 select * into v_order from public.gula_comandas
 where id=p_comanda_id for update;
 if not found or v_order.cancelada then
   raise exception 'Comanda inexistente o cancelada'; end if;

 select coalesce(sum(monto),0) into v_paid
 from public.gula_pagos where comanda_id=p_comanda_id;
 if v_paid>0 or v_order.estado_pago in ('Pagado','Abono')
 then raise exception 'Comanda con pagos: conciliar antes de editar'; end if;

 v_olddate:=(v_order.fecha_entrega at time zone 'America/Santiago')::date;
 v_newdate:=(p_fecha_entrega at time zone 'America/Santiago')::date;

 -- Normalizar líneas nuevas y rechazar duplicados antes de alterar inventario.
 create temporary table if not exists pg_temp.gula_edicion_lineas (
  producto_id uuid primary key, qty integer not null check(qty>0),
  nombre text not null, precio integer not null, nota text not null
 ) on commit drop;
 truncate table pg_temp.gula_edicion_lineas;

 for v_item in select value from jsonb_array_elements(p_items)
 loop
  if coalesce(v_item->>'product_id','') !~
    '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
  or coalesce(v_item->>'qty','') !~ '^[0-9]{1,6}$'
  then raise exception 'Producto o cantidad inválidos'; end if;
  v_id:=(v_item->>'product_id')::uuid;
  v_qty:=(v_item->>'qty')::integer;
  if v_qty<1 then raise exception 'Cantidad inválida'; end if;
  insert into pg_temp.gula_edicion_lineas(producto_id,qty,nombre,precio,nota)
  values(v_id,v_qty,'',0,coalesce(v_item->>'note',''));
 end loop;

 -- Para evitar deadlocks, bloqueo de productos en orden estable.
 for v_prod in
  select id from public.gula_productos
  where id in (select producto_id from pg_temp.gula_edicion_lineas
   union select producto_id from public.gula_movimientos_stock
   where comanda_id=p_comanda_id)
  order by id for update
 loop null; end loop;

 -- Solo pedidos creados por el nuevo flujo tienen movimientos RESERVA.
 -- No editar por esta vía comandas antiguas: faltaría su trazabilidad.
 if not exists (
  select 1 from public.gula_operaciones_comanda
  where comanda_id=p_comanda_id
 ) then raise exception 'Comanda histórica: requiere migración supervisada'; end if;

 -- Bloquear cambios de clasificación/control de stock si hay reservas:
 -- la categoría de la reserva debe permanecer coherente con la nueva.
 for v_prod in
  select p.id,p.nombre,p.precio,p.activo,p.categoria,p.controla_stock,
         l.qty,l.nota
  from pg_temp.gula_edicion_lineas l
  join public.gula_productos p on p.id=l.producto_id
  order by p.id
 loop
  if not v_prod.activo or v_prod.precio is null or v_prod.precio<0
  then raise exception 'Producto no disponible'; end if;
  update pg_temp.gula_edicion_lineas
   set nombre=v_prod.nombre,precio=v_prod.precio
   where producto_id=v_prod.id;
 end loop;
 select count(*) into v_rows from pg_temp.gula_edicion_lineas;
 if v_rows<>jsonb_array_length(p_items)
 then raise exception 'Productos duplicados o inexistentes'; end if;

 -- Liberar reservas antiguas usando sus movimientos, no la foto del catálogo.
 for v_line in
  select producto_id,fecha_stock,(-sum(delta))::integer as qty
  from public.gula_movimientos_stock
  where comanda_id=p_comanda_id
    and motivo in ('RESERVA','LIBERACION')
  group by producto_id,fecha_stock having sum(delta)<0
  order by producto_id
 loop
  if v_line.fecha_stock is null then
   update public.gula_stock_general
    set disponible=disponible+v_line.qty,actualizado_en=now()
    where producto_id=v_line.producto_id;
  else
   update public.gula_stock_diario
    set disponible=disponible+v_line.qty,actualizado_en=now()
    where producto_id=v_line.producto_id and fecha=v_line.fecha_stock;
  end if;
  if not found then raise exception 'Falta fila de stock para liberar'; end if;
  insert into public.gula_movimientos_stock
   (producto_id,comanda_id,fecha_stock,delta,motivo,creado_por,clave_idempotencia)
  values(v_line.producto_id,p_comanda_id,v_line.fecha_stock,
    v_line.qty,'LIBERACION',v_uid,gen_random_uuid());
 end loop;

 -- Reservar cantidades nuevas. Liberación y reserva están dentro de
 -- la misma transacción: cualquier error revierte TODOS los cambios.
 for v_prod in
  select l.*,p.categoria,p.controla_stock
  from pg_temp.gula_edicion_lineas l
  join public.gula_productos p on p.id=l.producto_id
  order by l.producto_id
 loop
  v_total:=v_total+v_prod.precio::bigint*v_prod.qty;
  if v_total>2147483647 then raise exception 'Total excede límite'; end if;
  if v_prod.controla_stock then
   if v_prod.categoria='PRODUCTOS' then
    update public.gula_stock_general
     set disponible=disponible-v_prod.qty,actualizado_en=now()
     where producto_id=v_prod.producto_id and disponible>=v_prod.qty;
   elsif v_prod.categoria='MENU_FINDE' then
    update public.gula_stock_diario
     set disponible=disponible-v_prod.qty,actualizado_en=now()
     where producto_id=v_prod.producto_id and fecha=v_newdate
      and disponible>=v_prod.qty;
   else raise exception 'Categoría no configurada'; end if;
   if not found then raise exception 'Stock insuficiente o no cargado'; end if;
   insert into public.gula_movimientos_stock
    (producto_id,comanda_id,fecha_stock,delta,motivo,creado_por,clave_idempotencia)
   values(v_prod.producto_id,p_comanda_id,
     case when v_prod.categoria='MENU_FINDE' then v_newdate else null end,
     -v_prod.qty,'RESERVA',v_uid,gen_random_uuid());
  end if;
  v_items:=v_items||jsonb_build_array(jsonb_build_object(
   'product_id',v_prod.producto_id,'name',v_prod.nombre,
   'qty',v_prod.qty,'price',v_prod.precio,'note',v_prod.nota));
 end loop;

 update public.gula_comandas
 set cliente=btrim(p_cliente),telefono=coalesce(p_telefono,''),
  fecha_entrega=p_fecha_entrega,tipo_entrega=p_tipo_entrega,
  notas=coalesce(p_notas,''),items=v_items,total=v_total::integer,
  actualizado_en=now()
 where id=p_comanda_id;

 return jsonb_build_object('comanda_id',p_comanda_id,'total',v_total,
  'editada',true,'fecha_anterior',v_olddate,'fecha_nueva',v_newdate);
end
$$;
revoke all on function public.gula_editar_comanda_segura(
 uuid,text,text,timestamptz,text,text,jsonb) from public,anon,authenticated;
commit;

-- PENDIENTE ANTES DE ACTIVAR:
-- 1. La función re-libera y re-reserva, con resultado neto correcto, pero
--    no crea un movimiento neto único; verificar auditoría y concurrencia.
-- 2. Evitar cambios directos de categoria/controla_stock y escritura directa
--    de comandas, especialmente durante reservas.
-- 3. Bloquear cambios en catálogo que invaliden reservas existentes.
-- 4. No usar temp table en un entorno con pooling sin ensayos específicos.
-- 5. Pruebas: cantidades +/-; fecha nueva; stock insuficiente; dos usuarios;
--    comanda antigua; pagos; edición repetida; stock no controlado.
