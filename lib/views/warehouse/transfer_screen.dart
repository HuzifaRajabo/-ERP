import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/transfer_controller.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../shared/app_ui.dart';

/// شاشة كاملة لنقل المخزون بين مستودعين.
class TransferScreen extends StatelessWidget {
  final int? initialFromWarehouseId;

  const TransferScreen({super.key, this.initialFromWarehouseId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحويل مخزون'), centerTitle: true),
      body: TransferTab(initialFromWarehouseId: initialFromWarehouseId),
    );
  }
}

/// قسم التحويل — يُستخدم داخل شاشة تفاصيل المستودع وعند فتحه كمستقل.
class TransferTab extends StatelessWidget {
  final int? initialFromWarehouseId;

  const TransferTab({super.key, this.initialFromWarehouseId});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(TransferController.create());

    if (initialFromWarehouseId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.fromWarehouseId.value != initialFromWarehouseId) {
          controller.selectFromWarehouse(initialFromWarehouseId);
        }
      });
    }

    return _TransferBody(controller: controller);
  }
}

class _TransferBody extends StatefulWidget {
  final TransferController controller;

  const _TransferBody({required this.controller});

  @override
  State<_TransferBody> createState() => _TransferBodyState();
}

class _TransferBodyState extends State<_TransferBody> {
  final _qtyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    Get.delete<TransferController>();
    super.dispose();
  }

  void _syncQuantity(String v) {
    widget.controller.quantity.value =
        double.tryParse(v.replaceAll(',', '.'));
  }

  void _addToCart() {
    final err = widget.controller.addSelectionToCart();
    if (err != null) {
      widget.controller.errorMessage.value = err;
      return;
    }
    _qtyCtrl.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _submit() async {
    if (widget.controller.cartItems.isEmpty) {
      widget.controller.errorMessage.value =
          'أضف منتجاً واحداً على الأقل قبل تنفيذ التحويل';
      return;
    }
    final ok = await widget.controller.submit();
    if (ok && mounted) {
      _qtyCtrl.clear();
      _notesCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = widget.controller.state.value;
      if (s == TransferState.submitting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (s == TransferState.success) {
        return _SuccessView(
          controller: widget.controller,
          onDone: () {
            widget.controller.resetTransfer();
            _qtyCtrl.clear();
            _notesCtrl.clear();
          },
        );
      }

      if (s == TransferState.loading && widget.controller.warehouses.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      return _buildForm();
    });
  }

  Widget _buildForm() {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final semantic = context.semantic;
    final c = widget.controller;
    final fromId = c.fromWarehouseId.value;
    final productId = c.selectedProductId.value;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // رسالة الخطأ (تظهر أعلى الشاشة بدل استبدال النموذج بالكامل،
            // حتى لا يفقد المستخدم ما أضافه للسلة سابقاً عند حدوث خطأ)
            Obx(() {
              final err = c.errorMessage.value;
              if (err == null) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: semantic.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: semantic.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: semantic.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(err,
                          style: TextStyle(color: semantic.error)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: semantic.error,
                      onPressed: () => c.errorMessage.value = null,
                    ),
                  ],
                ),
              );
            }),
            _sectionTitle('المستودع المصدر'),
            Obx(() => _reactiveDropdown(
                  label: 'من مستودع',
                  icon: Icons.arrow_upward_rounded,
                  value: fromId,
                  onChanged: c.selectFromWarehouse,
                  items: [
                    for (final w in c.warehouses)
                      DropdownMenuItem(value: w.id, child: Text(w.name)),
                  ],
                )),
            const SizedBox(height: 16),
            _sectionTitle('المستودع الوجهة'),
            Obx(() => _reactiveDropdown(
                  label: 'إلى مستودع',
                  icon: Icons.arrow_downward_rounded,
                  value: c.toWarehouseId.value,
                  onChanged: (v) => c.toWarehouseId.value = v,
                  items: [
                    for (final w in c.warehouses)
                      if (w.id != fromId)
                        DropdownMenuItem(value: w.id, child: Text(w.name)),
                  ],
                )),
            const SizedBox(height: 20),

            // ===== سلة المنتجات المضافة =====
            Obx(() {
              if (c.cartItems.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionTitle('منتجات هذا التحويل (${c.cartItems.length})'),
                  ...c.cartItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(item.productName,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _fmt(item.quantity),
                            style: textTheme.titleSmall?.copyWith(
                              color: colors.primary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            color: colors.onSurfaceVariant,
                            onPressed: () => c.removeFromCart(index),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 4),
                ],
              );
            }),

            _sectionTitle('إضافة منتج للتحويل'),
            Obx(() {
              if (c.isLoadingProducts.value) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _reactiveDropdown(
                label: 'اختر المنتج',
                icon: Icons.inventory_2_outlined,
                value: productId,
                onChanged: c.selectProduct,
                items: [
                  for (final p in c.availableProducts)
                    DropdownMenuItem(
                        value: p.productId,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(p.productName,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Text(' (${_fmt(p.available)})',
                                style: textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant)),
                          ],
                        )),
                ],
              );
            }),
            const SizedBox(height: 16),
            TextFormField(
              controller: _qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: AppUi.inputDecoration(
                  label: 'الكمية (بالوحدة الأساسية)', icon: Icons.numbers),
              onChanged: _syncQuantity,
              onFieldSubmitted: (_) => _addToCart(),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _addToCart,
              icon: const Icon(Icons.add),
              label: const Text('أضف للتحويل'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle('ملاحظات (اختياري)'),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              onChanged: (v) => c.notes.value = v.trim().isEmpty ? null : v.trim(),
              decoration:
                  AppUi.inputDecoration(label: 'ملاحظات (اختياري)', icon: Icons.notes),
            ),
            const SizedBox(height: 24),
            Obx(() => FilledButton.icon(
                  onPressed: c.cartItems.isEmpty ? null : _submit,
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: Text(c.cartItems.isEmpty
                      ? 'أضف منتجاً واحداً على الأقل'
                      : 'تنفيذ التحويل (${c.cartItems.length} منتج)'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _reactiveDropdown({
    required String label,
    required IconData icon,
    required int? value,
    required ValueChanged<int?> onChanged,
    required List<DropdownMenuItem<int>> items,
  }) {
    final validValue =
        items.any((i) => i.value == value) ? value : null;
    return InputDecorator(
      decoration: AppUi.inputDecoration(label: label, icon: icon),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: validValue,
          hint: Text(label),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: Theme.of(context).textTheme.titleSmall),
      );

  String _fmt(double q) =>
      q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(2);
}

class _SuccessView extends StatelessWidget {
  final TransferController controller;
  final VoidCallback onDone;

  const _SuccessView({required this.controller, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final r = controller.lastResult;
    final itemsCount = r?.items.length ?? 0;
    final totalQty =
        r?.items.fold<double>(0, (sum, i) => sum + i.quantity) ?? 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded,
                color: context.semantic.success, size: 72),
            const SizedBox(height: 16),
            Text('تم التحويل بنجاح',
                style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              itemsCount <= 1
                  ? 'الكمية المنقولة: ${_fmtQty(totalQty)} وحدة أساسية'
                  : '$itemsCount منتجات — إجمالي ${_fmtQty(totalQty)} وحدة أساسية',
              style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onDone,
              icon: const Icon(Icons.add),
              label: const Text('تحويل جديد'),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtQty(double q) =>
      q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(2);
}