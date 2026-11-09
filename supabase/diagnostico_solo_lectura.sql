-- DIAGNÓSTICO DE SOLO LECTURA PARA SUPABASE SQL EDITOR
-- No crea, modifica ni elimina datos. Revisar resultados sin compartir
-- datos personales, contraseñas, claves ni información de clientes.

-- 1. Columnas reales, tipos, nulabilidad y valores por defecto
select table_name, ordinal_position, column_name, data_type, udt_name,
       is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name in ('gula_productos','gula_comandas','gula_configuracion','gula_usuarios')
order by table_name, ordinal_position;

-- 2. Restricciones (PK, FK, CHECK, UNIQUE)
select c.conrelid::regclass::text as tabla, c.conname as restriccion,
       pg_get_constraintdef(c.oid) as definicion
from pg_constraint c
where c.conrelid in (
  'public.gula_productos'::regclass,
  'public.gula_comandas'::regclass,
  'public.gula_configuracion'::regclass,
  'public.gula_usuarios'::regclass
)
order by 1, 2;

-- 3. Políticas RLS (pueden contener detalles de permisos, revisar antes de compartir)
select schemaname, tablename, policyname, permissive, roles, cmd,
       qual as condicion_lectura, with_check as condicion_escritura
from pg_policies
where schemaname='public'
  and tablename in ('gula_productos','gula_comandas','gula_configuracion','gula_usuarios')
order by tablename, policyname;

-- 4. Triggers existentes
select event_object_table as tabla, trigger_name, event_manipulation as evento,
       action_statement
from information_schema.triggers
where event_object_schema='public'
  and event_object_table in ('gula_productos','gula_comandas','gula_configuracion','gula_usuarios')
order by 1,2,3;

-- 5. Índices
select tablename, indexname, indexdef
from pg_indexes
where schemaname='public'
  and tablename in ('gula_productos','gula_comandas','gula_configuracion','gula_usuarios')
order by tablename,indexname;

-- 6. Totales por tabla, sin datos personales
select 'gula_productos' as tabla, count(*) as registros from public.gula_productos
union all select 'gula_comandas',count(*) from public.gula_comandas
union all select 'gula_configuracion',count(*) from public.gula_configuracion
union all select 'gula_usuarios',count(*) from public.gula_usuarios;

-- IMPORTANTE: Ejecutar solo cuando se haya acordado revisar el proyecto.
-- No compartir volcados de filas con clientes, teléfonos, tokens ni secretos.
