import 'package:flutter_test/flutter_test.dart';
import 'package:mi_bodega/core/database/app_database.dart'
    hide AppUser, Store, Unit, ProductUnitConversion;
import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/features/auth/data/services/bootstrap_service.dart';
import 'package:mi_bodega/features/catalog/data/repositories/drift_catalog_repository.dart';
import 'package:mi_bodega/features/products/data/repositories/drift_product_repository.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart';
import 'package:mi_bodega/features/sales/data/repositories/drift_sale_repository.dart';
import 'package:mi_bodega/features/sales/domain/entities/sale.dart';

import '../helpers/db_test_utils.dart';

void main() {
  late AppDatabase db;
  late BootstrapService bootstrap;
  late DriftProductRepository products;
  late DriftCatalogRepository catalog;

  Future<void> setup() async {
    db = await openTestMemoryDatabase();
    bootstrap = BootstrapService(db, testPinHasher);
    await bootstrap.seedRolesAndPermissions();
    await bootstrap.setup(
      storeName: 'Bodega',
      ownerFullName: 'Dueño',
      ownerUsername: 'owner',
      ownerPin: '1234',
      ownerRecoveryPin: '9999',
    );
    products = DriftProductRepository(db);
    catalog = DriftCatalogRepository(db);
  }

  int storeId() => 1;

  Future<int> category() async =>
      (await catalog.createCategory('Lácteos')).orNull!.id!;

  Future<int> brand() async => (await catalog.createBrand('Gloria')).orNull!.id!;

  Future<int> baseUnitId() async {
    final units = await db.catalogDao.watchActiveUnits().first;
    return units.first.id;
  }

  tearDown(() async {
    await db.close();
  });

  group('Productos (CRUD + conversiones)', () {
    test('crea producto con stock inicial y conversiones', () async {
      await setup();
      final unitId = await baseUnitId();
      final result = await products.createProduct(
        ProductDraft(
          storeId: storeId(),
          baseUnitId: unitId,
          name: 'Leche',
          sku: 'L-01',
          salePrice: const Money(350),
          purchasePrice: const Money(280),
          initialStock: 50,
        ),
        conversions: [
          ProductUnitConversion(
            productId: 0,
            unitId: unitId,
            factor: 24,
            purchasePrice: const Money(5700),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      );
      expect(result.isOk, isTrue);
      final p = result.orNull!;
      expect(p.name, 'Leche');

      final withStock = await products.productWithStock(p.id!);
      expect(withStock.orNull!.stock, 50);

      final conversions = await products.watchConversions(p.id!).first;
      expect(conversions, hasLength(1));
      expect(conversions.first.factor, 24);
      expect(conversions.first.purchasePrice!.cents, 5700);
    });

    test('edita producto sin tocar stock', () async {
      await setup();
      final unitId = await baseUnitId();
      final p = (await products.createProduct(ProductDraft(
        storeId: storeId(),
        baseUnitId: unitId,
        name: 'Antes',
        initialStock: 10,
      )))
          .orNull!;

      final updated = await products.updateProduct(
        p.id!,
        ProductDraft(
          storeId: storeId(),
          baseUnitId: unitId,
          name: 'Después',
          salePrice: const Money(999),
        ),
      );
      expect(updated.orNull!.name, 'Después');
      final stock = await products.productWithStock(p.id!);
      expect(stock.orNull!.stock, 10);
    });

    test('búsqueda por nombre, código y barras + filtros + orden', () async {
      await setup();
      final unitId = await baseUnitId();
      final catId = await category();
      final brandId = await brand();

      await products.createProduct(ProductDraft(
        storeId: storeId(),
        categoryId: catId,
        brandId: brandId,
        baseUnitId: unitId,
        name: 'Arroz',
        sku: 'ARZ-01',
        barcode: '7750001',
        salePrice: const Money(500),
      ));
      await products.createProduct(ProductDraft(
        storeId: storeId(),
        baseUnitId: unitId,
        name: 'Azúcar',
        sku: 'AZU-02',
        salePrice: const Money(300),
      ));

      // Por nombre.
      var r = await products.searchProducts(storeId: storeId(), search: 'arroz');
      expect(r.orNull!.single.product.name, 'Arroz');
      // Por código.
      r = await products.searchProducts(storeId: storeId(), search: 'AZU-02');
      expect(r.orNull!.single.product.name, 'Azúcar');
      // Por barras.
      r = await products.searchProducts(storeId: storeId(), search: '7750001');
      expect(r.orNull!.single.product.name, 'Arroz');

      // Filtro por categoría.
      r = await products.searchProducts(storeId: storeId(), search: '', categoryId: catId);
      expect(r.orNull!.map((e) => e.product.name), ['Arroz']);

      // Orden por precio ascendente (watch + sort).
      final sorted = await db.productDao
          .watchProducts(storeId: storeId(), sort: ProductSort.priceAsc)
          .first;
      expect(sorted.first.product.name, 'Azúcar');
    });

    test('no permite duplicar código de barras', () async {
      await setup();
      final unitId = await baseUnitId();
      await products.createProduct(ProductDraft(
        storeId: storeId(),
        baseUnitId: unitId,
        name: 'A',
        barcode: 'X1',
      ));
      final dup = await products.createProduct(ProductDraft(
        storeId: storeId(),
        baseUnitId: unitId,
        name: 'B',
        barcode: 'X1',
      ));
      expect(dup.isErr, isTrue);
    });

    test('favorito y activo', () async {
      await setup();
      final unitId = await baseUnitId();
      final p = (await products.createProduct(ProductDraft(
        storeId: storeId(),
        baseUnitId: unitId,
        name: 'A',
      )))
          .orNull!;
      await products.setFavorite(p.id!, true);
      await products.setActive(p.id!, false);

      final withStock = await products.productWithStock(p.id!);
      expect(withStock.orNull!.product.isFavorite, isTrue);
      expect(withStock.orNull!.product.active, isFalse);
    });
  });

  group('Eliminación segura', () {
    test('sin historial se elimina físicamente', () async {
      await setup();
      final unitId = await baseUnitId();
      final p = (await products.createProduct(ProductDraft(
        storeId: storeId(),
        baseUnitId: unitId,
        name: 'A',
        initialStock: 5,
      )))
          .orNull!;

      expect((await products.canHardDelete(p.id!)).orNull, isTrue);
      final result = await products.deleteProduct(p.id!);
      expect(result.orNull, DeleteProductResult.hardDeleted);
      expect((await products.productWithStock(p.id!)).orNull, isNull);
    });

    test('con historial solo se desactiva (soft delete)', () async {
      await setup();
      final unitId = await baseUnitId();
      final p = (await products.createProduct(ProductDraft(
        storeId: storeId(),
        baseUnitId: unitId,
        name: 'A',
        salePrice: const Money(100),
        initialStock: 10,
      )))
          .orNull!;

      // Crear una venta que genere movimiento histórico.
      final roles = await db.authDao.allRoles();
      final admin = roles.firstWhere((r) => r.name == 'Administrador');
      await DriftSaleRepository(db).registerSale(SaleRequest(
        storeId: storeId(),
        userId: admin.id,
        items: [
          SaleItemInput(productId: p.id!, quantity: 1, unitPrice: const Money(100)),
        ],
        paymentMethod: PaymentMethod.cash,
        amountReceived: const Money(100),
      ));

      expect((await products.canHardDelete(p.id!)).orNull, isFalse);
      final result = await products.deleteProduct(p.id!);
      expect(result.orNull, DeleteProductResult.softDeactivated);

      // Sigue existiendo pero desactivado.
      final withStock = await products.productWithStock(p.id!);
      expect(withStock.orNull!.product.active, isFalse);
    });
  });

  group('Seed de unidades', () {
    test('siembra unidades peruanas de forma idempotente', () async {
      await setup();
      final units1 = await db.catalogDao.watchActiveUnits().first;
      expect(units1.length, 13);

      await bootstrap.seedRolesAndPermissions(); // segunda llamada
      final units2 = await db.catalogDao.watchActiveUnits().first;
      expect(units2.length, 13);
      expect(units2.map((u) => u.name), containsAll([
        'Unidad', 'Kilogramo', 'Gramo', 'Litro', 'Mililitro', 'Botella',
        'Lata', 'Paquete', 'Par', 'Docena', 'Caja', 'Bolsa', 'Saco',
      ]));
    });
  });
}
