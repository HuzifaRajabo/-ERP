import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/utils/money_utils.dart';
import '../../controllers/payment_controller.dart';
import '../../models/payment_model.dart';
import '../../repositories/payment_repository.dart';
import '../../views/shared/shared_components.dart';
import '../../core/theme/app_dimensions.dart';

class DebtsScreen extends GetView<PaymentController> {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الديون'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: controller.loadDebts,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.person_outline), text: 'على الزبائن'),
              Tab(
                icon: Icon(Icons.local_shipping_outlined),
                text: 'للموردين',
              ),
            ],
          ),
        ),
        body: Obx(() {
          if (controller.isLoadingDebts.value) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            children: [
              // ديون الزبائن = مبالغ مستحقة لنا (نحن ندين علينا)
              _DebtList(
                debts: controller.customerDebts,
                config: DebtConfig.customer,
              ),
              // ديون الموردين = مبالغ مستحقة عليه (نحن ندين لهم)
              _DebtList(
                debts: controller.supplierDebts,
                config: DebtConfig.supplier,
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ==============================
// إعدادات كل نوع دين
// ==============================

class DebtConfig {
  final String emptyMessage;
  final String totalLabel; // وصف الإجمالي
  final String directionLabel; // اتجاه الدين
  final Color color;
  final IconData icon;
  final PaymentType paymentType;
  final String invoiceType;

  const DebtConfig({
    required this.emptyMessage,
    required this.totalLabel,
    required this.directionLabel,
    required this.color,
    required this.icon,
    required this.paymentType,
    required this.invoiceType,
  });

  // الزبائن: الدين علينا — نستلم منهم
  static const customer = DebtConfig(
    emptyMessage: 'لا توجد ديون على الزبائن',
    totalLabel: 'إجمالي المستحق لنا',
    directionLabel: 'مستحق لنا',
    color: Colors.blue,
    icon: Icons.person_outline,
    paymentType: PaymentType.inbound,
    invoiceType: 'SALE',
  );

  // الموردون: الدين لهم — ندفع لهم
  static const supplier = DebtConfig(
    emptyMessage: 'لا توجد ديون للموردين',
    totalLabel: 'إجمالي المستحق له',
    directionLabel: 'مستحق له',
    color: Colors.orange,
    icon: Icons.local_shipping_outlined,
    paymentType: PaymentType.outbound,
    invoiceType: 'PURCHASE',
  );
}

// ==============================
// قائمة الديون
// ==============================

class _DebtList extends StatelessWidget {
  final List<PartyDebtSummary> debts;
  final DebtConfig config;

  const _DebtList({required this.debts, required this.config});

  @override
  Widget build(BuildContext context) {
    if (debts.isEmpty) {
      return AppEmptyState(
        icon: Icons.check_circle_outline,
        title: config.emptyMessage,
      );
    }

    final totalDebt = debts.fold(0, (sum, d) => sum + d.totalRemaining);

    return Column(
      children: [
        // ==============================
        // شريط الإجمالي مع اتجاه الدين
        // ==============================
        AppCard(
          margin: EdgeInsets.all(AppSpacing.md),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(config.icon, color: config.color),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.totalLabel,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: config.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // توضيح اتجاه الدين
                      Text(
                        config.directionLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: config.color.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  MoneyUtils.formatMoney(totalDebt),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: config.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ==============================
        // القائمة
        // ==============================
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            itemCount: debts.length,
            separatorBuilder: (_, _) => SizedBox(height: AppSpacing.xs),
            itemBuilder: (context, index) =>
                _DebtCard(debt: debts[index], config: config),
          ),
        ),
      ],
    );
  }
}

// ==============================
// بطاقة الطرف
// ==============================

class _DebtCard extends GetView<PaymentController> {
  final PartyDebtSummary debt;
  final DebtConfig config;

  const _DebtCard({required this.debt, required this.config});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: config.color.withOpacity(0.1),
                child: Icon(config.icon, color: config.color),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.partyName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (debt.partyPhone != null)
                      Text(
                        debt.partyPhone!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                    Text(
                      '${debt.invoiceCount} فاتورة غير مسددة',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),

              // المبلغ مع اتجاه واضح
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    MoneyUtils.formatMoney(debt.totalRemaining),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: config.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // توضيح اتجاه هذا الدين بالتحديد
                  AppStatusBadge(
                    label: config.directionLabel,
                    color: config.color,
                    icon: null,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          SizedBox(height: AppSpacing.sm),

          Row(
            children: [
              // زر الفواتير
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Get.toNamed(
                    '/party-invoices',
                    arguments: {
                      'partyId': debt.partyId,
                      'partyName': debt.partyName,
                      'paymentType': config.paymentType,
                    },
                  ),
                  icon: const Icon(Icons.receipt_long_outlined, size: 16),
                  label: const Text('الفواتير'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: config.color,
                    side: BorderSide(color: config.color.withOpacity(0.4)),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // زر الدفع العام
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showGeneralPaymentSheet(context),
                  icon: const Icon(Icons.payments_outlined, size: 16),
                  label: Text(
                    config.paymentType == PaymentType.inbound
                        ? 'تحصيل' // من زبون = نستلم
                        : 'سداد', // لمورد = ندفع
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: config.color,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showGeneralPaymentSheet(BuildContext context) {
    Get.bottomSheet(
      _GeneralPaymentSheet(debt: debt, paymentType: config.paymentType),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}

// ==============================
// BottomSheet الدفعة العامة مع التوزيع
// ==============================

class _GeneralPaymentSheet extends StatefulWidget {
  final PartyDebtSummary debt;
  final PaymentType paymentType;

  const _GeneralPaymentSheet({
    required this.debt,
    required this.paymentType,
  });

  @override
  State<_GeneralPaymentSheet> createState() =>
      _GeneralPaymentSheetState();
}

class _GeneralPaymentSheetState
    extends State<_GeneralPaymentSheet> {
  late final TextEditingController amountCtrl;
  late final TextEditingController notesCtrl;

  bool amountEntered = false;

  PaymentController get controller =>
      Get.find<PaymentController>();

  @override
  void initState() {
    super.initState();

    amountCtrl = TextEditingController();
    notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  // =========================================================
  // توزيع المبلغ
  // =========================================================

  Future<void> _distributeAmount(
      ScrollController scrollController,
      ) async {
    // إخفاء لوحة المفاتيح
    FocusManager.instance.primaryFocus?.unfocus();

    final amount = MoneyUtils.parseAmount(
      amountCtrl.text,
    );

    // التحقق من المبلغ
    if (amount == null || amount <= 0) {
      controller.formError.value =
      'يرجى إدخال مبلغ صحيح';
      return;
    }

    controller.formError.value = null;

    try {
      await controller.initGeneralPayment(
        partyId: widget.debt.partyId,
        amount: amount,
        type: widget.paymentType,
      );

      if (!mounted) return;

      // في حال وجود خطأ من Controller
      if (controller.formError.value != null) {
        return;
      }

      setState(() {
        amountEntered = true;
      });

      // ننتظر تحديث الواجهة
      await Future.delayed(
        const Duration(milliseconds: 150),
      );

      if (!mounted) return;

      // الانتقال إلى قسم التوزيع
      if (scrollController.hasClients) {
        await scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      controller.formError.value =
          e.toString().replaceFirst(
            'Exception: ',
            '',
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: ListView(
                controller: scrollController,
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  24,
                ),
                children: [
                  // =================================================
                  // Handle
                  // =================================================

                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius:
                        BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // =================================================
                  // العنوان
                  // =================================================

                  Text(
                    'دفعة عامة — ${widget.debt.partyName}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // =================================================
                  // إجمالي المستحق
                  // =================================================

                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'إجمالي المستحق',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          '${MoneyUtils.formatInput(widget.debt.totalRemaining)} \$',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // =================================================
                  // المبلغ المدفوع
                  // =================================================

                  Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amountCtrl,

                          textDirection:
                          TextDirection.ltr,
                          textAlign: TextAlign.left,

                          keyboardType:
                          const TextInputType
                              .numberWithOptions(
                            decimal: true,
                            signed: false,
                          ),

                          textInputAction:
                          TextInputAction.done,

                          decoration: InputDecoration(
                            labelText: 'المبلغ المدفوع',
                            hintText: '0.00',

                            suffixIcon: Padding(
                              padding:
                              const EdgeInsetsDirectional
                                  .only(
                                end: 14,
                              ),
                              child: Center(
                                widthFactor: 1,
                                child: Text(
                                  '\$',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight:
                                    FontWeight.bold,
                                    color:
                                    Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),

                            border: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(14),
                            ),

                            focusedBorder:
                            OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary,
                                width: 2,
                              ),
                            ),
                          ),

                          onSubmitted: (_) {
                            _distributeAmount(
                              scrollController,
                            );
                          },
                        ),
                      ),

                      const SizedBox(width: 10),

                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            _distributeAmount(
                              scrollController,
                            );
                          },
                          style:
                          ElevatedButton.styleFrom(
                            padding:
                            const EdgeInsets.symmetric(
                              horizontal: 18,
                            ),
                            shape:
                            RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'توزيع',
                            style: TextStyle(
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // =================================================
                  // رسالة الخطأ
                  // =================================================

                  Obx(
                        () =>
                    controller.formError.value !=
                        null
                        ? _ErrorBox(
                      message: controller
                          .formError.value!,
                    )
                        : const SizedBox.shrink(),
                  ),

                  // =================================================
                  // قسم التوزيع
                  // =================================================

                  if (amountEntered) ...[
                    const SizedBox(height: 16),

                    Obx(() {
                      // ==========================================
                      // جاري التحميل
                      // ==========================================

                      if (controller
                          .isLoadingDistribution
                          .value) {
                        return const Center(
                          child: Padding(
                            padding:
                            EdgeInsets.all(20),
                            child:
                            CircularProgressIndicator(),
                          ),
                        );
                      }

                      // ==========================================
                      // لا توجد فواتير
                      // ==========================================

                      if (controller
                          .distributionList
                          .isEmpty) {
                        return Container(
                          padding:
                          const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                            Colors.orange.shade50,
                            borderRadius:
                            BorderRadius.circular(
                              12,
                            ),
                          ),
                          child: const Text(
                            'لا توجد فواتير مستحقة لتوزيع الدفعة عليها.',
                            textAlign:
                            TextAlign.center,
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          // ========================================
                          // طريقة التوزيع
                          // ========================================

                          Row(
                            children: [
                              const Text(
                                'طريقة التوزيع:',
                                style: TextStyle(
                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Obx(
                                      () =>
                                      SegmentedButton<bool>(
                                        segments: const [
                                          ButtonSegment<bool>(
                                            value: true,
                                            label:
                                            Text('تلقائي'),
                                          ),
                                          ButtonSegment<bool>(
                                            value: false,
                                            label:
                                            Text('يدوي'),
                                          ),
                                        ],
                                        selected: {
                                          controller
                                              .isAutoDistribute
                                              .value
                                        },
                                        onSelectionChanged:
                                            (value) {
                                          controller
                                              .toggleDistributionMode(
                                            value.first,
                                          );
                                        },
                                      ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // ========================================
                          // قائمة التوزيع
                          // ========================================

                          ...controller
                              .distributionList
                              .asMap()
                              .entries
                              .map(
                                (entry) =>
                                _DistributionRow(
                                  index: entry.key,
                                  info: entry.value,
                                  isAuto: controller
                                      .isAutoDistribute
                                      .value,
                                ),
                          ),

                          const Divider(),

                          // ========================================
                          // ملخص التوزيع
                          // ========================================

                          Obx(() {
                            final distributed =
                                controller
                                    .totalDistributed;

                            final undistributed =
                                controller
                                    .undistributed;

                            final remainingDebt =
                            (widget.debt
                                .totalRemaining -
                                distributed)
                                .clamp(
                              0,
                              widget.debt.totalRemaining,
                            );

                            return Container(
                              padding:
                              const EdgeInsets.all(12),
                              decoration:
                              BoxDecoration(
                                color:
                                Colors.grey.shade50,
                                borderRadius:
                                BorderRadius.circular(
                                  12,
                                ),
                                border: Border.all(
                                  color: Colors
                                      .grey.shade200,
                                ),
                              ),
                              child: Column(
                                children: [
                                  // ==================================
                                  // الموزع
                                  // ==================================

                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment
                                        .spaceBetween,
                                    children: [
                                      const Text(
                                        'الموزع',
                                        style: TextStyle(
                                          fontWeight:
                                          FontWeight
                                              .w600,
                                        ),
                                      ),
                                      Directionality(
                                        textDirection:
                                        TextDirection
                                            .ltr,
                                        child: Text(
                                          '${MoneyUtils.formatInput(distributed)} \$',
                                          style:
                                          const TextStyle(
                                            fontWeight:
                                            FontWeight
                                                .bold,
                                            color:
                                            Colors
                                                .green,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(
                                    height: 8,
                                  ),

                                  // ==================================
                                  // المتبقي على العميل
                                  // ==================================

                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment
                                        .spaceBetween,
                                    children: [
                                      const Text(
                                        'المتبقي على العميل',
                                        style: TextStyle(
                                          fontWeight:
                                          FontWeight
                                              .w600,
                                        ),
                                      ),
                                      Directionality(
                                        textDirection:
                                        TextDirection
                                            .ltr,
                                        child: Text(
                                          '${MoneyUtils.formatInput(remainingDebt)} \$',
                                          style: TextStyle(
                                            fontWeight:
                                            FontWeight
                                                .bold,
                                            color:
                                            remainingDebt >
                                                0
                                                ? Colors
                                                .orange
                                                : Colors
                                                .green,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(
                                    height: 8,
                                  ),

                                  // ==================================
                                  // غير موزع من الدفعة
                                  // ==================================

                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment
                                        .spaceBetween,
                                    children: [
                                      const Text(
                                        'غير موزع من الدفعة',
                                        style: TextStyle(
                                          fontWeight:
                                          FontWeight
                                              .w600,
                                        ),
                                      ),
                                      Directionality(
                                        textDirection:
                                        TextDirection
                                            .ltr,
                                        child: Text(
                                          '${MoneyUtils.formatInput(undistributed)} \$',
                                          style: TextStyle(
                                            fontWeight:
                                            FontWeight
                                                .bold,
                                            color:
                                            undistributed >
                                                0
                                                ? Colors
                                                .orange
                                                : Colors
                                                .green,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),

                          const SizedBox(height: 12),

                          // ==========================================
                          // الملاحظات
                          // ==========================================

                          TextField(
                            controller: notesCtrl,
                            maxLines: 2,
                            textDirection:
                            TextDirection.rtl,
                            decoration: InputDecoration(
                              labelText:
                              'ملاحظات (اختياري)',
                              prefixIcon: const Icon(
                                Icons.notes_outlined,
                              ),
                              border:
                              OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(
                                  12,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ==========================================
                          // حفظ الدفعة
                          // ==========================================

                          Obx(
                                () => SizedBox(
                              width: double.infinity,
                              height: 50,
                              child:
                              ElevatedButton.icon(
                                onPressed: controller
                                    .isSaving
                                    .value
                                    ? null
                                    : () async {
                                  FocusManager
                                      .instance
                                      .primaryFocus
                                      ?.unfocus();

                                  final success =
                                  await controller
                                      .saveGeneralPayment(
                                    partyId: widget
                                        .debt
                                        .partyId,
                                    type: widget
                                        .paymentType,
                                    notes: notesCtrl
                                        .text
                                        .trim()
                                        .isEmpty
                                        ? null
                                        : notesCtrl
                                        .text
                                        .trim(),
                                  );

                                  if (!mounted) {
                                    return;
                                  }

                                  if (success) {
                                    Get.back();

                                    Get.snackbar(
                                      'تم',
                                      'تم تسجيل الدفعة بنجاح',
                                      snackPosition:
                                      SnackPosition
                                          .BOTTOM,
                                      backgroundColor:
                                      Colors.green,
                                      colorText:
                                      Colors.white,
                                    );
                                  }
                                },
                                icon: const Icon(
                                  Icons.check,
                                ),
                                label: Text(
                                  controller
                                      .isSaving
                                      .value
                                      ? 'جاري الحفظ...'
                                      : 'حفظ الدفعة',
                                ),
                                style:
                                ElevatedButton
                                    .styleFrom(
                                  backgroundColor:
                                  Colors.green,
                                  foregroundColor:
                                  Colors.white,
                                  shape:
                                  RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius
                                        .circular(
                                      12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DistributionRow extends GetView<PaymentController> {
  final int index;
  final InvoicePaymentInfo info;
  final bool isAuto;

  const _DistributionRow({
    required this.index,
    required this.info,
    required this.isAuto,
  });

  @override
  Widget build(BuildContext context) {
    // المبلغ المتبقي على الفاتورة بعد الدفعة الحالية.
    //
    // info.remaining:
    // المبلغ المستحق على الفاتورة قبل التوزيع.
    //
    // info.suggestedPayment:
    // المبلغ الذي سيتم توزيعه حاليًا على هذه الفاتورة.
    final remainingAfterPayment =
    (info.remaining - info.suggestedPayment).clamp(0, info.remaining);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // =========================================================
          // معلومات الفاتورة
          // =========================================================

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  info.invoiceNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 3),

                // المتبقي الحقيقي بعد الدفعة الحالية
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    'المتبقي: ${MoneyUtils.formatInput(remainingAfterPayment)} \$',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // =========================================================
          // المبلغ الموزع
          // =========================================================

          isAuto
              ? Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius:
              BorderRadius.circular(8),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '${MoneyUtils.formatInput(info.suggestedPayment)} \$',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          )
              : SizedBox(
            width: 90,
            child: TextFormField(
              initialValue:
              info.suggestedPayment > 0
                  ? MoneyUtils.formatInput(
                info.suggestedPayment,
              )
                  : '',
              keyboardType:
              const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,

              onChanged: (value) {
                final amount =
                    MoneyUtils.parseAmount(value) ?? 0;

                controller.updateDistributionItem(
                  index,
                  amount,
                );
              },

              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================
// Widget مساعد
// ==============================

class _ErrorBox extends StatelessWidget {
  final String message;

  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
