import 'package:get/get.dart';
import '../repositories/invoice_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/party_repository.dart';
import '../models/invoice_model.dart';
import '../models/product_model.dart';
import '../models/party_model.dart';
import '../models/Invoice_draft.dart';
import '../core/services/app_event_bus.dart';

enum InvoiceLoadState { idle, loading, loadingMore, error }

class InvoiceController extends GetxController {
  final InvoiceRepository repo;
  final ProductRepository productRepo;
  final PartyRepository partyRepo;

  InvoiceController(this.repo, this.productRepo, this.partyRepo);

  // ==============================
  // State: قائمة الفواتير
  // ==============================

  final RxList<InvoiceModel> invoices = <InvoiceModel>[].obs;
  final Rx<InvoiceLoadState> state = InvoiceLoadState.idle.obs;
  final RxBool hasMore = true.obs;
  final RxnString errorMessage = RxnString();
  final Rxn<InvoiceType> selectedType = Rxn<InvoiceType>();

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
  final RxString draftNotes = ''.obs;
  final RxList<InvoiceItemDraft> draftItems = <InvoiceItemDraft>[].obs;

  // قائمة المنتجات والأطراف المتاحة للاختيار في شاشة الفاتورة
  final RxList<ProductModel> availableProducts = <ProductModel>[].obs;
  final RxList<PartyModel> availableParties = <PartyModel>[].obs;

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
    AppEventBus.instance.listenToInventory(loadInitial);
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
      final page = selectedType.value == null
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

  Future<void> refreshInvoices() async => loadInitial();

  // ==============================
  // حذف فاتورة (Reverse - يُعيد المخزون تلقائياً)
  // ==============================

  Future<void> deleteInvoice(int id) async {
    try {
      await repo.deleteInvoice(id);
      AppEventBus.instance.notifyProductChanged();
      AppEventBus.instance.notifyInventoryChanged();
    } catch (e) {
      state.value = InvoiceLoadState.error;
      errorMessage.value = e.toString();
    }
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
  /// يُحمِّل قوائم المنتجات والأطراف المتاحة للاختيار منها
  Future<void> startNewInvoice() async {
    draftType.value = InvoiceType.sale;
    draftParty.value = null;
    draftNotes.value = '';
    draftItems.clear();
    invoiceFormError.value = null;

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

  void setDraftNotes(String notes) {
    draftNotes.value = notes;
  }

  Future<void> _loadPartiesForType(InvoiceType type) async {
    try {
      // بيع   → عملاء + كليهما
      // شراء  → موردين + كليهما
      final typeFilter =
      type == InvoiceType.sale ? PartyType.customer : PartyType.supplier;

      final page = await partyRepo.getParties(
        type: typeFilter,
        pageSize: 1000,
      );
      availableParties.assignAll(page.parties);
    } catch (e) {
      invoiceFormError.value = 'فشل تحميل الأطراف: $e';
    }
  }

  /// إضافة سطر جديد للفاتورة الحالية
  void addDraftItem({
  required ProductModel product,
  required double quantity,
  int? unitPrice,
}) {
  // بيع → سعر البيع | شراء → سعر التكلفة
  final price = unitPrice ??
      (draftType.value == InvoiceType.sale
          ? product.salePrice
          : product.costPrice);

  draftItems.add(InvoiceItemDraft(
    productId: product.id!,
    productNameSnapshot: product.name,
    quantity: quantity,
    unitPrice: price,
  ));
}

  void removeDraftItem(int index) {
    draftItems.removeAt(index);
  }

  void updateDraftItem(
      int index, {
        double? quantity,
        int? unitPrice,
      }) {
    final old = draftItems[index];
    draftItems[index] = InvoiceItemDraft(
      productId: old.productId,
      productNameSnapshot: old.productNameSnapshot,
      quantity: quantity ?? old.quantity,
      unitPrice: unitPrice ?? old.unitPrice,
    );
    draftItems.refresh();
  }

  // ==============================
  // الإضافة السريعة: منتج جديد بدون مغادرة شاشة الفاتورة
  // ==============================

  Future<ProductModel?> quickAddProduct(ProductModel product) async {
    try {
      final id = await productRepo.insertProduct(product);
      final created = ProductModel(
        id: id,
        name: product.name,
        sku: product.sku,
        costPrice: product.costPrice,
        salePrice: product.salePrice,
      );
      availableProducts.insert(0, created);
      AppEventBus.instance.notifyInventoryChanged();
      return created;
    } catch (e) {
      invoiceFormError.value = 'فشل إضافة المنتج: $e';
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
      AppEventBus.instance.notifyProductChanged();
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

    // تحققات أولية على مستوى الواجهة قبل حتى الوصول لقاعدة البيانات
    if (draftParty.value == null) {
      invoiceFormError.value = 'يجب اختيار الطرف (العميل/المورد)';
      return false;
    }
    if (draftItems.isEmpty) {
      invoiceFormError.value = 'يجب إضافة سطر واحد على الأقل';
      return false;
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
      );

      await repo.createInvoice(draft);
      AppEventBus.instance.notifyProductChanged();
      AppEventBus.instance.notifyInventoryChanged();


      isSavingInvoice.value = false;
      return true;
    } catch (e) {
      // الرسائل هنا تأتي مباشرة من الـ Exceptions المخصصة
      // (InsufficientStockException, PartyNotFoundException, إلخ)
      // وهي بالفعل بصيغة عربية واضحة بفضل toString() المُعرَّف في كل منها
      invoiceFormError.value = e.toString().replaceFirst('Exception: ', '');
      isSavingInvoice.value = false;
      return false;
    }
  }

  // ==============================
  // Helpers
  // ==============================

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