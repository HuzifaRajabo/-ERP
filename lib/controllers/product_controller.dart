import 'package:get/get.dart';
import '../repositories/product_repository.dart';
import '../repositories/category_repository.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';
import '../core/services/app_event_bus.dart';
import '../core/utils/db_error_handler.dart';

enum ProductLoadState { idle, loading, loadingMore, error }

class ProductController extends GetxController {
  final ProductRepository repo;
  final CategoryRepository categoryRepo;

  ProductController(this.repo, this.categoryRepo);

  // ==============================
  // State
  // ==============================

  final RxList<ProductModel> products = <ProductModel>[].obs;
  final RxList<CategoryModel> categories = <CategoryModel>[].obs;
  final Rx<ProductLoadState> state = ProductLoadState.idle.obs;
  final RxBool hasMore = true.obs;
  final RxnString errorMessage = RxnString();
  final RxString searchKeyword = ''.obs;
  final Rxn<int> selectedCategoryId = Rxn<int>();

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

    AppEventBus.instance.listenToProducts(loadInitial);

    loadInitial();
    loadCategories();
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
          ? await repo.getAllProducts(
              lastId: _cursor,
            )
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
  // Search & Filter
  // ==============================

  void search(String keyword) {
    searchKeyword.value = keyword.trim();
    // debounce في onInit تتولى الباقي تلقائياً
  }

  void clearSearch() {
    searchKeyword.value = '';
  }

  void filterByCategory(int? categoryId) {
    selectedCategoryId.value = categoryId;
    loadInitial();
  }

  void clearCategoryFilter() {
    selectedCategoryId.value = null;
    loadInitial();
  }

  // ==============================
  // Categories
  // ==============================

  Future<void> loadCategories() async {
    try {
      categories.value = await categoryRepo.getAllCategories();
    } catch (_) {
      // الأصناف اختيارية — أي خطأ لا يوقف التطبيق
    }
  }

  Future<void> addCategory(String name, {String? description}) async {
    try {
      await categoryRepo.insertCategory(
        CategoryModel(name: name.trim()),
      );
      await loadCategories();
    } catch (e) {
      errorMessage.value = e.toString();
    }
  }

  Future<void> updateCategory(CategoryModel category) async {
    try {
      await categoryRepo.updateCategory(category);
      await loadCategories();
    } catch (e) {
      errorMessage.value = e.toString();
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      final category = categories.firstWhereOrNull((c) => c.id == id);
      if (category != null) {
        await categoryRepo.deleteOrDeactivateCategory(category);
      }
      if (selectedCategoryId.value == id) clearCategoryFilter();
      await loadCategories();
    } catch (e) {
      errorMessage.value = e.toString();
    }
  }

  // ==============================
  // CRUD
  // ==============================

  Future<void> addProduct(ProductModel product) async {
    try {
      await repo.insertProduct(product);
      AppEventBus.instance.notifyProductChanged();
      AppEventBus.instance.notifyInventoryChanged();
    } catch (e) {
      state.value = ProductLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  Future<void> updateProduct(ProductModel product) async {
    try {
      await repo.updateProduct(product);
      AppEventBus.instance.notifyProductChanged();
      AppEventBus.instance.notifyInventoryChanged();
    } catch (e) {
      state.value = ProductLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  Future<void> deleteProduct(int id) async {
    try {
      await repo.deleteProduct(id);
      AppEventBus.instance.notifyProductChanged();
      AppEventBus.instance.notifyInventoryChanged();
    } catch (e) {
      state.value = ProductLoadState.error;
      errorMessage.value = DbErrorHandler.handle(e, entityName: 'المنتج');
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