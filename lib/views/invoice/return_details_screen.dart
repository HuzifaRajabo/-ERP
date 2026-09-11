import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/utils/money_utils.dart';
import '../../controllers/return_controller.dart';
import '../../controllers/invoice_controller.dart';
import '../../models/payment_model.dart';
import '../../models/return_model.dart';
import '../../controllers/payment_controller.dart';

class ReturnDetailsScreen extends StatelessWidget {
  const ReturnDetailsScreen({super.key});

  int get returnId => Get.arguments as int;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final controller = Get.find<ReturnController>();

    return FutureBuilder<ReturnWithItems?>(
      future: controller.getReturnWithItems(returnId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('المرتجع غير موجود')),
          );
        }

        final data = snapshot.data!;
        final ret = data.returnModel;
        final items = data.items;
        final isSaleReturn = ret.type == ReturnType.saleReturn;
        final color = isSaleReturn ? Colors.purple : Colors.teal;

        return Scaffold(
          appBar: AppBar(title: Text(ret.returnNumber), centerTitle: true),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ==============================
              // رأس المرتجع
              // ==============================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ret.returnNumber,
                          style: textTheme.titleLarge,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            ret.type.label,
                            style: textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (ret.createdAt != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            ret.createdAt!,
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ==============================
              // معلومات الطرف والفاتورة
              // ==============================
              _InfoCard(
                icon: Icons.people_outline,
                title: isSaleReturn ? 'العميل' : 'المورد',
                color: Colors.blue,
                children: [
                  _InfoRow(label: 'الاسم', value: ret.partyNameSnapshot),
                  if (ret.partyAddressSnapshot.isNotEmpty)
                    _InfoRow(label: 'العنوان', value: ret.partyAddressSnapshot),
                ],
              ),
              const SizedBox(height: 12),

              // رابط للفاتورة الأصلية
              OutlinedButton.icon(
                onPressed: () async {
                  final invoice = await Get.find<InvoiceController>()
                      .repo
                      .getInvoiceById(ret.originalInvoiceId);
                  if (invoice != null) {
                    Get.toNamed('/invoice-details', arguments: invoice);
                  }
                },
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('عرض الفاتورة الأصلية'),
              ),
              const SizedBox(height: 12),

              // ==============================
              // جدول الأسطر
              // ==============================
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Column(
                  children: [
                    // رأس الجدول
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              'المنتج',
                              style: textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'الكمية',
                              textAlign: TextAlign.center,
                              style: textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'السعر',
                              textAlign: TextAlign.center,
                              style: textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'الإجمالي',
                              textAlign: TextAlign.end,
                              style: textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // الأسطر
                    ...items.map(
                      (item) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: colors.outlineVariant),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                item.productNameSnapshot,
                                style: textTheme.bodySmall,
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _fmtQty(item.quantity),
                                    textAlign: TextAlign.center,
                                    style: textTheme.bodySmall,
                                  ),
                                  if (item.unitName != null)
                                    Text(
                                      item.unitName!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                        fontSize: 10,
                                      ),
                                    ),
                                  if (item.conversionFactor != 1)
                                    Text(
                                      '= ${_fmtQty(item.baseQuantity)} أساسية',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                        fontSize: 10,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                MoneyUtils.formatMoney(item.unitPrice),
                                textAlign: TextAlign.center,
                                style: textTheme.bodySmall,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                MoneyUtils.formatMoney(item.lineTotal),
                                textAlign: TextAlign.end,
                                style: textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ملاحظات
              if (ret.notes != null && ret.notes!.isNotEmpty)
                _InfoCard(
                  icon: Icons.notes_outlined,
                  title: 'الملاحظات',
                  color: colors.onSurfaceVariant,
                  children: [
                    Text(
                      ret.notes!,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              if (ret.notes != null && ret.notes!.isNotEmpty)
                const SizedBox(height: 12),

              // ==============================
              // الإجمالي
              // ==============================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'إجمالي المرتجع',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      MoneyUtils.formatMoney(ret.totalAmount),
                      style: textTheme.headlineLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<PaymentModel>>(
                future: Get.find<PaymentController>().getPaymentsByReturn(
                  ret.id!,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final payments = snapshot.data ?? [];
                  if (payments.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        'الدفعات المرتبطة بالمرتجع',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...payments.map(
                        (payment) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: colors.surfaceContainer,
                            border: Border.all(color: colors.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.reply,
                                  color: Colors.red,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      MoneyUtils.formatMoney(payment.amount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Colors.red,
                                      ),
                                    ),
                                    if (payment.notes != null)
                                      Text(
                                        payment.notes!,
                                        style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                    if (payment.createdAt != null)
                                      Text(
                                        payment.createdAt!,
                                        style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final List<Widget> children;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtQty(double qty) =>
    qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(2);