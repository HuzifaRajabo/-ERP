import 'package:get/get.dart';

import '../models/product_unit_model.dart';
import '../repositories/product_unit_repository.dart';

enum ProductUnitLoadState { idle, loading, error }

class ProductUnitController extends GetxController {
  final ProductUnitRepository repo;

  ProductUnitController(this.repo);

  final RxList<ProductUnitModel> units = <ProductUnitModel>[].obs;
  final Rx<ProductUnitLoadState> state = ProductUnitLoadState.idle.obs;
  final RxnString errorMessage = RxnString();

  Future<void> loadUnitsForProduct(int productId, {bool activeOnly = true}) async {
    try {
      state.value = ProductUnitLoadState.loading;
      final list = await repo.getUnitsForProduct(productId, activeOnly: activeOnly);
      units.assignAll(list);
      state.value = ProductUnitLoadState.idle;
      errorMessage.value = null;
    } catch (e) {
      state.value = ProductUnitLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  Future<ProductUnitModel?> getBaseUnitForProduct(int productId) async {
    return repo.getBaseUnitForProduct(productId);
  }

  Future<void> addUnit(ProductUnitModel unit) async {
    try {
      await repo.insertUnit(unit);
      await loadUnitsForProduct(unit.productId);
    } catch (e) {
      state.value = ProductUnitLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  Future<void> updateUnit(ProductUnitModel unit) async {
    try {
      await repo.updateUnit(unit);
      await loadUnitsForProduct(unit.productId);
    } catch (e) {
      state.value = ProductUnitLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  Future<void> deactivateUnit(int id, int productId) async {
    try {
      await repo.deactivateUnit(id);
      await loadUnitsForProduct(productId);
    } catch (e) {
      state.value = ProductUnitLoadState.error;
      errorMessage.value = e.toString();
    }
  }
}
