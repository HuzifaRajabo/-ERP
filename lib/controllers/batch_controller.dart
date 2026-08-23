import 'package:get/get.dart';

import '../models/batch_model.dart';
import '../repositories/batch_repository.dart';

enum BatchLoadState { idle, loading, error }

class BatchController extends GetxController {
  final BatchRepository repo;

  BatchController(this.repo);

  final RxList<BatchModel> batches = <BatchModel>[].obs;
  final Rx<BatchLoadState> state = BatchLoadState.idle.obs;
  final RxnString errorMessage = RxnString();

  Future<void> loadBatchesForProduct(int productId) async {
    try {
      state.value = BatchLoadState.loading;
      final list = await repo.getBatchesForProduct(productId);
      batches.assignAll(list);
      state.value = BatchLoadState.idle;
      errorMessage.value = null;
    } catch (e) {
      state.value = BatchLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  Future<List<BatchStock>> getAvailableBatchesForProduct(
    int productId, {
    int? warehouseId,
  }) async {
    return repo.getAvailableBatchesForProduct(productId, warehouseId: warehouseId);
  }

  Future<List<BatchStock>> getExpiringBatches({
    int withinDays = 30,
    int? warehouseId,
  }) async {
    return repo.getExpiringBatches(withinDays: withinDays, warehouseId: warehouseId);
  }

  Future<void> addBatch(BatchModel batch) async {
    try {
      await repo.insertBatch(batch);
      if (batch.productId != 0) {
        await loadBatchesForProduct(batch.productId);
      }
    } catch (e) {
      state.value = BatchLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  Future<void> updateBatch(BatchModel batch) async {
    try {
      await repo.updateBatch(batch);
      if (batch.productId != 0) {
        await loadBatchesForProduct(batch.productId);
      }
    } catch (e) {
      state.value = BatchLoadState.error;
      errorMessage.value = e.toString();
    }
  }
}
