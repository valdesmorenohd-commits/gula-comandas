-- BORRADOR PARA PROYECTO SUPABASE DE PRUEBAS. NO EJECUTAR EN PRODUCCIÓN.
-- Requiere verificar previamente tipos de PK, esquema, RLS, roles y funciones existentes.
-- Esta migración solo CREA tablas auxiliares; no cambia datos ni columnas existentes.
begin;

create table if not exists public.gula_pagos (
  id uuid primary key default gen_random_uuid(),
  comanda_id uuid not null references public.gula_comandas(id) on delete restrict,
  monto integer not null check (monto > 0),
  medio text not null check (medio in ('EFECTIVO','TEF')),
  creado_en timestamptz not null default now(),
  creado_por uuid references auth.users(id),
  clave_idempotencia uuid not null unique
);
create index if not exists gula_pagos_comanda_idx on public.gula_pagos(comanda_id);
create index if not exists gula_pagos_fecha_idx on public.gula_pagos(creado_en);
alter table public.gula_pagos enable row level security;
-- Sin políticas todavía: acceso directo desde clientes bloqueado.
-- Los pagos deben registrarse mediante función transaccional con autorización
-- verificada y bloqueo de la comanda, no por INSERT directo desde el navegador.

create table if not exists public.gula_stock_diario (
  id uuid primary key default gen_random_uuid(),
  producto_id uuid not null references public.gula_productos(id) on delete restrict,
  fecha date not null,
  cantidad_inicial integer not null check (cantidad_inicial >= 0),
  disponible integer not null check (disponible >= 0),
  unique(producto_id, fecha)
);
alter table public.gula_stock_diario enable row level security;

create table if not exists public.gula_stock_general (
  producto_id uuid primary key references public.gula_productos(id) on delete restrict,
  disponible integer not null default 0 check (disponible >= 0)
);
alter table public.gula_stock_general enable row level security;

create table if not exists public.gula_movimientos_stock (
  id uuid primary key default gen_random_uuid(),
  producto_id uuid not null references public.gula_productos(id) on delete restrict,
  comanda_id uuid references public.gula_comandas(id) on delete restrict,
  fecha_stock date,
  delta integer not null check (delta <> 0),
  motivo text not null check (motivo in ('RESERVA','LIBERACION','AJUSTE')),
  creado_en timestamptz not null default now(),
  creado_por uuid references auth.users(id),
  clave_idempotencia uuid not null unique
);
create index if not exists gula_movimientos_stock_comanda_idx on public.gula_movimientos_stock(comanda_id);
alter table public.gula_movimientos_stock enable row level security;

commit;

-- IMPORTANTE:
-- 1. No insertar pagos históricos inferidos de estado_pago ni de notas.
-- 2. No exponer INSERT/UPDATE/DELETE a clientes sin transacciones y permisos.
-- 3. Faltan función RPC de guardado atómico, validaciones de roles, RLS de lectura,
--    catálogo de categoría/control de stock y plan de migración de pedidos.
-- 4. Los reportes por fecha de entrega no equivalen a cierre de caja por fecha de cobro.
