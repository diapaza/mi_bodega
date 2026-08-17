import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_bodega/core/di/app_providers.dart';
import 'package:mi_bodega/features/catalog/domain/entities/catalog.dart';

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(catalogRepositoryProvider).watchCategories();
});

final brandsProvider = StreamProvider<List<Brand>>((ref) {
  return ref.watch(catalogRepositoryProvider).watchBrands();
});

final unitsProvider = StreamProvider<List<Unit>>((ref) {
  return ref.watch(catalogRepositoryProvider).watchUnits();
});
