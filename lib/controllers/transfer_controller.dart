import 'package:get/get.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/stock_transfer_repository.dart';
import '../repositories/warehouse_repository.dart';import '../models/warehouse_model.dart';
import '../core/services/app_event_bus.dart';

enum TransferState { idle, loading, submitting, success, error }

/// عنصر ضمن سلة التحويل الحالية (قبل التنفيذ).
class TransferCartItem {
  final int productId;
  final String productName;
  final double quantity;
  final double availableAtAddTime;

  const TransferCartItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.availableAtAddTime,
  });
}

/// يدير عملية نقل مخزون بين مستودعين، لمنتج واحد أو أكثر ضمن نفس
/// عملية التحويل (سلة منتجات تُنفَّذ كلها معاً بشكل ذرّي).
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

  /// سلة المنتجات المضافة لهذه العملية (قبل الضغط على "تنفيذ التحويل").
  final RxList<TransferCartItem> cartItems = <TransferCartItem>[].obs;

  StockTransferBatchResult? _lastResult;
  StockTransferBatchResult? get lastResult => _lastResult;

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
    cartItems.clear();
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

  /// الكمية المتاحة من المنتج المختار حالياً، بعد خصم ما وُضع مسبقاً في
  /// السلة لنفس المنتج (حتى لا يُسمح بإضافته مرتين بمجموع يتجاوز المتوفر).
  double availableForSelectedProduct() {
    final productId = selectedProductId.value;
    if (productId == null) return 0;
    final summary = availableProducts.firstWhereOrNull(
      (p) => p.productId == productId,
    );
    if (summary == null) return 0;
    final alreadyInCart = cartItems
        .where((i) => i.productId == productId)
        .fold<double>(0, (sum, i) => sum + i.quantity);
    return summary.available - alreadyInCart;
  }

  /// يضيف المنتج والكمية المختارَين حالياً إلى سلة التحويل.
  /// يُعيد رسالة خطأ نصية عند الفشل، أو null عند النجاح.
  String? addSelectionToCart() {
    final productId = selectedProductId.value;
    final qty = quantity.value;

    if (productId == null) return 'اختر المنتج المراد نقله';
    if (qty == null || qty <= 0) return 'أدخل كمية صحيحة أكبر من صفر';

    final summary =
        availableProducts.firstWhereOrNull((p) => p.productId == productId);
    if (summary == null) return 'هذا المنتج لم يعد متاحاً في المستودع المصدر';

    final remaining = availableForSelectedProduct();
    if (qty > remaining) {
      return 'الكمية المطلوبة ($qty) تتجاوز المتاح فعلياً '
          '(${_fmt(remaining)}) بعد احتساب ما أُضيف مسبقاً للسلة';
    }

    // إن كان المنتج موجوداً بالسلة مسبقاً، ندمج الكمية بدل إضافة سطر مكرر.
    final existingIndex =
        cartItems.indexWhere((i) => i.productId == productId);
    if (existingIndex != -1) {
      final existing = cartItems[existingIndex];
      cartItems[existingIndex] = TransferCartItem(
        productId: existing.productId,
        productName: existing.productName,
        quantity: existing.quantity + qty,
        availableAtAddTime: summary.available,
      );
    } else {
      cartItems.add(TransferCartItem(
        productId: productId,
        productName: summary.productName,
        quantity: qty,
        availableAtAddTime: summary.available,
      ));
    }

    // تجهيز الحقول لإضافة منتج آخر
    selectedProductId.value = null;
    quantity.value = null;
    errorMessage.value = null;
    return null;
  }

  void removeFromCart(int index) {
    if (index < 0 || index >= cartItems.length) return;
    cartItems.removeAt(index);
  }

  String _fmt(double q) =>
      q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(2);

  /// يُنفّذ تحويل كل منتجات السلة دفعة واحدة (عملية ذرّية واحدة).
  /// يُعيد true عند النجاح.
  Future<bool> submit() async {
    // حماية من التنفيذ المزدوج: لو ضغط المستخدم الزر مرتين بسرعة قبل أن
    // تتحول الواجهة لحالة "submitting" (فرق التوقيت بين استدعاء الدالة
    // وإعادة رسم الشاشة عبر Obx)، يجب رفض الاستدعاء الثاني فوراً — وإلا
    // تُنفَّذ عمليتا تحويل منفصلتان بنفس الكميات بالضبط، فتتكرر كل حركة
    // في سجل "الحركات" مرتين تماماً كما هي.
    if (state.value == TransferState.submitting) return false;

    final from = fromWarehouseId.value;
    final to = toWarehouseId.value;

    if (from == null || to == null) {
      errorMessage.value = 'اختر المستودع المصدر والمستودع الوجهة';
      return false;
    }
    if (from == to) {
      errorMessage.value = 'لا يمكن النقل إلى نفس المستودع';
      return false;
    }
    if (cartItems.isEmpty) {
      errorMessage.value = 'أضف منتجاً واحداً على الأقل قبل تنفيذ التحويل';
      return false;
    }

    try {
      state.value = TransferState.submitting;
      _lastResult = await transferRepo.transferStockBatch(
        fromWarehouseId: from,
        toWarehouseId: to,
        items: [
          for (final item in cartItems)
            StockTransferItemInput(
              productId: item.productId,
              quantity: item.quantity,
            ),
        ],
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
    cartItems.clear();
    _lastResult = null;
    state.value = TransferState.idle;
    errorMessage.value = null;
    if (fromWarehouseId.value != null) {
      loadAvailableProducts(fromWarehouseId.value!);
    }
  }
}