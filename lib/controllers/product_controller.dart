import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../repositories/product_repository.dart';
import '../repositories/product_unit_repository.dart';
import '../repositories/category_repository.dart';
import '../models/product_model.dart';
import '../models/product_unit_model.dart';
import '../models/category_model.dart';
import '../core/services/app_event_bus.dart';
import '../core/services/product_unit_validator.dart';
import '../core/utils/db_error_handler.dart';

enum ProductLoadState { idle, loading, loadingMore, error }

class ProductController extends GetxController {
  final ProductRepository repo;
  final ProductUnitRepository unitRepo;
  final CategoryRepository categoryRepo;

  ProductController(this.repo, this.unitRepo, this.categoryRepo);

  // ==============================
  // State — قائمة المنتجات
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
  // State — وحدات مؤقتة (لنموذج إنشاء / تعديل المنتج)
  // ==============================

  /// الوحدات المؤقتة أثناء إنشاء أو تعديل منتج في الواجهة.
  /// تُعبأ من loadProductUnits() عند فتح منتج موجود،
  /// أو تبدأ فارغة وتُبنى تدريجياً عبر addTempUnit().
  final RxList<ProductUnitModel> tempUnits = <ProductUnitModel>[].obs;

  /// خطأ التحقق أو الحفظ الخاص بنموذج المنتج
  final RxnString unitFormError = RxnString();

