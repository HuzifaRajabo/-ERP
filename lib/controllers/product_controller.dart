import 'package:get/get.dart';
import '../repositories/product_repository.dart';
import '../models/product_model.dart';

enum ProductLoadState { idle, loading, loadingMore, error }

class ProductController extends GetxController {
  final ProductRepository repo;

  ProductController(this.repo);

  // ==============================
  // State
  // ==============================

  final RxList<ProductModel> products = <ProductModel>[].obs;
  final Rx<ProductLoadState> state = ProductLoadState.idle.obs;
  final RxBool hasMore = true.obs;
  final RxnString errorMessage = RxnString();
  final RxString searchKeyword = ''.obs;

  int? _cursor;

  // ==============================
  // Getters
  // ==============================

  bool get isLoading => state.value == ProductLoadState.loading;
  bool get isLoadingMore => state.value == ProductLoadState.loadingMore;
  bool get hasError => state.value == ProductLoadState.error;
  bool get isEmpty => products.isEmpty && state.value == ProductLoadState.idle;

  // ==============================
  // Lifecycle
  // ==============================

  @override
  void onInit() {
    super.onInit();

    // تشغيل البحث تلقائياً عند تغيير الكلمة مع debounce
    debounce(
      searchKeyword,
          (_) => loadInitial(),
      time: const Duration(milliseconds: 500),
    );

    loadInitial();
  }

  // ==============================
  // Load / Pagination
  // ==============================

  Future<void> loadInitial() async {
    _reset();
    state.value = ProductLoadState.loading;
    await _fetchPage();
  }

  Future<void> loadMore() async {
    if (!hasMore.value || state.value != ProductLoadState.idle) return;
    state.value = ProductLoadState.loadingMore;
    await _fetchPage();
  }

  Future<void> _fetchPage() async {
    try {
      final page = searchKeyword.value.isEmpty
          ? await repo.getAllProducts(lastId: _cursor)
          : await repo.searchProductsByName(
        searchKeyword.value,
        lastId: _cursor,
      );

      products.addAll(page.products);
      _cursor = page.nextCursor;
      hasMore.value = page.hasNextPage;
      state.value = ProductLoadState.idle;
      errorMessage.value = null;
    } catch (e) {
      state.value = ProductLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  // ==============================
  // Search
  // ==============================

  void search(String keyword) {
    searchKeyword.value = keyword.trim();
    // debounce في onInit تتولى الباقي تلقائياً
  }

  void clearSearch() {
    searchKeyword.value = '';
  }

  // ==============================
  // CRUD
  // ==============================

  Future<void> addProduct(ProductModel product) async {
    try {
      await repo.insertProduct(product);
      refreshProducts();
    } catch (e) {
      state.value = ProductLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  Future<void> updateProduct(ProductModel product) async {
    try {
      await repo.updateProduct(product);
      final index = products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        products[index] = product;
        products.refresh();
      }
    } catch (e) {
      state.value = ProductLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  Future<void> deleteProduct(int id) async {
    try {
      await repo.deleteProduct(id);
      products.removeWhere((p) => p.id == id);
    } catch (e) {
      state.value = ProductLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  Future<ProductModel?> getProductById(int id) {
    return repo.getProductById(id);
  }

  // ==============================
  // Helpers
  // ==============================

  Future<void> refreshProducts() async {
    await loadInitial();
  }

  void _reset() {
    products.clear();
    _cursor = null;
    hasMore.value = true;
    errorMessage.value = null;
    state.value = ProductLoadState.idle;
  }

  void clearError() {
    state.value = ProductLoadState.idle;
    errorMessage.value = null;
  }
}