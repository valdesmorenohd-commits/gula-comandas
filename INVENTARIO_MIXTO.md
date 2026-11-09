# Inventario mixto Gula — diseño de integración

## Categorías
- **MENÚ FINDE**: inventario separado por `producto_id + fecha_entrega` (zona horaria America/Santiago).
- **PRODUCTOS**: inventario general por `producto_id`, sin separación por día.
- Cada producto tiene `controla_stock` (sí/no). Desactivado significa venta sin límite; nunca se descuenta stock.

## Reglas
- Al llegar a 5 unidades, mostrar advertencia; a 0, mostrar AGOTADO e impedir nuevas reservas.
- La validación debe ejecutarse en Supabase dentro de una transacción, no solamente en el navegador, para evitar sobreventa entre dos iPhones.
- Guardar pedido nuevo: reservar cantidades. Editar: ajustar diferencia. Cambiar fecha: devolver stock a fecha anterior y reservar en nueva. Eliminar: liberar reserva.
- La edición o eliminación de una comanda debe actualizar pedido y stock atómicamente, con registro auditable de ajustes.
- Evitar doble descuento al reintentar guardar (identificador idempotente por operación).
- Definir si los menús no vendidos al terminar el día caducan; no trasladarlos automáticamente a otro día.

## Pagos y reportes
- Registrar movimientos independientes de pago: comanda, monto, medio (Efectivo/TEF), fecha y usuario.
- Saldo = total - suma de pagos. No permitir sobrepago. Para devoluciones o correcciones, registrar ajuste autorizado en lugar de borrar movimientos sin trazabilidad.
- Reportes agrupados por fecha de entrega en America/Santiago; mostrar montos recibidos por medio y saldo por cobrar.
- Las comandas históricas sin movimientos requieren migración cuidadosa: conservar su estado, no inventar el medio de pago ni asumir que el dinero fue recibido en una fecha concreta.

## Estado de implementación
- Rama de prueba incluye ya cambios en `index.html` y `cloud.js`: buscador de productos, cantidad +/−, edición de productos, limpieza al guardar.
- Inventario mixto y pagos reales todavía NO están conectados a Supabase. Se requiere revisar el esquema, las políticas RLS y ejecutar pruebas de concurrencia antes de publicar.
- El prototipo de reportes `reportes-demo.html` usa datos ficticios.
