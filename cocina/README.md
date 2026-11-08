# Gula Cocina — prototipo aislado (Windows)

Esta rama NO modifica la aplicación publicada ni la base de datos Supabase.

## Qué funciona
- Generador de ticket de cocina: número de comanda, cliente, hora, cantidades, productos y observaciones.
- Omite teléfono, precios, total y estado de pago.
- Simulación local sin impresora ni conexión a Supabase.
- Envío opcional por TCP/9100 a una impresora ESC/POS Ethernet, cuando se disponga de hardware compatible.

## Probar en Windows
1. Instalar Python 3.10 o posterior.
2. Abrir una terminal en esta carpeta.
3. Ejecutar: `python cocina/prueba_ticket.py`
4. Debe aparecer el ticket de ejemplo y el mensaje SIMULACION.

**Solo después de verificar el modelo y la IP de una impresora ESC/POS Ethernet**, probar:
`python cocina/prueba_ticket.py --ip 192.168.1.100`
La IP es un ejemplo, no la dirección real de tu equipo.

## Pendiente antes de automatizar
- Crear cola segura en Supabase para pedidos NUEVOS (no modificaciones), mediante migración SQL y políticas de acceso.
- Servicio Windows autenticado que lea la cola, registre intentos, recupere pendientes y permita reimpresión manual.
- Prueba física con la impresora elegida y configuración de caracteres en español.
- Definir qué hacer ante cortes de conexión y evitar duplicados (no se puede garantizar impresión física exactamente una vez sin confirmación del hardware).

No guardar contraseñas de Supabase ni claves de servicio en GitHub. No comprar impresora hasta comprobar compatibilidad y presupuesto.
