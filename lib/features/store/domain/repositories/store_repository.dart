import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/features/store/domain/entities/store.dart';

/// Contrato de la tienda y configuración.
abstract interface class StoreRepository {
  Future<Result<Store?>> getStore();

  Stream<Store?> watchStore();

  Future<Result<Store>> createStore(Store store);

  Future<Result<Store>> updateStore(Store store);

  Future<Result<String?>> getSetting(String key);

  Stream<String?> watchSetting(String key);

  Future<Result<void>> putSetting(String key, String value);
}
