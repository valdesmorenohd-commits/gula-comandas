# Gula Comandas 2.0 — rama de pruebas

**NO ES PRODUCCIÓN. No utilizar para ventas reales.**

Esta rama fue creada para trabajar separadamente de `main`. El sistema anterior Gula permanece sin cambios en `main`. **El código de la v0.5 todavía no está subido a esta rama**, ni la app está publicada; la versión v0.5 está disponible como ZIP en el chat.

## Decisiones confirmadas
- Firebase proyecto: `gula-comandas-2-0-pruebas`, plan Spark, sin facturación.
- Comienzo: cero comandas, cero clientes reales, ninguna migración del sistema anterior.
- Cliente móvil iPhone, PC Windows y tablet Android.
- Módulos: nueva comanda, historial, productos, inventario, caja, clientes, informes y administración.
- Las reglas de Firestore permanecen restrictivas; evitar abrir accesos públicos.
- No configurar respaldos de historial antiguo; antes de producción, proteger únicamente futuras ventas reales.
- Los cobros, stock y auditorías requieren operaciones seguras con validación de servidor o reglas estrictas probadas.

## Próximo despliegue
La demostración v0.5 puede subirse a Firebase Hosting sin Blaze desde un entorno con Firebase CLI utilizando el archivo `firebase.preview.json` y `--only hosting`. Eso **no** conecta operaciones reales. No tocar la configuración de GitHub Pages del sistema anterior.
