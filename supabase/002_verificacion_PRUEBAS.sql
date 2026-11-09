-- 002 - COMPROBACIONES NO DESTRUCTIVAS PARA PROYECTO DE PRUEBAS
-- Ejecutar solo después de 001; todas las consultas son de lectura.
select table_name,column_name,data_type
from information_schema.columns
where table_schema='public'
and table_name in ('gula_productos','gula_pagos','gula_stock_general','gula_stock_diario','gula_movimientos_stock')
order by table_name,ordinal_position;

select tablename, rowsecurity
from pg_tables where schemaname='public'
and tablename in ('gula_pagos','gula_stock_general','gula_stock_diario','gula_movimientos_stock');

select 'pagos' as tabla,count(*) as registros from public.gula_pagos
union all select 'stock_general',count(*) from public.gula_stock_general
union all select 'stock_diario',count(*) from public.gula_stock_diario
union all select 'movimientos_stock',count(*) from public.gula_movimientos_stock;

select categoria,controla_stock,count(*) as productos
from public.gula_productos group by categoria,controla_stock;

-- Las nuevas tablas deben comenzar vacías y todos los productos existentes
-- con controla_stock=false, para no bloquear ventas antes de integrar RPC.
