import 'package:get/get.dart';

import '../models/product_unit_model.dart';
import '../repositories/product_unit_repository.dart';

enum ProductUnitLoadState { idle, loading, error }

/// كنترولر مخصص لإدارة وحدات منتج بعينه في شاشة ProductUnitsScreen.
/// لإدارة الوحدات أثناء إنشاء/تعديل منتج استخدم ProductController.tempUnits.
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

  Future<List<AvailableBatchStock>> getAvailableBatchesForProduct(int productId) async {
    // لا توجد دفعات هنا — هذا الكنترولر للوحدات فقط
    return [];
  }

  Future<void> addUnit(ProductUnitModel unit) async {
    try {
      await repo.insertUnit(unit);
      await loadUnitsForProduct(unit.productId);
      errorMessage.value = null;
    } catch (e) {
      state.value = ProductUnitLoadState.error;
      errorMessage.value = e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<void> updateUnit(ProductUnitModel unit) async {
    try {
      await repo.updateUnit(unit);
      await loadUnitsForProduct(unit.productId);
      errorMessage.value = null;
    } catch (e) {
      state.value = ProductUnitLoadState.error;
      errorMessage.value = e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<void> deactivateUnit(int id, int productId) async {
    try {
      await repo.deleteOrDeactivateUnit(id);
      await loadUnitsForProduct(productId);
      errorMessage.value = null;
    } catch (e) {
      state.value = ProductUnitLoadState.error;
      errorMessage.value = e.toString();
    }
  }
}

/// نتيجة مؤقتة تُستخدم من شاشة الوحدات لإظهار المتاح من كل دفعة
class AvailableBatchStock {
  final dynamic batch;
  final double available;
  const AvailableBatchStock({required this.batch, required this.available});
}
