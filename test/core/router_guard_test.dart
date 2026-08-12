import 'package:flutter_test/flutter_test.dart';

import 'package:mi_bodega/core/router/app_router.dart';
import 'package:mi_bodega/features/auth/presentation/session_controller.dart';
import 'package:mi_bodega/features/store/domain/entities/store.dart';

SessionState _authed(List<String> perms) => SessionState(
      status: SessionStatus.authenticated,
      permissions: perms,
      store: Store(
        name: 'S',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

void main() {
  group('resolveRedirect (guards de navegación)', () {
    test('sin estado → splash', () {
      expect(resolveRedirect(null, '/'), '/splash');
      expect(resolveRedirect(null, '/splash'), isNull);
    });

    test('pendiente de setup → /setup', () {
      const s = SessionState(status: SessionStatus.pendingSetup);
      expect(resolveRedirect(s, '/login'), '/setup');
      expect(resolveRedirect(s, '/setup'), isNull);
    });

    test('no autenticado → /login', () {
      const s = SessionState(status: SessionStatus.unauthenticated);
      expect(resolveRedirect(s, '/'), '/login');
      expect(resolveRedirect(s, '/login'), isNull);
    });

    test('autenticado con permiso accede a /users', () {
      final s = _authed(const ['users.view']);
      expect(resolveRedirect(s, '/users'), isNull);
    });

    test('autenticado SIN permiso es redirigido al home', () {
      final s = _authed(const ['pos.use']);
      expect(resolveRedirect(s, '/users'), '/');
      expect(resolveRedirect(s, '/roles'), '/');
      expect(resolveRedirect(s, '/settings'), '/');
    });

    test('rutas de administración requieren permisos granulares', () {
      expect(permissionForRoute('/users'), 'users.view');
      expect(permissionForRoute('/users/new'), 'users.create');
      expect(permissionForRoute('/users/5'), 'users.edit');
      expect(permissionForRoute('/roles'), 'roles.view');
      expect(permissionForRoute('/roles/2'), 'roles.manage');
      expect(permissionForRoute('/backup'), 'backup.create');
      expect(permissionForRoute('/'), isNull);
    });

    test('autenticado que visita /login vuelve al home', () {
      final s = _authed(const ['pos.use']);
      expect(resolveRedirect(s, '/login'), '/');
    });
  });
}
