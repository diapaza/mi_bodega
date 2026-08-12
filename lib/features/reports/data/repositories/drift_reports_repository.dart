import 'package:drift/drift.dart';

import 'package:mi_bodega/core/database/app_database.dart' as db;
import 'package:mi_bodega/core/error/failures.dart';
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart';
import 'package:mi_bodega/features/reports/domain/entities/report.dart';
import 'package:mi_bodega/features/reports/domain/repositories/reports_repository.dart';
import 'package:mi_bodega/features/sales/domain/entities/sale.dart';

class DriftReportsRepository implements ReportsRepository {
  final db.AppDatabase database;

  DriftReportsRepository(this.database);

  @override
  Future<Result<SalesSummary>> summary({
    required int storeId,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      // Ingresos y nº de ventas.
      final revenueQuery = database.selectOnly(database.sales)
        ..addColumns([
          database.sales.total.sum(),
          database.sales.id.count(),
        ]);
      _applyRange(revenueQuery, storeId, from, to);
      final revRow = await revenueQuery.getSingle();
      final revenue = revRow.read(database.sales.total.sum()) ?? 0;
      final count = revRow.read(database.sales.id.count()) ?? 0;

      // COGS: Σ unit_cost × quantity de las ventas completadas (en Dart).
      final itemsQuery = database.select(database.saleItems).join([
        innerJoin(
          database.sales,
          database.sales.id.equalsExp(database.saleItems.saleId),
        ),
      ]);
      _applyWhere(itemsQuery, storeId, from, to);
      final itemRows = await itemsQuery.get();
      final cogs = itemRows.fold<int>(0, (sum, r) {
        final item = r.readTable(database.saleItems);
        return sum + (item.unitCost * item.quantity).round();
      });

      // Desglose por método de pago.
      final methodQuery = database.select(database.payments).join([
        innerJoin(
          database.sales,
          database.sales.id.equalsExp(database.payments.saleId),
        ),
      ]);
      _applyWhere(methodQuery, storeId, from, to);
      methodQuery.groupBy([database.payments.method]);
      methodQuery.addColumns([database.payments.amount.sum()]);
      final methodRows = await methodQuery.get();
      final byMethod = <PaymentMethod, Money>{};
      for (final r in methodRows) {
        byMethod[PaymentMethodX.fromName(r.readTable(database.payments).method)] =
            Money(r.read(database.payments.amount.sum()) ?? 0);
      }

      // Desglose por vendedor.
      final userQuery = database.selectOnly(database.sales)
        ..addColumns([
          database.sales.userId,
          database.sales.total.sum(),
        ]);
      _applyRange(userQuery, storeId, from, to);
      userQuery.groupBy([database.sales.userId]);
      final userRows = await userQuery.get();
      final byUser = <int, Money>{};
      for (final r in userRows) {
        byUser[r.read(database.sales.userId)!] =
            Money(r.read(database.sales.total.sum()) ?? 0);
      }

      final revenueMoney = Money(revenue);
      final cogsMoney = Money(cogs);
      final profit = revenueMoney - cogsMoney;

      return Ok(SalesSummary(
        revenue: revenueMoney,
        count: count,
        cogs: cogsMoney,
        grossProfit: profit,
        margin: revenueMoney.isZero ? 0 : profit.cents / revenueMoney.cents,
        byMethod: byMethod,
        byUser: byUser,
      ));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<List<ProductSalesStats>>> topProducts({
    required int storeId,
    DateTime? from,
    DateTime? to,
    int limit = 10,
  }) async {
    try {
      final rows = await (database.select(database.saleItems).join([
        innerJoin(
          database.sales,
          database.sales.id.equalsExp(database.saleItems.saleId),
        ),
        innerJoin(
          database.products,
          database.products.id.equalsExp(database.saleItems.productId),
        ),
        leftOuterJoin(
          database.inventory,
          database.inventory.productId.equalsExp(database.products.id),
        ),
      ])
            ..where(_completedRange(storeId, from, to)))
          .get();

      // Agregación en Dart (volúmenes de bodega pequeños).
      final byProduct = <int, _ProductAgg>{};
      for (final r in rows) {
        final item = r.readTable(database.saleItems);
        final agg = byProduct.putIfAbsent(item.productId, () => _ProductAgg());
        agg.productRow = r.readTable(database.products);
        agg.stock = r.readTableOrNull(database.inventory)?.quantity ?? 0;
        agg.quantity += item.quantity;
        agg.revenue += item.subtotal;
        agg.cost += (item.unitCost * item.quantity).round();
      }

      final result = byProduct.values.toList()
        ..sort((a, b) => b.quantity.compareTo(a.quantity));
      return Ok(result.take(limit).map((agg) {
        final p = agg.productRow!;
        final stock = ProductStock(
          Product(
            id: p.id,
            storeId: p.storeId,
            categoryId: p.categoryId,
            brandId: p.brandId,
            baseUnitId: p.baseUnitId,
            sku: p.sku,
            barcode: p.barcode,
            name: p.name,
            description: p.description,
            purchasePrice: Money(p.purchasePrice),
            salePrice: Money(p.salePrice),
            costPrice: Money(p.costPrice),
            stockMin: p.stockMin,
            stockMax: p.stockMax,
            photoPath: p.photoPath,
            active: p.active,
            isFavorite: p.isFavorite,
            createdAt: p.createdAt,
            updatedAt: p.updatedAt,
          ),
          agg.stock,
        );
        return ProductSalesStats(
          productStock: stock,
          quantity: agg.quantity,
          revenue: Money(agg.revenue),
          cost: Money(agg.cost),
          profit: Money(agg.revenue - agg.cost),
        );
      }).toList());
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<List<DailySalesPoint>>> dailySeries({
    required int storeId,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final conds = <String>['store_id = ?', 'status = ?'];
      final vars = <Variable>[
        Variable.withInt(storeId),
        Variable.withString('completed'),
      ];
      if (from != null) {
        conds.add('sale_date >= ?');
        vars.add(Variable.withDateTime(from));
      }
      if (to != null) {
        conds.add('sale_date < ?');
        vars.add(Variable.withDateTime(to));
      }
      final sql = 'SELECT date((sale_date / 1000), \'unixepoch\') AS day, '
          'SUM(total) AS revenue, COUNT(*) AS count FROM sales '
          'WHERE ${conds.join(' AND ')} '
          'GROUP BY date((sale_date / 1000), \'unixepoch\') ORDER BY day';
      final rows = await database.customSelect(sql, variables: vars).get();

      return Ok(rows.map((r) {
        final dayRaw = r.read<String>('day') as String? ?? '';
        final parts = dayRaw.split('-');
        return DailySalesPoint(
          day: parts.length == 3
              ? DateTime(
                  int.parse(parts[0]),
                  int.parse(parts[1]),
                  int.parse(parts[2]),
                )
              : DateTime.now(),
          revenue: Money(r.read<int>('revenue')),
          count: r.read<int>('count'),
        );
      }).toList());
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  void _applyWhere(
    JoinedSelectStatement<HasResultSet, dynamic> query,
    int storeId,
    DateTime? from,
    DateTime? to,
  ) {
    query.where(_completedRange(storeId, from, to));
  }

  Expression<bool> _completedRange(int storeId, DateTime? from, DateTime? to) {
    final conds = <Expression<bool>>[
      database.sales.storeId.equals(storeId),
      database.sales.status.equals('completed'),
    ];
    if (from != null) {
      conds.add(database.sales.saleDate.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      conds.add(database.sales.saleDate.isSmallerThanValue(to));
    }
    return conds.reduce((a, b) => a & b);
  }

  void _applyRange(
    dynamic query,
    int storeId,
    DateTime? from,
    DateTime? to,
  ) {
    query.where(_completedRange(storeId, from, to));
  }
}

class _ProductAgg {
  db.Product? productRow;
  double stock = 0;
  double quantity = 0;
  int revenue = 0;
  int cost = 0;
}
