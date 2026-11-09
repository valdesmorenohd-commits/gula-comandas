-- 001 - MIGRACIÓN DE ESTRUCTURA GULA (SOLO ENTORNO DE PRUEBAS)
-- NO EJECUTAR EN PRODUCCIÓN SIN RESPALDO Y REVISIÓN DE RLS/DEPENDENCIAS.
-- Precondición: tablas public.gula_productos y public.gula_comandas con id uuid.
-- NO migra notas ni infiere medios de pago de registros históricos.
-- Crea estructuras sin cambiar valores de pedidos ni descontar inventario.
begin;

alter table public.gula_productos
  add column if not exists categoria text,
  add column if not exists controla_stock boolean not null default false;

-- Sin clasificación automática: productos existentes quedan con categoria NULL.
alter table public.gula_productos
  drop constraint if exists gula_productos_categoria_chk;
alter table public.gula_productos
  add constraint gula_productos_categoria_chk
  check (categoria is null or categoria in ('MENU_FINDE','PRODUCTOS'));

create table if not exists public.gula_stock_general (
  producto_id uuid primary key references public.gula_productos(id) on delete restrict,
  disponible integer not null default 0 check (disponible >= 0),
  actualizado_en timestamptz not null default now()
);
create table if not exists public.gula_stock_diario (
  id uuid primary key default gen_random_uuid(),
  producto_id uuid not null references public.gula_productos(id) on delete restrict,
  fecha date not null,
  cantidad_inicial integer not null check (cantidad_inicial >= 0),
  disponible integer not null check (disponible >= 0),
  actualizado_en timestamptz not null default now(),
  unique(producto_id,fecha)
);
create table if not exists public.gula_pagos (
  id uuid primary key default gen_random_uuid(),
  comanda_id uuid not null references public.gula_comandas(id) on delete restrict,
  monto integer not null check (monto > 0),
  medio text not null check (medio in ('EFECTIVO','TEF')),
  creado_en timestamptz not null default now(),
  creado_por uuid references auth.users(id),
  clave_idempotencia uuid not null unique
);
create table if not exists public.gula_movimientos_stock (
  id uuid primary key default gen_random_uuid(),
  producto_id uuid not null references public.gula_productos(id) on delete restrict,
  comanda_id uuid references public.gula_comandas(id) on delete restrict,
  fecha_stock date,
  delta integer not null check (delta <> 0),
  motivo text not null check (motivo in ('RESERVA','LIBERACION','AJUSTE')),
  creado_en timestamptz not null default now(),
  creado_por uuid references auth.users(id),
  clave_idempotencia uuid not null unique,
  constraint gula_mov_stock_fecha_chk check (fecha_stock is null or fecha_stock >= date '2020-01-01')
);
create index if not exists gula_pagos_comanda_idx on public.gula_pagos(comanda_id);
create index if not exists gula_pagos_fecha_idx on public.gula_pagos(creado_en);
create index if not exists gula_movimientos_comanda_idx on public.gula_movimientos_stock(comanda_id);
create index if not exists gula_movimientos_producto_idx on public.gula_movimientos_stock(producto_id,fecha_stock);

-- Sin políticas de cliente: acceso bloqueado hasta validar roles y RPC.
alter table public.gula_stock_general enable row level security;
alter table public.gula_stock_diario enable row level security;
alter table public.gula_pagos enable row level security;
alter table public.gula_movimientos_stock enable row level security;

-- Revocar acceso directo a tablas nuevas a roles cliente; funciones RPC
-- posteriores deberán controlar autenticación y transacciones.
revoke all on public.gula_stock_general from anon, authenticated;
revoke all on public.gula_stock_diario from anon, authenticated;
revoke all on public.gula_pagos from anon, authenticated;
revoke all on public.gula_movimientos_stock from anon, authenticated;

commit;

-- SIGUIENTE FASE: antes de usar en la app, validar esquema y permisos reales,
-- crear funciones transaccionales de reservas y pagos con control de acceso,
-- ejecutar pruebas concurrentes y preparar despliegue con reversión.
