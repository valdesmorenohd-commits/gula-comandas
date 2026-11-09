-- BORRADOR PARA REVISIÓN: NO EJECUTAR EN PRODUCCIÓN SIN RESPALDO Y PRUEBAS
-- Supone gula_comandas.id UUID y gula_usuarios.user_id UUID.
begin;
create table if not exists public.gula_pagos (
 id uuid primary key default gen_random_uuid(),
 comanda_id uuid not null references public.gula_comandas(id) on delete restrict,
 monto integer not null check (monto > 0),
 medio text not null check (medio in ('Efectivo','TEF')),
 creado_en timestamptz not null default now(),
 registrado_por uuid not null default auth.uid(),
 operacion_id uuid not null unique
);
create index if not exists gula_pagos_comanda_idx on public.gula_pagos(comanda_id);
alter table public.gula_pagos enable row level security;
revoke all on public.gula_pagos from anon, authenticated;
grant select on public.gula_pagos to authenticated;
create policy "usuarios activos pueden ver pagos" on public.gula_pagos for select to authenticated
using (exists (select 1 from public.gula_usuarios u where u.user_id=auth.uid() and u.activo=true));
-- Pagos SOLO a través de la función transaccional; no otorgar INSERT/UPDATE/DELETE directos.
create or replace function public.gula_registrar_pago(p_comanda uuid,p_monto integer,p_medio text,p_operacion uuid)
returns public.gula_pagos
language plpgsql security definer set search_path = ''
as $$
declare v_order public.gula_comandas%rowtype; v_sum bigint; v_pago public.gula_pagos%rowtype;
begin
 if not exists(select 1 from public.gula_usuarios u where u.user_id=auth.uid() and u.activo=true)
 then raise exception 'Usuario no autorizado'; end if;
 if p_monto is null or p_monto<=0 or p_medio not in ('Efectivo','TEF') or p_operacion is null
 then raise exception 'Pago inválido'; end if;
 select * into v_pago from public.gula_pagos where operacion_id=p_operacion;
 if found then
   if v_pago.comanda_id<>p_comanda or v_pago.monto<>p_monto or v_pago.medio<>p_medio
   then raise exception 'Operación duplicada con otros datos'; end if;
   return v_pago;
 end if;
 select * into v_order from public.gula_comandas where id=p_comanda for update;
 if not found then raise exception 'Comanda no encontrada'; end if;
 select coalesce(sum(monto),0) into v_sum from public.gula_pagos where comanda_id=p_comanda;
 if v_sum+p_monto>v_order.total then raise exception 'Monto supera saldo pendiente'; end if;
 insert into public.gula_pagos(comanda_id,monto,medio,registrado_por,operacion_id)
 values(p_comanda,p_monto,p_medio,auth.uid(),p_operacion) returning * into v_pago;
 update public.gula_comandas set estado_pago=case
   when v_sum+p_monto=v_order.total then 'Pagado'
   else 'Abono' end where id=p_comanda;
 return v_pago;
end; $$;
revoke all on function public.gula_registrar_pago(uuid,integer,text,uuid) from public;
grant execute on function public.gula_registrar_pago(uuid,integer,text,uuid) to authenticated;
commit;
-- ADVERTENCIAS: verificar que las políticas actuales de gula_comandas permiten
-- los cambios de estado previstos. Restringir actualizaciones directas del estado
-- de pago y cambios de total que dejen pagos > total antes de activar.
-- Los pedidos antiguos con estado Pagado carecen de movimientos: NO asumir $0 recibido
-- ni inventar medio de pago; requieren conciliación histórica.
