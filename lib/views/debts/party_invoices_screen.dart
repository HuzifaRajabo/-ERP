import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/utils/money_utils.dart';
import '../../controllers/invoice_controller.dart';
import '../../core/services/app_event_bus.dart';
import '../../core/theme/app_colors.dart';
import '../../models/invoice_model.dart';
import '../../models/payment_model.dart';
import '../../models/returnable_packaging_model.dart';
import '../../repositories/returnable_packaging_repository.dart';
import '../shared/shared_components.dart';
import '../../core/theme/app_dimensions.dart';
import '../debts/payment_bottom_sheet.dart';
import '../shared/app_ui.dart';

class PartyInvoicesScreen extends StatefulWidget {
  const PartyInvoicesScreen({super.key});

  @override
  State<PartyInvoicesScreen> createState() => _PartyInvoicesScreenState();
}

class _PartyInvoicesScreenState extends State<PartyInvoicesScreen> {
  late final int partyId;
  late final String partyName;
  late final PaymentType paymentType;
  late final InvoiceController invoiceController;

  final RxList<InvoiceModel> partyInvoices = <InvoiceModel>[].obs;
  final RxList<PackagingCharge> packagingCharges = <PackagingCharge>[].obs;
  final RxBool isLoading = true.obs;
  final _workers = <Worker>[];

  @override
  void initState() {
    super.initState();

    final args = Get.arguments as Map<String, dynamic>;
    partyId = args['partyId'] as int;
    partyName = args['partyName'] as String;
    paymentType = args['paymentType'] as PaymentType;

    invoiceController = Get.find<InvoiceController>();

    _loadPartyInvoices();

    _workers.add(AppEventBus.instance.listenToInvoices(_loadPartyInvoices));
    _workers.add(AppEventBus.instance.listenToPackaging(_loadPartyInvoices));
  }

