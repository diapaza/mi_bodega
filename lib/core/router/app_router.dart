import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../../features/auth/presentation/setup_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/backup/presentation/backup_screen.dart';
import '../../features/catalog/presentation/catalog_manage_screens.dart';
import '../../features/cash/presentation/cash_history_screen.dart';
import '../../features/cash/presentation/cash_screen.dart';
import '../../features/customers/presentation/customer_detail_screen.dart';
import '../../features/customers/presentation/customers_screen.dart';
import '../../features/inventory/presentation/adjustment_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/inventory/presentation/movements_history_screen.dart';
import '../../features/products/presentation/product_form_screen.dart';
import '../../features/purchases/presentation/purchases_list_screen.dart';
import '../../features/purchases/presentation/restock_screen.dart';
import '../../features/purchases/presentation/suppliers_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/roles/presentation/role_edit_screen.dart';
import '../../features/roles/presentation/roles_list_screen.dart';
import '../../features/sales/presentation/sales_list_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/users/presentation/user_form_screen.dart';
import '../../features/users/presentation/users_list_screen.dart';

/// Permiso requerido por cada ruta administrativa.
String? permissionForRoute(String path) {
  if (path == '/users') return 'users.view';
  if (path == '/users/new') return 'users.create';
  if (path.startsWith('/users/')) return 'users.edit';
  if (path == '/roles') return 'roles.view';
  if (path.startsWith('/roles/')) return 'roles.manage';
  if (path == '/products/new') return 'products.create';
  if (path.startsWith('/products/')) return 'products.edit';
  if (path == '/categories' || path == '/brands' || path == '/units') {
    return 'categories.manage';
  }
  if (path.startsWith('/inventory/') && path.endsWith('/adjust')) {
    return 'inventory.adjust';
  }
  if (path.startsWith('/inventory')) return 'inventory.view';
  if (path == '/purchases') return 'purchases.view';
  if (path == '/purchases/new') return 'purchases.create';
  if (path == '/suppliers') return 'suppliers.manage';
  if (path == '/sales') return 'sales.view';
  if (path.startsWith('/cash')) return 'cash.view';
  if (path == '/reports') return 'reports.view';
  if (path == '/customers' || path.startsWith('/customers/')) {
    return 'customers.view';
  }
  if (path.startsWith('/inventory')) return 'inventory.view';
  if (path == '/settings') return 'settings.manage';
  if (path == '/backup') return 'backup.create';
  return null;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionControllerProvider);
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final result = resolveRedirect(
        session.valueOrNull,
        state.matchedLocation,
      );
      print('[Router] redirect ${state.matchedLocation} → $result (session: ${session.valueOrNull?.status})');
      return result;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/setup', builder: (_, _) => const SetupScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, _) => const AppShell()),
      GoRoute(path: '/users', builder: (_, _) => const UsersListScreen()),
      GoRoute(path: '/users/new', builder: (_, _) => const UserFormScreen()),
      GoRoute(
        path: '/users/:id',
        builder: (_, state) => UserFormScreen(
          userId: int.tryParse(state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(path: '/roles', builder: (_, _) => const RolesListScreen()),
      GoRoute(path: '/roles/new', builder: (_, _) => const RoleEditScreen()),
      GoRoute(
        path: '/roles/:id',
        builder: (_, state) => RoleEditScreen(
          roleId: int.tryParse(state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(path: '/products/new', builder: (_, _) => const ProductFormScreen()),
      GoRoute(
        path: '/products/:id',
        builder: (_, state) => ProductFormScreen(
          productId: int.tryParse(state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(path: '/categories', builder: (_, _) => const CategoriesScreen()),
      GoRoute(path: '/brands', builder: (_, _) => const BrandsScreen()),
      GoRoute(path: '/units', builder: (_, _) => const UnitsScreen()),
      GoRoute(
        path: '/inventory/movements',
        builder: (_, _) => const MovementsHistoryScreen(),
      ),
      GoRoute(
        path: '/inventory/:id/movements',
        builder: (_, state) => MovementsHistoryScreen(
          productId: int.tryParse(state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/inventory/:id/adjust',
        builder: (_, state) => AdjustmentScreen(
          productId: int.parse(state.pathParameters['id'] ?? '0'),
        ),
      ),
      GoRoute(path: '/purchases', builder: (_, _) => const PurchasesListScreen()),
      GoRoute(path: '/purchases/new', builder: (_, _) => const RestockScreen()),
      GoRoute(path: '/suppliers', builder: (_, _) => const SuppliersScreen()),
      GoRoute(path: '/sales', builder: (_, _) => const SalesListScreen()),
      GoRoute(path: '/cash', builder: (_, _) => const CashScreen()),
      GoRoute(path: '/cash/history', builder: (_, _) => const CashHistoryScreen()),
      GoRoute(path: '/reports', builder: (_, _) => const ReportsScreen()),
      GoRoute(path: '/customers', builder: (_, _) => const CustomersScreen()),
      GoRoute(
        path: '/customers/:id',
        builder: (_, state) => CustomerDetailScreen(
          customerId: int.parse(state.pathParameters['id'] ?? '0'),
        ),
      ),
      GoRoute(path: '/inventory', builder: (_, _) => const InventoryScreen()),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/backup',
        builder: (_, _) => const BackupScreen(),
      ),
    ],
  );
});

/// Lógica de redirección (pura, testeable).
///
/// - Sin estado → splash.
/// - Sin tienda → setup.
/// - No autenticado → login.
/// - Autenticado sin permiso de ruta → home (`/`).
String? resolveRedirect(SessionState? session, String location) {
  if (session == null) {
    return location == '/splash' ? null : '/splash';
  }

  switch (session.status) {
    case SessionStatus.initializing:
      return location == '/splash' ? null : '/splash';
    case SessionStatus.pendingSetup:
      return location == '/setup' ? null : '/setup';
    case SessionStatus.unauthenticated:
      return location == '/login' ? null : '/login';
    case SessionStatus.authenticated:
      if (location == '/login' || location == '/setup' || location == '/splash') {
        return '/';
      }
      final required = permissionForRoute(location);
      if (required != null && !session.can(required)) {
        return '/';
      }
      return null;
  }
}
