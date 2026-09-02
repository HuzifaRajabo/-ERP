import 'package:get/get.dart';
import '../repositories/invoice_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/party_repository.dart';
import '../repositories/product_unit_repository.dart';
import '../repositories/batch_repository.dart';
import '../repositories/warehouse_repository.dart';
import '../models/invoice_model.dart';
import '../models/product_model.dart';
import '../models/party_model.dart';
import '../models/product_unit_model.dart';
import '../models/warehouse_model.dart';
import '../models/invoice_draft.dart';
import '../core/services/app_event_bus.dart';

enum InvoiceLoadState { idle, loading, loadingMore, error }

class InvoiceController extends GetxController {
  final InvoiceRepository repo;
  final ProductRepository productRepo;
  final PartyRepository partyRepo;
  final ProductUnitRepository unitRepo;
  final BatchRepository batchRepo;
  final WarehouseRepository warehouseRepo;

  InvoiceController(
    this.repo,
    this.productRepo,
    this.partyRepo, {
    required this.unitRepo,
    required this.batchRepo,
    required this.warehouseRepo,
  });

  // ==============================
  // State: قائمة الفواتير
  // ==============================

  final RxList<InvoiceModel> invoices = <InvoiceModel>[].obs;
  final Rx<InvoiceLoadState> state = InvoiceLoadState.idle.obs;
  final RxBool hasMore = true.obs;
  final RxnString errorMessage = RxnString();
  final Rxn<InvoiceType> selectedType = Rxn<InvoiceType>();
  final RxString searchQuery = ''.obs;
  final RxInt draftInitialPayment = 0.obs;

  int? _cursor;

  bool get isLoading => state.value == InvoiceLoadState.loading;
  bool get isLoadingMore => state.value == InvoiceLoadState.loadingMore;
  bool get hasError => state.value == InvoiceLoadState.error;
  bool get isEmpty => invoices.isEmpty && state.value == InvoiceLoadState.idle;

  // ==============================
  // State: نموذج إنشاء فاتورة جديدة (Draft)
  // ==============================
  //
  // كل هذه القيم تُبنى تدريجياً أثناء تعبئة المستخدم لشاشة الفاتورة
  // ثم تُحوَّل لـ InvoiceDraft عند الحفظ النهائي.

  final Rx<InvoiceType> draftType = InvoiceType.sale.obs;
  final Rxn<PartyModel> draftParty = Rxn<PartyModel>();
  final RxnInt draftWarehouseId = RxnInt();
  final RxString draftNotes = ''.obs;
  final RxList<InvoiceItemDraft> draftItems = <InvoiceItemDraft>[].obs;

  // قائمة المنتجات والأطراف والمستودعات المتاحة للاختيار في شاشة الفاتورة
  final RxList<ProductModel> availableProducts = <ProductModel>[].obs;
  final RxList<PartyModel> availableParties = <PartyModel>[].obs;
  final RxList<WarehouseModel> availableWarehouses = <WarehouseModel>[].obs;

  /// المستودع المختار ككائن (لعرض الاسم في الواجهة)
  WarehouseModel? get selectedWarehouse {
    final id = draftWarehouseId.value;
    if (id == null) return null;
    for (final w in availableWarehouses) {
      if (w.id == id) return w;
    }
    return null;
  }

  final RxBool isSavingInvoice = false.obs;
  final RxnString invoiceFormError = RxnString();

  /// المجموع الكلي للفاتورة الحالية، يُحسب تلقائياً من الأسطر
  int get draftTotal => draftItems.fold(0, (sum, item) => sum + item.lineTotal);

  // ==============================
  // Lifecycle
  // ==============================

  @override
  void onInit() {
    super.onInit();
    AppEventBus.instance.listenToInvoices(loadInitial);
    loadInitial();
  }

  // ==============================
  // Load / Pagination (قائمة الفواتير)
  // ==============================

  Future<void> loadInitial() async {
    _reset();
    state.value = InvoiceLoadState.loading;
    await _fetchPage();
  }

  Future<void> loadMore() async {
    if (!hasMore.value || state.value != InvoiceLoadState.idle) return;
    state.value = InvoiceLoadState.loadingMore;
    await _fetchPage();
  }

