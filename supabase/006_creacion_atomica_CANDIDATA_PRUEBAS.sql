-- 006: IMPLEMENTACIÓN DE CREACIÓN ATÓMICA (CANDIDATA PARA PRUEBAS)
-- NO EJECUTAR EN PRODUCCIÓN. Requiere 001 y esquema validado.
-- No se concede EXECUTE a authenticated: primero probar y proteger rutas
-- directas de INSERT/UPDATE/DELETE de comandas.
begin;
create table if not exists public.gula_operaciones_comanda (
 clave uuid primary key,
 usuario_id uuid not null references auth.users(id),
 hash_solicitud text not null,
 comanda_id uuid unique references public.gula_comandas(id),
 creado_en timestamptz not null default now()
);
alter table public.gula_operaciones_comanda enable row level security;
revoke all on public.gula_operaciones_comanda from anon,authenticated;

create or replace function public.gula_crear_comanda_segura(
 p_cliente text,p_telefono text,p_fecha_entrega timestamptz,
 p_tipo_entrega text,p_notas text,p_items jsonb,p_clave uuid
) returns jsonb
language plpgsql security definer set search_path=''
as $$
declare
 v_uid uuid:=auth.uid();
 v_hash text;
 v_oper public.gula_operaciones_comanda%rowtype;
 v_fecha date;
 v_total bigint:=0;
 v_items jsonb:='[]'::jsonb;
 v_line record;
 v_prod record;
 v_qty integer;
 v_price integer;
 v_available integer;
 v_order public.gula_comandas%rowtype;
 v_item jsonb;
 v_id uuid;
