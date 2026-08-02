import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/utils/money_utils.dart';
import '../../controllers/payment_controller.dart';
import '../../models/payment_model.dart';
import '../../repositories/payment_repository.dart';

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
                text: 'على الموردين',
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green[300],
            ),
            const SizedBox(height: 16),
            Text(
              config.emptyMessage,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    final totalDebt = debts.fold(0, (sum, d) => sum + d.totalRemaining);

    return Column(
      children: [
        // ==============================
        // شريط الإجمالي مع اتجاه الدين
        // ==============================
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: config.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: config.color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(config.icon, color: config.color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.totalLabel,
                      style: TextStyle(
                        color: config.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    // توضيح اتجاه الدين
                    Text(
                      config.directionLabel,
                      style: TextStyle(
                        color: config.color.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                MoneyUtils.formatMoney(totalDebt),
                style: TextStyle(
                  color: config.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ],
          ),
        ),

        // ==============================
        // القائمة
        // ==============================
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: debts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: config.color.withOpacity(0.1),
                  child: Icon(config.icon, color: config.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt.partyName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (debt.partyPhone != null)
                        Text(
                          debt.partyPhone!,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      Text(
                        '${debt.invoiceCount} فاتورة غير مسددة',
                        style: TextStyle(color: Colors.grey[400], fontSize: 11),
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
                      style: TextStyle(
                        color: config.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    // توضيح اتجاه هذا الدين بالتحديد
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: config.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        config.directionLabel,
                        style: TextStyle(
                          color: config.color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

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
                const SizedBox(width: 8),

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
      ),
    );
  }

  void _showGeneralPaymentSheet(BuildContext context) {
    Get.bottomSheet(
      _GeneralPaymentSheet(debt: debt, paymentType: config.paymentType),
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }
}

// ==============================
// BottomSheet الدفعة العامة مع التوزيع
// ==============================

class _GeneralPaymentSheet extends GetView<PaymentController> {
  final PartyDebtSummary debt;
  final PaymentType paymentType;

  const _GeneralPaymentSheet({required this.debt, required this.paymentType});

  @override
  Widget build(BuildContext context) {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final amountEntered = false.obs;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // العنوان
              Text(
                'دفعة عامة — ${debt.partyName}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'إجمالي المستحق: ${MoneyUtils.formatMoney(debt.totalRemaining)}',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
              const SizedBox(height: 16),

              // حقل المبلغ
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'المبلغ المدفوع',
                        prefixIcon: const Icon(Icons.attach_money),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final amount = int.tryParse(amountCtrl.text) ?? 0;
                      if (amount <= 0) return;
                      await controller.initGeneralPayment(
                        partyId: debt.partyId,
                        amount: amount,
                        type: paymentType,
                      );
                      amountEntered.value = true;
                    },
                    child: const Text('توزيع'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // خطأ
              Obx(
                () => controller.formError.value != null
                    ? _ErrorBox(message: controller.formError.value!)
                    : const SizedBox.shrink(),
              ),

              // قسم التوزيع
              Obx(() {
                if (!amountEntered.value) return const SizedBox.shrink();
                if (controller.isLoadingDistribution.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.distributionList.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // تبديل التوزيع
                    Row(
                      children: [
                        const Text(
                          'طريقة التوزيع:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 12),
                        Obx(
                          () => SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(value: true, label: Text('تلقائي')),
                              ButtonSegment(value: false, label: Text('يدوي')),
                            ],
                            selected: {controller.isAutoDistribute.value},
                            onSelectionChanged: (v) =>
                                controller.toggleDistributionMode(v.first),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // قائمة التوزيع
                    ...controller.distributionList.asMap().entries.map(
                      (entry) => _DistributionRow(
                        index: entry.key,
                        info: entry.value,
                        isAuto: controller.isAutoDistribute.value,
                      ),
                    ),

                    const Divider(),

                    // ملخص التوزيع
                    Obx(
                      () => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'الموزَّع: ${MoneyUtils.formatMoney(controller.totalDistributed)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'المتبقي: ${MoneyUtils.formatMoney(controller.undistributed)}',
                            style: TextStyle(
                              color: controller.undistributed > 0
                                  ? Colors.orange
                                  : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ملاحظات
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'ملاحظات (اختياري)',
                        prefixIcon: const Icon(Icons.notes_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // زر الحفظ
                    Obx(
                      () => SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: controller.isSaving.value
                              ? null
                              : () async {
                                  final success = await controller
                                      .saveGeneralPayment(
                                        partyId: debt.partyId,
                                        type: paymentType,
                                        notes: notesCtrl.text.trim().isEmpty
                                            ? null
                                            : notesCtrl.text.trim(),
                                      );
                                  if (success) {
                                    Get.back();
                                    Get.snackbar(
                                      'تم',
                                      'تم تسجيل الدفعة بنجاح',
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: Colors.green,
                                      colorText: Colors.white,
                                    );
                                  }
                                },
                          icon: const Icon(Icons.check),
                          label: Text(
                            controller.isSaving.value
                                ? 'جاري الحفظ...'
                                : 'حفظ الدفعة',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        );
      },
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // معلومات الفاتورة
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.invoiceNumber,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'المتبقي: ${MoneyUtils.formatMoney(info.remaining)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),

          // حقل المبلغ (يدوي) أو نص (تلقائي)
          isAuto
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${info.suggestedPayment}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                )
              : SizedBox(
                  width: 90,
                  child: TextFormField(
                    initialValue: info.suggestedPayment > 0
                        ? MoneyUtils.formatInput(info.suggestedPayment)
                        : '',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    onChanged: (v) {
                      final amount = MoneyUtils.parseAmount(v) ?? 0;
                      controller.updateDistributionItem(index, amount);
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
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
