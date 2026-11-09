# Plan de integración y criterios de aceptación — Gula Comandas
**Estado:** pendiente de pruebas. No habilitar en producción.

## Bloqueos detectados al revisar la rama
1. `cloud.js` guarda comandas directamente en `gula_comandas`, sin reservar stock; no basta con añadir el adaptador. Hay que sustituir todas las rutas de alta, edición y eliminación por RPC seguras.
2. `cart` conserva `name,qty,price,note`, pero las nuevas RPC exigen `product_id`. Debe preservarse el ID al agregar, editar y reabrir una comanda.
3. El formulario ofrece `Pendiente/Pagado/Abono` sin movimientos reales. La nueva versión debe separar estado derivado de pagos de la captura de efectivo/TEF; jamás marcar pagado sin un movimiento verificado.
4. `refresh()` consulta como máximo 1000 comandas y no obtiene pagos ni existencias. Los reportes no pueden presentarse como completos hasta implementar paginación/consulta agregada del servidor.
5. La pantalla de historial elimina comandas directamente; la nueva versión debe cancelar sin borrar, y excluir canceladas de totales de venta.
6. La tabla `gula_productos` se consulta solo con `activo=true`. No asignar categorías automáticamente: se requiere revisión de los productos existentes.
7. Las funciones 003, 004, 006, 007 y 008 son candidatas. Falta auditar los privilegios SECURITY DEFINER, RLS, cambios directos al catálogo, permisos de ejecución y bloqueo concurrente de productos.
8. No usar la base Supabase de producción para ensayar. Crear un proyecto de pruebas con datos ficticios y cuentas separadas.

## Pantallas a integrar, en orden
### Productos
- Categoría: PRODUCTOS o MENÚ FINDE.
- Control de stock opcional; cargar existencias por fecha para MENÚ FINDE y generales para PRODUCTOS.
- Mostrar stock bajo (1–5), agotado (0) y sin control; distinguir stock no cargado.
- Bloquear cambios de categoría cuando existan reservas sin conciliar.

### Nueva comanda
- Selección guarda `product_id` y cantidad; consolidar líneas repetidas.
- No confiar en precio enviado desde el navegador: el servidor usa el catálogo.
- Generar UUID de operación una sola vez por intento; conservarlo en reintentos.
- Tras éxito, mostrar número de comanda y limpiar formulario.
- Tras error de red ambiguo, consultar resultado por clave antes de permitir un nuevo pedido.

### Historial
- Edición y cancelación solo administrador, mediante RPC.
- Comandas antiguas sin trazabilidad de inventario: edición especial o bloqueo supervisado.
- Mostrar canceladas y permitir filtrar, sin borrarlas.
- Pagos: agregar abonos en efectivo/TEF, saldo calculado, historial auditable.
- Si existe dinero recibido, exigir conciliación antes de cancelar.

### Reportes
- Usar fecha de entrega en America/Santiago para ventas.
- Mostrar separado: ventas, pagos registrados, saldos, pagos históricos no conciliados.
- Excluir canceladas del total vendido sin ocultar historial.
- Consulta completa, no limitada a 1000 filas, antes de ofrecer cierre oficial.
- CSV con protección ante fórmulas inyectadas en campos de texto.

## Matriz mínima de pruebas (proyecto aislado)
| Caso | Resultado esperado |
| --- | --- |
| Crear 3 brownies de 10 | Quedan 7; un solo movimiento de reserva |
| Reintentar con misma clave | Misma comanda; no vuelve a descontar |
| Dos teléfonos compran últimas 2 unidades | Solo una operación confirma |
| Crear con stock insuficiente | No se guarda pedido ni movimiento |
| Editar 3 a 5 | Descuento neto 2 |
| Editar 5 a 2 | Devuelve neto 3 |
| Mover pedido sábado a domingo | Devuelve al sábado y descuenta domingo |
| Cancelar sin pagos | Restituye una vez y conserva historial |
| Cancelar dos veces | Segunda operación no restituye |
| Abonar 1000 y luego 2000 | Suma 3000, saldo correcto |
| Dos abonos que superan saldo | Solo uno confirma |
| Reintentar mismo abono | No se duplica |
| Comanda histórica Pagado | No inventa efectivo ni TEF |
| Usuario no autorizado | Todas las RPC rechazan |
| Usuario normal edita stock | Rechazado |
| Cambio directo de tabla desde navegador | Rechazado por permisos/RLS |
| 1001+ comandas | Reportes completos y paginados |
| Cambio de hora Chile | Fecha local de entrega correcta |

## Puerta de despliegue
No desplegar hasta que se cumplan todos:
- [ ] Respaldo recuperable y verificado
- [ ] Diagnóstico de esquema, triggers y RLS completado
- [ ] Supabase de pruebas aislado
- [ ] Funciones revisadas y ejecutadas con cuentas de prueba
- [ ] Escrituras directas antiguas cerradas
- [ ] UI conectada a RPC, sin modo antiguo que eluda stock
- [ ] Conciliación de pedidos históricos definida
- [ ] Matriz de pruebas aprobada
- [ ] Plan de reversión ensayado
- [ ] Aprobación explícita para migrar producción

**No se ha ejecutado SQL ni alterado Supabase desde GitHub.**
