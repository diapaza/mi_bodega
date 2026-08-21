import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/mb_badge.dart';
import '../../../shared/widgets/mb_loading.dart';
import '../../auth/presentation/session_controller.dart';
import '../../inventory/presentation/inventory_screen.dart';
import '../../pos/presentation/pos_screen.dart';
import '../../products/presentation/products_list_screen.dart';
import '../../reports/presentation/dashboard_screen.dart';
import '../../sales/presentation/sales_list_screen.dart';

class _Dest {
  final String label;
  final IconData icon;
  final String permission;
  final Widget screen;

  const _Dest({
    required this.label,
    required this.icon,
    required this.permission,
    required this.screen,
  });
}

/// Shell principal: navegación inferior según permisos + drawer administrativo.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selected = 0;

  List<_Dest> _destinations(SessionState session) {
    return [
      if (session.can('dashboard.view'))
        _Dest(
          label: 'Inicio',
          icon: Icons.space_dashboard_outlined,
          permission: 'dashboard.view',
          screen: const DashboardScreen(),
        ),
      if (session.can('pos.use'))
        _Dest(
          label: 'POS',
          icon: Icons.point_of_sale,
          permission: 'pos.use',
          screen: const PosScreen(),
        ),
      if (session.can('products.view'))
        _Dest(
          label: 'Productos',
          icon: Icons.inventory_2_outlined,
          permission: 'products.view',
          screen: const ProductsListScreen(),
        ),
      if (session.can('inventory.view'))
        _Dest(
          label: 'Inventario',
          icon: Icons.inventory_outlined,
          permission: 'inventory.view',
          screen: const InventoryScreen(),
        ),
      if (session.can('sales.view'))
        _Dest(
          label: 'Ventas',
          icon: Icons.receipt_long_outlined,
          permission: 'sales.view',
          screen: const SalesListScreen(),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    if (session == null || session.user == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MbLoading(),
              SizedBox(height: 16),
              Text('Cargando...'),
            ],
          ),
        ),
      );
    }
    final destinations = _destinations(session);
    if (_selected >= destinations.length) _selected = 0;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.storefront, color: colors.primary, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                session.store?.name ?? 'MiBodega',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      drawer: _buildDrawer(context, session),
      body: IndexedStack(index: _selected, children: [
        for (final d in destinations) d.screen,
      ]),
      bottomNavigationBar: destinations.length < 2
          ? null
          : NavigationBar(
              selectedIndex: _selected,
              onDestinationSelected: (i) => setState(() => _selected = i),
              destinations: [
                for (final d in destinations)
                  NavigationDestination(icon: Icon(d.icon), label: d.label),
              ],
            ),
    );
  }

  Widget _buildDrawer(BuildContext context, SessionState session) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final user = session.user!;

    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: colors.primaryContainer,
                    child: Text(
                      user.fullName.isNotEmpty
                          ? user.fullName.substring(0, 1).toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 22,
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(user.fullName, style: theme.textTheme.titleMedium),
                  Text(
                    session.store?.name ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const MbBadge('Usuario'),
                      const SizedBox(width: 8),
                      if (user.isOwner) const MbBadge('Propietario', tone: MbBadgeTone.info),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // --- Operaciones ---
            _DrawerSectionHeader(label: 'Operaciones', theme: theme, colors: colors),
            if (session.can('cash.view'))
              ListTile(
                leading: const Icon(Icons.point_of_sale_outlined),
                title: const Text('Caja'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/cash');
                },
              ),
            if (session.can('customers.view'))
              ListTile(
                leading: const Icon(Icons.people_alt_outlined),
                title: const Text('Clientes'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/customers');
                },
              ),
            if (session.can('purchases.view'))
              ListTile(
                leading: const Icon(Icons.shopping_cart_outlined),
                title: const Text('Compras'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/purchases');
                },
              ),
            if (session.can('suppliers.manage'))
              ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: const Text('Proveedores'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/suppliers');
                },
              ),
            // --- Administración ---
            _DrawerSectionHeader(label: 'Administración', theme: theme, colors: colors),
            if (session.can('users.view'))
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('Usuarios'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/users');
                },
              ),
            if (session.can('reports.view'))
              ListTile(
                leading: const Icon(Icons.bar_chart_outlined),
                title: const Text('Reportes'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/reports');
                },
              ),
            if (session.can('roles.view'))
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Roles y permisos'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/roles');
                },
              ),
            // --- Sistema ---
            _DrawerSectionHeader(label: 'Sistema', theme: theme, colors: colors),
            if (session.can('settings.manage'))
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Configuración'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/settings');
                },
              ),
            if (session.can('backup.create'))
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: const Text('Respaldo'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/backup');
                },
              ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.logout, color: colors.error),
              title: const Text('Cerrar sesión'),
              textColor: colors.error,
              onTap: () async {
                Navigator.pop(context);
                await ref.read(sessionControllerProvider.notifier).logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerSectionHeader extends StatelessWidget {
  final String label;
  final ThemeData theme;
  final AppColors colors;

  const _DrawerSectionHeader({
    required this.label,
    required this.theme,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
