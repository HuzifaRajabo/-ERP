import 'package:get/get.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/stock_transfer_repository.dart';
import '../repositories/warehouse_repository.dart';import '../models/warehouse_model.dart';
import '../core/services/app_event_bus.dart';

enum TransferState { idle, loading, submitting, success, error }

/// يدير عملية نقل مخزون بين مستودعين لمنتج واحد.
class TransferController extends GetxController {
  final WarehouseRepository warehouseRepo;
  final InventoryRepository inventoryRepo;
  final StockTransferRepository transferRepo;

  TransferController({
    required this.warehouseRepo,
    required this.inventoryRepo,
    required this.transferRepo,
  });

  // ==============================
  // State
  // ==============================

  final Rx<TransferState> state = TransferState.idle.obs;
  final RxnString errorMessage = RxnString();

  final RxList<WarehouseModel> warehouses = <WarehouseModel>[].obs;
  final RxnInt fromWarehouseId = RxnInt();
  final RxnInt toWarehouseId = RxnInt();

  // منتجات المتوفرة في المستودع المصدر
  final RxList<ProductStockSummary> availableProducts =
      <ProductStockSummary>[].obs;
  final RxBool isLoadingProducts = false.obs;

  final RxnInt selectedProductId = RxnInt();
  final RxnDouble quantity = RxnDouble();
  final RxnString notes = RxnString();

  StockTransferResult? _lastResult;
  StockTransferResult? get lastResult => _lastResult;

  @override
  void onInit() {
    super.onInit();
    loadWarehouses();
  }

  Future<void> loadWarehouses() async {
    try {
      state.value = TransferState.loading;
      final list = await warehouseRepo.getAllWarehouses(activeOnly: true);
      warehouses.assignAll(list);
      state.value = TransferState.idle;
    } catch (e) {
      state.value = TransferState.error;
      errorMessage.value = e.toString();
    }
  }

  void selectFromWarehouse(int? id) {
    fromWarehouseId.value = id;
    selectedProductId.value = null;
    quantity.value = null;
    availableProducts.clear();
    if (toWarehouseId.value == id) toWarehouseId.value = null;
    if (id != null) loadAvailableProducts(id);
  }

  Future<void> loadAvailableProducts(int warehouseId) async {
    try {
      isLoadingProducts.value = true;
      final summaries =
          await inventoryRepo.getAllProductsStockByWarehouse(warehouseId);
      availableProducts.assignAll(
        summaries.where((s) => s.available > 0).toList(),
      );
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoadingProducts.value = false;
    }
  }

  void selectProduct(int? id) {
    selectedProductId.value = id;
    quantity.value = null;
  }

  /// يُنفّذ التحويل. يُعيد true عند النجاح.
  Future<bool> submit() async {
    final from = fromWarehouseId.value;
    final to = toWarehouseId.value;
    final productId = selectedProductId.value;
    final qty = quantity.value;

    if (from == null || to == null) {
      errorMessage.value = 'اختر المستودع المصدر والمستودع الوجهة';
      return false;
    }
    if (from == to) {
      errorMessage.value = 'لا يمكن النقل إلى نفس المستودع';
      return false;
    }
    if (productId == null) {
      errorMessage.value = 'اختر المنتج المراد نقله';
      return false;
    }
    if (qty == null || qty <= 0) {
      errorMessage.value = 'أدخل كمية صحيحة أكبر من صفر';
      return false;
    }

    try {
      state.value = TransferState.submitting;
      _lastResult = await transferRepo.transferStock(
        fromWarehouseId: from,
        toWarehouseId: to,
        productId: productId,
        quantity: qty,
        notes: notes.value,
      );
      state.value = TransferState.success;
      errorMessage.value = null;
      AppEventBus.instance.notifyInventoryChanged();
      return true;
    } catch (e) {
      state.value = TransferState.error;
      errorMessage.value = e.toString();
      return false;
    }
  }

  void resetTransfer() {
    toWarehouseId.value = null;
    selectedProductId.value = null;
    quantity.value = null;
    notes.value = null;
    _lastResult = null;
    state.value = TransferState.idle;
    errorMessage.value = null;
    if (fromWarehouseId.value != null) {
      loadAvailableProducts(fromWarehouseId.value!);
    }
  }
}
