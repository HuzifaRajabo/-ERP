import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/transfer_controller.dart';
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
    final controller = Get.put(
      TransferController(
        warehouseRepo: Get.find(),
        inventoryRepo: Get.find(),
        transferRepo: Get.find(),
      ),
    );

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
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
      final err = widget.controller.errorMessage.value;
      if (err != null) {
        return Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(err, textAlign: TextAlign.center),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: () {
                  widget.controller.errorMessage.value = null;
                  widget.controller.state.value = TransferState.idle;
                },
                child: const Text('محاولة مجدداً'),
              ),
            ),
          ],
        );
      }

      if (s == TransferState.loading && widget.controller.warehouses.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      return _buildForm();
    });
  }

  Widget _buildForm() {
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
            _sectionTitle('المنتج'),
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
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12)),
                          ],
                        )),
                ],
              );
            }),
            const SizedBox(height: 20),
            _sectionTitle('الكمية (بالوحدة الأساسية)'),
            TextFormField(
              controller: _qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration:
                  AppUi.inputDecoration(label: 'الكمية', icon: Icons.numbers),
              onChanged: _syncQuantity,
              validator: (v) {
                final q = double.tryParse(v?.replaceAll(',', '.') ?? '');
                if (q == null || q <= 0) return 'أدخل كمية صحيحة';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              onChanged: (v) => c.notes.value = v.trim().isEmpty ? null : v.trim(),
              decoration:
                  AppUi.inputDecoration(label: 'ملاحظات (اختياري)', icon: Icons.notes),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('تنفيذ التحويل'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
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
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
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
    final r = controller.lastResult;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF16A34A), size: 72),
            const SizedBox(height: 16),
            const Text('تم التحويل بنجاح',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'الكمية المنقولة: ${_fmtQty(r?.quantity ?? 0)} وحدة أساسية',
              style: TextStyle(color: Colors.grey[600]),
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
