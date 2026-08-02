import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/utils/money_utils.dart';
import '../../controllers/payment_controller.dart';
import '../../models/invoice_model.dart';
import '../shared/payment_widgets.dart';

class PaymentBottomSheet extends GetView<PaymentController> {
  final InvoiceModel invoice;

  const PaymentBottomSheet({super.key, required this.invoice});

  static Future<void> show(InvoiceModel invoice) async {
    await Get.bottomSheet(
      PaymentBottomSheet(invoice: invoice),
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    controller.initPaymentForm(invoice);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          return ListView(
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
              Row(
                children: [
                  const Icon(Icons.payments_outlined, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'تسجيل دفعة — ${invoice.invoiceNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ملخص الفاتورة
              _InvoiceSummaryCard(invoice: invoice),
              const SizedBox(height: 16),

              // حقل المبلغ
              Obx(
                () => TextFormField(
                  initialValue: controller.paymentAmount.value > 0
                      ? MoneyUtils.formatInput(controller.paymentAmount.value)
                      : '',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (v) => controller.setPaymentAmount(
                    MoneyUtils.parseAmount(v) ?? 0,
                  ),
                  decoration: InputDecoration(
                    labelText: 'المبلغ المدفوع',
                    prefixIcon: const Icon(Icons.attach_money),
                    suffixText:
                        'الحد الأقصى: ${MoneyUtils.formatMoney(invoice.remaining)}',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // حقل الملاحظات
              TextFormField(
                onChanged: controller.setPaymentNotes,
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

              // رسالة الخطأ
              Obx(
                () => controller.formError.value != null
                    ? ErrorBox(message: controller.formError.value!)
                    : const SizedBox.shrink(),
              ),

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
                                .saveInvoicePayment();
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
                    icon: controller.isSaving.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      controller.isSaving.value
                          ? 'جاري الحفظ...'
                          : 'حفظ الدفعة',
                      style: const TextStyle(fontSize: 16),
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
        },
      ),
    );
  }
}

class _InvoiceSummaryCard extends StatelessWidget {
  final InvoiceModel invoice;

  const _InvoiceSummaryCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SummaryItem(
                label: 'الإجمالي',
                value: MoneyUtils.formatMoney(invoice.totalAmount),
                color: Colors.blueGrey,
              ),
              _SummaryItem(
                label: 'المدفوع',
                value: MoneyUtils.formatMoney(invoice.paidAmount),
                color: Colors.green,
              ),
              _SummaryItem(
                label: 'المتبقي',
                value: MoneyUtils.formatMoney(invoice.remaining),
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: invoice.totalAmount > 0
                  ? (invoice.paidAmount / invoice.totalAmount).clamp(0.0, 1.0)
                  : 0,
              minHeight: 6,
              color: Colors.green,
              backgroundColor: Colors.grey.shade200,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}
