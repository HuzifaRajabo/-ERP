import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/utils/money_utils.dart';
import '../../controllers/payment_controller.dart';
import '../../models/invoice_model.dart';
import '../../views/shared/shared_components.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_colors.dart';

class PaymentBottomSheet extends GetView<PaymentController> {
  final InvoiceModel invoice;

  const PaymentBottomSheet({super.key, required this.invoice});

  static Future<void> show(InvoiceModel invoice) async {
    // تهيئة نموذج الدفعة مرة واحدة فقط قبل فتح النافذة — وليس داخل
    // build()، لأن build() يُعاد تنفيذه في كل مرة يتغيّر فيها
    // MediaQuery.viewInsets (أي عند ظهور/اختفاء لوحة المفاتيح)، وكان هذا
    // يُصفّر المبلغ الذي كتبه المستخدم ويعيده إلى "المتبقي بالكامل" —
    // وغالباً يحدث هذا التصفير عند الضغط على زر الحفظ نفسه (لأن لمس
    // الشاشة يُغلق لوحة المفاتيح قبل تنفيذ onPressed)، فيُحفظ المبلغ
    // الخاطئ (المتبقي الكامل) بدل المبلغ الذي أدخله المستخدم فعلياً.
    Get.find<PaymentController>().initPaymentForm(invoice);

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
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              // Handle
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
              SizedBox(height: AppSpacing.sm),

              // العنوان - باستخدام AppSectionHeader
              AppSectionHeader(
                title: 'تسجيل دفعة — ${invoice.invoiceNumber}',
                action: null,
              ),
              SizedBox(height: AppSpacing.sm),

              // ملخص الفاتورة
              _InvoiceSummaryCard(invoice: invoice),
              SizedBox(height: AppSpacing.md),

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
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                  ),
                ),
              ),
SizedBox(height: AppSpacing.sm),

              // حقل الملاحظات
              TextFormField(
                onChanged: controller.setPaymentNotes,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  prefixIcon: const Icon(Icons.notes_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.md),

              // رسالة الخطأ
              Obx(
                () => controller.formError.value != null
                    ? AppErrorState(
                  message: controller.formError.value!,
                  title: 'خطأ',
                )
                    : const SizedBox.shrink(),
              ),
              SizedBox(height: AppSpacing.sm),

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
                        borderRadius: BorderRadius.circular(AppRadius.medium),
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // استخدام AppSectionHeader للعنوان
          AppSectionHeader(
            title: 'ملخص الفاتورة',
            action: null,
          ),
          const SizedBox(height: AppSpacing.sm),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SummaryItem(
                label: 'الإجمالي',
                value: MoneyUtils.formatMoney(invoice.totalAmount),
                color: Theme.of(context).colorScheme.onSurface,
              ),
              _SummaryItem(
                label: 'المدفوع',
                value: MoneyUtils.formatMoney(invoice.paidAmount),
                color: AppColors.success,
              ),
              _SummaryItem(
                label: 'المتبقي',
                value: MoneyUtils.formatMoney(invoice.remaining),
                color: Theme.of(context).colorScheme.error,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: invoice.totalAmount > 0
                ? (invoice.paidAmount / invoice.totalAmount).clamp(0.0, 1.0)
                : 0,
            minHeight: 6,
            color: AppColors.success,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.grey[500],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}