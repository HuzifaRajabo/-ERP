import 'package:get/get.dart';
import '../repositories/payment_repository.dart';
import '../repositories/invoice_repository.dart';
import '../repositories/party_repository.dart';
import '../models/payment_model.dart';
import '../models/invoice_model.dart';
import '../core/services/app_event_bus.dart';
import '../core/utils/db_error_handler.dart';

enum PaymentLoadState { idle, loading, error }

class PaymentController extends GetxController {
  final PaymentRepository repo;
  final InvoiceRepository invoiceRepo;

  PaymentController(this.repo, this.invoiceRepo);

  // ==============================
  // State: دفعات الفاتورة الحالية
  // ==============================

  final RxList<PaymentModel> invoicePayments = <PaymentModel>[].obs;
  final Rx<PaymentLoadState> state = PaymentLoadState.idle.obs;
  final RxnString errorMessage = RxnString();

  bool get isLoading => state.value == PaymentLoadState.loading;
  bool get hasError => state.value == PaymentLoadState.error;

  // ==============================
  // State: ديون العملاء والموردين
  // ==============================

  final RxList<PartyDebtSummary> customerDebts = <PartyDebtSummary>[].obs;
  final RxList<PartyDebtSummary> supplierDebts = <PartyDebtSummary>[].obs;
  final RxBool isLoadingDebts = false.obs;

  // ==============================
  // State: نموذج الدفعة (للفاتورة المحددة)
  // ==============================

  final Rxn<InvoiceModel> targetInvoice = Rxn<InvoiceModel>();
  final RxInt paymentAmount = 0.obs;
  final RxString paymentNotes = ''.obs;
  final RxBool isSaving = false.obs;
  final RxnString formError = RxnString();

  // ==============================
  // State: الدفعة العامة على الطرف
  // ==============================

  // قائمة الفواتير مع التوزيع المقترح (قابل للتعديل يدوياً)
  final RxList<InvoicePaymentInfo> distributionList =
      <InvoicePaymentInfo>[].obs;
  final RxInt generalPaymentAmount = 0.obs;
  final RxBool isAutoDistribute = true.obs; // تلقائي أم يدوي
  final RxBool isLoadingDistribution = false.obs;

  // ==============================
  // Getters مفيدة
  // ==============================

  /// مجموع ما وُزِّع حتى الآن
  int get totalDistributed =>
      distributionList.fold(0, (sum, i) => sum + i.suggestedPayment);

  /// المبلغ المتبقي من الدفعة العامة بعد التوزيع
  int get undistributed =>
      (generalPaymentAmount.value - totalDistributed).clamp(0, 999999999);

  /// هل التوزيع صالح (لا يتجاوز أي فاتورة متبقيها)
  bool get isDistributionValid =>
      distributionList.every((i) => i.suggestedPayment <= i.remaining) &&
          totalDistributed <= generalPaymentAmount.value;

  // ==============================
  // Lifecycle
  // ==============================

  @override
  void onInit() {
    super.onInit();
    // عند أي تغيير في الفواتير أعد تحميل الديون
    AppEventBus.instance.listenToInvoices(() {
      loadDebts();
    });
    loadDebts();
  }

  // ==============================
  // دفعات فاتورة محددة
  // ==============================

  Future<void> navigateToPartyDetails(int partyId) async {
    try {
      final partyRepo = Get.find<PartyRepository>();
      final party = await partyRepo.getPartyById(partyId);
      if (party != null) {
        Get.toNamed('/party-details', arguments: party);
      } else {
        Get.snackbar('خطأ', 'لم يتم العثور على الطرف');
      }
    } catch (e) {
      Get.snackbar('خطأ', e.toString());
    }
  }

