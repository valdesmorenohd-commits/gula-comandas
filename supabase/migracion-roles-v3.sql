-- Gula v3: ejecutar en Supabase SQL Editor DESPUÉS de identificar el UID administrador.
-- Sustituir ADMIN_UID y FELIPE_UID por los IDs correctos de auth.users.
alter table public.gula_usuarios add column if not exists nombre text;
alter table public.gula_usuarios add column if not exists rol text not null default 'usuario';
alter table public.gula_usuarios drop constraint if exists gula_usuarios_rol_check;
alter table public.gula_usuarios add constraint gula_usuarios_rol_check check (rol in ('admin','usuario'));
-- No aplicar roles por defecto a un usuario equivocado: identificar las cuentas antes.
-- update public.gula_usuarios set nombre='Daniel',rol='admin' where user_id='ADMIN_UID';
-- update public.gula_usuarios set nombre='Felipe',rol='usuario' where user_id='FELIPE_UID';
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
create policy "gula_usuarios_update_admin" on public.gula_usuarios as restrictive for update to authenticated using (public.gula_es_admin()) with check (public.gula_es_admin());
create policy "gula_usuarios_delete_admin" on public.gula_usuarios as restrictive for delete to authenticated using (public.gula_es_admin());
create policy "gula_usuarios_insert_admin" on public.gula_usuarios as restrictive for insert to authenticated with check (public.gula_es_admin());
-- La creación de cuentas auth.users debe hacerse con una Edge Function y service role SOLO en servidor.
