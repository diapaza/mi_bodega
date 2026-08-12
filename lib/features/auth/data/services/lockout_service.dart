import 'package:mi_bodega/core/database/daos.dart' as daos;
import 'package:mi_bodega/features/store/domain/entities/store.dart';

/// Resultado de la consulta de bloqueo.
class LockStatus {
  final bool locked;
  final DateTime? lockedUntil;

  const LockStatus({required this.locked, this.lockedUntil});

  int? get remainingSeconds {
    if (!locked || lockedUntil == null) return null;
    return lockedUntil!.difference(DateTime.now()).inSeconds.clamp(0, 1 << 31);
  }
}

/// Anti fuerza bruta: bloquea el login tras varios intentos fallidos.
///
/// El contador y el tiempo de bloqueo se persisten en `app_settings` por
/// usuario, de modo que sobreviven al reinicio de la app.
class LockoutService {
  final daos.StoreDao _storeDao;
  final int maxAttempts;
  final Duration baseLockDuration;
  final Duration maxLockDuration;

  LockoutService(
    daos.StoreDao storeDao, {
    this.maxAttempts = 5,
    this.baseLockDuration = const Duration(seconds: 30),
    this.maxLockDuration = const Duration(minutes: 15),
  }) : _storeDao = storeDao;

  /// Estado de bloqueo actual para un usuario.
  Future<LockStatus> isLocked(String username) async {
    final untilRaw = await _storeDao.getSetting(SettingKeys.loginLockedUntil(username));
    final until = DateTime.tryParse(untilRaw ?? '');
    if (until == null) {
      return const LockStatus(locked: false);
    }
    return LockStatus(locked: DateTime.now().isBefore(until), lockedUntil: until);
  }

  /// Registra un intento fallido; devuelve el nuevo estado.
  Future<LockStatus> registerFailure(String username) async {
    final failuresKey = SettingKeys.loginFailures(username);
    final lockedUntilKey = SettingKeys.loginLockedUntil(username);

    final current = int.tryParse(await _storeDao.getSetting(failuresKey) ?? '') ?? 0;
    final count = current + 1;

    if (count >= maxAttempts) {
      final lockNumber = count ~/ maxAttempts;
      final seconds = (baseLockDuration.inSeconds * (1 << (lockNumber - 1)))
          .clamp(0, maxLockDuration.inSeconds)
          .toInt();
      final until = DateTime.now().add(Duration(seconds: seconds));
      await _storeDao.putSetting(failuresKey, '0');
      await _storeDao.putSetting(lockedUntilKey, until.toIso8601String());
      return LockStatus(locked: true, lockedUntil: until);
    }
    await _storeDao.putSetting(failuresKey, '$count');
    return const LockStatus(locked: false);
  }

  /// Limpia el historial de fallos tras un login exitoso.
  Future<void> resetFailures(String username) async {
    await _storeDao.putSetting(SettingKeys.loginFailures(username), '0');
    await _storeDao.putSetting(SettingKeys.loginLockedUntil(username), '');
  }
}
