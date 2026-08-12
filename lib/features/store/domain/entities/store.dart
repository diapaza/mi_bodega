/// Entidad Tienda.
library;


class Store {
  final int? id;
  final String name;
  final String? rucDni;
  final String? address;
  final String? phone;
  final String currency;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Store({
    this.id,
    required this.name,
    this.rucDni,
    this.address,
    this.phone,
    this.currency = 'PEN',
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// Claves de configuración de la aplicación.
class SettingKeys {
  static const currency = 'currency';
  static const storeName = 'store_name';
  static const autoBackup = 'auto_backup';
  static const backupIntervalDays = 'backup_interval_days';
  static const lastBackupAt = 'last_backup_at';

  /// Pedir PIN en cada apertura de la app (seguridad reforzada).
  static const requirePinOnStart = 'require_pin_on_start';

  /// Sesión: hash del token + id de usuario activo.
  static const sessionTokenHash = 'session_token_hash';
  static const sessionUserId = 'session_user_id';

  /// Umbral de diferencia (céntimos) que exige autorización al cerrar caja.
  static const cashDifferenceThreshold = 'cash_difference_threshold';

  /// Backup: cuenta de Google asociada y configuración.
  static const driveAccount = 'drive_account';
  static const backupIncludePhotos = 'backup_include_photos';
  static const backupEncryption = 'backup_encryption';
  static const backupRetention = 'backup_retention';

  /// Bloqueo por intentos (por usuario).
  static String loginFailures(String username) => 'login_failures.$username';
  static String loginLockedUntil(String username) => 'login_locked_until.$username';

  SettingKeys._();
}
