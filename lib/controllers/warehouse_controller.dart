import 'package:get/get.dart';

import '../models/warehouse_model.dart';
import '../repositories/warehouse_repository.dart';

enum WarehouseLoadState { idle, loading, error }

class WarehouseController extends GetxController {
  final WarehouseRepository repo;

  WarehouseController(this.repo);

  final RxList<WarehouseModel> warehouses = <WarehouseModel>[].obs;
  final Rx<WarehouseLoadState> state = WarehouseLoadState.idle.obs;
  final RxnString errorMessage = RxnString();

  Future<void> loadWarehouses({bool activeOnly = true}) async {
    try {
      state.value = WarehouseLoadState.loading;
      final list = await repo.getAllWarehouses(activeOnly: activeOnly);
      warehouses.assignAll(list);
      state.value = WarehouseLoadState.idle;
      errorMessage.value = null;
    } catch (e) {
      state.value = WarehouseLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  Future<WarehouseModel?> getDefaultWarehouse() async {
    return repo.getDefaultWarehouse();
  }

  Future<void> addWarehouse(WarehouseModel warehouse) async {
    try {
      await repo.insertWarehouse(warehouse);
      await loadWarehouses();
    } catch (e) {
      state.value = WarehouseLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  Future<void> updateWarehouse(WarehouseModel warehouse) async {
    try {
      await repo.updateWarehouse(warehouse);
      await loadWarehouses();
    } catch (e) {
      state.value = WarehouseLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  Future<void> deactivateWarehouse(int id) async {
    try {
      await repo.deactivateWarehouse(id);
      await loadWarehouses();
    } catch (e) {
      state.value = WarehouseLoadState.error;
      errorMessage.value = e.toString();
    }
  }
}
