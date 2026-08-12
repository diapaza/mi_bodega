import 'package:flutter_test/flutter_test.dart';
import 'package:mi_bodega/core/database/app_database.dart' hide AppUser, Role;
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/core/security/session_store.dart';
import 'package:mi_bodega/features/auth/data/repositories/drift_auth_repository.dart';
import 'package:mi_bodega/features/auth/data/services/auth_service.dart';
import 'package:mi_bodega/features/auth/data/services/bootstrap_service.dart';
import 'package:mi_bodega/features/auth/data/services/lockout_service.dart';
import 'package:mi_bodega/features/auth/data/services/session_service.dart';
import 'package:mi_bodega/features/auth/domain/entities/auth.dart';
import 'package:mi_bodega/features/auth/domain/entities/permission_catalog.dart';

import '../helpers/db_test_utils.dart';

class _Env {
  final AppDatabase db;
  final MemorySessionStore sessionStore;
  final AuthService auth;
  final DriftAuthRepository repo;
  AppUser? owner;

  _Env(this.db, this.sessionStore, this.auth, this.repo);
}

Future<_Env> _setup() async {
  final db = await openTestMemoryDatabase();
  final bootstrap = BootstrapService(db, testPinHasher);
  await bootstrap.seedRolesAndPermissions();
  await bootstrap.setup(
    storeName: 'Bodega',
    ownerFullName: 'Dueña',
    ownerUsername: 'owner',
    ownerPin: '1234',
    ownerRecoveryPin: '9999',
  );
  final repo = DriftAuthRepository(db, testPinHasher);
  final sessionStore = MemorySessionStore();
  final auth = AuthService(
    repo,
    SessionService(sessionStore, db.storeDao, db.authDao),
    LockoutService(db.storeDao, baseLockDuration: const Duration(seconds: 2)),
    db.auditDao,
  );
  final env = _Env(db, sessionStore, auth, repo);
  env.owner = (await repo.authenticate('owner', '1234')).orNull!.user;
  return env;
}

