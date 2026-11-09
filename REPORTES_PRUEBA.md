# Reportes y abonos — rama de pruebas

**La aplicación de producción y Supabase no se modificaron.**

Abrir `reportes-demo.html` en un navegador para ver el prototipo interactivo (funciona sin internet). Incluye:
- Reporte por **fecha de entrega**, no fecha de creación.
- Resumen de ventas, recibidos y pendientes.
- Agrupación por producto o por comanda.
- Efectivo y TEF separados, múltiples abonos por pedido y saldo actualizado.
- Filtros y exportación CSV para Excel.
- Datos ficticios; sin conexión a Supabase.

## Diseño para integrar en producción
Se necesita una tabla de movimientos de pago, con `comanda_id`, `monto`, `medio`, `creado_en` y un identificador único. Cada pago o abono es un movimiento, no se reemplaza el anterior. El total pagado es la suma de movimientos, y el saldo es el total de la comanda menos lo pagado. Validar que los abonos no superen el saldo, idealmente mediante una operación transaccional en la base de datos.

La consulta debe usar el día calendario de **America/Santiago** de `fecha_entrega` y no el día UTC. Reportar por fecha de entrega implica que los pagos recibidos antes o después aparecen asociados al día de entrega de la comanda, no al día efectivo del cobro.

Antes de activar: revisar políticas RLS existentes y permisos de usuarios; migrar comandas antiguas sin inventar medios de pago; evitar contabilizar pagos duplicados; contemplar cambios en el total y devoluciones; verificar exportaciones y totales con datos de prueba. El estado `Pagado` existente no demuestra un medio de pago: se mostrará `Sin definir` hasta regularizarlo.

**Pendiente:** integrar UI con `cloud.js`, crear migración segura de Supabase y probar con una base de pruebas antes de publicar.