  Future<void> loadInvoicePayments(int invoiceId) async {
    try {
      state.value = PaymentLoadState.loading;
      final payments = await repo.getPaymentsByInvoice(invoiceId);
      invoicePayments.assignAll(payments);
      state.value = PaymentLoadState.idle;
    } catch (e) {
      state.value = PaymentLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  // ==============================
  // تهيئة نموذج الدفعة على فاتورة محددة
  // ==============================

  void initPaymentForm(InvoiceModel invoice) {
    targetInvoice.value = invoice;
    // الافتراضي: المبلغ المتبقي كاملاً
    paymentAmount.value = invoice.remaining;
    paymentNotes.value = '';
    formError.value = null;
  }

  void setPaymentAmount(int amount) {
    paymentAmount.value = amount;
    formError.value = null;
  }

  void setPaymentNotes(String notes) {
    paymentNotes.value = notes;
  }

  // ==============================
  // حفظ دفعة على فاتورة محددة
  // ==============================

  Future<bool> saveInvoicePayment() async {
    formError.value = null;

    if (targetInvoice.value == null) {
      formError.value = 'لم يتم تحديد الفاتورة';
      return false;
    }

    if (paymentAmount.value <= 0) {
      formError.value = 'يجب أن يكون المبلغ أكبر من صفر';
      return false;
    }

    if (paymentAmount.value > targetInvoice.value!.remaining) {
      formError.value =
      'المبلغ (${paymentAmount.value}) يتجاوز المتبقي '
          '(${targetInvoice.value!.remaining})';
      return false;
    }

    isSaving.value = true;

    try {
      await repo.payInvoice(
        invoiceId: targetInvoice.value!.id!,
        partyId: targetInvoice.value!.partyId,
        amount: paymentAmount.value,
        type: targetInvoice.value!.type == InvoiceType.sale
            ? PaymentType.inbound
            : PaymentType.outbound,
        notes: paymentNotes.value.trim().isEmpty
            ? null
            : paymentNotes.value.trim(),
      );

      // إخطار بقية الـ Controllers
      AppEventBus.instance.notifyInvoiceChanged();

      // تحديث دفعات الفاتورة الحالية
      await loadInvoicePayments(targetInvoice.value!.id!);

      isSaving.value = false;
      return true;
    } catch (e) {
      formError.value = e.toString().replaceFirst('Exception: ', '');
      isSaving.value = false;
      return false;
    }
  }

  // ==============================
  // تهيئة الدفعة العامة على طرف
  // ==============================

  Future<void> initGeneralPayment({
    required int partyId,
    required int amount,
    required PaymentType type,
  }) async {
    generalPaymentAmount.value = amount;
    isAutoDistribute.value = true;
    formError.value = null;
    isLoadingDistribution.value = true;

    try {
      // جلب الفواتير غير المسددة مع التوزيع التلقائي المقترح
      final invoices = await repo.getUnpaidInvoicesForParty(
        partyId: partyId,
        availableAmount: amount,
      );

      if (invoices.isEmpty) {
        formError.value = 'لا توجد فواتير مستحقة لهذا الطرف';
        isLoadingDistribution.value = false;
        return;
      }

      // التحقق من أن المبلغ لا يتجاوز مجموع الديون
      final totalRemaining = invoices.fold(0, (sum, i) => sum + i.remaining);
      if (amount > totalRemaining) {
        formError.value =
        'المبلغ ($amount) يتجاوز إجمالي الديون المستحقة ($totalRemaining)';
        isLoadingDistribution.value = false;
        return;
      }

      distributionList.assignAll(invoices);
    } catch (e) {
      formError.value = e.toString();
    } finally {
      isLoadingDistribution.value = false;
    }
  }

  // ==============================
  // التبديل بين التوزيع التلقائي واليدوي
  // ==============================

  void toggleDistributionMode(bool isAuto) {
    isAutoDistribute.value = isAuto;

    if (isAuto) {
      // إعادة حساب التوزيع التلقائي (FIFO)
      _recalculateAutoDistribution();
    }
  }

  void _recalculateAutoDistribution() {
    int remaining = generalPaymentAmount.value;

    for (int i = 0; i < distributionList.length; i++) {
      final invoice = distributionList[i];
      final suggested = remaining >= invoice.remaining
          ? invoice.remaining
          : remaining;

      distributionList[i] = InvoicePaymentInfo(
        invoiceId: invoice.invoiceId,
        invoiceNumber: invoice.invoiceNumber,
        totalAmount: invoice.totalAmount,
        paidAmount: invoice.paidAmount,
        remaining: invoice.remaining,
        suggestedPayment: suggested,
      );

      remaining -= suggested;
      if (remaining <= 0) break;
    }

    distributionList.refresh();
  }

  // ==============================
  // تعديل يدوي لمبلغ فاتورة في التوزيع
  // ==============================

  void updateDistributionItem(int index, int amount) {
    if (index < 0 || index >= distributionList.length) return;

    final invoice = distributionList[index];

    // التحقق: لا يتجاوز المتبقي على الفاتورة
    if (amount > invoice.remaining) {
      formError.value =
      'المبلغ يتجاوز المتبقي على الفاتورة ${invoice.invoiceNumber} '
          '(${invoice.remaining})';
      return;
    }

    // التحقق: مجموع التوزيع لا يتجاوز المبلغ الكلي
    final currentTotal = totalDistributed - invoice.suggestedPayment + amount;
    if (currentTotal > generalPaymentAmount.value) {
      formError.value =
      'مجموع التوزيع ($currentTotal) يتجاوز المبلغ المدفوع '
          '(${generalPaymentAmount.value})';
      return;
    }

    formError.value = null;
    distributionList[index] = InvoicePaymentInfo(
      invoiceId: invoice.invoiceId,
      invoiceNumber: invoice.invoiceNumber,
      totalAmount: invoice.totalAmount,
      paidAmount: invoice.paidAmount,
      remaining: invoice.remaining,
      suggestedPayment: amount,
    );
    distributionList.refresh();
  }

  // ==============================
  // حفظ الدفعة العامة بعد التوزيع
  // ==============================

  Future<bool> saveGeneralPayment({
    required int partyId,
    required PaymentType type,
    String? notes,
  }) async {
    formError.value = null;

    if (distributionList.isEmpty) {
      formError.value = 'لا توجد فواتير للتوزيع';
      return false;
    }

    // تصفية الفواتير التي لها مبلغ > 0 فقط
    final activeItems = distributionList
        .where((i) => i.suggestedPayment > 0)
        .map((i) => PaymentDistributionItem(
      invoiceId: i.invoiceId,
      invoiceNumber: i.invoiceNumber,
      amount: i.suggestedPayment,
    ))
        .toList();

    if (activeItems.isEmpty) {
      formError.value = 'يجب توزيع مبلغ على فاتورة واحدة على الأقل';
      return false;
    }

    if (!isDistributionValid) {
      formError.value = 'التوزيع غير صحيح، تحقق من المبالغ';
      return false;
    }

    isSaving.value = true;

    try {
      await repo.distributePayment(PaymentDistribution(
        partyId: partyId,
        totalAmount: generalPaymentAmount.value,
        type: type,
        notes: notes,
        items: activeItems,
      ));

      AppEventBus.instance.notifyInvoiceChanged();

      isSaving.value = false;
      return true;
    } catch (e) {
      formError.value = e.toString().replaceFirst('Exception: ', '');
      isSaving.value = false;
      return false;
    }
  }

  // ==============================
  // حذف دفعة
  // ==============================

  Future<bool> deletePayment(int paymentId, int invoiceId) async {
    try {
      await repo.deletePayment(paymentId);
      AppEventBus.instance.notifyInvoiceChanged();
      await loadInvoicePayments(invoiceId);
      return true;
    } catch (e) {
      errorMessage.value =
          DbErrorHandler.handle(e, entityName: 'الدفعة');
      return false;
    }
  }

  // ==============================
  // ديون العملاء والموردين
  // ==============================

  Future<void> loadDebts() async {
    try {
      isLoadingDebts.value = true;

      final results = await Future.wait([
        repo.getAllDebts(invoiceType: 'SALE'),
        repo.getAllDebts(invoiceType: 'PURCHASE'),
      ]);

      customerDebts.assignAll(results[0]);
      supplierDebts.assignAll(results[1]);
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoadingDebts.value = false;
    }
  }

  // ==============================
  // Helpers
  // ==============================

  void clearError() {
    formError.value = null;
    errorMessage.value = null;
  }

  void resetForm() {
    targetInvoice.value = null;
    paymentAmount.value = 0;
    paymentNotes.value = '';
    formError.value = null;
    distributionList.clear();
    generalPaymentAmount.value = 0;
  }
}