  /// هل جاري حفظ المنتج مع وحداته؟
  final RxBool isSavingProduct = false.obs;

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
              categoryId: selectedCategoryId.value,
              includeInactive: true,
            )
          : await repo.searchProductsByName(
              searchKeyword.value,
              lastId: _cursor,
              categoryId: selectedCategoryId.value,
              includeInactive: true,
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
    } catch (_) {}
  }

  Future<void> addCategory(String name, {String? description}) async {
    try {
      await categoryRepo.insertCategory(CategoryModel(name: name.trim()));
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
  // TempUnits API — يُستخدم من ProductFormScreen
  // ==============================

  /// يُحمّل وحدات منتج موجود إلى tempUnits.
  /// استدعه عند فتح نموذج تعديل منتج.
  Future<void> loadProductUnits(int productId) async {
    try {
      final units = await unitRepo.getUnitsForProduct(
        productId,
        activeOnly: false, // نحمّل الكل ليرى المستخدم المعطّلة
      );
      tempUnits.assignAll(units);
      unitFormError.value = null;
    } catch (e) {
      unitFormError.value = e.toString();
    }
  }

  /// يُضيف وحدة للقائمة المؤقتة (مع تحقق فوري)
  void addTempUnit(ProductUnitModel unit) {
    // إذا كانت هي الأولى وليست base unit، نحذّر
    // التحقق الكامل يحدث عند saveProduct()
    tempUnits.add(unit);
    unitFormError.value = null;
  }

  /// يُعدّل وحدة في موضعها بالقائمة المؤقتة
  void updateTempUnit(int index, ProductUnitModel unit) {
    if (index < 0 || index >= tempUnits.length) return;
    tempUnits[index] = unit;
    unitFormError.value = null;
  }

  /// يحذف وحدة من القائمة المؤقتة
  void removeTempUnit(int index) {
    if (index < 0 || index >= tempUnits.length) return;
    tempUnits.removeAt(index);
  }

  /// يُفرّغ القائمة المؤقتة (استدعه عند إغلاق النموذج أو البدء بمنتج جديد)
  void clearTempUnits() {
    tempUnits.clear();
    unitFormError.value = null;
  }

  /// يُنشئ وحدة أساسية افتراضية للمنتج الجديد
  ProductUnitModel buildDefaultBaseUnit({
    required int costPrice,
    required int salePrice,
    String unitName = 'قطعة',
  }) {
    return ProductUnitModel(
      productId: 0, // سيُعيَّن لاحقاً من saveProduct
      unitName: unitName,
      conversionFactor: 1.0,
      costPrice: costPrice,
      defaultSalePrice: salePrice,
      canBuy: true,
      canSell: true,
      isDefaultSellUnit: true,
      isBaseUnit: true,
    );
  }

  // ==============================
  // saveProduct — الحفظ الكامل (منتج + وحداته)
  // ==============================

  /// ينشئ أو يُعدّل منتجاً مع وحداته ضمن transaction واحدة.
  ///
  /// [product.id == null]  → Create
  /// [product.id != null]  → Update
  ///
  /// يُعيد id المنتج عند النجاح، أو null عند الفشل
  /// (يُعيَّن unitFormError في حالة الفشل).
  Future<int?> saveProduct(
    ProductModel product,
    List<ProductUnitModel> units,
  ) async {
    unitFormError.value = null;

    // ── تحقق مسبق ──
    try {
      ProductUnitValidator.validate(product.name, units);
    } on ProductUnitValidationException catch (e) {
      unitFormError.value = e.message;
      return null;
    }

    isSavingProduct.value = true;
    try {
      int productId;

      if (product.id == null) {
        productId = await repo.createProductWithUnits(product, units);
      } else {
        await repo.updateProductWithUnits(product, units);
        productId = product.id!;
      }

      AppEventBus.instance.notifyProductChanged();
      AppEventBus.instance.notifyInventoryChanged();
      return productId;
    } catch (e) {
      unitFormError.value = e.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      isSavingProduct.value = false;
    }
  }

  // ==============================
  // CRUD بسيط (بدون وحدات — للتوافق مع الكود القديم)
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

  /// حذف منتج — يفوّض للـ Repository منطق "حذف فعلي أو إيقاف".
  ///
  /// - [ProductDeleteResult.deleted]     → رسالة نجاح "تم حذف المنتج".
  /// - [ProductDeleteResult.deactivated] → رسالة توضيحية بـ"تم إيقافه".
  /// - [ProductDeleteResult.notFound]    → لا يُظهر خطأً، المنتج غير موجود.
  Future<void> deleteProduct(int id) async {
    try {
      final result = await repo.deleteOrDeactivateProduct(id);

      AppEventBus.instance.notifyProductChanged();
      AppEventBus.instance.notifyInventoryChanged();

      switch (result) {
        case ProductDeleteResult.deleted:
          errorMessage.value = null;
          Get.snackbar(
            'حذف المنتج',
            'تم حذف المنتج',
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(12),
          );
        case ProductDeleteResult.hasStock:
          errorMessage.value = null;
          Get.snackbar(
            'لا يمكن حذف المنتج',
            'ما زال لهذا المنتج مخزون متبقٍ، '
            'يجب تصفية المخزون أولاً قبل حذفه.',
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 4),
          );
        case ProductDeleteResult.deactivated:
          errorMessage.value = null;
          Get.snackbar(
            'إيقاف المنتج',
            'لا يمكن حذف المنتج لأنه مرتبط بسجلات تاريخية، '
            'لذلك تم إيقافه.',
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 4),
          );
        case ProductDeleteResult.notFound:
          errorMessage.value = null;
      }
    } catch (e) {
      errorMessage.value = DbErrorHandler.handle(e, entityName: 'المنتج');
    }
  }

  Future<ProductModel?> getProductById(int id) {
    return repo.getProductById(id);
  }

  /// إعادة تفعيل منتج موقوف (is_active = 1).
  Future<void> reactivateProduct(int id) async {
    try {
      await repo.setProductActive(id, true);
      AppEventBus.instance.notifyProductChanged();
      AppEventBus.instance.notifyInventoryChanged();
      Get.snackbar(
        'إعادة التفعيل',
        'تمت إعادة تفعيل المنتج',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    } catch (e) {
      errorMessage.value = DbErrorHandler.handle(e, entityName: 'المنتج');
    }
  }

  /// إحضار وحدات منتج بعينه (للقراءة فقط، لا يُغيّر tempUnits)
  Future<List<ProductUnitModel>> getProductUnits(
    int productId, {
    bool activeOnly = true,
  }) {
    return unitRepo.getUnitsForProduct(productId, activeOnly: activeOnly);
  }

  /// إحضار وحدة البيع الافتراضية لمنتج معين
  Future<ProductUnitModel?> getDefaultSellUnit(int productId) {
    return unitRepo.getDefaultSellUnitForProduct(productId);
  }

  /// إحضار الوحدات المسموح بها للبيع
  Future<List<ProductUnitModel>> getSellableUnits(int productId) {
    return unitRepo.getSellableUnits(productId);
  }

  /// إحضار الوحدات المسموح بها للشراء
  Future<List<ProductUnitModel>> getBuyableUnits(int productId) {
    return unitRepo.getBuyableUnits(productId);
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
    unitFormError.value = null;
  }
}
