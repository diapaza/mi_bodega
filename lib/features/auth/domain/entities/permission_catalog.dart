/// Definiciones de permisos del sistema (seed).
library;

class PermissionDefinition {
  final String code;
  final String name;
  final String module;

  const PermissionDefinition(this.code, this.name, this.module);
}

/// Catálogo granular de permisos.
///
/// Los permisos se agrupan por módulo para su presentación en la gestión de
/// roles. Los códigos siguen el patrón `<modulo>.<accion>`.
class PermissionCatalog {
  const PermissionCatalog._();

  static const _all = <PermissionDefinition>[
    PermissionDefinition('dashboard.view', 'Ver tablero', 'dashboard'),
    // POS
    PermissionDefinition('pos.use', 'Usar punto de venta', 'pos'),
    // Ventas
    PermissionDefinition('sales.create', 'Registrar ventas', 'ventas'),
    PermissionDefinition('sales.view', 'Ver ventas', 'ventas'),
    PermissionDefinition('sales.cancel', 'Anular ventas', 'ventas'),
    PermissionDefinition('sales.price_override', 'Modificar precio en venta', 'ventas'),
    // Productos
    PermissionDefinition('products.view', 'Ver productos', 'productos'),
    PermissionDefinition('products.create', 'Crear productos', 'productos'),
    PermissionDefinition('products.edit', 'Editar productos', 'productos'),
    PermissionDefinition('products.disable', 'Desactivar productos', 'productos'),
    PermissionDefinition('categories.manage', 'Administrar categorías', 'productos'),
    // Inventario
    PermissionDefinition('inventory.view', 'Ver inventario', 'inventario'),
    PermissionDefinition('inventory.adjust', 'Ajustar inventario', 'inventario'),
    // Compras
    PermissionDefinition('purchases.view', 'Ver compras', 'compras'),
    PermissionDefinition('purchases.create', 'Registrar compras', 'compras'),
    PermissionDefinition('suppliers.manage', 'Administrar proveedores', 'compras'),
    // Clientes
    PermissionDefinition('customers.view', 'Ver clientes', 'clientes'),
    PermissionDefinition('customers.create', 'Crear clientes', 'clientes'),
    // Caja
    PermissionDefinition('cash.open', 'Abrir caja', 'caja'),
    PermissionDefinition('cash.close', 'Cerrar caja', 'caja'),
    PermissionDefinition('cash.view', 'Ver caja', 'caja'),
    PermissionDefinition('cash.manage', 'Manejar efectivo', 'caja'),
    PermissionDefinition('cash.authorize', 'Autorizar diferencias', 'caja'),
    // Reportes
    PermissionDefinition('reports.view', 'Ver reportes', 'reportes'),
    // Usuarios
    PermissionDefinition('users.view', 'Ver usuarios', 'usuarios'),
    PermissionDefinition('users.create', 'Crear usuarios', 'usuarios'),
    PermissionDefinition('users.edit', 'Editar usuarios', 'usuarios'),
    PermissionDefinition('users.disable', 'Desactivar usuarios', 'usuarios'),
    PermissionDefinition('users.reset_pin', 'Restablecer PIN', 'usuarios'),
    // Roles
    PermissionDefinition('roles.view', 'Ver roles', 'roles'),
    PermissionDefinition('roles.manage', 'Administrar roles', 'roles'),
    // Configuración
    PermissionDefinition('settings.manage', 'Configurar la app', 'configuración'),
    // Respaldo
    PermissionDefinition('backup.create', 'Crear respaldos', 'respaldo'),
    PermissionDefinition('backup.restore', 'Restaurar respaldos', 'respaldo'),
    // Auditoría
    PermissionDefinition('audit.view', 'Ver auditoría', 'auditoría'),
  ];

  static List<PermissionDefinition> get all => List.unmodifiable(_all);

  /// Módulos ordenados para la UI de roles.
  static List<String> get modules {
    final seen = <String>{};
    final result = <String>[];
    for (final p in _all) {
      if (seen.add(p.module)) result.add(p.module);
    }
    return result;
  }

  static List<PermissionDefinition> byModule(String module) =>
      _all.where((p) => p.module == module).toList();

  /// Permisos otorgados por defecto al rol Vendedor.
  static const vendedorCodes = <String>[
    'pos.use',
    'sales.create',
    'sales.view',
    'products.view',
    'inventory.view',
    'customers.create',
    'cash.open',
    'cash.close',
  ];
}
