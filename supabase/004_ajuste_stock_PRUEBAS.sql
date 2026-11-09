-- 004 - FUNCIÓN DE AJUSTE DE INVENTARIO, SOLO PARA PROYECTO DE PRUEBAS
-- Requiere 001. No conectar todavía a guardar comandas: la reserva debe
-- realizarse en la MISMA transacción que la creación/edición de la comanda.
-- Esta RPC se limita a ajustes manuales de inventario por administradores.
-- Los ajustes NO sustituyen el flujo transaccional de pedidos.
begin;
create or replace function public.gula_ajustar_stock(
 p_producto_id uuid,
 p_fecha date,
 p_delta integer,
 p_clave_idempotencia uuid
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
 v_usuario uuid := auth.uid();
 v_categoria text;
 v_controla boolean;
 v_stock integer;
 v_existente public.gula_movimientos_stock%rowtype;
begin
 if v_usuario is null or not exists (
  select 1 from public.gula_usuarios
  where user_id=v_usuario and activo=true and rol='admin'
 ) then raise exception 'Solo administrador' using errcode='42501'; end if;
 if p_producto_id is null or p_delta is null or p_delta=0
    or p_clave_idempotencia is null
 then raise exception 'Datos inválidos' using errcode='22023'; end if;

 -- Bloqueo común por producto: serializa altas, ajustes y configuración
 -- que adopten este mismo protocolo de bloqueo.
 select categoria,controla_stock into v_categoria,v_controla
 from public.gula_productos
 where id=p_producto_id and activo=true for update;
 if not found then raise exception 'Producto inexistente o inactivo'; end if;
 if not v_controla then raise exception 'Control de inventario desactivado'; end if;
 if v_categoria not in ('PRODUCTOS','MENU_FINDE') or v_categoria is null
 then raise exception 'Categoría no configurada'; end if;
 if (v_categoria='MENU_FINDE' and p_fecha is null)
    or (v_categoria='PRODUCTOS' and p_fecha is not null)
 then raise exception 'Fecha incompatible con la categoría'; end if;

 select * into v_existente from public.gula_movimientos_stock
 where clave_idempotencia=p_clave_idempotencia;
 if found then
  if v_existente.producto_id<>p_producto_id
    or v_existente.delta<>p_delta
    or v_existente.motivo<>'AJUSTE'
    or v_existente.fecha_stock is distinct from p_fecha
  then raise exception 'Clave de operación reutilizada con otros datos'; end if;
  if v_categoria='PRODUCTOS' then
   select disponible into v_stock from public.gula_stock_general
   where producto_id=p_producto_id;
  else
   select disponible into v_stock from public.gula_stock_diario
   where producto_id=p_producto_id and fecha=p_fecha;
  end if;
  return jsonb_build_object('repetido',true,'disponible',v_stock,
    'stock_bajo',coalesce(v_stock<=5,false));
 end if;

 if v_categoria='PRODUCTOS' then
  -- No crear automáticamente filas con stock cero: primero cargar existencias.
  update public.gula_stock_general
  set disponible=disponible+p_delta,actualizado_en=now()
  where producto_id=p_producto_id and disponible+p_delta>=0
  returning disponible into v_stock;
 else
  update public.gula_stock_diario
  set disponible=disponible+p_delta,actualizado_en=now()
  where producto_id=p_producto_id and fecha=p_fecha
    and disponible+p_delta>=0
  returning disponible into v_stock;
 end if;
 if not found then
  raise exception 'Stock no configurado o ajuste dejaría saldo negativo';
 end if;

 insert into public.gula_movimientos_stock
 (producto_id,fecha_stock,delta,motivo,creado_por,clave_idempotencia)
 values (p_producto_id,p_fecha,p_delta,'AJUSTE',v_usuario,p_clave_idempotencia);

 return jsonb_build_object('repetido',false,'disponible',v_stock,
   'stock_bajo',v_stock<=5,'agotado',v_stock=0);
end
$$;
revoke all on function public.gula_ajustar_stock(uuid,date,integer,uuid) from public;
revoke all on function public.gula_ajustar_stock(uuid,date,integer,uuid) from anon;
grant execute on function public.gula_ajustar_stock(uuid,date,integer,uuid) to authenticated;
commit;

-- ANTES DE DESPLEGAR: verificar RLS de gula_usuarios y rol exacto 'admin',
-- revocar accesos directos a tablas de stock, probar idempotencia,
-- dos ajustes simultáneos, saldos negativos y categorías incompatibles.
-- Una reserva de comanda NO debe invocar esta RPC por separado.
