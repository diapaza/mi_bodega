# mi_bodega

Aplicación móvil POS/inventario para pequeñas bodegas peruanas (offline-first).

## Seguridad y firma de release

- **PINs:** PBKDF2-HMAC-SHA256 + salt (nunca en claro), con bloqueo por intentos.
- **Sesión:** token en `flutter_secure_storage` (solo su hash en la BD).
- **Backups:** cifrados con AES-256-GCM (passphrase del propietario) antes de subir a Google Drive (carpeta privada de la app).
- **Permisos:** RBAC validado en la lógica (`PermissionGuard`), no solo en la UI.
- **Android:** `android:allowBackup="false"` (el auto-backup del SO no sube la BD en claro).

### Firma de release (Android)

Antes de publicar, configura un keystore de release:

1. Copia `android/key.properties.example` a `android/key.properties`.
2. Genera tu keystore y rellena los valores (ver el `.example`).
3. `flutter build appbundle --release`.

`key.properties` y los `.jks` están en `.gitignore`; no los subas al repositorio.

## Getting Started

This project is a starting point for a Flutter application.


A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
