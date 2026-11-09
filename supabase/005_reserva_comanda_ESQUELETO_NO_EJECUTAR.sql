-- 005 - CREAR COMANDA CON RESERVA ATÓMICA DE STOCK
-- SOLO ENTORNO AISLADO DE PRUEBAS. Requiere 001 y revisión de permisos.
-- IMPORTANTE: La app actual guarda directamente en gula_comandas.
-- No activar esta RPC como solución completa sin bloquear esa ruta y
-- desarrollar edición/cancelación transaccional y lectura segura de stock.
begin;
create or replace function public.gula_crear_comanda_con_stock(
 p_cliente text, p_telefono text, p_fecha_entrega timestamptz,
 p_tipo_entrega text, p_notas text, p_items jsonb,
 p_clave_operacion uuid
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
 v_uid uuid := auth.uid();
 v_fecha date;
 v_total bigint := 0;
 v_comanda public.gula_comandas%rowtype;
 v_item jsonb;
 v_producto record;
 v_cantidad integer;
 v_precio integer;
 v_disponible integer;
 v_id uuid;
 v_nombre text;
 v_items jsonb := '[]'::jsonb;
 v_idx integer;
begin
 if v_uid is null or not exists (
   select 1 from public.gula_usuarios where user_id=v_uid and activo=true
 ) then raise exception 'Usuario no autorizado' using errcode='42501'; end if;
 if p_clave_operacion is null or p_cliente is null
    or length(btrim(p_cliente))=0 or p_fecha_entrega is null
    or p_items is null or jsonb_typeof(p_items)<>'array'
    or jsonb_array_length(p_items)=0
 then raise exception 'Datos de comanda inválidos' using errcode='22023'; end if;
 if p_tipo_entrega not in ('Retiro','Despacho')
 then raise exception 'Tipo de entrega inválido'; end if;

 -- Idempotencia de creación requiere una tabla única separada para evitar
 -- duplicación al reintentar. NO aceptar llamadas hasta tenerla.
 -- Esta función deliberadamente falla de forma segura mientras falte
 -- ese componente, para que nunca se use por accidente en producción.
 raise exception 'RPC 005 pendiente de completar: idempotencia de comanda y edición/cancelación'
   using errcode='0A000';

 -- Plan de implementación (no ejecutado):
 -- 1. Insertar clave única en gula_operaciones_comanda, con hash de payload.
 -- 2. Validar cada producto_id/qty y precio desde gula_productos.
 -- 3. Bloquear todos los productos por UUID en orden estable (FOR UPDATE).
 -- 4. Descontar stock general o diario según fecha de entrega de Chile,
 --    solo cuando controla_stock=true y exista fila de inventario.
 -- 5. Insertar comanda, movimientos y resultado en una transacción.
 -- 6. Repetir clave devuelve la misma comanda, sin volver a descontar.
 -- 7. Editar/cancelar calcula diferencia y restaura stock atómicamente.
 -- 8. Prohibir escrituras directas de comandas que eludan la RPC.
end
$$;
revoke all on function public.gula_crear_comanda_con_stock(text,text,timestamptz,text,text,jsonb,uuid) from public,anon,authenticated;
commit;

-- NO HABILITAR EXECUTE. Esta función es un punto de integración bloqueado
-- a propósito, no una implementación lista para utilizar.
