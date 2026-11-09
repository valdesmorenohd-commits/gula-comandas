-- 007: CANCELACIÓN CON RESTITUCIÓN DE STOCK (CANDIDATA PARA PRUEBAS)
-- NO EJECUTAR EN PRODUCCIÓN. Depende de 001 y 006.
-- Requiere verificar esquema real, roles, triggers y RLS antes de habilitar.
-- Mantiene historial: NO elimina comandas. No realiza devoluciones de dinero.
begin;
alter table public.gula_comandas
 add column if not exists cancelada boolean not null default false,
 add column if not exists cancelada_en timestamptz;

create or replace function public.gula_cancelar_comanda_segura(
 p_comanda_id uuid
) returns jsonb
language plpgsql security definer set search_path=''
as $$
declare
 v_uid uuid:=auth.uid();
 v_order public.gula_comandas%rowtype;
 v_line record;
 v_producto record;
 v_fecha date;
 v_mov record;
 v_total_pagado bigint;
begin
 if v_uid is null or not exists (
  select 1 from public.gula_usuarios
  where user_id=v_uid and activo=true and rol='admin'
 ) then raise exception 'Solo administrador' using errcode='42501'; end if;
 if p_comanda_id is null then raise exception 'Comanda requerida'; end if;

 select * into v_order from public.gula_comandas
 where id=p_comanda_id for update;
 if not found then raise exception 'Comanda inexistente'; end if;
 if v_order.cancelada then
  return jsonb_build_object('comanda_id',p_comanda_id,'repetido',true);
 end if;

 -- Cancelación de pedido con dinero recibido exige flujo explícito
 -- de devolución y conciliación. No suponer que Pagado equivale a abonos.
 select coalesce(sum(monto),0) into v_total_pagado
 from public.gula_pagos where comanda_id=p_comanda_id;
 if v_total_pagado>0 or v_order.estado_pago in ('Pagado','Abono') then
  raise exception 'Comanda con pagos o estado histórico: conciliar antes de cancelar';
 end if;

 v_fecha:=(v_order.fecha_entrega at time zone 'America/Santiago')::date;

 -- Solo restituir movimientos que realmente fueron descontados por el
 -- mecanismo nuevo. Las comandas históricas no tienen reservas.
 for v_mov in
  select producto_id,fecha_stock,-sum(delta)::integer as devolver
  from public.gula_movimientos_stock
  where comanda_id=p_comanda_id and motivo in ('RESERVA','LIBERACION')
  group by producto_id,fecha_stock
  having sum(delta)<0
  order by producto_id
 loop
  -- La fila de producto se bloquea como en la RPC de creación.
  select id,categoria into v_producto from public.gula_productos
  where id=v_mov.producto_id for update;
  if not found then raise exception 'Producto de reserva no encontrado'; end if;

  if v_mov.fecha_stock is null then
   update public.gula_stock_general
   set disponible=disponible+v_mov.devolver,actualizado_en=now()
   where producto_id=v_mov.producto_id;
  else
   update public.gula_stock_diario
   set disponible=disponible+v_mov.devolver,actualizado_en=now()
   where producto_id=v_mov.producto_id and fecha=v_mov.fecha_stock;
  end if;
  if not found then raise exception 'No existe fila de stock para devolver'; end if;

  insert into public.gula_movimientos_stock
   (producto_id,comanda_id,fecha_stock,delta,motivo,creado_por,clave_idempotencia)
  values (v_mov.producto_id,p_comanda_id,v_mov.fecha_stock,
   v_mov.devolver,'LIBERACION',v_uid,gen_random_uuid());
 end loop;

 update public.gula_comandas
 set cancelada=true,cancelada_en=now(),actualizado_en=now()
 where id=p_comanda_id;

 return jsonb_build_object('comanda_id',p_comanda_id,'repetido',false,
  'cancelada',true);
end
$$;
revoke all on function public.gula_cancelar_comanda_segura(uuid)
 from public,anon,authenticated;
commit;

-- BLOQUEOS ANTES DE PRODUCCIÓN:
-- 1. NO concede EXECUTE: pendiente auditoría de seguridad y pruebas.
-- 2. Debe prohibirse borrar/editar directamente comandas desde cliente.
-- 3. El historial/reportes deben excluir canceladas de ventas y conservar
--    el registro para auditoría.
-- 4. Falta edición con diferencias de stock y cambio de fecha.
-- 5. La suma de movimientos exige que ningún otro flujo registre reservas
--    fuera del mismo protocolo; revisar operaciones históricas.
-- 6. Falta flujo de devoluciones de dinero, especialmente Pagado/Abono.
