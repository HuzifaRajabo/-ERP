import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/utils/money_utils.dart';
import '../../controllers/return_controller.dart';
import '../../models/invoice_model.dart';
import '../../models/return_model.dart';

class ReturnFormScreen extends StatefulWidget {
  const ReturnFormScreen({super.key});

  @override
  State<ReturnFormScreen> createState() => _ReturnFormScreenState();
}

class _ReturnFormScreenState extends State<ReturnFormScreen> {
  late final InvoiceModel invoice;
  late final ReturnType returnType;
  late final ReturnController controller;
  final notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>;
    invoice = args['invoice'] as InvoiceModel;
    returnType = args['returnType'] as ReturnType;
    controller = Get.find<ReturnController>();
    controller.loadReturnableItems(invoice.id!);
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(returnType.label), centerTitle: true),
      body: Obx(() {
        if (controller.isLoadingItems.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.returnableItems.isEmpty) {
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
                const Text(
                  'لا توجد كميات قابلة للإرجاع',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ==============================
            // معلومات الفاتورة الأصلية
            // ==============================
            _InvoiceInfoCard(invoice: invoice),
            const SizedBox(height: 16),

            // ==============================
            // أسطر المرتجع
            // ==============================
            _ItemsHeader(controller: controller),
            const SizedBox(height: 8),

            ...controller.returnableItems.asMap().entries.map(
              (entry) => _ReturnItemRow(
                index: entry.key,
                item: entry.value,
                controller: controller,
              ),
            ),
            const SizedBox(height: 16),

            // ==============================
            // الملخص
            // ==============================
            _ReturnSummary(controller: controller),
            const SizedBox(height: 16),

            // ==============================
            // الملاحظات
            // ==============================
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                prefixIcon: const Icon(Icons.notes_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ==============================
            // رسالة الخطأ
            // ==============================
            Obx(
              () => controller.formError.value != null
                  ? _ErrorCard(message: controller.formError.value!)
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 12),

            // ==============================
            // زر الحفظ
            // ==============================
            Obx(
              () => SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: controller.isSaving.value
                      ? null
                      : () async {
                          final success = await controller.saveReturn(
                            originalInvoiceId: invoice.id!,
                            type: returnType,
                            notes: notesController.text.trim().isEmpty
                                ? null
                                : notesController.text.trim(),
                          );
                          if (success) {
                            Get.back();
                            Get.snackbar(
                              'تم',
                              'تم تسجيل المرتجع بنجاح',
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
                      : const Icon(Icons.undo_rounded),
                  label: Text(
                    controller.isSaving.value
                        ? 'جاري الحفظ...'
                        : 'تسجيل المرتجع',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        );
      }),
    );
  }
}

// ==============================
// بطاقة معلومات الفاتورة
// ==============================

class _InvoiceInfoCard extends StatelessWidget {
  final InvoiceModel invoice;

  const _InvoiceInfoCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.invoiceNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  invoice.partyNameSnapshot,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                MoneyUtils.formatMoney(invoice.totalAmount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'إجمالي الفاتورة',
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==============================
// رأس جدول الأسطر
// ==============================

class _ItemsHeader extends StatelessWidget {
  final ReturnController controller;

  const _ItemsHeader({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'اختر الكميات المرتجعة',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        // زر تحديد الكل
        TextButton.icon(
          onPressed: () {
            for (int i = 0; i < controller.returnableItems.length; i++) {
              controller.selectFullQuantity(i);
            }
          },
          icon: const Icon(Icons.select_all, size: 16),
          label: const Text('تحديد الكل'),
        ),
      ],
    );
  }
}

// ==============================
// سطر منتج في المرتجع
// ==============================

class _ReturnItemRow extends StatefulWidget {
  final int index;
  final ReturnableItem item;
  final ReturnController controller;

  const _ReturnItemRow({
    required this.index,
    required this.item,
    required this.controller,
  });

  @override
  State<_ReturnItemRow> createState() => _ReturnItemRowState();
}

class _ReturnItemRowState extends State<_ReturnItemRow> {
  late TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
      text: widget.item.selectedQuantity > 0
          ? widget.item.selectedQuantity.toString()
          : '',
    );
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.item.selectedQuantity > 0
            ? Colors.purple.withOpacity(0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.item.selectedQuantity > 0
              ? Colors.purple.withOpacity(0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // اسم المنتج
          Text(
            widget.item.productName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // معلومات الكمية
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _QtyInfo(
                      label: 'الكمية الأصلية',
                      value: _fmt(widget.item.originalQuantity),
                      color: Colors.grey,
                    ),
                    if (widget.item.returnedSoFar > 0)
                      _QtyInfo(
                        label: 'مُرجع سابقاً',
                        value: _fmt(widget.item.returnedSoFar),
                        color: Colors.orange,
                      ),
                    _QtyInfo(
                      label: 'متاح للإرجاع',
                      value: _fmt(widget.item.availableToReturn),
                      color: Colors.green,
                    ),
                  ],
                ),
              ),

              // حقل الكمية المرتجعة
              Column(
                children: [
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      controller: _qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.center,
                      onChanged: (v) {
                        final qty = double.tryParse(v) ?? 0;
                        widget.controller.updateReturnQuantity(
                          widget.index,
                          qty,
                        );
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: '0',
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // زر إرجاع الكل
                  GestureDetector(
                    onTap: () {
                      widget.controller.selectFullQuantity(widget.index);
                      _qtyCtrl.text = widget.item.availableToReturn.toString();
                    },
                    child: Text(
                      'الكل',
                      style: TextStyle(
                        color: Colors.purple[300],
                        fontSize: 11,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // الإجمالي إذا كانت هناك كمية
          if (widget.item.selectedQuantity > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'قيمة المرتجع: ',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                Text(
                  MoneyUtils.formatMoney(widget.item.lineTotal),
                  style: const TextStyle(
                    color: Colors.purple,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(double qty) =>
      qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(2);
}

class _QtyInfo extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _QtyInfo({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[400], fontSize: 11),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================
// ملخص المرتجع
// ==============================

class _ReturnSummary extends StatelessWidget {
  final ReturnController controller;

  const _ReturnSummary({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final total = controller.returnTotal;
      final activeCount = controller.returnableItems
          .where((i) => i.selectedQuantity > 0)
          .length;

      if (total == 0) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إجمالي المرتجع',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  '$activeCount منتج',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
            Text(
              MoneyUtils.formatMoney(total),
              style: const TextStyle(
                color: Colors.purple,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ==============================
// بطاقة الخطأ
// ==============================

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
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