void main() {
  group('AuthService', () {
    test('login correcto abre sesión y restaura al reabrir', () async {
      final env = await _setup();
      final login = await env.auth.login('owner', '1234');
      expect(login.isOk, isTrue);
      expect(login.orNull!.permissions.length, greaterThan(10));

      final restored = await env.auth.restoreSession();
      expect(restored.orNull?.username, 'owner');
    });

    test('login incorrecto no abre sesión', () async {
      final env = await _setup();
      final bad = await env.auth.login('owner', '0000');
      expect(bad.isErr, isTrue);
      final restored = await env.auth.restoreSession();
      expect(restored.orNull, isNull);
    });

    test('bloquea tras 5 intentos fallidos y persiste', () async {
      final env = await _setup();
      for (var i = 0; i < 5; i++) {
        await env.auth.login('owner', '0000');
      }
      final status = await env.auth.lockStatus('owner');
      expect(status.locked, isTrue);
      expect(status.remainingSeconds, greaterThan(0));

      final attempt = await env.auth.login('owner', '1234');
      expect(attempt.isErr, isTrue);
      expect(attempt.failure!.code, FailureCode.locked);
    });

    test('login correcto limpia los fallos acumulados', () async {
      final env = await _setup();
      for (var i = 0; i < 3; i++) {
        await env.auth.login('owner', '0000');
      }
      await env.auth.login('owner', '1234');
      final status = await env.auth.lockStatus('owner');
      expect(status.locked, isFalse);
    });

    test('recuperación con PIN de recuperación offline', () async {
      final env = await _setup();
      final ok = await env.auth.loginWithRecovery('owner', '9999');
      expect(ok.isOk, isTrue);
      expect(ok.orNull!.user.isOwner, isTrue);

      final bad = await env.auth.loginWithRecovery('owner', '1111');
      expect(bad.isErr, isTrue);
    });

    test('logout limpia la sesión', () async {
      final env = await _setup();
      await env.auth.login('owner', '1234');
      await env.auth.logout();
      final restored = await env.auth.restoreSession();
      expect(restored.orNull, isNull);
    });
  });

  group('Usuarios (administración)', () {
    test('crea, edita, cambia rol y desactiva vendedor', () async {
      final env = await _setup();
      final roles = (await env.repo.listRoles()).orNull!;
      final vendedorRole = roles.firstWhere((r) => r.name == 'Vendedor');

      final created = await env.repo.createUser(UserDraft(
        storeId: env.owner!.storeId,
        fullName: 'Vendedor Uno',
        username: 'v1',
        pin: '1111',
        roleId: vendedorRole.id!,
      ));
      expect(created.isOk, isTrue);

      final updated = await env.repo.updateUserDetails(
        created.orNull!.id!,
        fullName: 'Vendedor Actualizado',
      );
      expect(updated.orNull!.fullName, 'Vendedor Actualizado');

      await env.repo.changeRole(created.orNull!.id!, vendedorRole.id!);

      // Desactivar impide login.
      await env.repo.setActive(created.orNull!.id!, false);
      final login = await env.repo.authenticate('v1', '1111');
      expect(login.isErr, isTrue);

      await env.repo.setActive(created.orNull!.id!, true);
      final login2 = await env.repo.authenticate('v1', '1111');
      expect(login2.isOk, isTrue);
    });

    test('reset de PIN invalida el anterior', () async {
      final env = await _setup();
      final roles = (await env.repo.listRoles()).orNull!;
      final vendedorRole = roles.firstWhere((r) => r.name == 'Vendedor');
      await env.repo.createUser(UserDraft(
        storeId: env.owner!.storeId,
        fullName: 'V1',
        username: 'v1',
        pin: '1111',
        roleId: vendedorRole.id!,
      ));
      await env.repo.resetPin(2, '2222');
      expect((await env.repo.authenticate('v1', '1111')).isErr, isTrue);
      expect((await env.repo.authenticate('v1', '2222')).isOk, isTrue);
    });

    test('usuario duplicado se rechaza', () async {
      final env = await _setup();
      final roles = (await env.repo.listRoles()).orNull!;
      final vendedorRole = roles.firstWhere((r) => r.name == 'Vendedor');
      await env.repo.createUser(UserDraft(
        storeId: env.owner!.storeId,
        fullName: 'A',
        username: 'v1',
        pin: '1111',
        roleId: vendedorRole.id!,
      ));
      final dup = await env.repo.createUser(UserDraft(
        storeId: env.owner!.storeId,
        fullName: 'B',
        username: 'v1',
        pin: '2222',
        roleId: vendedorRole.id!,
      ));
      expect(dup.isErr, isTrue);
      expect(dup.failure!.code, FailureCode.alreadyExists);
    });
  });

  group('Roles y permisos', () {
    test('rol custom con permisos asignados', () async {
      final env = await _setup();
      final all = (await env.repo.allPermissions()).orNull!;
      final ids = all.where((p) => p.module == 'ventas').map((p) => p.id!).toList();

      final role = await env.repo.createRole(RoleDraft(
        name: 'Cajero',
        description: 'Solo ventas',
        permissionIds: ids,
      ));
      expect(role.isOk, isTrue);

      final perms = await env.repo.permissionsForRole(role.orNull!.id!);
      expect(perms.orNull!.map((p) => p.code).toList(),
          containsAll(['sales.create', 'sales.view', 'sales.cancel']));
    });

    test('roles de sistema protegidos de edición', () async {
      final env = await _setup();
      final roles = (await env.repo.listRoles()).orNull!;
      final admin = roles.firstWhere((r) => r.name == 'Administrador');
      final res = await env.repo.updateRole(
        Role(
          id: admin.id,
          name: 'Hack',
          isSystem: true,
          active: true,
          createdAt: admin.createdAt,
          updatedAt: admin.updatedAt,
        ),
      );
      expect(res.isErr, isTrue);
      expect(res.failure!.code, FailureCode.constraintViolation);
    });

    test('rol asignado no se puede eliminar; sin asignar sí', () async {
      final env = await _setup();
      final roles = (await env.repo.listRoles()).orNull!;
      final vendedor = roles.firstWhere((r) => r.name == 'Vendedor');
      expect((await env.repo.deleteRole(vendedor.id!)).isErr, isTrue);

      final custom = await env.repo.createRole(const RoleDraft(name: 'Libre'));
      expect((await env.repo.deleteRole(custom.orNull!.id!)).isOk, isTrue);
    });

    test('matriz de permisos: admin todos, vendedor subset', () async {
      final env = await _setup();
      final ownerPerms =
          (await env.repo.permissionsForUser(env.owner!.id!)).orNull!;
      final allCodes = PermissionCatalog.all.map((p) => p.code).toSet();
      expect(ownerPerms.map((p) => p.code).toSet(), allCodes);

      final roles = (await env.repo.listRoles()).orNull!;
      final vendedor = roles.firstWhere((r) => r.name == 'Vendedor');
      await env.repo.createUser(UserDraft(
        storeId: env.owner!.storeId,
        fullName: 'V',
        username: 'v1',
        pin: '1111',
        roleId: vendedor.id!,
      ));
      final vPerms = (await env.repo.permissionsForUser(2)).orNull!;
      expect(vPerms.map((p) => p.code).toSet(),
          PermissionCatalog.vendedorCodes.toSet());
      expect(vPerms.map((p) => p.code), isNot(contains('users.manage')));
    });

    test('auditoría registra operaciones sensibles', () async {
      final env = await _setup();
      await env.repo.createUser(const UserDraft(
        storeId: 1,
        fullName: 'A',
        username: 'u1',
        pin: '1111',
        roleId: 2,
      ));
      await env.repo.setActive(2, false);
      await env.repo.resetPin(2, '2222');
      await env.auth.logout();

      final audits = await env.db.auditDao.recentAudits();
      final actions = audits.map((a) => a.action).toList();
      expect(actions, containsAll(['create', 'disable', 'reset_pin']));
    });
  });
}
