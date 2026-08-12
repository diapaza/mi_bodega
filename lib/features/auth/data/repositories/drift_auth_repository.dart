import 'package:drift/drift.dart';
import 'package:mi_bodega/core/database/app_database.dart' as db;
import 'package:mi_bodega/core/database/daos.dart' as daos;
import 'package:mi_bodega/core/error/abort_transaction.dart';
import 'package:mi_bodega/core/error/failures.dart';
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/core/security/pin_hasher.dart';
import 'package:mi_bodega/features/auth/domain/entities/auth.dart';
import 'package:mi_bodega/features/auth/domain/repositories/auth_repository.dart';

class DriftAuthRepository implements AuthRepository {
  final db.AppDatabase database;
  final PinHasher _hasher;

  DriftAuthRepository(this.database, [this._hasher = const PinHasher()]);

  daos.AuthDao get _authDao => database.authDao;
  daos.AuditDao get _auditDao => database.auditDao;

  @override
  Future<Result<LoginResult>> authenticate(String username, String pin) async {
    try {
      final user = await _authDao.userByUsername(username.trim());
      if (user == null || !user.active) {
        return const Err(Failure(
          code: FailureCode.notFound,
          message: 'Usuario o PIN incorrecto.',
        ));
      }
      if (!_hasher.verify(pin, user.pinHash)) {
        await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
          userId: Value(user.id),
          action: 'login_failed',
          entityType: 'user',
          entityId: Value('${user.id}'),
        ));
        return const Err(Failure(
          code: FailureCode.notFound,
          message: 'Usuario o PIN incorrecto.',
        ));
      }
      return Ok(await _buildLogin(user.id));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<LoginResult>> loginWithRecovery(
      String username, String recoveryPin) async {
    try {
      final user = await _authDao.userByUsername(username.trim());
      final recoveryHash = user?.recoveryPinHash;
      if (user == null || !user.active || recoveryHash == null) {
        return const Err(Failure(
          code: FailureCode.notFound,
          message: 'No se puede recuperar el acceso con esos datos.',
        ));
      }
      if (!_hasher.verify(recoveryPin, recoveryHash)) {
        await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
          userId: Value(user.id),
          action: 'recovery_failed',
          entityType: 'user',
          entityId: Value('${user.id}'),
        ));
        return const Err(Failure(
          code: FailureCode.notFound,
          message: 'PIN de recuperación incorrecto.',
        ));
      }
      await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
        userId: Value(user.id),
        action: 'recovery_login',
        entityType: 'user',
        entityId: Value('${user.id}'),
      ));
      return Ok(await _buildLogin(user.id));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  Future<LoginResult> _buildLogin(int userId) async {
    final permissions = await _authDao.permissionsForUser(userId);
    final user = await _authDao.userById(userId);
    await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
      userId: Value(userId),
      action: 'login',
      entityType: 'user',
      entityId: Value('$userId'),
    ));
    return LoginResult(
      user: _mapUser(user!),
      permissions: permissions.map((p) => p.code).toList(),
    );
  }

  @override
  Stream<List<AppUser>> watchUsers(int storeId) {
    return _authDao.watchUsers(storeId).map((rows) => rows.map(_mapUser).toList());
  }

  @override
  Future<Result<List<AppUser>>> listUsers(int storeId) async {
    try {
      final rows = await _authDao.allUsers(storeId);
      return Ok(rows.map(_mapUser).toList());
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<AppUser>> createUser(UserDraft draft) async {
    try {
      if (draft.pin.length < 4) {
        return const Err(Failure(
          code: FailureCode.validation,
          message: 'El PIN debe tener al menos 4 dígitos.',
        ));
      }
      final user = await database.transaction(() async {
        final existing = await _authDao.userByUsername(draft.username.trim());
        if (existing != null) {
          throw AbortTransaction(Failure(
            code: FailureCode.alreadyExists,
            message: 'El nombre de usuario ya existe.',
          ));
        }
        final pinHash = _hasher.hash(draft.pin);
        final id = await _authDao.insertUser(db.UsersCompanion.insert(
          storeId: draft.storeId,
          fullName: draft.fullName,
          username: draft.username.trim(),
          pinHash: pinHash,
          roleId: draft.roleId,
          isOwner: Value(draft.isOwner),
        ));
        await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
          userId: Value(id),
          action: 'create',
          entityType: 'user',
          entityId: Value('$id'),
          afterJson: Value('{"full_name":"${draft.fullName}"}'),
        ));
        return await _authDao.userById(id);
      });
      return Ok(_mapUser(user!));
    } on AbortTransaction catch (e) {
      return Err(e.failure);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<AppUser>> updateUserDetails(
    int userId, {
    required String fullName,
    String? username,
  }) async {
    try {
      final user = await database.transaction(() async {
        final existing = await _authDao.userById(userId);
        if (existing == null) {
          throw AbortTransaction(Failure(
            code: FailureCode.notFound,
            message: 'Usuario no encontrado.',
          ));
        }
        final newUsername = username?.trim();
        if (newUsername != null &&
            newUsername.isNotEmpty &&
            newUsername != existing.username) {
          final clash = await _authDao.userByUsername(newUsername);
          if (clash != null && clash.id != userId) {
            throw AbortTransaction(Failure(
              code: FailureCode.alreadyExists,
              message: 'El nombre de usuario ya existe.',
            ));
          }
        }
        await (database.update(database.users)..where((t) => t.id.equals(userId)))
            .write(db.UsersCompanion(
          fullName: Value(fullName),
          username: newUsername == null || newUsername.isEmpty
              ? Value(existing.username)
              : Value(newUsername),
          updatedAt: Value(DateTime.now()),
        ));
        await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
          userId: Value(userId),
          action: 'update',
          entityType: 'user',
          entityId: Value('$userId'),
        ));
        return await _authDao.userById(userId);
      });
      return Ok(_mapUser(user!));
    } on AbortTransaction catch (e) {
      return Err(e.failure);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<void>> setActive(int userId, bool active) async {
    try {
      final user = await _authDao.userById(userId);
      if (user == null) {
        return const Err(Failure(
          code: FailureCode.notFound,
          message: 'Usuario no encontrado.',
        ));
      }
      await (database.update(database.users)..where((t) => t.id.equals(userId)))
          .write(db.UsersCompanion(
        active: Value(active),
        updatedAt: Value(DateTime.now()),
      ));
      await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
        userId: Value(userId),
        action: active ? 'enable' : 'disable',
        entityType: 'user',
        entityId: Value('$userId'),
      ));
      return const Ok(null);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<void>> changeRole(int userId, int roleId) async {
    try {
      final role = await _authDao.roleById(roleId);
      if (role == null || !role.active) {
        return const Err(Failure(
          code: FailureCode.notFound,
          message: 'Rol no encontrado.',
        ));
      }
      final user = await _authDao.userById(userId);
      if (user == null) {
        return const Err(Failure(
          code: FailureCode.notFound,
          message: 'Usuario no encontrado.',
        ));
      }
      await (database.update(database.users)..where((t) => t.id.equals(userId)))
          .write(db.UsersCompanion(
        roleId: Value(roleId),
        updatedAt: Value(DateTime.now()),
      ));
      await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
        userId: Value(userId),
        action: 'change_role',
        entityType: 'user',
        entityId: Value('$userId'),
        afterJson: Value('{"role_id":$roleId}'),
      ));
      return const Ok(null);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<void>> resetPin(int userId, String newPin) async {
    try {
      if (newPin.length < 4) {
        return const Err(Failure(
          code: FailureCode.validation,
          message: 'El PIN debe tener al menos 4 dígitos.',
        ));
      }
      await (database.update(database.users)..where((t) => t.id.equals(userId)))
          .write(db.UsersCompanion(
        pinHash: Value(_hasher.hash(newPin)),
        updatedAt: Value(DateTime.now()),
      ));
      await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
        userId: Value(userId),
        action: 'reset_pin',
        entityType: 'user',
        entityId: Value('$userId'),
      ));
      return const Ok(null);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<void>> setRecoveryPin(int userId, String recoveryPin) async {
    try {
      if (recoveryPin.length < 4) {
        return const Err(Failure(
          code: FailureCode.validation,
          message: 'El PIN de recuperación debe tener al menos 4 dígitos.',
        ));
      }
      await (database.update(database.users)..where((t) => t.id.equals(userId)))
          .write(db.UsersCompanion(
        recoveryPinHash: Value(_hasher.hash(recoveryPin)),
        updatedAt: Value(DateTime.now()),
      ));
      await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
        userId: Value(userId),
        action: 'set_recovery_pin',
        entityType: 'user',
        entityId: Value('$userId'),
      ));
      return const Ok(null);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<List<Role>>> listRoles() async {
    try {
      final rows = await _authDao.allRoles();
      return Ok(rows.map(_mapRole).toList());
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Stream<List<Role>> watchRoles() {
    return _authDao.watchRoles().map((rows) => rows.map(_mapRole).toList());
  }

  @override
  Future<Result<Role>> createRole(RoleDraft draft) async {
    try {
      final role = await database.transaction(() async {
        final roleId = await _authDao.insertRole(db.RolesCompanion.insert(
          name: draft.name,
          description: draft.description == null
              ? const Value.absent()
              : Value(draft.description),
        ));
        await _replaceRolePermissions(roleId, draft.permissionIds);
        await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
          action: 'create',
          entityType: 'role',
          entityId: Value('$roleId'),
          afterJson: Value('{"name":"${draft.name}"}'),
        ));
        return await _authDao.roleById(roleId);
      });
      return Ok(_mapRole(role!));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<Role>> updateRole(Role role, {List<int> permissionIds = const []}) async {
    try {
      final updated = await database.transaction(() async {
        final existing = await _authDao.roleById(role.id!);
        if (existing == null) {
          throw AbortTransaction(Failure(
            code: FailureCode.notFound,
            message: 'Rol no encontrado.',
          ));
        }
        if (existing.isSystem) {
          throw AbortTransaction(Failure(
            code: FailureCode.constraintViolation,
            message: 'Los roles del sistema no se pueden modificar.',
          ));
        }
        await _authDao.updateRole(existing.toCompanion(true).copyWith(
              name: Value(role.name),
              description: role.description == null
                  ? const Value.absent()
                  : Value(role.description),
              active: Value(role.active),
              updatedAt: Value(DateTime.now()),
            ));
        if (permissionIds.isNotEmpty) {
          final before = (await _authDao.permissionsForRole(role.id!))
              .map((p) => p.code)
              .join(',');
          await _replaceRolePermissions(role.id!, permissionIds);
          final after = (await _authDao.permissionsForRole(role.id!))
              .map((p) => p.code)
              .join(',');
          if (before != after) {
            await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
              action: 'change_permissions',
              entityType: 'role',
              entityId: Value('${role.id}'),
              beforeJson: Value('{"codes":"$before"}'),
              afterJson: Value('{"codes":"$after"}'),
            ));
          }
        }
        await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
          action: 'update',
          entityType: 'role',
          entityId: Value('${role.id}'),
        ));
        return await _authDao.roleById(role.id!);
      });
      return Ok(_mapRole(updated!));
    } on AbortTransaction catch (e) {
      return Err(e.failure);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<void>> setRoleActive(int roleId, bool active) async {
    try {
      final existing = await _authDao.roleById(roleId);
      if (existing == null) {
        return const Err(Failure(
          code: FailureCode.notFound,
          message: 'Rol no encontrado.',
        ));
      }
      if (existing.isSystem) {
        return const Err(Failure(
          code: FailureCode.constraintViolation,
          message: 'Los roles del sistema no se pueden desactivar.',
        ));
      }
      await _authDao.updateRole(existing.toCompanion(true).copyWith(
            active: Value(active),
            updatedAt: Value(DateTime.now()),
          ));
      await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
        action: active ? 'enable_role' : 'disable_role',
        entityType: 'role',
        entityId: Value('$roleId'),
      ));
      return const Ok(null);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<void>> deleteRole(int roleId) async {
    try {
      await database.transaction(() async {
        final existing = await _authDao.roleById(roleId);
        if (existing == null) {
          throw AbortTransaction(Failure(
            code: FailureCode.notFound,
            message: 'Rol no encontrado.',
          ));
        }
        if (existing.isSystem) {
          throw AbortTransaction(Failure(
            code: FailureCode.constraintViolation,
            message: 'Los roles del sistema no se pueden eliminar.',
          ));
        }
        final assigned = await _authDao.countUsersWithRole(roleId);
        if (assigned > 0) {
          throw AbortTransaction(Failure(
            code: FailureCode.constraintViolation,
            message: 'El rol está asignado a $assigned usuario(s). '
                'Reasígnelos antes de eliminar.',
          ));
        }
        await _authDao.clearPermissionsForRole(roleId);
        await _authDao.deleteRole(roleId);
        await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
          action: 'delete',
          entityType: 'role',
          entityId: Value('$roleId'),
        ));
      });
      return const Ok(null);
    } on AbortTransaction catch (e) {
      return Err(e.failure);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<List<Permission>>> permissionsForRole(int roleId) async {
    try {
      final rows = await _authDao.permissionsForRole(roleId);
      return Ok(rows.map(_mapPermission).toList());
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<List<Permission>>> permissionsForUser(int userId) async {
    try {
      final rows = await _authDao.permissionsForUser(userId);
      return Ok(rows.map(_mapPermission).toList());
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<List<Permission>>> allPermissions() async {
    try {
      final rows = await _authDao.allPermissions();
      return Ok(rows.map(_mapPermission).toList());
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  Future<void> _replaceRolePermissions(int roleId, List<int> permissionIds) async {
    await _authDao.clearPermissionsForRole(roleId);
    await _authDao.assignPermissionsToRole(roleId, permissionIds);
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

  Role _mapRole(db.Role r) {
    return Role(
      id: r.id,
      name: r.name,
      description: r.description,
      isSystem: r.isSystem,
      active: r.active,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    );
  }

  Permission _mapPermission(db.Permission p) {
    return Permission(
      id: p.id,
      code: p.code,
      name: p.name,
      module: p.module,
      description: p.description,
    );
  }
}
