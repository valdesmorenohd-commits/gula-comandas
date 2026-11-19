# Prueba aislada de acceso · Gula Comandas 2.0

Esta pantalla comprueba **solo Firebase Authentication** con el usuario existente del proyecto `gula-comandas-2-0-pruebas`. No lee ni escribe Firestore, ni permite vender. No incluye la demo v0.5 ni el resto de la app.

## Seguridad
- No almacena contraseñas ni claves privadas en el repositorio.
- `firebaseConfig` es configuración web pública; **no** da permisos de administrador.
- Mantener las reglas Firestore `allow read, write: if false;` hasta disponer de acceso protegido y probado.
- No activar Blaze ni contratar servicios.
- No modificar `main`, GitHub Pages, ni Firebase del sistema actual.

## Publicación opcional desde un entorno con Node.js/Firebase CLI
Clonar este repositorio y cambiar a `gula2-pruebas-spark`. Después ejecutar **desde la raíz**:

```bash
npx --yes firebase-tools login --no-localhost
npx --yes firebase-tools deploy --only hosting --config auth-test/firebase.json --project gula-comandas-2-0-pruebas
```

Comprobar que el proyecto de destino sea exactamente `gula-comandas-2-0-pruebas`. Firebase mostrará una URL de Hosting de pruebas si termina correctamente. Esto puede usar Spark dentro de su cuota gratuita. El comando despliega únicamente `auth-test/` y no modifica reglas ni funciones. Si ya existe un Hosting de pruebas en ese proyecto, este despliegue **reemplaza su contenido visible**, por lo que verificar antes.

## Pendiente
Publicar la demostración v0.5 completa desde su ZIP, luego integrar funciones reales y validar roles, inventario, abonos, caja, auditoría e impresión. No usar para ventas reales.
