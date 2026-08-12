import 'package:drift/drift.dart';

import 'app_database.dart';

/// Construye la estrategia de migración de [db].
///
/// Desde la versión 1. Toda futura evolución del esquema se agrega en
/// `onUpgrade` de forma paso a paso y NUNCA destructiva:
/// - columnas nuevas: `ALTER TABLE ... ADD COLUMN ... DEFAULT`
/// - tablas nuevas: `CREATE TABLE IF NOT EXISTS`
/// - índices nuevos: `CREATE INDEX IF NOT EXISTS`
MigrationStrategy buildMigrationStrategy(AppDatabase db) {
  return MigrationStrategy(
    // Los PRAGMAs se aplican por conexión en `openAppDatabase` (drift_flutter
    // `DriftNativeOptions.setup`). En tests se aplican manualmente.
    onCreate: (m) async {
      await m.createAll();
      await _createBaseIndexes(db);
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v2: PIN de recuperación por usuario (recuperación offline).
        await m.addColumn(db.users, db.users.recoveryPinHash);
      }
      if (from < 3) {
        // v3: motivo de anulación de ventas (trazabilidad).
        await m.addColumn(db.sales, db.sales.cancelReason);
      }
      if (from < 4) {
        // v4: unidad de compra y unidades de venta por unidad de compra.
        await m.addColumn(db.products, db.products.purchaseUnitId);
        await m.addColumn(db.products, db.products.saleUnitsPerPurchaseUnit);
        // Backfill: productos existentes → unidad de compra = unidad base.
        await db.customStatement(
          'UPDATE products SET purchase_unit_id = base_unit_id '
          'WHERE purchase_unit_id IS NULL',
        );
      }
    },
  );
}

/// Índices que requieren sintaxis SQL (únicos parciales) fuera del DSL.
Future<void> _createBaseIndexes(AppDatabase db) async {
  await db.customStatement(
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_products_sku '
    'ON products (sku) WHERE sku IS NOT NULL AND sku != \'\'',
  );
  await db.customStatement(
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_products_barcode '
    'ON products (barcode) WHERE barcode IS NOT NULL AND barcode != \'\'',
  );
}
