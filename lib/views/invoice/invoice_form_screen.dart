import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/invoice_controller.dart';
import '../../models/invoice_model.dart';
import '../../models/product_model.dart';
import '../../models/party_model.dart';
import '../../models/invoice_draft.dart';
import '../../core/utils/money_utils.dart';

class InvoiceFormScreen extends GetView<InvoiceController> {
  const InvoiceFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'رجوع',
          onPressed: Get.back,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'فاتورة جديدة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            SizedBox(height: 2),
            Text(
              'إنشاء فاتورة مبيعات أو مشتريات',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        actions: [
          Obx(
            () => TextButton.icon(
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
                          backgroundColor: const Color(0xFF16A34A),
                          colorText: Colors.white,
                        );
                      }
                    },
              icon: controller.isSavingInvoice.value
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF2563EB),
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 19),
              label: Text(
                controller.isSavingInvoice.value ? 'جارٍ الحفظ...' : 'حفظ',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _InvoiceTypeSelector(),
              SizedBox(height: 16),
              _PartySelector(),
              SizedBox(height: 16),
              _ItemsSection(),
              SizedBox(height: 16),
              _TotalSection(),
              SizedBox(height: 16),
              _PaymentSection(),
              SizedBox(height: 16),
              _NotesField(),
              SizedBox(height: 16),
              _FormErrorMessage(),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceTypeSelector extends GetView<InvoiceController> {
  const _InvoiceTypeSelector();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'نوع العملية',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TypeButton(
                  label: 'المبيعات',
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFF16A34A),
                  selected: controller.draftType.value == InvoiceType.sale,
                  onTap: () => controller.setDraftType(InvoiceType.sale),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TypeButton(
                  label: 'المشتريات',
                  icon: Icons.shopping_cart_rounded,
                  color: const Color(0xFFF59E0B),
                  selected: controller.draftType.value == InvoiceType.purchase,
                  onTap: () => controller.setDraftType(InvoiceType.purchase),
                ),
              ),
            ],
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
    return Material(
      color: selected ? color : color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : color,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartySelector extends GetView<InvoiceController> {
  const _PartySelector();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final draftParty = controller.draftParty.value;
        final typeLabel = controller.draftType.value == InvoiceType.sale
            ? 'العميل'
            : 'المورد';

        return GestureDetector(
          onTap: () => _showPartyPicker(context),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'الطرف',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      typeLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.people_alt_rounded,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: draftParty == null
                          ? const Text(
                              'اختر العميل أو المورد',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6B7280),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  draftParty.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                if (draftParty.phone != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    draftParty.phone!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                    const Icon(
                      Icons.chevron_left_rounded,
                      color: Color(0xFF9CA3AF),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
                          ).withValues(alpha: 0.15),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.sticky_note_2_outlined,
                size: 18,
                color: Color(0xFF2563EB),
              ),
              SizedBox(width: 8),
              Text(
                'ملاحظات',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: controller.setDraftNotes,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'إضافة أي ملاحظات أو تعليمات خاصة...',
              filled: true,
              fillColor: const Color(0xFFF7F8FC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsSection extends GetView<InvoiceController> {
  const _ItemsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.inventory_2_rounded,
              size: 18,
              color: Color(0xFF2563EB),
            ),
            const SizedBox(width: 8),
            const Text(
              'المنتجات',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showProductPicker(context),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('إضافة'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Obx(() {
          if (controller.draftItems.isEmpty) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 38,
                    color: Color(0xFF9CA3AF),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'لم يتم إضافة منتجات بعد',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            );
          }

          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                _TableHeader(),
                const SizedBox(height: 6),
                ...controller.draftItems.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _ItemRow(index: entry.key, item: entry.value),
                  ),
                ),
              ],
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'المنتج',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'الكمية',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'السعر',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'الإجمالي',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
            ),
          ),
          SizedBox(width: 28),
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productNameSnapshot,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.quantity} × ${MoneyUtils.formatMoney(item.unitPrice)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
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
          Expanded(
            flex: 2,
            child: Text(
              MoneyUtils.formatMoney(item.lineTotal),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: Color(0xFF111827),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => controller.removeDraftItem(index),
            child: const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
                size: 18,
              ),
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
                          subtitle: Text('الوصف: ${product.description}'),
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
    final descriptionCtrl = TextEditingController();
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
                controller: descriptionCtrl,
                decoration: const InputDecoration(labelText: 'الوصف *'),
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
              final name = nameCtrl.text.trim();
              final description = descriptionCtrl.text.trim();

              // ==============================
              // Validate name
              // ==============================

              if (name.isEmpty) {
                Get.snackbar(
                  'تنبيه',
                  'يرجى إدخال اسم المنتج',
                );
                return;
              }

              // ==============================
              // Validate description
              // ==============================

              if (description.isEmpty) {
                Get.snackbar(
                  'تنبيه',
                  'يرجى إدخال وصف المنتج',
                );
                return;
              }

              // ==============================
              // Parse money using MoneyUtils
              // ==============================

              final costPrice = MoneyUtils.parseAmount(costCtrl.text);
              final salePrice = MoneyUtils.parseAmount(saleCtrl.text);

              if (costPrice == null) {
                Get.snackbar(
                  'تنبيه',
                  'سعر التكلفة غير صحيح',
                );
                return;
              }

              if (salePrice == null) {
                Get.snackbar(
                  'تنبيه',
                  'سعر البيع غير صحيح',
                );
                return;
              }

              // ==============================
              // Prevent double click
              // ==============================

              Get.dialog(
                const Center(
                  child: CircularProgressIndicator(),
                ),
                barrierDismissible: false,
              );

              try {
                final product = await controller.quickAddProduct(
                  ProductModel(
                    name: name,
                    description: description,
                    costPrice: costPrice,
                    salePrice: salePrice,
                  ),
                );

                // أغلق loading
                if (Get.isDialogOpen == true) {
                  Get.back();
                }

                if (product == null) {
                  Get.snackbar(
                    'فشل الإضافة',
                    controller.invoiceFormError.value ??
                        'تعذر إضافة المنتج',
                  );
                  return;
                }

                // ==============================
                // Add directly to invoice
                // ==============================

                controller.addDraftItem(
                  product: product,
                  quantity: 1,
                  // لا نحدد السعر هنا.
                  // Controller سيختار:
                  // Sale  → salePrice
                  // Purchase → costPrice
                );

                // إغلاق نافذة إضافة المنتج
                Get.back();

                Get.snackbar(
                  'تمت الإضافة',
                  'تمت إضافة المنتج إلى الفاتورة',
                );
              } catch (e) {
                if (Get.isDialogOpen == true) {
                  Get.back();
                }

                Get.snackbar(
                  'خطأ',
                  e.toString().replaceFirst('Exception: ', ''),
                );
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}

class _TotalSection extends GetView<InvoiceController> {
  const _TotalSection();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Color(0xFF2563EB),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'إجمالي الفاتورة',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    MoneyUtils.formatMoney(controller.draftTotal),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${controller.draftItems.length} عنصر',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
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

      final PaymentStatus status;
      if (paid <= 0) {
        status = PaymentStatus.unpaid;
      } else if (paid >= total) {
        status = PaymentStatus.paid;
      } else {
        status = PaymentStatus.partial;
      }

      final statusColor = switch (status) {
        PaymentStatus.unpaid => const Color(0xFFEF4444),
        PaymentStatus.partial => const Color(0xFFF59E0B),
        PaymentStatus.paid => const Color(0xFF16A34A),
      };

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.payments_rounded,
                  size: 18,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
                const Text(
                  'الدفع المقدم',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    status.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              initialValue: paid > 0 ? MoneyUtils.formatInput(paid) : '',
              onChanged: (v) {
                final amount = MoneyUtils.parseAmount(v) ?? 0;
                controller.setInitialPayment(amount);
              },
              decoration: InputDecoration(
                hintText: 'المبلغ المدفوع',
                filled: true,
                fillColor: const Color(0xFFF7F8FC),
                prefixIcon: const Icon(Icons.payments_rounded, size: 20),
                suffixText: 'من ${MoneyUtils.formatMoney(total)}',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (total > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (paid / total).clamp(0.0, 1.0),
                  minHeight: 8,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  backgroundColor: const Color(0xFFE5E7EB),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: _PaymentStat(
                    label: 'المدفوع',
                    value: MoneyUtils.formatMoney(paid),
                    color: const Color(0xFF16A34A),
                  ),
                ),
                Expanded(
                  child: _PaymentStat(
                    label: 'المتبقي',
                    value: MoneyUtils.formatMoney(remaining),
                    color: remaining > 0 ? const Color(0xFFEF4444) : const Color(0xFF6B7280),
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
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
      ],
    );
  }
}

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
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                controller.invoiceFormError.value!,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

