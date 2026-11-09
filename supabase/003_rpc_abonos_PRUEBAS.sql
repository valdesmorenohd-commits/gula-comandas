-- 003: FUNCIÓN DE ABONOS (EXCLUSIVAMENTE EN PROYECTO DE PRUEBAS)
-- Requiere ejecutar 001 primero y verificar estructura y políticas RLS.
-- No habilitar en producción hasta bloquear la edición directa de total y estado_pago,
-- definir conciliación de pedidos antiguos y validar el acceso real de usuarios.
begin;

create or replace function public.gula_registrar_abono(
 p_comanda_id uuid, p_monto integer, p_medio text, p_clave_idempotencia uuid
) returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
 v_usuario uuid := auth.uid();
 v_orden public.gula_comandas%rowtype;
 v_existente public.gula_pagos%rowtype;
 v_pagado bigint;
 v_pago public.gula_pagos%rowtype;
begin
 if v_usuario is null or not exists (
  select 1 from public.gula_usuarios
  where user_id=v_usuario and activo=true
 ) then raise exception 'Usuario no autorizado' using errcode='42501'; end if;

 if p_comanda_id is null or p_clave_idempotencia is null
 or p_monto is null or p_monto<=0
 or p_medio is null or p_medio not in ('EFECTIVO','TEF')
 then raise exception 'Datos del abono inválidos' using errcode='22023'; end if;

 -- Serializa abonos de la misma comanda; evita sobrepago simultáneo.
 select * into v_orden from public.gula_comandas
 where id=p_comanda_id for update;
 if not found then raise exception 'Comanda no encontrada' using errcode='P0002'; end if;

 -- No convertir automáticamente registros antiguos marcados como pagados:
 -- carecen de medio de pago y fecha verificable.
 if v_orden.estado_pago='Pagado' and not exists (
  select 1 from public.gula_pagos where comanda_id=p_comanda_id
 ) then
  raise exception 'Comanda histórica pagada: requiere conciliación antes de registrar abonos'
   using errcode='22023';
 end if;

 select * into v_existente from public.gula_pagos
 where clave_idempotencia=p_clave_idempotencia;
 if found then
  if v_existente.comanda_id<>p_comanda_id
    or v_existente.monto<>p_monto or v_existente.medio<>p_medio then
   raise exception 'Clave de operación reutilizada con datos distintos' using errcode='23505';
  end if;
  select coalesce(sum(monto),0) into v_pagado from public.gula_pagos
   where comanda_id=p_comanda_id;
  return jsonb_build_object('pago_id',v_existente.id,'repetido',true,
    'abonado',v_pagado,'saldo',v_orden.total-v_pagado);
 end if;

 select coalesce(sum(monto),0) into v_pagado from public.gula_pagos
 where comanda_id=p_comanda_id;
 if v_orden.total is null or v_orden.total<0 or v_pagado+p_monto>v_orden.total
 then raise exception 'El abono supera el saldo disponible' using errcode='22023'; end if;

 insert into public.gula_pagos
  (comanda_id,monto,medio,creado_por,clave_idempotencia)
 values (p_comanda_id,p_monto,p_medio,v_usuario,p_clave_idempotencia)
 returning * into v_pago;

 -- Esta actualización NO sustituye la necesidad de proteger modificaciones
 -- directas del total y estado_pago por otras rutas de la aplicación.
 update public.gula_comandas
 set estado_pago=case when v_pagado+p_monto=v_orden.total then 'Pagado' else 'Abono' end,
     actualizado_en=now()
 where id=p_comanda_id;

 return jsonb_build_object('pago_id',v_pago.id,'repetido',false,
  'abonado',v_pagado+p_monto,'saldo',v_orden.total-v_pagado-p_monto);
end
$$;

revoke all on function public.gula_registrar_abono(uuid,integer,text,uuid) from public;
revoke all on function public.gula_registrar_abono(uuid,integer,text,uuid) from anon;
grant execute on function public.gula_registrar_abono(uuid,integer,text,uuid) to authenticated;
commit;

-- PRUEBAS OBLIGATORIAS ANTES DE USO:
-- 1. Cuenta no autorizada debe recibir error.
-- 2. Dos abonos simultáneos que excedan saldo: solo uno debe confirmar.
-- 3. Misma clave y mismos datos: devuelve repetido=true sin duplicar.
-- 4. Misma clave y datos distintos: rechaza.
-- 5. Comanda histórica Pagado sin movimientos: rechaza.
-- 6. Modificación de total después de pagar: debe impedirse en capa DB.
-- 7. Usuario normal: confirmar autorización esperada y políticas vigentes.
-- 8. SQL Editor ejecuta como rol privilegiado: no sirve para probar RLS de clientes.
