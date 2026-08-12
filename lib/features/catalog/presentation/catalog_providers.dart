import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_bodega/core/di/app_providers.dart';
import 'package:mi_bodega/features/catalog/domain/entities/catalog.dart';

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  print('[Catalog] categoriesProvider created');
  return ref.watch(catalogRepositoryProvider).watchCategories();
});

final brandsProvider = StreamProvider<List<Brand>>((ref) {
  print('[Catalog] brandsProvider created');
  return ref.watch(catalogRepositoryProvider).watchBrands();
});

final unitsProvider = StreamProvider<List<Unit>>((ref) {
  print('[Catalog] unitsProvider created');
  return ref.watch(catalogRepositoryProvider).watchUnits();
});
