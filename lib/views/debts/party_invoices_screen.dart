import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/utils/money_utils.dart';
import '../../controllers/invoice_controller.dart';
import '../../core/services/app_event_bus.dart';
import '../../models/invoice_model.dart';
import '../../models/payment_model.dart';
import '../shared/shared_components.dart';
import '../../core/theme/app_dimensions.dart';
import '../debts/payment_bottom_sheet.dart';

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
  final RxBool isLoading = true.obs;

  @override
  void initState() {
    super.initState();

    final args = Get.arguments as Map<String, dynamic>;
    partyId = args['partyId'] as int;
    partyName = args['partyName'] as String;
    paymentType = args['paymentType'] as PaymentType;

    invoiceController = Get.find<InvoiceController>();

    _loadPartyInvoices();

    // تحديث عند أي تغيير في الفواتير
    AppEventBus.instance.listenToInvoices(_loadPartyInvoices);
  }

  Future<void> _loadPartyInvoices() async {
    try {
      isLoading.value = true;
      final page = await invoiceController.repo.getInvoicesByParty(
        partyId: partyId,
        pageSize: 1000,
      );
      // ← استثناء المدفوعة كاملاً
      partyInvoices.assignAll(
        page.invoices
            .where((i) => i.paymentStatus != PaymentStatus.paid)
            .toList(),
      );
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

        if (partyInvoices.isEmpty) {
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
                  'لا توجد فواتير لهذا الطرف',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        // ==============================
        // ملخص الديون في الأعلى
        // ==============================
        final unpaidInvoices = partyInvoices
            .where((i) => i.paymentStatus != PaymentStatus.paid)
            .toList();
        final totalRemaining = unpaidInvoices.fold(
          0,
          (sum, i) => sum + i.remaining,
        );
        final totalAmount = partyInvoices.fold(
          0,
          (sum, i) => sum + i.totalAmount,
        );
        final totalPaid = partyInvoices.fold(0, (sum, i) => sum + i.paidAmount);

        return Column(
          children: [
            // ==============================
            // بطاقة الملخص
            // ==============================
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
                        label: 'إجمالي الفواتير',
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

            // ==============================
            // قائمة الفواتير
            // ==============================
            Expanded(
              child: _InvoicesList(
                invoices: partyInvoices,
                paymentType: paymentType,
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
// قائمة الفواتير
// ==============================

class _InvoicesList extends StatelessWidget {
  final RxList<InvoiceModel> invoices;
  final PaymentType paymentType;

  // نحتاج reference للـ selected من _StatusFilter
  // نستخدم حل بسيط بـ Rx مشترك
  final Rx<PaymentStatus?> _selected = Rxn<PaymentStatus?>();

  _InvoicesList({required this.invoices, required this.paymentType});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final filtered = _selected.value == null
          ? invoices
          : invoices.where((i) => i.paymentStatus == _selected.value).toList();

      if (filtered.isEmpty) {
        return Center(
          child: Text(
            'لا توجد فواتير بهذه الحالة',
            style: TextStyle(color: Colors.grey[500]),
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _PartyInvoiceCard(
          invoice: filtered[index],
          paymentType: paymentType,
        ),
      );
    });
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
                      Get.toNamed('/invoice-details', arguments: invoice.id),
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
