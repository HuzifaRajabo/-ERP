import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/utils/money_utils.dart';
import '../../controllers/return_controller.dart';
import '../../models/invoice_model.dart';
import '../../models/return_model.dart';
import '../../models/product_unit_model.dart';
import '../../controllers/product_controller.dart';
import '../../core/theme/app_semantic_colors.dart';

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
    final textTheme = Theme.of(context).textTheme;

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
                  color: context.semantic.success,
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد كميات قابلة للإرجاع',
                  style: textTheme.bodyLarge,
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
                returnType: returnType,
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
                              backgroundColor: context.semantic.success,
                              colorText: context.semantic.onSuccess,
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
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.receipt_long_outlined, color: colors.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.invoiceNumber,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  invoice.partyNameSnapshot,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                MoneyUtils.formatMoney(invoice.totalAmount),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'إجمالي الفاتورة',
                style: textTheme.labelSmall,
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
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'اختر الكميات المرتجعة',
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
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
  final ReturnType returnType;

  const _ReturnItemRow({
    required this.index,
    required this.item,
    required this.controller,
    required this.returnType,
  });

  @override
  State<_ReturnItemRow> createState() => _ReturnItemRowState();
}

class _ReturnItemRowState extends State<_ReturnItemRow> {
  late TextEditingController _qtyCtrl;
  final _units = <ProductUnitModel>[].obs;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
      text: widget.item.selectedQuantity > 0
          ? _fmt(widget.item.selectedQuantity)
          : '',
    );
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    try {
      // وحدة الإرجاع: وحدات قابلة للبيع لمرتجع مبيعات، وقابلة للشراء لمرتجع مشتريات
      final productController = Get.find<ProductController>();
      final units = widget.returnType == ReturnType.saleReturn
          ? await productController.getSellableUnits(widget.item.productId)
          : await productController.getBuyableUnits(widget.item.productId);
      if (mounted) _units.assignAll(units);
    } catch (_) {
      // لا نكسر النموذج عند فشل جلب الوحدات
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  String get _baseUnitName =>
      widget.item.baseUnitName ?? 'وحدة أساسية';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final selectedQty = widget.item.selectedQuantity;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selectedQty > 0
            ? Colors.purple.withValues(alpha: 0.04)
            : colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selectedQty > 0
              ? Colors.purple.withValues(alpha: 0.3)
              : colors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // اسم المنتج
          Text(
            widget.item.productName,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // معلومات الكمية (بالوحدة الأساسية للعرض الموحّد)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _QtyInfo(
                      label: 'الأصلي',
                      value: '${_fmt(widget.item.originalQuantity)} '
                          '${widget.item.invoiceUnitName ?? _baseUnitName}',
                      color: colors.onSurfaceVariant,
                    ),
                    if (widget.item.returnedBaseQuantity > 0)
                      _QtyInfo(
                        label: 'مُرجع سابقاً',
                        value:
                            '${_fmt(widget.item.returnedBaseQuantity)} $_baseUnitName',
                        color: context.semantic.warning,
                      ),
                    _QtyInfo(
                      label: 'المتبقي',
                      value:
                          '${_fmt(widget.item.remainingBaseQuantity)} $_baseUnitName',
                      color: context.semantic.success,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'وحدة الإرجاع',
                      style: textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    Obx(() {
                      if (_units.isEmpty) {
                        return Text(
                          widget.item.selectedUnitName ?? _baseUnitName,
                          style: textTheme.bodySmall,
                        );
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.outlineVariant),
                        ),
                        child: DropdownButton<int>(
                          value: widget.item.selectedUnitId,
                          isDense: true,
                          underline: const SizedBox.shrink(),
                          items: _units
                              .map(
                                (u) => DropdownMenuItem<int>(
                                  value: u.id,
                                  child: Text(
                                    '${u.unitName} (1 = ${_fmt(u.conversionFactor)} $_baseUnitName)',
                                    style: textTheme.labelMedium,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (id) {
                            if (id == null) return;
                            final unit = _units.firstWhere((u) => u.id == id);
                            widget.controller.updateReturnUnit(
                              widget.index,
                              unit,
                            );
                            final updated =
                                widget.controller.returnableItems[widget.index];
                            _qtyCtrl.text = updated.selectedQuantity > 0
                                ? _fmt(updated.selectedQuantity)
                                : '';
                          },
                        ),
                      );
                    }),
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
                      final updated =
                          widget.controller.returnableItems[widget.index];
                      _qtyCtrl.text = updated.selectedQuantity > 0
                          ? _fmt(updated.selectedQuantity)
                          : '';
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
          if (selectedQty > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'قيمة المرتجع: ',
                  style: textTheme.labelSmall,
                ),
                Text(
                  MoneyUtils.formatMoney(widget.item.lineTotal),
                  style: textTheme.titleSmall?.copyWith(
                    color: Colors.purple,
                    fontWeight: FontWeight.bold,
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
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: textTheme.labelSmall,
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
    final textTheme = Theme.of(context).textTheme;

    return Obx(() {
      final total = controller.returnTotal;
      final activeCount = controller.returnableItems
          .where((i) => i.selectedQuantity > 0)
          .length;

      if (total == 0) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إجمالي المرتجع',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$activeCount منتج',
                  style: textTheme.labelSmall,
                ),
              ],
            ),
            Text(
              MoneyUtils.formatMoney(total),
              style: textTheme.headlineLarge?.copyWith(
                color: Colors.purple,
                fontWeight: FontWeight.bold,
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
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.semantic.errorContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onSurface, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}