// lib/controllers/return_controller.dart

import 'package:get/get.dart';
import '../repositories/return_repository.dart';
import '../models/return_model.dart';
import '../core/services/app_event_bus.dart';
import '../core/utils/unit_conversion.dart';
import '../models/product_unit_model.dart';

enum ReturnLoadState { idle, loading, error }

class ReturnController extends GetxController {
  final ReturnRepository repo;

  ReturnController(this.repo);

  // ==============================
  // State: قائمة المرتجعات
  // ==============================

  final RxList<ReturnModel> returns = <ReturnModel>[].obs;
  final Rx<ReturnLoadState> state = ReturnLoadState.idle.obs;
  final RxnString errorMessage = RxnString();

  bool get isLoading => state.value == ReturnLoadState.loading;
  bool get hasError => state.value == ReturnLoadState.error;

  // ==============================
  // State: نموذج إنشاء مرتجع
  // ==============================

  final RxList<ReturnableItem> returnableItems = <ReturnableItem>[].obs;
  final RxBool isLoadingItems = false.obs;
  final RxBool isSaving = false.obs;
  final RxnString formError = RxnString();

  // نوع المرتجع الحالي (يحدّد ما إن كان المرتجع يُقصّ على المخزون الفعلي)
  ReturnType? currentReturnType;

  // المجموع الكلي للمرتجع الحالي
  int get returnTotal => returnableItems.fold(
    0, (sum, i) => sum + i.lineTotal,
  );

  // ==============================
  // Lifecycle
  // ==============================

  @override
  void onInit() {
    super.onInit();
    AppEventBus.instance.listenToInvoices(loadAllReturns);
  }

  // ==============================
  // جلب الأسطر القابلة للإرجاع
  // ==============================

  Future<void> loadReturnableItems(int invoiceId, {ReturnType? type}) async {
    try {
      isLoadingItems.value = true;
      formError.value = null;
      currentReturnType = type;
      final items = await repo.getReturnableItems(invoiceId);
      returnableItems.assignAll(items);

      if (items.isEmpty) {
        formError.value = 'لا توجد كميات قابلة للإرجاع في هذه الفاتورة';
      }
    } catch (e) {
      formError.value = e.toString();
    } finally {
      isLoadingItems.value = false;
    }
  }

  // ==============================
  // تحديث الكمية المحددة للإرجاع (التحقق بالوحدة الأساسية)
  // ==============================

  void updateReturnQuantity(int index, double quantity) {
    if (index < 0 || index >= returnableItems.length) return;

    final item = returnableItems[index];

    if (quantity < 0) {
      formError.value = 'الكمية لا يمكن أن تكون سالبة';
      return;
    }

    final requestedBase = UnitConversion.toBaseQuantity(
      quantity,
      item.selectedUnitConversionFactor,
    );

    if (requestedBase > item.remainingBaseQuantity + 0.0001) {
      final unitLabel = item.selectedUnitName ??
          item.baseUnitName ??
          'وحدة أساسية';
      formError.value =
          'لا يمكن إرجاع هذه الكمية. الكمية المتبقية القابلة للإرجاع '
          'هي ${_fmtQty(item.remainingBaseQuantity)} $unitLabel '
          'للمنتج "${item.productName}".';
      return;
    }

    formError.value = null;
    returnableItems[index] = item.copyWith(selectedQuantity: quantity);
    returnableItems.refresh();
  }

  // ==============================
  // تغيير وحدة الإرجاع لسطر معيّن
  // ==============================

  void updateReturnUnit(int index, ProductUnitModel unit) {
    if (index < 0 || index >= returnableItems.length) return;

    final item = returnableItems[index];
    final keepBase = item.selectedBaseQuantity;

    returnableItems[index] = item.copyWith(
      selectedUnitId: unit.id,
      selectedUnitName: unit.unitName,
      selectedUnitConversionFactor: unit.conversionFactor,
    );
    returnableItems.refresh();
    formError.value = null;

    // أعد حساب الكمية بالوحدة الجديدة لنفس المقدار الأساسي المحتفظ به
    final updated = returnableItems[index];
    if (keepBase > 0) {
      updateReturnQuantity(index, updated.remainingInUnit(keepBase));
    }
  }

  /// الكمية الكاملة الممكنة (بالوحدة المختارة) = المتبقي بالأساسية ÷ معاملها
  void selectFullQuantity(int index) {
    if (index < 0 || index >= returnableItems.length) return;
    final item = returnableItems[index];
    final fullInUnit = item.remainingInUnit(item.remainingBaseQuantity);
    updateReturnQuantity(index, fullInUnit);
  }

  // تصفير سطر معين
  void clearQuantity(int index) {
    updateReturnQuantity(index, 0);
  }

  String _fmtQty(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  // ==============================
  // حفظ المرتجع
  // ==============================

  Future<bool> saveReturn({
    required int originalInvoiceId,
    required ReturnType type,
    String? notes,
  }) async {
    formError.value = null;

    final activeItems =
    returnableItems.where((i) => i.selectedQuantity > 0).toList();

    if (activeItems.isEmpty) {
      formError.value = 'يجب تحديد كمية واحدة على الأقل للإرجاع';
      return false;
    }

    isSaving.value = true;

    try {
      await repo.createReturn(
        originalInvoiceId: originalInvoiceId,
        type: type,
        notes: notes,
        items: activeItems,
      );

      // إخطار باقي الـ Controllers
      AppEventBus.instance.notifyInvoiceChanged();
      AppEventBus.instance.notifyInventoryChanged();

      isSaving.value = false;
      return true;
    } catch (e) {
      formError.value = e.toString().replaceFirst('Exception: ', '');
      isSaving.value = false;
      return false;
    }
  }

  // ==============================
  // مرتجعات فاتورة معينة
  // ==============================

  final RxList<ReturnModel> invoiceReturns = <ReturnModel>[].obs;

  Future<void> loadInvoiceReturns(int invoiceId) async {
    try {
      final result = await repo.getReturnsByInvoice(invoiceId);
      invoiceReturns.assignAll(result);
    } catch (e) {
      errorMessage.value = e.toString();
    }
  }

  // ==============================
  // تفاصيل مرتجع
  // ==============================

  Future<ReturnWithItems?> getReturnWithItems(int returnId) {
    return repo.getReturnWithItems(returnId);
  }

  // ==============================
  // قائمة كل المرتجعات
  // ==============================

  Future<void> loadAllReturns() async {
    try {
      state.value = ReturnLoadState.loading;
      final page = await repo.getAllReturns();
      returns.assignAll(page.returns);
      state.value = ReturnLoadState.idle;
    } catch (e) {
      state.value = ReturnLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  // ==============================
  // Helpers
  // ==============================

  void resetForm() {
    returnableItems.clear();
    formError.value = null;
  }

  void clearError() {
    state.value = ReturnLoadState.idle;
    errorMessage.value = null;
    formError.value = null;
  }
}