import 'package:drift/drift.dart';
import 'package:mi_bodega/core/database/app_database.dart' as db;
import 'package:mi_bodega/core/database/daos.dart' as daos;
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/features/auth/data/services/lockout_service.dart';
import 'package:mi_bodega/features/auth/data/services/session_service.dart';
import 'package:mi_bodega/features/auth/domain/entities/auth.dart';
import 'package:mi_bodega/features/auth/domain/repositories/auth_repository.dart';

/// Caso de uso de autenticación: orquesta repositorio + bloqueo + sesión.
class AuthService {
  final AuthRepository _repository;
  final SessionService _session;
  final LockoutService _lockout;
  final daos.AuditDao _auditDao;

  AuthService(
    this._repository,
    this._session,
    this._lockout,
    this._auditDao,
  );

  /// Estado de bloqueo actual del usuario.
  Future<LockStatus> lockStatus(String username) => _lockout.isLocked(username);

  /// Login con PIN: valida bloqueo, autentica y abre sesión.
  Future<Result<LoginResult>> login(String username, String pin) async {
    final trimmed = username.trim();
    final lock = await _lockout.isLocked(trimmed);
    if (lock.locked) {
      return Err(Failure(
        code: FailureCode.locked,
        message: 'Demasiados intentos. Intenta en '
            '${lock.remainingSeconds} s.',
      ));
    }

    final result = await _repository.authenticate(trimmed, pin);
    return result.fold(
      (login) async {
        await _lockout.resetFailures(trimmed);
        await _session.createSession(login.user);
        return Ok(login);
      },
      (failure) async {
        final status = await _lockout.registerFailure(trimmed);
        if (status.locked) {
          return Err(Failure(
            code: FailureCode.locked,
            message: 'Demasiados intentos. Intenta en '
                '${status.remainingSeconds} s.',
          ));
        }
        return Err(failure);
      },
    );
  }

  /// Login mediante el PIN de recuperación (propietario).
  Future<Result<LoginResult>> loginWithRecovery(
      String username, String recoveryPin) async {
    final trimmed = username.trim();
    final result = await _repository.loginWithRecovery(trimmed, recoveryPin);
    return result.fold(
      (login) async {
        await _lockout.resetFailures(trimmed);
        await _session.createSession(login.user);
        return Ok(login);
      },
      (failure) async {
        await _lockout.registerFailure(trimmed);
        return Err(failure);
      },
    );
  }

  /// Restaura la sesión persistida (o `null` si no hay sesión válida).
  Future<Result<AppUser?>> restoreSession() async {
    try {
      if (await _session.requirePinOnStart) {
        return const Ok(null);
      }
      final user = await _session.restoreSession();
      return Ok(user);
    } catch (e) {
      return Err(Failure(
        code: FailureCode.unexpected,
        message: 'No se pudo restaurar la sesión.',
        cause: e,
      ));
    }
  }

  /// Cierra la sesión actual y audita el logout.
  Future<Result<void>> logout({int? userId}) async {
    try {
      if (userId != null) {
        await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
          userId: Value(userId),
          action: 'logout',
          entityType: 'user',
          entityId: Value('$userId'),
        ));
      }
      await _session.clearSession();
      return const Ok(null);
    } catch (e) {
      return Err(Failure(
        code: FailureCode.unexpected,
        message: 'No se pudo cerrar la sesión.',
        cause: e,
      ));
    }
  }
}
