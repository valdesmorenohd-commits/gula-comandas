-- Gula v3: ejecutar en Supabase SQL Editor en una sola transacción. Verificar primero el respaldo y las políticas existentes.
begin;
do $gula$ begin
 if (select count(*) from auth.users where lower(email) in ('valdesmoreno.hd@gmail.com','fortega1991@gmail.com')) <> 2 then
  raise exception 'No se encontraron exactamente las dos cuentas de Gula. No se aplicó ningún cambio.';
 end if;
 if (select count(*) from public.gula_usuarios gu join auth.users au on au.id=gu.user_id where lower(au.email) in ('valdesmoreno.hd@gmail.com','fortega1991@gmail.com') and gu.activo) <> 2 then
  raise exception 'Las dos cuentas deben estar activas en gula_usuarios. No se aplicó ningún cambio.';
 end if;
end $gula$;
alter table public.gula_usuarios add column if not exists nombre text;
alter table public.gula_usuarios add column if not exists rol text not null default 'usuario';
alter table public.gula_usuarios drop constraint if exists gula_usuarios_rol_check;
alter table public.gula_usuarios add constraint gula_usuarios_rol_check check (rol in ('admin','usuario'));
update public.gula_usuarios gu set nombre='Daniel',rol='admin' from auth.users au where gu.user_id=au.id and lower(au.email)='valdesmoreno.hd@gmail.com';
update public.gula_usuarios gu set nombre='Felipe',rol='usuario' from auth.users au where gu.user_id=au.id and lower(au.email)='fortega1991@gmail.com';
create or replace function public.gula_es_admin() returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.gula_usuarios where user_id=(select auth.uid()) and activo=true and rol='admin');
$$;
revoke all on function public.gula_es_admin() from public;
grant execute on function public.gula_es_admin() to authenticated;
-- Retirar las políticas anteriores que permitan modificar o borrar sin comprobar rol.
-- IMPORTANTE: comprobar los nombres de las políticas actuales en pg_policies antes de continuar.
-- No ejecutar una migración parcial: cualquier política antigua permisiva anularía estas restricciones.
-- Nuevas políticas restrictivas (se suman con AND a las permisivas):
create policy "gula_comandas_actualizacion_admin_restrictiva" on public.gula_comandas as restrictive for update to authenticated using (public.gula_es_admin()) with check (public.gula_es_admin());
create policy "gula_comandas_eliminacion_admin_restrictiva" on public.gula_comandas as restrictive for delete to authenticated using (public.gula_es_admin());
create policy "gula_productos_insert_admin" on public.gula_productos as restrictive for insert to authenticated with check (public.gula_es_admin());
create policy "gula_productos_update_admin" on public.gula_productos as restrictive for update to authenticated using (public.gula_es_admin()) with check (public.gula_es_admin());
create policy "gula_productos_delete_admin" on public.gula_productos as restrictive for delete to authenticated using (public.gula_es_admin());
create policy "gula_configuracion_insert_admin" on public.gula_configuracion as restrictive for insert to authenticated with check (public.gula_es_admin());
create policy "gula_configuracion_update_admin" on public.gula_configuracion as restrictive for update to authenticated using (public.gula_es_admin()) with check (public.gula_es_admin());
create policy "gula_configuracion_delete_admin" on public.gula_configuracion as restrictive for delete to authenticated using (public.gula_es_admin());
create policy "gula_usuarios_select_admin" on public.gula_usuarios for select to authenticated using (public.gula_es_admin());
create policy "gula_usuarios_update_admin_allow" on public.gula_usuarios for update to authenticated using (public.gula_es_admin()) with check (public.gula_es_admin());
create policy "gula_usuarios_insert_admin_allow" on public.gula_usuarios for insert to authenticated with check (public.gula_es_admin());
create policy "gula_usuarios_update_admin" on public.gula_usuarios as restrictive for update to authenticated using (public.gula_es_admin()) with check (public.gula_es_admin());
create policy "gula_usuarios_delete_admin" on public.gula_usuarios as restrictive for delete to authenticated using (public.gula_es_admin());
create policy "gula_usuarios_insert_admin" on public.gula_usuarios as restrictive for insert to authenticated with check (public.gula_es_admin());
-- Los administradores no deben desactivarse ni quitarse su propio rol por error.
create or replace function public.gula_proteger_admin_propio() returns trigger language plpgsql security definer set search_path=public as $gula$
begin
 if old.user_id = auth.uid() and old.rol='admin' and (new.rol<>'admin' or new.activo is distinct from true) then
  raise exception 'No puedes quitar tu propio acceso de administrador';
 end if;
 return new;
end $gula$;
drop trigger if exists gula_evitar_autobloqueo on public.gula_usuarios;
create trigger gula_evitar_autobloqueo before update on public.gula_usuarios for each row execute function public.gula_proteger_admin_propio();
-- La creación de cuentas auth.users debe hacerse con una Edge Function y service role SOLO en servidor.

commit;
