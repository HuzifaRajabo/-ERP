import 'package:get/get.dart';
import '../core/services/app_event_bus.dart';
import '../models/inventory_transaction_model.dart';
import '../models/warehouse_model.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/warehouse_repository.dart';

enum WarehouseDetailTab { overview, inventory, movements, transfer }

enum WarehouseMovementState { idle, loading, loadingMore, error }

/// يعرض تفاصيل مستودع واحد: نظرة عامة، المخزون، الحركات.
/// (التحويل عملية مستقلة تُنفَّذ من شاشته الخاصة).
class WarehouseDetailController extends GetxController {
  final WarehouseRepository warehouseRepo;
  final InventoryRepository inventoryRepo;

  final int warehouseId;

  WarehouseDetailController({
    required this.warehouseId,
    required this.warehouseRepo,
    required this.inventoryRepo,
  });

  // ==============================
  // State
  // ==============================

  final Rxn<WarehouseModel> warehouse = Rxn<WarehouseModel>();
  final RxInt inventoryValue = 0.obs;
  final RxInt productCount = 0.obs;
  final RxInt transferCount = 0.obs;

  final RxList<ProductStockSummary> stockSummaries =
      <ProductStockSummary>[].obs;
  final RxBool isLoadingStock = false.obs;

  final RxList<InventoryTransactionView> movements =
      <InventoryTransactionView>[].obs;
  final Rx<WarehouseMovementState> movementState = WarehouseMovementState.idle.obs;
  final RxBool hasMore = true.obs;
  final RxnString errorMessage = RxnString();
  final Rxn<InventoryTransactionType> selectedType = Rxn<InventoryTransactionType>();

  // تفاصيل دفعات منتج محدد داخل المستودع
  final Rxn<Map<String, dynamic>> selectedProductBatches = Rxn();
  final RxBool isLoadingBatches = false.obs;

  int? _cursor;

  Worker? _inventoryListener;

  bool get isLoadingMovement =>
      movementState.value == WarehouseMovementState.loading;
  bool get hasMovementError =>
      movementState.value == WarehouseMovementState.error;
  bool get isEmptyMovements => movements.isEmpty;

  @override
  void onInit() {
    super.onInit();
    _inventoryListener =
        AppEventBus.instance.listenToInventory(refreshAll);
    loadWarehouse();
    loadOverview();
    loadStock();
    resetMovements();
  }

  @override
  void onClose() {
    _inventoryListener?.dispose();
    super.onClose();
  }

  Future<void> loadWarehouse() async {
    warehouse.value = await warehouseRepo.getWarehouseById(warehouseId);
  }

  // ==============================
  // Overview
  // ==============================

  Future<void> loadOverview() async {
    inventoryValue.value = await inventoryRepo.getWarehouseInventoryValue(warehouseId);
  }

  // ==============================
  // Inventory (مخزون المستودع)
  // ==============================

  Future<void> loadStock() async {
    try {
      isLoadingStock.value = true;
      final summaries =
          await inventoryRepo.getAllProductsStockByWarehouse(warehouseId);
      stockSummaries.assignAll(summaries.where((s) => s.available > 0).toList());
      productCount.value = stockSummaries.length;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoadingStock.value = false;
    }
  }

  // ==============================
  // Movements (حركات المستودع)
  // ==============================

  Future<void> resetMovements() async {
    _reset();
    movementState.value = WarehouseMovementState.loading;
    await _fetchMovements();
    _countTransfers();
  }

  Future<void> loadMoreMovements() async {
    if (!hasMore.value || movementState.value != WarehouseMovementState.idle) return;
    movementState.value = WarehouseMovementState.loadingMore;
    await _fetchMovements();
  }

  void filterByType(InventoryTransactionType? type) {
    selectedType.value = type;
    resetMovements();
  }

  Future<void> _fetchMovements() async {
    try {
      final page = await inventoryRepo.getTransactionsByWarehouse(
        warehouseId: warehouseId,
        type: selectedType.value,
        lastId: _cursor,
      );
      movements.addAll(page.transactions);
      _cursor = page.nextCursor;
      hasMore.value = page.hasNextPage;
      movementState.value = WarehouseMovementState.idle;
      errorMessage.value = null;
    } catch (e) {
      movementState.value = WarehouseMovementState.error;
      errorMessage.value = e.toString();
    }
  }

  Future<void> _countTransfers() async {
    transferCount.value =
        await inventoryRepo.getWarehouseTransferCount(warehouseId);
  }

  // ==============================
  // تفاصيل دفعات منتج في المستودع
  // ==============================

  Future<void> loadProductBatches(int productId) async {
    try {
      isLoadingBatches.value = true;
      final batches = await inventoryRepo.getWarehouseProductBatches(
        warehouseId: warehouseId,
        productId: productId,
      );
      selectedProductBatches.value = {
        'productId': productId,
        'batches': batches,
      };
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoadingBatches.value = false;
    }
  }

  // ==============================
  // Helpers
  // ==============================

  void _reset() {
    movements.clear();
    _cursor = null;
    hasMore.value = true;
    errorMessage.value = null;
    movementState.value = WarehouseMovementState.idle;
  }

  Future<void> refreshAll() async {
    await loadWarehouse();
    await loadOverview();
    await loadStock();
    await resetMovements();
  }
}

