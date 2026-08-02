import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/invoice_controller.dart';
import '../../models/invoice_model.dart';
import '../../models/product_model.dart';
import '../../models/party_model.dart';
import '../../models/Invoice_draft.dart';
import '../../core/utils/money_utils.dart';

class InvoiceFormScreen extends GetView<InvoiceController> {
  const InvoiceFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة جديدة'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _InvoiceTypeSelector(),
          SizedBox(height: 16),
          _PartySelector(),
          SizedBox(height: 16),
          _NotesField(),
          SizedBox(height: 20),
          _ItemsSection(),
          SizedBox(height: 20),
          _TotalSection(),
          SizedBox(height: 12),
          _PaymentSection(),
          SizedBox(height: 12),
          _FormErrorMessage(),
          SizedBox(height: 12),
          _SaveButton(),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ==============================
// نوع الفاتورة (بيع / شراء)
// ==============================

class _InvoiceTypeSelector extends GetView<InvoiceController> {
  const _InvoiceTypeSelector();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Row(
        children: [
          Expanded(
            child: _TypeButton(
              label: 'بيع',
              icon: Icons.arrow_upward_rounded,
              color: Colors.green,
              selected: controller.draftType.value == InvoiceType.sale,
              onTap: () => controller.setDraftType(InvoiceType.sale), // ← صح
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TypeButton(
              label: 'شراء',
              icon: Icons.arrow_downward_rounded,
              color: Colors.orange,
              selected: controller.draftType.value == InvoiceType.purchase,
              onTap: () =>
                  controller.setDraftType(InvoiceType.purchase), // ← صح
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? Colors.white : color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================
// اختيار الطرف مع إضافة سريعة
// ==============================

class _PartySelector extends GetView<InvoiceController> {
  const _PartySelector();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => GestureDetector(
        onTap: () => _showPartyPicker(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.people_outline, color: Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: controller.draftParty.value == null
                    ? Text(
                        'اختر الطرف',
                        style: TextStyle(color: Colors.grey[600]),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            controller.draftParty.value!.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (controller.draftParty.value!.phone != null)
                            Text(
                              controller.draftParty.value!.phone!,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _showPartyPicker(BuildContext context) {
    Get.bottomSheet(
      _PartyPickerSheet(),
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }
}

class _PartyPickerSheet extends GetView<InvoiceController> {
  final RxString search = ''.obs;

  _PartyPickerSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'اختر الطرف',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Search
              TextField(
                onChanged: (v) => search.value = v.trim(),
                decoration: InputDecoration(
                  hintText: 'بحث...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
              const SizedBox(height: 8),

              // زر إضافة سريعة
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.add, color: Colors.white),
                ),
                title: const Text('إضافة طرف جديد'),
                onTap: () {
                  Get.back();
                  _showQuickAddPartyDialog();
                },
              ),
              const Divider(),

              // القائمة
              Expanded(
                child: Obx(() {
                  final list = controller.availableParties
                      .where(
                        (p) => p.name.toLowerCase().contains(
                          search.value.toLowerCase(),
                        ),
                      )
                      .toList();

                  if (list.isEmpty) {
                    return const Center(child: Text('لا توجد نتائج'));
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final party = list[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _typeColor(
                            party.type,
                          ).withOpacity(0.15),
                          child: Icon(
                            _typeIcon(party.type),
                            color: _typeColor(party.type),
                            size: 20,
                          ),
                        ),
                        title: Text(party.name),
                        subtitle: party.phone != null
                            ? Text(party.phone!)
                            : null,
                        onTap: () {
                          controller.setDraftParty(party);
                          Get.back();
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showQuickAddPartyDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final selectedType = PartyType.customer.obs;

    Get.dialog(
      AlertDialog(
        title: const Text('إضافة طرف جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'الاسم *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'الهاتف'),
              ),
              const SizedBox(height: 12),
              Obx(
                () => SegmentedButton<PartyType>(
                  segments: const [
                    ButtonSegment(
                      value: PartyType.customer,
                      label: Text('عميل'),
                    ),
                    ButtonSegment(
                      value: PartyType.supplier,
                      label: Text('مورد'),
                    ),
                    ButtonSegment(value: PartyType.both, label: Text('كلاهما')),
                  ],
                  selected: {selectedType.value},
                  onSelectionChanged: (v) => selectedType.value = v.first,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final party = await controller.quickAddParty(
                PartyModel(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim().isEmpty
                      ? null
                      : phoneCtrl.text.trim(),
                  type: selectedType.value,
                ),
              );
              if (party != null) {
                controller.setDraftParty(party);
                Get.back();
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Color _typeColor(PartyType type) => switch (type) {
    PartyType.customer => Colors.blue,
    PartyType.supplier => Colors.orange,
    PartyType.both => Colors.purple,
  };

  IconData _typeIcon(PartyType type) => switch (type) {
    PartyType.customer => Icons.person_outline,
    PartyType.supplier => Icons.local_shipping_outlined,
    PartyType.both => Icons.people_outline,
  };
}

// ==============================
// حقل الملاحظات
// ==============================

class _NotesField extends GetView<InvoiceController> {
  const _NotesField();

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: controller.setDraftNotes,
      maxLines: 2,
      decoration: InputDecoration(
        labelText: 'ملاحظات (اختياري)',
        prefixIcon: const Icon(Icons.notes_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ==============================
// أسطر المنتجات
// ==============================

class _ItemsSection extends GetView<InvoiceController> {
  const _ItemsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'أسطر الفاتورة',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            TextButton.icon(
              onPressed: () => _showProductPicker(context),
              icon: const Icon(Icons.add),
              label: const Text('إضافة منتج'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Obx(() {
          if (controller.draftItems.isEmpty) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 40,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'لم تُضف أي منتجات بعد',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // رأس الجدول
              _TableHeader(),
              const Divider(height: 1),
              // الأسطر
              ...controller.draftItems.asMap().entries.map(
                (entry) => _ItemRow(index: entry.key, item: entry.value),
              ),
            ],
          );
        }),
      ],
    );
  }

  void _showProductPicker(BuildContext context) {
    Get.bottomSheet(
      _ProductPickerSheet(),
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'المنتج',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'الكمية',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'سغر القطعة',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'الإجمالي',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          SizedBox(width: 32),
        ],
      ),
    );
  }
}

class _ItemRow extends GetView<InvoiceController> {
  final int index;
  final InvoiceItemDraft item;

  const _ItemRow({required this.index, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // اسم المنتج
          Expanded(
            flex: 3,
            child: Text(
              item.productNameSnapshot,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // الكمية (قابلة للتعديل)
          Expanded(
            flex: 2,
            child: _EditableCell(
              value: item.quantity.toString(),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (v) {
                final qty = double.tryParse(v);
                if (qty != null && qty > 0) {
                  controller.updateDraftItem(index, quantity: qty);
                }
              },
            ),
          ),
          // السعر (قابل للتعديل)
          Expanded(
            flex: 2,
            child: _EditableCell(
              value: MoneyUtils.formatInput(item.unitPrice),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (v) {
                final price = MoneyUtils.parseAmount(v);
                if (price != null && price > 0) {
                  controller.updateDraftItem(index, unitPrice: price);
                }
              },
            ),
          ),
          // الإجمالي
          Expanded(
            flex: 2,
            child: Text(
              MoneyUtils.formatMoney(item.lineTotal),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          // حذف السطر
          GestureDetector(
            onTap: () => controller.removeDraftItem(index),
            child: const Icon(
              Icons.remove_circle_outline,
              color: Colors.red,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableCell extends StatefulWidget {
  final String value;
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;

  const _EditableCell({
    required this.value,
    required this.keyboardType,
    required this.onChanged,
  });

  @override
  State<_EditableCell> createState() => _EditableCellState();
}

class _EditableCellState extends State<_EditableCell> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      keyboardType: widget.keyboardType,
      textAlign: TextAlign.center,
      onChanged: widget.onChanged,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }
}

class _ProductPickerSheet extends GetView<InvoiceController> {
  final RxString search = ''.obs;

  _ProductPickerSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'اختر منتجاً',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => search.value = v.trim(),
                decoration: InputDecoration(
                  hintText: 'بحث...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
              const SizedBox(height: 8),

              // إضافة سريعة
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.add, color: Colors.white),
                ),
                title: const Text('إضافة منتج جديد'),
                onTap: () {
                  Get.back();
                  _showQuickAddProductDialog();
                },
              ),
              const Divider(),

              Expanded(
                child: Obx(() {
                  final list = controller.availableProducts
                      .where(
                        (p) => p.name.toLowerCase().contains(
                          search.value.toLowerCase(),
                        ),
                      )
                      .toList();

                  if (list.isEmpty) {
                    return const Center(child: Text('لا توجد نتائج'));
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final product = list[index];

                      return Obx(() {
                        final isSale =
                            controller.draftType.value == InvoiceType.sale;
                        final price = isSale
                            ? product.salePrice
                            : product.costPrice;
                        final priceColor = isSale
                            ? Colors.green
                            : Colors.orange;
                        final priceLabel = isSale ? 'سعر البيع' : 'سعر التكلفة';

                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE3F2FD),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: Colors.blue,
                              size: 20,
                            ),
                          ),
                          title: Text(product.name),
                          subtitle: Text('SKU: ${product.sku}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                MoneyUtils.formatMoney(price),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: priceColor,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                priceLabel,
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            controller.addDraftItem(
                              product: product,
                              quantity: 1,
                            );
                            Get.back();
                          },
                        );
                      });
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showQuickAddProductDialog() {
    final nameCtrl = TextEditingController();
    final skuCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final saleCtrl = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('إضافة منتج جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'الاسم *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: skuCtrl,
                decoration: const InputDecoration(labelText: 'SKU *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: costCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'سعر التكلفة *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: saleCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'سعر البيع *'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || skuCtrl.text.trim().isEmpty)
                return;
              final product = await controller.quickAddProduct(
                ProductModel(
                  name: nameCtrl.text.trim(),
                  sku: skuCtrl.text.trim(),
                  costPrice: MoneyUtils.parseAmount(costCtrl.text) ?? 0,
                  salePrice: MoneyUtils.parseAmount(saleCtrl.text) ?? 0,
                ),
              );
              if (product != null) {
                controller.addDraftItem(
                  product: product,
                  quantity: 1,
                  unitPrice: product.salePrice,
                );
                Get.back();
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}

// ==============================
// المجموع الكلي
// ==============================

class _TotalSection extends GetView<InvoiceController> {
  const _TotalSection();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'المبلغ الإجمالي',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              MoneyUtils.formatMoney(controller.draftTotal),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentSection extends GetView<InvoiceController> {
  const _PaymentSection();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final total = controller.draftTotal;
      final paid = controller.draftInitialPayment.value;
      final remaining = (total - paid).clamp(0, total);

      // حالة الدفع
      final PaymentStatus status;
      if (paid <= 0) {
        status = PaymentStatus.unpaid;
      } else if (paid >= total) {
        status = PaymentStatus.paid;
      } else {
        status = PaymentStatus.partial;
      }

      final statusColor = switch (status) {
        PaymentStatus.unpaid => Colors.red,
        PaymentStatus.partial => Colors.orange,
        PaymentStatus.paid => Colors.green,
      };

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الدفع عند الإنشاء',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),

            // حقل المبلغ المدفوع
            TextFormField(
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              initialValue: paid > 0 ? MoneyUtils.formatInput(paid) : '',
              onChanged: (v) {
                final amount = MoneyUtils.parseAmount(v) ?? 0;
                controller.setInitialPayment(amount);
              },
              decoration: InputDecoration(
                labelText: 'المبلغ المدفوع',
                prefixIcon: const Icon(Icons.payments_outlined),
                suffixText: 'من ${MoneyUtils.formatMoney(total)}',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // شريط التقدم
            if (total > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total > 0 ? (paid / total).clamp(0.0, 1.0) : 0,
                  minHeight: 8,
                  color: statusColor,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
              const SizedBox(height: 10),
            ],

            // ملخص
            Row(
              children: [
                Expanded(
                  child: _PaymentStat(
                    label: 'المدفوع',
                    value: MoneyUtils.formatMoney(paid),
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _PaymentStat(
                    label: 'المتبقي',
                    value: MoneyUtils.formatMoney(remaining),
                    color: remaining > 0 ? Colors.red : Colors.grey,
                  ),
                ),
                // badge الحالة
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    status.label,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _PaymentStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PaymentStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
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

// ==============================
// رسالة الخطأ
// ==============================

class _FormErrorMessage extends GetView<InvoiceController> {
  const _FormErrorMessage();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.invoiceFormError.value == null) {
        return const SizedBox.shrink();
      }
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                controller.invoiceFormError.value!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ==============================
// زر الحفظ
// ==============================

class _SaveButton extends GetView<InvoiceController> {
  const _SaveButton();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: controller.isSavingInvoice.value
              ? null
              : () async {
                  final success = await controller.saveInvoice();
                  if (success) {
                    Get.back();
                    Get.snackbar(
                      'تم',
                      'تم حفظ الفاتورة بنجاح',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.green,
                      colorText: Colors.white,
                    );
                  }
                },
          icon: controller.isSavingInvoice.value
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_outlined),
          label: Text(
            controller.isSavingInvoice.value ? 'جاري الحفظ...' : 'حفظ الفاتورة',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