  @override
  void dispose() {
    for (final worker in _workers) {
      worker.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPartyInvoices() async {
    try {
      isLoading.value = true;
      final page = await invoiceController.repo.getInvoicesByParty(
        partyId: partyId,
        pageSize: 1000,
      );
      partyInvoices.assignAll(
        page.invoices
            .where((i) => i.paymentStatus != PaymentStatus.paid)
            .toList(),
      );
      if (paymentType == PaymentType.inbound &&
          Get.isRegistered<ReturnablePackagingRepository>()) {
        final charges = await Get.find<ReturnablePackagingRepository>()
            .getCharges(partyId: partyId, unpaidOnly: true);
        packagingCharges.assignAll(charges);
      } else {
        packagingCharges.clear();
      }
    } catch (e) {
      Get.snackbar('خطأ', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(partyName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPartyInvoices,
          ),
        ],
      ),
      body: Obx(() {
        if (isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (partyInvoices.isEmpty && packagingCharges.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد مستحقات لهذا الطرف',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        final unpaidInvoices = partyInvoices
            .where((i) => i.paymentStatus != PaymentStatus.paid)
            .toList();
        final invoiceRemaining = unpaidInvoices.fold<int>(
          0,
          (sum, i) => sum + i.remaining,
        );
        final packagingRemaining = packagingCharges.fold<int>(
          0,
          (sum, c) => sum + c.remaining,
        );
        final totalRemaining = invoiceRemaining + packagingRemaining;
        final totalAmount =
            partyInvoices.fold<int>(0, (sum, i) => sum + i.totalAmount) +
            packagingCharges.fold<int>(0, (sum, c) => sum + c.amount);
        final totalPaid =
            partyInvoices.fold<int>(0, (sum, i) => sum + i.paidAmount) +
            packagingCharges.fold<int>(0, (sum, c) => sum + c.paidAmount);

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: totalRemaining > 0
                      ? [Colors.red.shade400, Colors.red.shade600]
                      : [Colors.green.shade400, Colors.green.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SummaryCol(
                        label: 'الإجمالي',
                        value: MoneyUtils.formatMoney(totalAmount),
                        color: Colors.white,
                      ),
                      _SummaryCol(
                        label: 'المدفوع',
                        value: MoneyUtils.formatMoney(totalPaid),
                        color: Colors.white70,
                      ),
                      _SummaryCol(
                        label: 'المتبقي',
                        value: MoneyUtils.formatMoney(totalRemaining),
                        color: Colors.white,
                        isBold: true,
                      ),
                    ],
                  ),
                  if (totalAmount > 0) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (totalPaid / totalAmount).clamp(0.0, 1.0),
                        minHeight: 8,
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${((totalPaid / totalAmount) * 100).toStringAsFixed(0)}% مدفوع',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: partyInvoices.length + packagingCharges.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index < partyInvoices.length) {
                    return _PartyInvoiceCard(
                      invoice: partyInvoices[index],
                      paymentType: paymentType,
                    );
                  }
                  return _PackagingChargeCard(
                    charge: packagingCharges[index - partyInvoices.length],
                    onPaid: _loadPartyInvoices,
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ==============================
// فلتر الحالة
// ==============================

// class _FilterChip extends StatelessWidget {
//   final String label;
//   final bool selected;
//   final Color color;
//   final VoidCallback onTap;

//   const _FilterChip({
//     required this.label,
//     required this.selected,
//     required this.color,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 200),
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
//         decoration: BoxDecoration(
//           color: selected ? color : color.withOpacity(0.08),
//           borderRadius: BorderRadius.circular(20),
//           border: Border.all(color: color.withOpacity(0.4)),
//         ),
//         child: Text(
//           label,
//           style: TextStyle(
//             color: selected ? Colors.white : color,
//             fontWeight: FontWeight.w600,
//             fontSize: 12,
//           ),
//         ),
//       ),
//     );
//   }
// }

// ==============================
// بطاقة تعويض العبوات
// ==============================

class _PackagingChargeCard extends StatelessWidget {
  final PackagingCharge charge;
  final VoidCallback onPaid;

  const _PackagingChargeCard({required this.charge, required this.onPaid});

  @override
  Widget build(BuildContext context) {
    final isPartial = charge.paidAmount > 0 && charge.remaining > 0;
    final statusColor = isPartial ? Colors.orange : Colors.red;
    final statusLabel = isPartial ? 'مدفوع جزئياً' : 'غير مدفوع';

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      charge.displayNumber,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (charge.typeName != null || charge.createdAt != null)
                      Text(
                        [
                          if (charge.typeName != null) charge.typeName!,
                          if (charge.createdAt != null) charge.createdAt!,
                        ].join(' • '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[400],
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const AppStatusBadge(
                    label: 'تعويض عبوات',
                    color: AppColors.warning,
                    icon: null,
                  ),
                  const SizedBox(height: 4),
                  AppStatusBadge(
                    label: statusLabel,
                    color: statusColor,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _AmountItem(
                label: 'الإجمالي',
                value: MoneyUtils.formatMoney(charge.amount),
                color: Theme.of(context).colorScheme.onSurface,
              ),
              _AmountItem(
                label: 'المدفوع',
                value: MoneyUtils.formatMoney(charge.paidAmount),
                color: Colors.green,
              ),
              _AmountItem(
                label: 'المتبقي',
                value: MoneyUtils.formatMoney(charge.remaining),
                color: charge.remaining > 0 ? Colors.red : Colors.grey,
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.small),
            child: LinearProgressIndicator(
              value: charge.amount > 0
                  ? (charge.paidAmount / charge.amount).clamp(0.0, 1.0)
                  : 0,
              minHeight: 6,
              color: statusColor,
              backgroundColor: Colors.grey.shade200,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _PackagingChargePaymentSheet.show(
                charge: charge,
                onPaid: onPaid,
              ),
              icon: const Icon(Icons.payments_outlined, size: 16),
              label: const Text('تحصيل'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackagingChargePaymentSheet extends StatefulWidget {
  final PackagingCharge charge;
  final VoidCallback onPaid;

  const _PackagingChargePaymentSheet({
    required this.charge,
    required this.onPaid,
  });

  static Future<void> show({
    required PackagingCharge charge,
    required VoidCallback onPaid,
  }) {
    return Get.bottomSheet(
      _PackagingChargePaymentSheet(charge: charge, onPaid: onPaid),
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }

  @override
  State<_PackagingChargePaymentSheet> createState() =>
      _PackagingChargePaymentSheetState();
}

class _PackagingChargePaymentSheetState
    extends State<_PackagingChargePaymentSheet> {
  late final TextEditingController _amountCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.charge.remaining > 0
          ? MoneyUtils.formatInput(widget.charge.remaining)
          : '',
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = MoneyUtils.parseAmount(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'يرجى إدخال مبلغ صحيح');
      return;
    }
    if (amount > widget.charge.remaining) {
      setState(
        () => _error =
            'المبلغ يتجاوز المتبقي (${MoneyUtils.formatMoney(widget.charge.remaining)})',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Get.find<ReturnablePackagingRepository>().payCharge(
        chargeId: widget.charge.id!,
        amount: amount,
      );
      AppEventBus.instance.notifyPackagingChanged();
      AppEventBus.instance.notifyInvoiceChanged();
      Get.back();
      AppUi.showSuccess('تم تسجيل دفعة تعويض العبوات');
      widget.onPaid();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
              ),
            ),
            SizedBox(height: AppSpacing.md),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'تحصيل — ${widget.charge.displayNumber}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SizedBox(height: AppSpacing.md),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'المبلغ المدفوع',
                prefixIcon: const Icon(Icons.attach_money),
                suffixText:
                    'الحد الأقصى: ${MoneyUtils.formatMoney(widget.charge.remaining)}',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
              ),
            ),
            if (_error != null) ...[
              SizedBox(height: AppSpacing.sm),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
            SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check),
                label: Text(_saving ? 'جاري الحفظ...' : 'حفظ الدفعة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================
// بطاقة الفاتورة
// ==============================

class _PartyInvoiceCard extends StatelessWidget {
  final InvoiceModel invoice;
  final PaymentType paymentType;

  const _PartyInvoiceCard({required this.invoice, required this.paymentType});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (invoice.paymentStatus) {
      PaymentStatus.unpaid => Colors.red,
      PaymentStatus.partial => Colors.orange,
      PaymentStatus.paid => Colors.green,
    };

    return AppCard(
      child: Column(
        children: [
          // رأس البطاقة
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.invoiceNumber,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (invoice.createdAt != null)
                      Text(
                        invoice.createdAt!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[400],
                        ),
                      ),
                  ],
                ),
              ),

              //badge الحالة باستخدام AppStatusBadge
              AppStatusBadge(
                label: invoice.paymentStatus.label,
                color: statusColor,
                icon: null,
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          SizedBox(height: AppSpacing.sm),

          // أرقام الدفع
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _AmountItem(
                label: 'الإجمالي',
                value: MoneyUtils.formatMoney(invoice.totalAmount),
                color: Theme.of(context).colorScheme.onSurface,
              ),
              _AmountItem(
                label: 'المدفوع',
                value: MoneyUtils.formatMoney(invoice.paidAmount),
                color: Colors.green,
              ),
              _AmountItem(
                label: 'المتبقي',
                value: MoneyUtils.formatMoney(invoice.remaining),
                color: invoice.remaining > 0 ? Colors.red : Colors.grey,
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),

          // شريط التقدم
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.small),
            child: LinearProgressIndicator(
              value: invoice.totalAmount > 0
                  ? (invoice.paidAmount / invoice.totalAmount).clamp(0.0, 1.0)
                  : 0,
              minHeight: 6,
              color: statusColor,
              backgroundColor: Colors.grey.shade200,
            ),
          ),

          // أزرار الإجراءات
          SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Get.toNamed('/invoice-details', arguments: invoice),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('التفاصيل'),
                ),
              ),
              if (invoice.paymentStatus != PaymentStatus.paid) ...[
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => PaymentBottomSheet.show(invoice),
                    icon: const Icon(Icons.payments_outlined, size: 16),
                    label: const Text('دفعة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AmountItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.grey[500],
            fontSize: 11,
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _SummaryCol extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isBold;

  const _SummaryCol({
    required this.label,
    required this.value,
    required this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: color.withOpacity(0.8), fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: isBold ? 20 : 16,
          ),
        ),
      ],
    );
  }
}