begin
 if v_uid is null or not exists (
  select 1 from public.gula_usuarios where user_id=v_uid and activo=true
 ) then raise exception 'Acceso denegado' using errcode='42501'; end if;
 if p_clave is null or p_cliente is null or length(btrim(p_cliente))=0
 or p_fecha_entrega is null or p_items is null
 or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0
 or p_tipo_entrega is distinct from 'Retiro' and p_tipo_entrega is distinct from 'Despacho'
 then raise exception 'Comanda inválida' using errcode='22023'; end if;
 if jsonb_array_length(p_items)>100 then raise exception 'Demasiados ítems'; end if;

 v_hash:=md5(jsonb_build_object('cliente',p_cliente,'telefono',p_telefono,
  'fecha',p_fecha_entrega,'tipo',p_tipo_entrega,'notas',p_notas,
  'items',p_items)::text);
 -- Unique key serializa reintentos concurrentes de la misma operación.
 insert into public.gula_operaciones_comanda(clave,usuario_id,hash_solicitud)
 values(p_clave,v_uid,v_hash) on conflict (clave) do nothing;
 select * into v_oper from public.gula_operaciones_comanda
 where clave=p_clave for update;
 if v_oper.usuario_id<>v_uid or v_oper.hash_solicitud<>v_hash
 then raise exception 'Clave reutilizada con otra solicitud' using errcode='23505'; end if;
 if v_oper.comanda_id is not null then
  return jsonb_build_object('comanda_id',v_oper.comanda_id,'repetido',true);
 end if;

 v_fecha:=(p_fecha_entrega at time zone 'America/Santiago')::date;
 -- Rechaza identificadores repetidos en una misma solicitud: evita doble
 -- bloqueo, doble descuento y diferencias de auditoría.
 if exists (
  select 1 from jsonb_array_elements(p_items) e
  group by e->>'product_id' having count(*)>1
 ) then raise exception 'Producto duplicado: consolidar cantidades'; end if;

 -- Bloquea todos los productos en orden estable para evitar interbloqueos.
 for v_prod in
  select p.id,p.nombre,p.precio,p.categoria,p.controla_stock,p.activo
  from public.gula_productos p
  where p.id in (
   select case when (e->>'product_id') ~*
    '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then (e->>'product_id')::uuid else null end
   from jsonb_array_elements(p_items) e
  )
  order by p.id for update
 loop
  -- The row locks are held through the transaction.
  null;
 end loop;

 for v_item in select value from jsonb_array_elements(p_items)
 loop
  if coalesce(v_item->>'product_id','') !~
    '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
  then raise exception 'Identificador de producto inválido'; end if;
  v_id:=(v_item->>'product_id')::uuid;
  if coalesce(v_item->>'qty','') !~ '^[0-9]{1,6}$'
  then raise exception 'Cantidad inválida'; end if;
  v_qty:=(v_item->>'qty')::integer;
  if v_qty<1 then raise exception 'Cantidad debe ser positiva'; end if;

  select id,nombre,precio,categoria,controla_stock,activo into v_prod
  from public.gula_productos where id=v_id;
  if not found or not v_prod.activo then raise exception 'Producto no disponible'; end if;
  v_price:=v_prod.precio;
  if v_price is null or v_price<0 then raise exception 'Precio inválido'; end if;
  v_total:=v_total+v_price::bigint*v_qty;
  if v_total>2147483647 then raise exception 'Total supera límite'; end if;

  if v_prod.controla_stock then
   if v_prod.categoria='PRODUCTOS' then
    update public.gula_stock_general
    set disponible=disponible-v_qty,actualizado_en=now()
    where producto_id=v_id and disponible>=v_qty
    returning disponible into v_available;
   elsif v_prod.categoria='MENU_FINDE' then
    update public.gula_stock_diario
    set disponible=disponible-v_qty,actualizado_en=now()
    where producto_id=v_id and fecha=v_fecha and disponible>=v_qty
    returning disponible into v_available;
   else raise exception 'Categoría sin configurar'; end if;
   if not found then raise exception 'Stock insuficiente o no cargado para %',v_prod.nombre; end if;
  end if;

  v_items:=v_items||jsonb_build_array(jsonb_build_object(
   'product_id',v_id,'name',v_prod.nombre,'qty',v_qty,
   'price',v_price,'note',coalesce(v_item->>'note','')));
 end loop;

 insert into public.gula_comandas
 (cliente,telefono,fecha_entrega,tipo_entrega,estado_pago,notas,items,total,creado_por)
 values (btrim(p_cliente),coalesce(p_telefono,''),p_fecha_entrega,p_tipo_entrega,
 'Pendiente',coalesce(p_notas,''),v_items,v_total::integer,v_uid)
 returning * into v_order;

 -- Auditoría después de insertar comanda: una sola transacción.
 for v_line in
  select (e->>'product_id')::uuid as product_id,
         (e->>'qty')::integer as qty
  from jsonb_array_elements(v_items) e
 loop
  select categoria,controla_stock into v_prod
  from public.gula_productos where id=v_line.product_id;
  if v_prod.controla_stock then
   insert into public.gula_movimientos_stock
   (producto_id,comanda_id,fecha_stock,delta,motivo,creado_por,clave_idempotencia)
   values (v_line.product_id,v_order.id,
    case when v_prod.categoria='MENU_FINDE' then v_fecha else null end,
    -v_line.qty,'RESERVA',v_uid,gen_random_uuid());
  end if;
 end loop;

 update public.gula_operaciones_comanda
 set comanda_id=v_order.id where clave=p_clave;
 return jsonb_build_object('comanda_id',v_order.id,'numero',v_order.numero,
  'total',v_total,'repetido',false);
end
$$;
revoke all on function public.gula_crear_comanda_segura(text,text,timestamptz,text,text,jsonb,uuid)
 from public,anon,authenticated;
commit;

-- LIMITACIONES BLOQUEANTES:
-- A. Falta RPC para editar/cancelar y restituir stock.
-- B. Falta cerrar INSERT directo de gula_comandas y escrituras de stock.
-- C. Falta revisar triggers/defaults/RLS y probar con usuario real.
-- D. Falta lectura de stock y categoría desde interfaz; el cliente debe
--    enviar product_id, no solo name. No usar contra app publicada.
-- E. No concede EXECUTE deliberadamente.