  Future<void> _fetchPage() async {
    try {
      final query = searchQuery.value.trim();
      final page = query.isNotEmpty
          ? await repo.searchInvoices(
              query: query,
              type: selectedType.value,
              lastId: _cursor,
            )
          : selectedType.value == null
              ? await repo.getAllInvoices(lastId: _cursor)
              : await repo.getInvoicesByType(
                  type: selectedType.value!,
                  lastId: _cursor,
                );

      invoices.addAll(page.invoices);
      _cursor = page.nextCursor;
      hasMore.value = page.hasNextPage;
      state.value = InvoiceLoadState.idle;
      errorMessage.value = null;
    } catch (e) {
      state.value = InvoiceLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  void filterByType(InvoiceType? type) {
    selectedType.value = type;
    loadInitial();
  }

  /// يُستدعى من حقل البحث في شاشة الفواتير (رقم الفاتورة أو اسم الطرف).
  /// يعيد ضبط الصفحات ويجلب من جديد عبر Repository → Database،
  /// بدون أي فلترة محلية داخل الـ Widget.
  void setSearchQuery(String query) {
    if (searchQuery.value == query) return;
    searchQuery.value = query;
    loadInitial();
  }

  Future<void> refreshInvoices() async => loadInitial();

  // ==============================
  // حذف فاتورة — مسموح فقط إذا لم تترتب عليها أي حركة مخزون/دفعة/مرتجع
  // (Repository يتحقق من هذا صراحة ويرمي استثناء بدل الحذف المتسلسل الأعمى)
  // ==============================

  Future<InvoiceDeleteResult> deleteInvoice(int id) async {
    final result = await repo.deleteInvoice(id);

    if (result == InvoiceDeleteResult.allowed) {
      AppEventBus.instance.notifyProductChanged();
      AppEventBus.instance.notifyInventoryChanged();
      AppEventBus.instance.notifyInvoiceChanged();
    }

    return result;
  }

  // ==============================
  // جلب فاتورة كاملة مع أسطرها (لصفحة التفاصيل)
  // ==============================

  Future<InvoiceWithItems?> getInvoiceWithItems(int id) {
    return repo.getInvoiceWithItems(id);
  }

  // ==============================
  // بناء فاتورة جديدة (Draft) - دورة الحياة الكاملة
  // ==============================

  /// يُستدعى عند فتح شاشة "فاتورة جديدة"
  /// يُحمِّل قوائم المنتجات والأطراف والمستودعات المتاحة للاختيار منها
  Future<void> startNewInvoice() async {
    draftType.value = InvoiceType.sale;
    draftParty.value = null;
    draftNotes.value = '';
    draftItems.clear();
    draftInitialPayment.value = 0;
    invoiceFormError.value = null;

    // المستودع الافتراضي يُختار تلقائياً إن وُجد
    await loadAvailableWarehouses();
    final defaultWarehouse = await warehouseRepo.getDefaultWarehouse();
    draftWarehouseId.value =
        defaultWarehouse?.id ?? availableWarehouses.firstOrNull?.id;

    await loadAvailableProducts();
    await _loadPartiesForType(InvoiceType.sale); // ← فلترة من البداية
  }

  Future<void> loadAvailableProducts() async {
    final page = await productRepo.getAllProducts(pageSize: 1000);
    availableProducts.assignAll(page.products);
  }

  Future<void> loadAvailableParties() async {
    final page = await partyRepo.getParties();
    availableParties.assignAll(page.parties);
  }

  Future<void> loadAvailableWarehouses() async {
    try {
      final list = await warehouseRepo.getAllWarehouses();
      availableWarehouses.assignAll(list);
    } catch (e) {
      invoiceFormError.value = 'فشل تحميل المستودعات: $e';
    }
  }

  // ==============================
  // بيانات سطر الفاتورة: الوحدات والدفعات والمخزون
  // ==============================
  // هذه الدوال تُفوِّض الاستعلام للـ Repositories الموجودة ولا تعيد
  // تنفيذ أي منطق حسابي (FEFO والتحويل موجودة في الريبو/الموديل).

  /// وحدات المنتج القابلة للاستخدام حسب نوع الفاتورة
  /// (بيع → canSell، شراء → canBuy)
  Future<List<ProductUnitModel>> getUnitsForProduct(int productId) {
    return draftType.value == InvoiceType.sale
        ? unitRepo.getSellableUnits(productId)
        : unitRepo.getBuyableUnits(productId);
  }

  /// رقم دفعة مقترح تلقائياً (قابل للتعديل من المستخدم) — يُستخدم عند
  /// إضافة منتج لفاتورة شراء جديدة تتطلب دفعة.
  Future<String> suggestNextBatchNumber() => batchRepo.generateNextBatchNumber();

  /// دفعات المنتج المتاحة في المستودع المختار، مرتبة FEFO
  /// (الأقرب انتهاءً أولاً) — نفس الترتيب الذي تستخدمه عملية الحفظ.
  Future<List<BatchStock>> getAvailableBatches(int productId) {
    return batchRepo.getAvailableBatchesForProduct(
      productId,
      warehouseId: draftWarehouseId.value,
    );
  }

  /// الكمية المتاحة من منتج في المستودع المختار (بالوحدة الأساسية)
  Future<double> getAvailableQuantity(int productId) {
    return repo.getAvailableQuantity(
      productId,
      warehouseId: draftWarehouseId.value,
    );
  }

  // ==============================
  // تغيير نوع الفاتورة
  // ==============================

  void setDraftType(InvoiceType type) {
    draftType.value = type;
    draftParty.value = null; // إعادة تعيين الطرف لأن النوع تغيّر
    _loadPartiesForType(type);
  }

  void setDraftParty(PartyModel party) {
    draftParty.value = party;
  }

  void setDraftWarehouse(int? warehouseId) {
    draftWarehouseId.value = warehouseId;
  }

  void setDraftNotes(String notes) {
    draftNotes.value = notes;
  }

  Future<void> _loadPartiesForType(InvoiceType type) async {
    try {
      // بيع   → عملاء + كليهما
      // شراء  → موردين + كليهما
      final typeFilter = type == InvoiceType.sale
          ? PartyType.customer
          : PartyType.supplier;

      final page = await partyRepo.getParties(type: typeFilter, pageSize: 1000);
      availableParties.assignAll(page.parties);
    } catch (e) {
      invoiceFormError.value = 'فشل تحميل الأطراف: $e';
    }
  }

  /// إضافة سطر جديد للفاتورة الحالية
  ///
  /// [unitPrice] إن لم يُحدد يُؤخذ من المنتج (بيع → salePrice، شراء → costPrice).
  /// [batchAllocations] توزيع الدفعات (للبيع) — فارغة تعني "تلقائي FEFO"
  /// ويتولى Repository الحفظ التخصيص عبر BatchRepository.
  /// معلومات [newBatchNumber]... تُستخدم في فواتير الشراء لإنشاء دفعة جديدة.
  void addDraftItem({
    required ProductModel product,
    required double quantity,
    int? unitPrice,
    int? unitId,
    String? unitName,
    double conversionFactor = 1,
    List<BatchAllocationSnapshot> batchAllocations = const [],
    String? newBatchNumber,
    String? newProductionDate,
    String? newExpiryDate,
  }) {
    if (product.id == null) {
      invoiceFormError.value =
      'لا يمكن إضافة منتج بدون رقم تعريف';
      return;
    }

    if (quantity <= 0) {
      invoiceFormError.value =
      'الكمية يجب أن تكون أكبر من صفر';
      return;
    }

    final price = unitPrice ??
        (draftType.value == InvoiceType.sale
            ? product.salePrice
            : product.costPrice);

    if (price < 0) {
      invoiceFormError.value =
      'سعر المنتج غير صالح';
      return;
    }

    draftItems.add(
      InvoiceItemDraft(
        productId: product.id!,
        productNameSnapshot: product.name,
        quantity: quantity,
        unitPrice: price,
        unitId: unitId,
        unitNameSnapshot: unitName,
        conversionFactorSnapshot: conversionFactor,
        batchAllocations: batchAllocations,
        newBatchNumber: newBatchNumber,
        newProductionDate: newProductionDate,
        newExpiryDate: newExpiryDate,
      ),
    );

    draftItems.refresh();
  }

  void removeDraftItem(int index) {
    draftItems.removeAt(index);
  }

  /// تعديل سطر موجود — القيم التي لا تُمرَّر تبقى كما هي.
  void updateDraftItem(
    int index, {
    double? quantity,
    int? unitPrice,
    int? unitId,
    bool clearUnit = false,
    String? unitNameSnapshot,
    double? conversionFactorSnapshot,
    List<BatchAllocationSnapshot>? batchAllocations,
    String? newBatchNumber,
    String? newProductionDate,
    String? newExpiryDate,
    bool clearBatchInfo = false,
  }) {
    if (index < 0 || index >= draftItems.length) return;
    final old = draftItems[index];
    final hasNewBatch = !clearBatchInfo &&
        ((newBatchNumber ?? old.newBatchNumber)?.trim().isNotEmpty ?? false);
    draftItems[index] = InvoiceItemDraft(
      productId: old.productId,
      productNameSnapshot: old.productNameSnapshot,
      quantity: quantity ?? old.quantity,
      unitPrice: unitPrice ?? old.unitPrice,
      unitId: clearUnit ? null : (unitId ?? old.unitId),
      unitNameSnapshot:
          clearUnit ? null : (unitNameSnapshot ?? old.unitNameSnapshot),
      conversionFactorSnapshot:
          conversionFactorSnapshot ?? old.conversionFactorSnapshot,
      batchId: old.batchId,
      batchAllocations: batchAllocations ?? old.batchAllocations,
      newBatchNumber: hasNewBatch
          ? (newBatchNumber ?? old.newBatchNumber)
          : null,
      newProductionDate: hasNewBatch
          ? (newProductionDate ?? old.newProductionDate)
          : null,
      newExpiryDate: hasNewBatch ? (newExpiryDate ?? old.newExpiryDate) : null,
    );
    draftItems.refresh();
  }

  /// تحديث دفعات السطر في الـ Draft (يُستخدم بعد تعديل توزيع الدفعات يدوياً)
  void setDraftItemBatchAllocations(
    int index,
    List<BatchAllocationSnapshot> allocations, {
    int? batchId,
  }) {
    if (index < 0 || index >= draftItems.length) return;
    final old = draftItems[index];
    draftItems[index] = InvoiceItemDraft(
      productId: old.productId,
      productNameSnapshot: old.productNameSnapshot,
      quantity: old.quantity,
      unitPrice: old.unitPrice,
      unitId: old.unitId,
      unitNameSnapshot: old.unitNameSnapshot,
      conversionFactorSnapshot: old.conversionFactorSnapshot,
      batchId: batchId ?? (allocations.isNotEmpty ? allocations.first.batchId : old.batchId),
      batchAllocations: allocations,
      newBatchNumber: old.newBatchNumber,
      newProductionDate: old.newProductionDate,
      newExpiryDate: old.newExpiryDate,
    );
    draftItems.refresh();
  }

  /// مجموع الكميات بالوحدة الأساسية (لتلخيص الفاتورة)
  double get draftTotalBaseQuantity =>
      draftItems.fold(0, (sum, item) => sum + item.baseQuantity);

  // ==============================
  // الإضافة السريعة: منتج جديد بدون مغادرة شاشة الفاتورة
  // ==============================

  Future<ProductModel?> quickAddProduct(ProductModel product) async {
    try {
      invoiceFormError.value = null;

      final id = await productRepo.insertProduct(product);

      if (id <= 0) {
        throw Exception('لم يتم إنشاء المنتج بشكل صحيح');
      }

      final created = ProductModel(
        id: id,
        name: product.name,
        description: product.description,
        costPrice: product.costPrice,
        salePrice: product.salePrice,
      );

      // تحديث قائمة المنتجات الموجودة في شاشة الفاتورة.
      availableProducts.insert(0, created);

      // إشعار باقي أجزاء التطبيق.
      AppEventBus.instance.notifyProductChanged();
      AppEventBus.instance.notifyInventoryChanged();

      return created;
    } catch (e) {
      invoiceFormError.value =
          e.toString().replaceFirst('Exception: ', '');

      return null;
    }
  }

  // ==============================
  // الإضافة السريعة: طرف جديد بدون مغادرة شاشة الفاتورة
  // ==============================

  Future<PartyModel?> quickAddParty(PartyModel party) async {
    try {
      final id = await partyRepo.insertParty(party);
      final created = PartyModel(
        id: id,
        type: party.type,
        name: party.name,
        phone: party.phone,
        address: party.address,
      );
      availableParties.insert(0, created);
      AppEventBus.instance.notifyPartyChanged();
      return created;
    } catch (e) {
      invoiceFormError.value = 'فشل إضافة الطرف: $e';
      return null;
    }
  }

  // ==============================
  // حفظ الفاتورة النهائي
  // ==============================
  //
  // يُحوِّل الـ Draft الحالي إلى InvoiceDraft فعلي ويُرسله للـ Repository
  // الذي يتولى كل التحققات (الطرف موجود، المنتجات موجودة، المخزون كافٍ)
  // داخل transaction واحدة ذرية.

  Future<bool> saveInvoice() async {
    invoiceFormError.value = null;

    if (draftParty.value == null) {
      invoiceFormError.value = 'يجب اختيار الطرف';
      return false;
    }
    if (draftItems.isEmpty) {
      invoiceFormError.value = 'يجب إضافة سطر واحد على الأقل';
      return false;
    }

    // التحقق من المبلغ المدفوع قبل الإرسال
    if (draftInitialPayment.value > draftTotal) {
      invoiceFormError.value =
          'المبلغ المدفوع لا يمكن أن يتجاوز إجمالي الفاتورة ($draftTotal)';
      return false;
    }

    // التحقق من اتساق التوزيع اليدوي للدفعات (للبيع فقط).
    // مجموع الدفعات المخصصة يدوياً يجب أن يساوي كمية السطر بالوحدة الأساسية.
    // (توفر الكمية نفسها يتحقق منه Repository داخل transaction الحفظ)
    if (draftType.value == InvoiceType.sale) {
      for (final item in draftItems) {
        if (item.batchAllocations.isEmpty) continue; // تخصيص تلقائي FEFO

        final allocatedSum = item.batchAllocations
            .fold<double>(0, (sum, allocation) => sum + allocation.quantity);
        if ((allocatedSum - item.baseQuantity).abs() > 0.0001) {
          invoiceFormError.value =
              'توزيع الدفعات لـ "${item.productNameSnapshot}" '
              '(${_fmtQty(allocatedSum)}) لا يطابق الكمية المطلوبة '
              '(${_fmtQty(item.baseQuantity)})';
          return false;
        }
        if (item.batchAllocations.any((allocation) => allocation.quantity <= 0)) {
          invoiceFormError.value =
              'كمية السحب من كل دفعة يجب أن تكون أكبر من صفر '
              'في "${item.productNameSnapshot}"';
          return false;
        }
      }
    }

    isSavingInvoice.value = true;

    try {
      final draft = InvoiceDraft(
        type: draftType.value,
        partyId: draftParty.value!.id!,
        partyNameSnapshot: draftParty.value!.name,
        partyAddressSnapshot: draftParty.value!.address ?? '',
        notes: draftNotes.value.trim().isEmpty ? null : draftNotes.value.trim(),
        items: List.from(draftItems),
        initialPayment: draftInitialPayment.value,
        warehouseId: draftWarehouseId.value,
      );

      await repo.createInvoice(draft);
      AppEventBus.instance.notifyInventoryChanged();
      AppEventBus.instance.notifyInvoiceChanged();

      isSavingInvoice.value = false;
      return true;
    } catch (e) {
      invoiceFormError.value = e.toString().replaceFirst('Exception: ', '');
      isSavingInvoice.value = false;
      return false;
    }
  }

  void setInitialPayment(int amount) {
    draftInitialPayment.value = amount;
  }

  // ==============================
  // Helpers
  // ==============================

  static String _fmtQty(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);

  void _reset() {
    invoices.clear();
    _cursor = null;
    hasMore.value = true;
    errorMessage.value = null;
    state.value = InvoiceLoadState.idle;
  }

  void clearError() {
    state.value = InvoiceLoadState.idle;
    errorMessage.value = null;
  }
}