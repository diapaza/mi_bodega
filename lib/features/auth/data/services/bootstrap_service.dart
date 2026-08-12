import 'package:mi_bodega/core/database/app_database.dart' as db;
import 'package:mi_bodega/core/database/daos.dart' as daos;
import 'package:drift/drift.dart';
import 'package:mi_bodega/core/security/pin_hasher.dart';
import 'package:mi_bodega/features/auth/domain/entities/permission_catalog.dart';
import 'package:mi_bodega/features/store/domain/entities/store.dart';

/// Resultado del estado de inicialización de la aplicación.
enum BootstrapState { pendingSetup, ready }

class BootstrapResult {
  final BootstrapState state;
  final Store? store;

  const BootstrapResult(this.state, {this.store});
}

/// Siembra los datos base (permisos, roles) y ejecuta el primer arranque
/// (tienda + caja por defecto + propietario).
class BootstrapService {
  final db.AppDatabase database;
  final PinHasher _hasher;

  BootstrapService(this.database, [this._hasher = const PinHasher()]);

  daos.AuthDao get _authDao => database.authDao;
  daos.StoreDao get _storeDao => database.storeDao;
  daos.CashDao get _cashDao => database.cashDao;

  /// Permisos, roles y unidades base (idempotente e incremental).
  ///
  /// Inserta permisos faltantes (para no romper instalaciones existentes) y
  /// garantiza que el rol Administrador reciba cualquier permiso nuevo.
  Future<void> seedRolesAndPermissions() async {
    await database.transaction(() async {
      final existingPermissions = await _authDao.allPermissions();
      final existingCodes = existingPermissions.map((p) => p.code).toSet();
      for (final def in PermissionCatalog.all) {
        if (!existingCodes.contains(def.code)) {
          await _authDao.insertPermission(db.PermissionsCompanion.insert(
            code: def.code,
            name: def.name,
            module: def.module,
          ));
        }
      }
      final allPermissions = await _authDao.allPermissions();

      final existingRoles = await _authDao.allRoles();
      if (existingRoles.isEmpty) {
        final adminRoleId = await _authDao.insertRole(db.RolesCompanion.insert(
          name: 'Administrador',
          description: const Value('Acceso total a la tienda'),
          isSystem: const Value(true),
        ));
        final vendedorRoleId = await _authDao.insertRole(db.RolesCompanion.insert(
          name: 'Vendedor',
          description: const Value('Permisos limitados para el punto de venta'),
          isSystem: const Value(true),
        ));

        await _authDao.assignPermissionsToRole(
          adminRoleId,
          allPermissions.map((p) => p.id).toList(),
        );

        final vendedorPermissionIds = allPermissions
            .where((p) => PermissionCatalog.vendedorCodes.contains(p.code))
            .map((p) => p.id)
            .toList();
        await _authDao.assignPermissionsToRole(vendedorRoleId, vendedorPermissionIds);
      } else {
        // Garantizar que el rol Administrador tenga los permisos nuevos.
        final admin = existingRoles.firstWhere((r) => r.name == 'Administrador');
        final current = await _authDao.permissionsForRole(admin.id);
        final currentIds = current.map((p) => p.id).toSet();
        final missing = allPermissions
            .where((p) => !currentIds.contains(p.id))
            .map((p) => p.id)
            .toList();
        if (missing.isNotEmpty) {
          await _authDao.assignPermissionsToRole(admin.id, missing);
        }
      }
    });

    await _seedUnits();
  }

  /// Unidades habituales de una bodega peruana (idempotente).
  Future<void> _seedUnits() async {
    const units = [
      ('Unidad', 'ud', 'unit'),
      ('Kilogramo', 'kg', 'weight'),
      ('Gramo', 'g', 'weight'),
      ('Litro', 'lt', 'volume'),
      ('Mililitro', 'ml', 'volume'),
      ('Botella', 'bot', 'package'),
      ('Lata', 'lata', 'package'),
      ('Paquete', 'paq', 'package'),
      ('Par', 'par', 'unit'),
      ('Docena', 'doc', 'unit'),
      ('Caja', 'caja', 'package'),
      ('Bolsa', 'bolsa', 'package'),
      ('Saco', 'saco', 'package'),
    ];
    final existing = await database.catalogDao.watchActiveUnits().first;
    if (existing.isNotEmpty) return;
    for (final (name, symbol, type) in units) {
      await database.catalogDao.insertUnit(db.UnitsCompanion.insert(
        name: name,
        symbol: symbol,
        unitType: Value(type),
      ));
    }
  }

  /// Indica si la aplicación ya tiene tienda configurada.
  Future<BootstrapResult> checkState() async {
    await seedRolesAndPermissions();
    final store = await _storeDao.firstStore();
    if (store == null) {
      return const BootstrapResult(BootstrapState.pendingSetup);
    }
    return BootstrapResult(BootstrapState.ready, store: _mapStore(store));
  }

  /// Primer arranque: crea tienda, caja por defecto y propietario.
  Future<BootstrapResult> setup({
    required String storeName,
    String? rucDni,
    String? address,
    String? phone,
    required String ownerFullName,
    required String ownerUsername,
    required String ownerPin,
    required String ownerRecoveryPin,
  }) async {
    final result = await database.transaction(() async {
      final existing = await _storeDao.firstStore();
      if (existing != null) {
        return BootstrapResult(BootstrapState.ready, store: _mapStore(existing));
      }

      final storeId = await _storeDao.insertStore(db.StoresCompanion.insert(
        name: storeName,
        rucDni: _text(rucDni),
        address: _text(address),
        phone: _text(phone),
        currency: const Value('PEN'),
      ));

      await _cashDao.insertRegister(db.CashRegistersCompanion.insert(
        storeId: storeId,
        name: 'Caja principal',
      ));

      final roles = await _authDao.allRoles();
      final adminRole = roles.firstWhere((r) => r.name == 'Administrador');

      final pinHash = _hasher.hash(ownerPin);
      final recoveryHash = _hasher.hash(ownerRecoveryPin);
      await _authDao.insertUser(db.UsersCompanion.insert(
        storeId: storeId,
        fullName: ownerFullName,
        username: ownerUsername.trim(),
        pinHash: pinHash,
        recoveryPinHash: Value(recoveryHash),
        roleId: adminRole.id,
        isOwner: const Value(true),
      ));

      await _storeDao.putSetting(SettingKeys.currency, 'PEN');
      await _storeDao.putSetting(SettingKeys.storeName, storeName);

      final store = await _storeDao.firstStore();
      return BootstrapResult(BootstrapState.ready, store: _mapStore(store!));
    });
    return result;
  }

  Store _mapStore(db.Store s) => Store(
        id: s.id,
        name: s.name,
        rucDni: s.rucDni,
        address: s.address,
        phone: s.phone,
        currency: s.currency,
        active: s.active,
        createdAt: s.createdAt,
        updatedAt: s.updatedAt,
      );

  static Value<String?> _text(String? v) =>
      v == null ? const Value.absent() : Value(v);
}
