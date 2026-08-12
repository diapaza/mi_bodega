import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mi_bodega/app.dart';
import 'package:mi_bodega/core/di/app_providers.dart';
import 'package:mi_bodega/core/security/session_store.dart';
import 'package:mi_bodega/features/auth/domain/entities/auth.dart';
import 'package:mi_bodega/features/auth/presentation/session_controller.dart';
import 'package:mi_bodega/features/pos/presentation/pos_providers.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart';
import 'package:mi_bodega/features/sales/domain/entities/sale.dart';
import 'package:mi_bodega/features/store/domain/entities/store.dart';

class _FakeSessionController extends SessionController {
  final SessionState result;

  _FakeSessionController(this.result);

  @override
  Future<SessionState> build() async => result;
}

SessionState _authed(List<String> perms) => SessionState(
      status: SessionStatus.authenticated,
      user: AppUser(
        id: 1,
        storeId: 1,
        fullName: 'Dueña',
        username: 'owner',
        roleId: 1,
        isOwner: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      permissions: perms,
      store: Store(
        name: 'Bodega Test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

Widget _app(SessionState state) {
  return ProviderScope(
    overrides: [
      sessionControllerProvider.overrideWith(() => _FakeSessionController(state)),
      sessionStoreProvider.overrideWithValue(MemorySessionStore()),
      // El shell del POS necesita sus providers; se sustituyen con vacíos.
      posProductsProvider
          .overrideWith((ref) => Stream.value(const <ProductStock>[])),
      favoriteProductsProvider
          .overrideWith((ref) => Stream.value(const <ProductStock>[])),
      topSoldProvider
          .overrideWith((ref) async => const <TopSoldProduct>[]),
      defaultRegisterProvider.overrideWith((ref) async => 1),
      openCashSessionProvider.overrideWith((ref) => Stream.value(null)),
    ],
    child: const MiBodegaApp(),
  );
}

void main() {
  testWidgets('Sin tienda configurada muestra la pantalla de configuración',
      (tester) async {
    await tester.pumpWidget(_app(const SessionState(
      status: SessionStatus.pendingSetup,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Configurar MiBodega'), findsOneWidget);
  });

  testWidgets('No autenticado muestra el login', (tester) async {
    await tester.pumpWidget(_app(const SessionState(
      status: SessionStatus.unauthenticated,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Ingresar'), findsOneWidget);
    expect(find.text('¿Olvidaste tu PIN?'), findsOneWidget);
  });

  testWidgets('Autenticado ve el shell con su navegación por permisos',
      (tester) async {
    await tester.pumpWidget(_app(_authed(const ['pos.use'])));
    await tester.pumpAndSettle();

    // Vendedor: ve el POS (búsqueda + caja cerrada), pero NO Productos ni Inicio.
    expect(find.text('Buscar producto…'), findsOneWidget);
    expect(find.textContaining('Caja cerrada'), findsOneWidget);
    expect(find.text('Productos'), findsNothing);
    expect(find.text('Inicio'), findsNothing);

    // El drawer muestra Cerrar sesión y Usuarios solo si tiene permiso.
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(find.text('Usuarios'), findsNothing); // sin users.view
  });

  testWidgets('Admin ve Usuarios y Roles en el drawer', (tester) async {
    await tester.pumpWidget(_app(_authed(const [
      'users.view',
      'roles.view',
      'settings.manage',
    ])));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Usuarios'), findsOneWidget);
    expect(find.text('Roles y permisos'), findsOneWidget);
  });
}
