import 'package:get/get.dart';
import '../repositories/inventory_repository.dart';
import '../models/inventory_transaction_model.dart';
import '../core/services/app_event_bus.dart';

enum InventoryLoadState { idle, loading, loadingMore, error }

class InventoryController extends GetxController {
  final InventoryRepository repo;

  InventoryController(this.repo);

  // ==============================
  // State: قائمة الحركات
  // ==============================

  final RxList<InventoryTransactionView> transactions =
      <InventoryTransactionView>[].obs;
  final Rx<InventoryLoadState> state = InventoryLoadState.idle.obs;
  final RxBool hasMore = true.obs;
  final RxnString errorMessage = RxnString();

  // ==============================
  // State: ملخص المخزون
  // ==============================

  final RxList<ProductStockSummary> stockSummaries =
      <ProductStockSummary>[].obs;
  final RxBool isLoadingStock = false.obs;

  // ==============================
  // Filters
  // ==============================

  final Rxn<InventoryTransactionType> selectedType =
  Rxn<InventoryTransactionType>();
  final RxnInt selectedProductId = RxnInt();

  int? _cursor;

  // ==============================
  // Getters
  // ==============================

  bool get isLoading => state.value == InventoryLoadState.loading;
  bool get isLoadingMore => state.value == InventoryLoadState.loadingMore;
  bool get hasError => state.value == InventoryLoadState.error;
  bool get isEmpty =>
      transactions.isEmpty && state.value == InventoryLoadState.idle;

  // ==============================
  // Lifecycle
  // ==============================

  @override
  void onInit() {
    super.onInit();
    AppEventBus.instance.listenToInventory(refreshAll);
    loadInitial();
    loadStockSummaries();
  }

  // ==============================
  // Load / Pagination
  // ==============================

  Future<void> loadInitial() async {
    _reset();
    state.value = InventoryLoadState.loading;
    await _fetchPage();
  }

  Future<void> loadMore() async {
    if (!hasMore.value || state.value != InventoryLoadState.idle) return;
    state.value = InventoryLoadState.loadingMore;
    await _fetchPage();
  }

  Future<void> _fetchPage() async {
    try {
      InventoryTransactionPage page;

      // أولوية الفلتر: منتج > نوع > الكل
      if (selectedProductId.value != null) {
        page = await repo.getTransactionsByProduct(
          productId: selectedProductId.value!,
          lastId: _cursor,
        );
      } else if (selectedType.value != null) {
        page = await repo.getTransactionsByType(
          type: selectedType.value!,
          lastId: _cursor,
        );
      } else {
        page = await repo.getAllTransactions(lastId: _cursor);
      }

      transactions.addAll(page.transactions);
      _cursor = page.nextCursor;
      hasMore.value = page.hasNextPage;
      state.value = InventoryLoadState.idle;
      errorMessage.value = null;
    } catch (e) {
      state.value = InventoryLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  // ==============================
  // Filters
  // ==============================

  void filterByType(InventoryTransactionType? type) {
    selectedType.value = type;
    selectedProductId.value = null;
    loadInitial();
  }

  void filterByProduct(int? productId) {
    selectedProductId.value = productId;
    selectedType.value = null;
    loadInitial();
  }

  void clearFilters() {
    selectedType.value = null;
    selectedProductId.value = null;
    loadInitial();
  }

  // ==============================
  // ملخص المخزون
  // ==============================

  Future<void> loadStockSummaries() async {
    try {
      isLoadingStock.value = true;
      final summaries = await repo.getAllProductsStock();
      stockSummaries.assignAll(summaries);
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoadingStock.value = false;
    }
  }

  Future<void> refreshAll() async {
    await loadInitial();
    await loadStockSummaries();
  }

  // ==============================
  // Helpers
  // ==============================

  void _reset() {
    transactions.clear();
    _cursor = null;
    hasMore.value = true;
    errorMessage.value = null;
    state.value = InventoryLoadState.idle;
  }

  void clearError() {
    state.value = InventoryLoadState.idle;
    errorMessage.value = null;
  }
}