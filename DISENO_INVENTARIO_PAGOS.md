# Diseño de migración — inventario mixto y pagos (NO EJECUTAR AÚN)
Fecha: 2026-11-09

Este archivo es una especificación de trabajo en GitHub, **no una migración aplicada**. El proyecto Supabase mostrado por el usuario contiene las tablas public.gula_productos, gula_comandas, gula_configuracion y gula_usuarios. No se ha comprobado el DDL completo, los triggers, los constraints ni las expresiones de las políticas RLS. No ejecutar SQL contra producción sin respaldo y pruebas.

## Estructura verificada en capturas
- gula_productos: id uuid, nombre text, precio int4, activo bool, creado_en timestamptz, actualizado_en timestamptz. Cuatro políticas RLS.
- gula_comandas: id uuid, numero int8, cliente text, telefono text, fecha_entrega timestamptz, tipo_entrega text, estado_pago text, notas text, items jsonb, total int4, creado_por uuid, creado_en timestamptz, actualizado_en timestamptz. Tres políticas RLS.
- Algunas notas contienen «Efectivo» o «Tef»; otras contienen indicaciones. No migrar notas a medios de pago automáticamente.
- Los items existentes incluyen qty, name, price, note. No presuponer product_id en comandas históricas.

## Propuesta de tablas/campos (pendiente de validar)
1. gula_productos: categoria ('MENU_FINDE' o 'PRODUCTOS'), controla_stock boolean, stock_general integer >= 0. Los productos existentes deben conservar sus valores; asignar categoria explícitamente después de revisión, no por heurística del nombre.
2. gula_stock_diario: id uuid, producto_id uuid FK, fecha date, cantidad_inicial integer, disponible integer, UNIQUE(producto_id, fecha), valores >= 0. Fecha corresponde al calendario de Chile y al día de entrega.
3. gula_pagos: id uuid, comanda_id uuid FK, monto integer > 0, medio ('EFECTIVO','TEF'), creado_en timestamptz, creado_por uuid, clave_idempotencia unique. Múltiples movimientos por comanda; registrar devoluciones/rectificaciones con modelo auditable separado.
4. gula_movimientos_stock: id uuid, producto_id uuid FK, comanda_id uuid nullable, fecha_stock date nullable, delta integer, motivo, creado_en, creado_por, clave_idempotencia unique. Auditoría de reservas, liberaciones y ajustes.

## Reglas funcionales obligatorias
- Stock de MENU_FINDE se controla por fecha de entrega; stock de PRODUCTOS es permanente, sin reinicio diario.
- Al guardar una comanda, descontar stock **una sola vez**, de manera atómica, con validación de saldo disponible y bloqueo de concurrencia. No descontar desde el navegador sin transacción. Si se edita, cambia fecha, o se elimina, revertir/recalcular diferencias dentro de la misma transacción.
- Advertir cuando queden exactamente 5 o menos unidades; mostrar agotado al llegar a 0. No permitir sobreventa salvo decisión explícita del administrador.
- Los pagos no pueden superar el saldo de la comanda; registrar de manera atómica con control de concurrencia e idempotencia.
- Una comanda histórica «Pagado» sin movimientos no debe computarse automáticamente como efectivo o TEF; mostrar «medio no registrado / cobro histórico sin conciliar».
- Reportes por fecha_entrega en America/Santiago, no creado_en; distinguir monto de pedidos, recibido documentado, saldo y cobros históricos sin conciliar. Para conciliación de caja por día de cobro se requerirá otro criterio (fecha del movimiento).
- Conservar los nombres, precios y cantidades históricas en items, incluso si se edita el producto actual.
- Mantener permisos: usuario normal puede crear/consultar; administrador puede editar/eliminar y administrar inventario. Revisar política específica para insertar pagos y operaciones transaccionales; no usar service_role en frontend.
- No activar la nueva interfaz contra producción antes de desplegar y verificar las migraciones; GitHub branch NO separa Supabase.

## Validación previa al despliegue
1. Exportar respaldo verificable de las cuatro tablas y registrar esquema, índices, triggers, RLS y funciones.
2. Crear proyecto Supabase de pruebas aislado y datos ficticios.
3. Revisar constraints y políticas de acceso con cuentas admin y usuario.
4. Ensayar simultaneidad: dos iPhones piden la última unidad; solo uno debe confirmar.
5. Ensayar guardado repetido por falla de conexión, edición, cancelación, cambio de fecha, y varios abonos simultáneos.
6. Verificar fechas límite y cambios de horario Chile; comparar totales con pedidos reales sin mutarlos.
7. Planificar despliegue, respaldo, reversión y monitoreo antes de tocar producción.

## Estado de la rama
- Ya existe búsqueda, controles +/- de cantidad, edición de productos, limpieza tras guardar y vista preliminar de reportes en cloud.js/index.html.
- Aún NO existe integración transaccional de inventario/pagos con Supabase.
- La vista de reportes actual lee hasta 1000 comandas; evitar afirmar totales exhaustivos.
