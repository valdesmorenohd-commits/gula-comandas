# Puesta en marcha de Supabase de pruebas — Gula Comandas

## Objetivo
Probar inventario, abonos y reportes en un proyecto Supabase totalmente independiente, con datos ficticios. **No ejecutar los archivos 001–008 en producción ni copiarlos todavía al proyecto nuevo sin revisión.**

## Paso 1: crear el proyecto
1. En https://supabase.com/dashboard inicia sesión en tu cuenta.
2. Crea un proyecto nuevo, con un nombre claramente distinto, por ejemplo `gula-comandas-pruebas`. No elijas el proyecto existente `yobauucfbpdsrmrjjdhy`.
3. Guarda la contraseña de base de datos en un gestor de contraseñas. No la compartas por chat.
4. En Project Settings / API Keys, identifica la URL y la **publishable key** del proyecto nuevo. No copies claves `secret` ni `service_role` a páginas web.
5. Si el plan no permite crear otro proyecto gratuito, no cambies el proyecto actual: se puede estudiar otra cuenta/organización o un entorno local.

## Paso 2: confirmar aislamiento
- La URL del proyecto nuevo debe ser distinta de `https://yobauucfbpdsrmrjjdhy.supabase.co`.
- No reutilizar usuarios reales, datos de clientes ni teléfonos.
- No vincular GitHub Pages de producción a la base nueva.
- No activar `GULA_STAGING_RPC_ENABLED` todavía.

## Paso 3: diagnóstico seguro
1. Abrir `staging/diagnostico-supabase-pruebas.html` desde un servidor estático de confianza.
2. Introducir **solo** la URL y la clave pública del proyecto de pruebas.
3. Ejecutar la consulta de solo lectura. En un proyecto vacío se esperan errores de tablas inexistentes; eso es normal.
4. Compartir únicamente los nombres de tablas/errores, nunca contraseñas ni claves secretas.

## Paso 4: revisar migraciones antes de ejecutar
- 001 crea tablas y revoca acceso; verificar restricciones y dependencias.
- 003/004: auditar SECURITY DEFINER y permisos.
- 006: validar inserción de comanda, idempotencia, `numero`, restricciones de estado y RLS.
- 007: probar cancelación, dinero recibido y devolución única.
- 008: probar edición, concurrencia, stock por fecha y operaciones históricas.
- Cerrar escrituras directas a `gula_comandas` y cambios de categoría que eludan la reserva.
- Las tablas de pruebas deben ser inicializadas con datos inventados y cuentas de prueba.

## Paso 5: pruebas obligatorias
- Creación y reintento con la misma clave de operación.
- Dos sesiones intentando reservar las últimas unidades.
- Modificar cantidades y fecha de entrega.
- Cancelar una comanda dos veces.
- Registrar pagos parciales en efectivo y TEF; no permitir abonos mayores al saldo.
- Comprobar usuario administrador y usuario normal.
- Verificar que los reportes no mezclen ventas con dinero recibido.

## Condición para avanzar
**Primero** obtener el proyecto de pruebas aislado y validar su esquema; **después** corregir las migraciones y ejecutar pruebas. No hay autorización para alterar producción.
