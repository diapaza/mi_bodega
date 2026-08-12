import 'package:mi_bodega/core/database/app_database.dart' as db;
import 'package:mi_bodega/core/database/daos.dart' as daos;
import 'package:mi_bodega/core/security/session_store.dart';
import 'package:mi_bodega/core/security/session_token.dart';
import 'package:mi_bodega/features/auth/domain/entities/auth.dart';
import 'package:mi_bodega/features/store/domain/entities/store.dart';

/// Gestiona la sesión local del dispositivo.
///
/// El token crudo vive en [SessionStore] (secure storage); en la base de
/// datos solo se persiste su hash y el id de usuario activo.
class SessionService {
  final SessionStore _store;
  final daos.StoreDao _storeDao;
  final daos.AuthDao _authDao;

  SessionService(this._store, this._storeDao, this._authDao);

  /// Crea una sesión para [user] tras un login exitoso.
  Future<void> createSession(AppUser user) async {
    final token = SessionToken.generate();
    await _store.writeToken(token);
    await _storeDao.putSetting(SettingKeys.sessionTokenHash, SessionToken.hash(token));
    await _storeDao.putSetting(SettingKeys.sessionUserId, '${user.id}');
  }

  /// Restaura la sesión persistida, o devuelve `null` si no es válida.
  Future<AppUser?> restoreSession() async {
    final token = await _store.readToken();
    if (token == null || token.isEmpty) return null;

    final storedHash = await _storeDao.getSetting(SettingKeys.sessionTokenHash);
    if (storedHash == null || storedHash != SessionToken.hash(token)) {
      await clearSession();
      return null;
    }

    final userIdRaw = await _storeDao.getSetting(SettingKeys.sessionUserId);
    final userId = int.tryParse(userIdRaw ?? '');
    final row = userId == null ? null : await _authDao.userById(userId);
    if (row == null || !row.active) {
      await clearSession();
      return null;
    }
    return _mapUser(row);
  }

  AppUser _mapUser(db.AppUser u) {
    return AppUser(
      id: u.id,
      storeId: u.storeId,
      fullName: u.fullName,
      username: u.username,
      roleId: u.roleId,
      active: u.active,
      isOwner: u.isOwner,
      createdAt: u.createdAt,
      updatedAt: u.updatedAt,
      pinHash: u.pinHash,
      recoveryPinHash: u.recoveryPinHash,
    );
  }

  /// Cierra la sesión (borra token y hash).
  Future<void> clearSession() async {
    await _store.deleteToken();
    await _storeDao.putSetting(SettingKeys.sessionTokenHash, '');
    await _storeDao.putSetting(SettingKeys.sessionUserId, '');
  }

  /// Indica si la configuración exige PIN en cada apertura.
  Future<bool> get requirePinOnStart async {
    final v = await _storeDao.getSetting(SettingKeys.requirePinOnStart);
    return v == 'true';
  }
}
