import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/invoice_controller.dart';
import '../../controllers/feature_controller.dart';
import '../../models/business_config.dart';
import '../../models/invoice_model.dart';
import '../../models/product_model.dart';
import '../../models/party_model.dart';
import '../../models/product_unit_model.dart';
import '../../models/category_model.dart';
import '../../models/warehouse_model.dart';
import '../../models/invoice_draft.dart';
import '../../models/batch_model.dart';
import '../../models/returnable_packaging_model.dart';
import '../../core/utils/money_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/utils/packaging_quantity_format.dart';
import '../../core/utils/unit_conversion.dart';
import '../../controllers/packaging_controller.dart';
import '../shared/shared_components.dart';

// ==============================
// أدوات مساعدة للتنسيق
// ==============================

String _fmtQty(double value) {
  if (value % 1 == 0) return value.toInt().toString();
  final s = value.toStringAsFixed(2);
  return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
}

String? _packagingTypeName(int productId) {
  if (!featureEnabled(AppFeature.returnablePackaging)) return null;
  if (!Get.isRegistered<PackagingController>()) return null;
  return Get.find<PackagingController>().mappingByProductId[productId]?.typeName;
}

Future<bool> _saveInvoiceHandlingPackaging(InvoiceController controller) async {
  try {
    return await controller.saveInvoice();
  } on PackagingShortageException catch (shortage) {
    final extras = await _askPurchasedEmpties(shortage);
    if (extras == null) return false;
    try {
      return await controller.saveInvoice(purchasedEmptyByTypeId: extras);
    } on PackagingShortageException catch (again) {
      controller.invoiceFormError.value = again.message;
      return false;
    }
  }
}

Future<Map<int, double>?> _askPurchasedEmpties(
  PackagingShortageException shortage,
) async {
  final packaging = Get.isRegistered<PackagingController>()
      ? Get.find<PackagingController>()
      : null;
  final extras = <int, double>{
    for (final item in shortage.shortages) item.typeId: item.shortage,
  };
  final crateControllers = <int, TextEditingController>{};
  final bottleControllers = <int, TextEditingController>{};
  for (final item in shortage.shortages) {
    final units = packaging?.unitsByType[item.typeId] ?? [];
    final crate = PackagingQuantityFormat.aggregateUnit(units);
    var remaining = item.shortage;
    var crates = 0;
    if (crate != null && crate.conversionFactor > 0) {
      crates = remaining ~/ crate.conversionFactor;
      remaining -= crates * crate.conversionFactor;
    }
    crateControllers[item.typeId] = TextEditingController(
      text: crates > 0 ? crates.toString() : '',
    );
    bottleControllers[item.typeId] = TextEditingController(
      text: remaining > 0
          ? PackagingQuantityFormat.formatQuantity(remaining)
          : '',
    );
  }

  final confirmed = await Get.dialog<bool>(
    AlertDialog(
      title: const Text('الفوارغ لا تكفي'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'كمية الشراء تتجاوز الفوارغ المتاحة في المستودع. '
              'هل اشتريت عبوات فارغة جديدة لتُضاف إلى المخزون؟',
            ),
            const SizedBox(height: 12),
            for (final item in shortage.shortages) ...[
              Text(
                item.typeName,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                'مطلوب ${PackagingQuantityFormat.formatQuantity(item.needed)} • '
                'متاح ${PackagingQuantityFormat.formatQuantity(item.available)} • '
                'النقص ${PackagingQuantityFormat.formatQuantity(item.shortage)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: crateControllers[item.typeId],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'صناديق مشتراة'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: bottleControllers[item.typeId],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'زجاجات مشتراة'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: const Text('لم أشتر عبوات جديدة'),
        ),
        FilledButton(
          onPressed: () {
            var belowShortage = false;
            for (final item in shortage.shortages) {
              final units = packaging?.unitsByType[item.typeId] ?? [];
              final crate = PackagingQuantityFormat.aggregateUnit(units);
              final crates =
                  double.tryParse(crateControllers[item.typeId]!.text.trim()) ??
                      0;
              final bottles =
                  double.tryParse(bottleControllers[item.typeId]!.text.trim()) ??
                      0;
              final fromCrates = crate == null
                  ? 0.0
                  : UnitConversion.toBaseQuantity(crates, crate.conversionFactor);
              extras[item.typeId] = fromCrates + bottles;
              if (extras[item.typeId]! + 0.0001 < item.shortage) {
                belowShortage = true;
              }
            }
            if (belowShortage) {
              Get.snackbar(
                'تنبيه',
                'كمية العبوات المشتراة أقل من النقص',
                snackPosition: SnackPosition.BOTTOM,
              );
              return;
            }
            Get.back(result: true);
          },
          child: const Text('اشتريت عبوات جديدة'),
        ),
      ],
    ),
  );

  for (final controller in crateControllers.values) {
    controller.dispose();
  }
  for (final controller in bottleControllers.values) {
    controller.dispose();
  }
  if (confirmed != true) return null;
  return extras;
}

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

double _parseQty(String input) {
  const arabicDigits = {
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
  };
  var normalized = input.trim();
  for (final entry in arabicDigits.entries) {
    normalized = normalized.replaceAll(entry.key, entry.value);
  }
  return double.tryParse(normalized) ?? 0;
}

class InvoiceFormScreen extends GetView<InvoiceController> {
  const InvoiceFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 2),
            Text('إنشاء فاتورة مبيعات أو مشتريات'),
          ],
        ),
        actions: [
          Obx(
            () => TextButton.icon(
              onPressed: controller.isSavingInvoice.value
                  ? null
                      : () async {
                      final snackBg = context.semantic.success;
                      final snackFg = context.semantic.onSuccess;
                      final success = await _saveInvoiceHandlingPackaging(
                        controller,
                      );
                      if (success) {
                        Get.back();
                        Get.snackbar(
                          'تم',
                          'تم حفظ الفاتورة بنجاح',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: snackBg,
                          colorText: snackFg,
                        );
                      }
                    },
              icon: controller.isSavingInvoice.value
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 19),
              label: Text(
                controller.isSavingInvoice.value ? 'جارٍ الحفظ...' : 'حفظ',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
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
            children: [
              const _InvoiceTypeSelector(),
              const SizedBox(height: 16),
              const _SalesChannelSelector(),
              const _PartySelector(),
              const SizedBox(height: 16),
              if (featureEnabled(AppFeature.warehouses)) ...[
                const _WarehouseSelector(),
                const SizedBox(height: 16),
              ],
              const _DateInfoCard(),
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

// ==============================
// نوع الفاتورة
// ==============================

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
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TypeButton(
                  label: 'المبيعات',
                  icon: Icons.trending_up_rounded,
                  color: context.semantic.success,
                  selected: controller.draftType.value == InvoiceType.sale,
                  onTap: () => controller.setDraftType(InvoiceType.sale),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TypeButton(
                  label: 'المشتريات',
                  icon: Icons.shopping_cart_rounded,
                  color: context.semantic.warning,
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

class _SalesChannelSelector extends GetView<InvoiceController> {
  const _SalesChannelSelector();

  @override
  Widget build(BuildContext context) {
    final wholesale = featureEnabled(AppFeature.wholesale);
    final retail = featureEnabled(AppFeature.retail);
    if (!(wholesale && retail)) return const SizedBox.shrink();

    return Obx(() {
      if (controller.draftType.value != InvoiceType.sale) {
        return const SizedBox.shrink();
      }
      final current = controller.draftSalesChannel.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'قناة البيع',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _TypeButton(
                    label: 'جملة',
                    icon: Icons.storefront_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    selected: current == SalesMode.wholesale.key,
                    onTap: () => controller.setDraftSalesChannel(
                      SalesMode.wholesale.key,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TypeButton(
                    label: 'مفرق',
                    icon: Icons.point_of_sale_outlined,
                    color: const Color(0xFF7C3AED),
                    selected: current == SalesMode.retail.key,
                    onTap: () => controller.setDraftSalesChannel(
                      SalesMode.retail.key,
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
              Icon(icon, size: 18, color: selected
                  ? Theme.of(context).colorScheme.onPrimary
                  : color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? Theme.of(context).colorScheme.onPrimary
                      : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================
// اختيار الطرف (عميل / مورد)
// ==============================

class _PartySelector extends GetView<InvoiceController> {
  const _PartySelector();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final draftParty = controller.draftParty.value;
      final typeLabel = controller.draftType.value == InvoiceType.sale
          ? 'العميل'
          : 'المورد';

      return GestureDetector(
        onTap: () => _showPartyPicker(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    draftParty == null ? 'مطلوب' : 'محدد',
                    style: TextStyle(
                      fontSize: 10,
                      color: draftParty == null
                          ? context.semantic.error
                          : context.semantic.success,
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
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.people_alt_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: draftParty == null
                        ? Text(
                            'اختر $typeLabel',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                draftParty.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                              ),
                              if (draftParty.phone != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  draftParty.phone!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                  Icon(
                    Icons.chevron_left_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  void _showPartyPicker(BuildContext context) {
    Get.bottomSheet(
      _PartyPickerSheet(),
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'اختر الطرف',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              AppSearchField(
                hint: 'بحث...',
                onChanged: (v) => search.value = v.trim(),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Icon(
                    Icons.add,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                title: const Text('إضافة طرف جديد'),
                onTap: () {
                  Get.back();
                  _showQuickAddPartyDialog();
                },
              ),
              const Divider(),
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
              } else {
                Get.snackbar(
                  'خطأ',
                  controller.invoiceFormError.value ?? 'تعذر إضافة الطرف',
                  snackPosition: SnackPosition.BOTTOM,
                );
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
// اختيار المستودع
// ==============================

class _WarehouseSelector extends GetView<InvoiceController> {
  const _WarehouseSelector();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final warehouse = controller.selectedWarehouse;
      final warehouses = controller.availableWarehouses;

      return GestureDetector(
        onTap: warehouses.isEmpty ? null : () => _showWarehousePicker(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warehouse_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'المستودع',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'يُسحب منه المخزون',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                      color: context.semantic.successContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.inventory_rounded,
                      color: context.semantic.success,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: warehouse == null
                        ? Text(
                            warehouses.isEmpty
                                ? 'لا توجد مستودعات مفعّلة'
                                : 'اختر المستودع',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: warehouses.isEmpty
                                  ? context.semantic.error
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                warehouse.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                warehouse.type.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                  ),
                  Icon(
                    Icons.chevron_left_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  void _showWarehousePicker(BuildContext context) {
    Get.bottomSheet(
      _WarehousePickerSheet(),
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }
}

class _WarehousePickerSheet extends GetView<InvoiceController> {
  const _WarehousePickerSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      minChildSize: 0.35,
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
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'اختر المستودع',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'سيتم خصم الكميات من المخزون الموجود في هذا المستودع',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Obx(() {
                  final list = controller.availableWarehouses;

                  if (list.isEmpty) {
                    return const Center(
                      child: Text('لا توجد مستودعات — أضف مستودعاً أولاً'),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final warehouse = list[index];
                      final isSelected =
                          warehouse.id == controller.draftWarehouseId.value;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: context.semantic.success.withValues(
                            alpha: 0.12,
                          ),
                          child: Icon(
                            _warehouseIcon(warehouse.type),
                            color: context.semantic.success,
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                warehouse.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (warehouse.isDefault) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'افتراضي',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(warehouse.type.label),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: context.semantic.success,
                              )
                            : null,
                        onTap: () {
                          controller.setDraftWarehouse(warehouse.id);
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
}

/// أيقونة نوع المستودع للعرض فقط
IconData _warehouseIcon(WarehouseType type) => switch (type) {
  WarehouseType.main => Icons.warehouse_outlined,
  WarehouseType.van => Icons.local_shipping_outlined,
  WarehouseType.branch => Icons.store_outlined,
};

// ==============================
// تاريخ الفاتورة (يوم الإنشاء)
// ==============================

class _DateInfoCard extends StatelessWidget {
  const _DateInfoCard();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final label =
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'التاريخ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================
// المنتجات: بطاقات الأسطر + زر الإضافة
// ==============================

class _ItemsSection extends GetView<InvoiceController> {
  const _ItemsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.inventory_2_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'المنتجات',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _openProductPicker(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'إضافة منتج',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
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
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 38,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'لم يتم إضافة منتجات بعد',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: controller.draftItems
                .asMap()
                .entries
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ItemCard(index: entry.key, item: entry.value),
                  ),
                )
                .toList(),
          );
        }),
      ],
    );
  }

  void _openProductPicker() {
    Get.bottomSheet(
      _ProductPickerSheet(),
      isScrollControlled: true,
      backgroundColor: Theme.of(Get.context!).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }
}

// ==============================
// بطاقة سطر فاتورة في النموذج
// ==============================

class _ItemCard extends GetView<InvoiceController> {
  final int index;
  final InvoiceItemDraft item;

  const _ItemCard({required this.index, required this.item});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSale = controller.draftType.value == InvoiceType.sale;
      final typeName = _packagingTypeName(item.productId);

      return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productNameSnapshot,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (typeName != null) ...[
                      const SizedBox(height: 4),
                      PackagingEmptyBadge(typeName: typeName),
                      if (!isSale)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'سيتم تعبئة فوارغ من مستودع الفاتورة',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.semantic.info,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'حذف السطر',
                onPressed: () => controller.removeDraftItem(index),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: context.semantic.error,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _ItemField(
                label: 'الوحدة',
                value: item.unitNameSnapshot ?? 'الوحدة الأساسية',
              ),
              const SizedBox(width: 12),
              _ItemField(label: 'الكمية', value: _fmtQty(item.quantity)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'سعر الوحدة: ${MoneyUtils.formatMoney(item.unitPrice)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                MoneyUtils.formatMoney(item.lineTotal),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          if (item.conversionFactorSnapshot != 1) ...[
            const SizedBox(height: 6),
            Text(
              'يعادل ${_fmtQty(item.baseQuantity)} وحدة أساسية',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (featureEnabled(AppFeature.batches))
            _ItemBatchSummary(item: item, isSale: isSale),
          if (featureEnabled(AppFeature.batches)) const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openEditor(),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.4),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(
                'تعديل',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    });
  }

  void _openEditor() {
    if (item.productId <= 0) return;
    Get.bottomSheet(
      _ItemConfigSheet(
        product: ProductModel(
          id: item.productId,
          name: item.productNameSnapshot,
          description: '',
          costPrice: 0,
          salePrice: 0,
        ),
        editIndex: index,
      ),
      isScrollControlled: true,
      backgroundColor: Theme.of(Get.context!).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }
}

class _ItemField extends StatelessWidget {
  final String label;
  final String value;

  const _ItemField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// ملخص الدفعات داخل بطاقة السطر:
/// بيع: دفعات محددة يدوياً، أو شارة "تلقائي FEFO" إن ترك التوزيع للنظام
/// شراء: معلومات الدفعة الجديدة إن وُجدت
class _ItemBatchSummary extends StatelessWidget {
  final InvoiceItemDraft item;
  final bool isSale;

  const _ItemBatchSummary({required this.item, required this.isSale});

  @override
  Widget build(BuildContext context) {
    if (!isSale) {
      if (!item.hasNewBatchInfo) return const SizedBox.shrink();
      return _wrap(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'دفعة جديدة:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: context.semantic.onWarningContainer,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${item.newBatchNumber}'
              '${featureEnabled(AppFeature.expiry) && item.newExpiryDate != null ? ' · انتهاء ${_fmtDate(item.newExpiryDate)}' : ''}',
              style: TextStyle(
                fontSize: 11,
                color: context.semantic.onWarningContainer,
              ),
            ),
          ],
        ),
        context.semantic.warningContainer,
        context.semantic.warningContainer,
      );
    }

    if (item.batchAllocations.isEmpty) {
      return _wrap(
        Row(
          children: [
            Icon(
              Icons.auto_mode_rounded,
              size: 14,
              color: context.semantic.success,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'التخصيص تلقائي — FEFO (الأقرب انتهاءً أولاً)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.semantic.success,
                ),
              ),
            ),
          ],
        ),
        context.semantic.successContainer,
        context.semantic.successContainer,
      );
    }

    return _wrap(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الدفعات:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: context.semantic.onSuccessContainer,
            ),
          ),
          const SizedBox(height: 4),
          ...item.batchAllocations.map(
            (allocation) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '${allocation.batchNumber} — '
                '${_fmtQty(allocation.quantity)}'
                '${featureEnabled(AppFeature.expiry) && allocation.expiryDate != null ? ' — انتهاء ${_fmtDate(allocation.expiryDate)}' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  color: context.semantic.onSuccessContainer,
                ),
              ),
            ),
          ),
        ],
      ),
      context.semantic.successContainer,
      context.semantic.successContainer,
    );
  }

  Widget _wrap(Widget child, Color background, Color border) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}

// ==============================
// قائمة اختيار المنتج
// ==============================

class _ProductPickerSheet extends GetView<InvoiceController> {
  final RxString search = ''.obs;

  _ProductPickerSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
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
                  color: Theme.of(context).colorScheme.outlineVariant,
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
                  hintText: 'بحث بالاسم...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Icon(
                    Icons.add,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
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
                            ? context.semantic.success
                            : context.semantic.warning;
                        final priceLabel = isSale ? 'سعر البيع' : 'سعر التكلفة';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: context.semantic.infoContainer,
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                          ),
                          title: Text(product.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ProductStockLine(productId: product.id),
                              if (product.id != null &&
                                  _packagingTypeName(product.id!) != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: PackagingEmptyBadge(
                                    typeName: _packagingTypeName(product.id!),
                                  ),
                                ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                MoneyUtils.formatMoney(price),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: priceColor,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                priceLabel,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _selectProduct(product),
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

  void _selectProduct(ProductModel product) {
    if (product.id == null) {
      Get.snackbar(
        'تنبيه',
        'لا يمكن اختيار منتج بدون رقم تعريف',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    Get.back();
    Get.bottomSheet(
      _ItemConfigSheet(product: product),
      isScrollControlled: true,
      backgroundColor: Theme.of(Get.context!).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }

  void _showQuickAddProductDialog() {
    Get.dialog(const _QuickAddProductDialog());
  }
}

// ==============================
// نافذة الإضافة السريعة لمنتج جديد
// ==============================

class _QuickAddProductDialog extends StatefulWidget {
  const _QuickAddProductDialog();

  @override
  State<_QuickAddProductDialog> createState() =>
      _QuickAddProductDialogState();
}

class _QuickAddProductDialogState extends State<_QuickAddProductDialog> {
  final nameCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();
  final unitCtrl = TextEditingController(text: 'قطعة');
  final costCtrl = TextEditingController();
  final saleCtrl = TextEditingController();

  int? _selectedCategoryId;

  @override
  void dispose() {
    nameCtrl.dispose();
    descriptionCtrl.dispose();
    unitCtrl.dispose();
    costCtrl.dispose();
    saleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.92,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const SizedBox(height: AppSpacing.md),
              _buildBasicCard(context),
              const SizedBox(height: AppSpacing.md),
              _buildUnitCard(context),
              const SizedBox(height: AppSpacing.md),
              _buildPricingCard(context),
              const SizedBox(height: AppSpacing.lg),
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: .08),
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Icon(
              Icons.add_box_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إضافة منتج جديد',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'بيانات المنتج الأساسية',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
              context,
              icon: Icons.inventory_2_outlined,
              title: 'البيانات الأساسية',
            ),
            const SizedBox(height: AppSpacing.md),
            _QuickAddField(
              controller: nameCtrl,
              label: 'اسم المنتج',
              hint: 'مثال: مياه معدنية',
              icon: Icons.inventory_2_outlined,
              required: true,
            ),
            const SizedBox(height: AppSpacing.md),
            _QuickAddField(
              controller: descriptionCtrl,
              label: 'الوصف',
              hint: 'وصف اختياري للمنتج',
              icon: Icons.description_outlined,
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildCategoryDropdown(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown(BuildContext context) {
    final categories = Get.find<InvoiceController>().categories;
    return Obx(
      () => DropdownButtonFormField<int?>(
        initialValue: _selectedCategoryId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'التصنيف',
          prefixIcon: Icon(
            Icons.category_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
        ),
        items: [
          const DropdownMenuItem<int?>(
            value: null,
            child: Text('بدون تصنيف'),
          ),
          ...categories
              .where((c) => c.isActive)
              .map(
                (CategoryModel c) => DropdownMenuItem<int?>(
                  value: c.id,
                  child: Text(c.name),
                ),
              ),
        ],
        onChanged: (value) {
          setState(() => _selectedCategoryId = value);
        },
      ),
    );
  }

  Widget _buildUnitCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
              context,
              icon: Icons.straighten_outlined,
              title: 'الوحدة الأساسية',
            ),
            const SizedBox(height: AppSpacing.md),
            _QuickAddField(
              controller: unitCtrl,
              label: 'اسم الوحدة',
              hint: 'قطعة',
              icon: Icons.straighten_outlined,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'الوحدة الأساسية تُستخدم لحساب المخزون · معامل التحويل = 1\n'
              'يمكنك إضافة وحدات توزيع أخرى بعد حفظ المنتج.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
              context,
              icon: Icons.price_change_outlined,
              title: 'الأسعار',
            ),
            const SizedBox(height: AppSpacing.md),
            _QuickAddField(
              controller: costCtrl,
              label: 'التكلفة',
              hint: '0.00',
              icon: Icons.price_change_outlined,
              required: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _QuickAddField(
              controller: saleCtrl,
              label: 'سعر البيع',
              hint: '0.00',
              icon: Icons.sell_outlined,
              required: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, {required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Text(title, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: Get.back,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
              ),
              child: const Text('إلغاء'),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('إضافة المنتج'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final controller = Get.find<InvoiceController>();
    final sheetSurface = Theme.of(context).colorScheme.surface;

    final name = nameCtrl.text.trim();
    final description = descriptionCtrl.text.trim();
    final unitName = unitCtrl.text.trim();

    if (name.isEmpty) {
      Get.snackbar('تنبيه', 'يرجى إدخال اسم المنتج');
      return;
    }
    if (unitName.isEmpty) {
      Get.snackbar('تنبيه', 'يرجى إدخال اسم الوحدة الأساسية');
      return;
    }

    final costPrice = MoneyUtils.parseAmount(costCtrl.text);
    final salePrice = MoneyUtils.parseAmount(saleCtrl.text);

    if (costPrice == null) {
      Get.snackbar('تنبيه', 'سعر التكلفة غير صحيح');
      return;
    }
    if (salePrice == null) {
      Get.snackbar('تنبيه', 'سعر البيع غير صحيح');
      return;
    }

    Get.dialog(
      const Center(child: CircularProgressIndicator()),
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
        unitName: unitName,
        categoryId: _selectedCategoryId,
      );

      if (Get.isDialogOpen == true) {
        Get.back();
      }

      if (product == null) {
        Get.snackbar(
          'فشل الإضافة',
          controller.invoiceFormError.value ?? 'تعذر إضافة المنتج',
        );
        return;
      }

      Get.back();
      if (product.id != null) {
        Get.bottomSheet(
          _ItemConfigSheet(product: product),
          isScrollControlled: true,
          backgroundColor: sheetSurface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
        );
      }
    } catch (e) {
      if (Get.isDialogOpen == true) {
        Get.back();
      }
      Get.snackbar(
        'خطأ',
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

/// سطر مخزون صغير يظهر تحت اسم المنتج في القائمة (يُجلب بدون حظر القائمة)
class _ProductStockLine extends StatefulWidget {
  final int? productId;

  const _ProductStockLine({required this.productId});

  @override
  State<_ProductStockLine> createState() => _ProductStockLineState();
}

class _ProductStockLineState extends State<_ProductStockLine> {
  Future<double>? _future;

  @override
  void initState() {
    super.initState();
    final id = widget.productId;
    if (id != null) {
      _future = Get.find<InvoiceController>().getAvailableQuantity(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_future == null) return const SizedBox.shrink();
    return FutureBuilder<double>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Text('...', style: TextStyle(fontSize: 11));
        }
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }
        final available = snapshot.data ?? 0;
        final color = available > 0
            ? context.semantic.success
            : context.semantic.error;
        return Text(
          'المتوفر: ${_fmtQty(available)} (بالوحدة الأساسية)',
          style: TextStyle(fontSize: 11, color: color),
        );
      },
    );
  }
}

// ==============================
// نافذة تهيئة سطر الفاتورة
// (الوحدة + الكمية + السعر + الدفعات)
// ==============================

class _ItemConfigSheet extends StatefulWidget {
  final ProductModel product;

  /// عند التعديل: رقم السطر في draftItems، وإلا فهو إضافة جديدة
  final int? editIndex;

  const _ItemConfigSheet({required this.product, this.editIndex});

  @override
  State<_ItemConfigSheet> createState() => _ItemConfigSheetState();
}

class _ItemConfigSheetState extends State<_ItemConfigSheet> {
  InvoiceController get controller => Get.find<InvoiceController>();

  bool get isSale => controller.draftType.value == InvoiceType.sale;

  bool get isEditMode => widget.editIndex != null;

  final qtyCtrl = TextEditingController(text: '1');
  final priceCtrl = TextEditingController();
  final batchNumberCtrl = TextEditingController();

  DateTime? productionDate;
  DateTime? expiryDate;

  List<ProductUnitModel> units = [];
  ProductUnitModel? selectedUnit;
  bool isLoadingUnits = true;
  String? errorMessage;

  // حالة توزيع الدفعات (بيع)
  bool manualAllocation = false;
  List<BatchStock> batches = [];
  bool isLoadingBatches = false;
  final allocCtrls = <int, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _prefillFromDraft();
    _loadUnits();
    // اقتراح رقم دفعة تلقائياً لفواتير الشراء فقط، وفقط إذا لم يوجد
    // رقم محفوظ مسبقاً (لا نستبدل رقماً أدخله/عدّله المستخدم عند التعديل).
    if (!isSale && batchNumberCtrl.text.trim().isEmpty) {
      _suggestBatchNumber();
    }
  }

  Future<void> _suggestBatchNumber() async {
    try {
      final suggested = await controller.suggestNextBatchNumber();
      if (!mounted) return;
      // نتحقق مجدداً أن المستخدم لم يبدأ الكتابة أثناء انتظار التوليد.
      if (batchNumberCtrl.text.trim().isEmpty) {
        setState(() => batchNumberCtrl.text = suggested);
      }
    } catch (_) {
      // فشل التوليد لا يمنع المستخدم من إدخال رقم يدوياً — الحقل يبقى فارغاً.
    }
  }

  @override
  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
    batchNumberCtrl.dispose();
    for (final ctrl in allocCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _prefillFromDraft() {
    if (!isEditMode) return;
    final existing = controller.draftItems[widget.editIndex!];
    qtyCtrl.text = _fmtQty(existing.quantity);
    priceCtrl.text = MoneyUtils.formatInput(existing.unitPrice);
    if (existing.newBatchNumber != null) {
      batchNumberCtrl.text = existing.newBatchNumber!;
    }
    productionDate = existing.newProductionDate != null
        ? DateTime.tryParse(existing.newProductionDate!)
        : null;
    expiryDate = existing.newExpiryDate != null
        ? DateTime.tryParse(existing.newExpiryDate!)
        : null;
    if (isSale && existing.batchAllocations.isNotEmpty) {
      manualAllocation = true;
    }
  }

  Future<void> _loadUnits() async {
    try {
      final productId = widget.product.id;
      if (productId == null) throw Exception('معرّف المنتج غير صالح');

      var list = await controller.getUnitsForProduct(productId);
      if (!featureEnabled(AppFeature.productUnits)) {
        final baseUnits = list.where((unit) => unit.isBaseUnit).toList();
        list = baseUnits.isNotEmpty
            ? baseUnits
            : list.where((unit) => unit.conversionFactor == 1).toList();
        if (list.isEmpty) {
          list = await controller.getUnitsForProduct(productId);
        }
      }

      ProductUnitModel? unit;
      if (isEditMode) {
        final existing = controller.draftItems[widget.editIndex!];
        if (existing.unitId != null) {
          for (final candidate in list) {
            if (candidate.id == existing.unitId) {
              unit = candidate;
              break;
            }
          }
        }
      }
      if (unit == null && list.isNotEmpty) {
        for (final candidate in list) {
          if (candidate.isDefaultSellUnit) {
            unit = candidate;
            break;
          }
        }
        unit ??= list.first;
      }

      setState(() {
        units = list;
        selectedUnit = unit;
        isLoadingUnits = false;
      });

      if (priceCtrl.text.isEmpty || !isEditMode) {
        _applyUnitDefaultPrice();
      }

      if (isSale) await _loadBatches();
    } catch (e) {
      setState(() {
        isLoadingUnits = false;
        errorMessage =
            'فشل تحميل وحدات المنتج: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  /// سعر الوحدة الافتراضي حسب نوع الفاتورة
  void _applyUnitDefaultPrice() {
    final unit = selectedUnit;
    if (unit == null) return;
    final price = isSale ? unit.defaultSalePrice : (unit.costPrice ?? 0);
    setState(() {
      priceCtrl.text = MoneyUtils.formatInput(price);
    });
  }

  Future<void> _loadBatches() async {
    final productId = widget.product.id;
    if (productId == null) return;
    setState(() => isLoadingBatches = true);
    try {
      final list = await controller.getAvailableBatches(productId);
      if (!mounted) return;
      setState(() {
        batches = list;
        isLoadingBatches = false;
      });
      if (manualAllocation) _syncAllocControllers();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingBatches = false;
        errorMessage =
            'فشل تحميل دفعات المنتج: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  void _syncAllocControllers() {
    if (!isEditMode) return;
    final existing = controller.draftItems[widget.editIndex!];
    for (final allocation in existing.batchAllocations) {
      allocCtrls[allocation.batchId]?.text = _fmtQty(allocation.quantity);
    }
  }

  double get requestedBaseQty {
    final qty = _parseQty(qtyCtrl.text);
    final factor = selectedUnit?.conversionFactor ?? 1;
    return qty * factor;
  }

  double get allocatedBaseQty {
    var sum = 0.0;
    for (final stock in batches) {
      final ctrl = allocCtrls[stock.batch.id];
      if (ctrl == null) continue;
      sum += _parseQty(ctrl.text);
    }
    return sum;
  }

  bool get allocationsConsistent =>
      (allocatedBaseQty - requestedBaseQty).abs() < 0.0001;

  double get availableTotalSum =>
      batches.fold(0, (sum, stock) => sum + stock.available);

  int get effectivePrice => MoneyUtils.parseAmount(priceCtrl.text) ?? -1;

  int get computedTotal {
    final qty = _parseQty(qtyCtrl.text);
    final price = effectivePrice;
    if (price < 0) return 0;
    return (qty * price).round();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.82,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    if (errorMessage != null) ...[
                      _errorBox(errorMessage!),
                      const SizedBox(height: 12),
                    ],
                    _buildUnitSection(),
                    const SizedBox(height: 14),
                    _buildQuantityAndPrice(),
                    const SizedBox(height: 14),
                    if (isLoadingUnits)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (units.isEmpty && errorMessage == null)
                      _errorBox(
                        'لا توجد وحدات معرّفة لهذا المنتج — عدّل المنتج وأضف وحدات أولاً',
                      )
                    else if (featureEnabled(AppFeature.batches) && isSale)
                      _buildSaleAllocation()
                    else if (featureEnabled(AppFeature.batches) && !isSale)
                      _buildPurchaseBatchFields(),
                    const SizedBox(height: 18),
                    _buildConfirmButton(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.inventory_2_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.product.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                isSale ? 'سطر فاتورة بيع' : 'سطر فاتورة شراء',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: Get.back,
          icon: Icon(
            Icons.close_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildUnitSection() {
    final unit = selectedUnit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الوحدة',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: !featureEnabled(AppFeature.productUnits) || units.isEmpty
              ? null
              : _showUnitPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    unit?.unitName ?? 'اختر الوحدة',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  unit == null
                      ? ''
                      : '×${_fmtQty(unit.conversionFactor)} · '
                            '${MoneyUtils.formatMoney(isSale ? unit.defaultSalePrice : (unit.costPrice ?? 0))}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.expand_more_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showUnitPicker() {
    Get.bottomSheet(
      _UnitPickerSheet(
        units: units,
        selectedId: selectedUnit?.id,
        isSale: isSale,
        onSelect: (unit) {
          setState(() => selectedUnit = unit);
          _applyUnitDefaultPrice();
        },
      ),
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }

  Widget _buildQuantityAndPrice() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الكمية',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    _stepButton(
                      icon: Icons.remove_rounded,
                      onTap: () => _stepQuantity(-1),
                    ),
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    _stepButton(
                      icon: Icons.add_rounded,
                      onTap: () => _stepQuantity(1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSale ? 'سعر البيع للوحدة' : 'سعر الشراء للوحدة',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainer,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  void _stepQuantity(int delta) {
    final current = _parseQty(qtyCtrl.text);
    final next = current + delta;
    setState(() {
      qtyCtrl.text = next <= 0 ? '0' : _fmtQty(next);
    });
  }

  // ── البيع: توزيع الدفعات ──

  Widget _buildSaleAllocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'تخصيص الدفعات',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            Switch(
              value: manualAllocation,
              activeThumbColor: Theme.of(context).colorScheme.primary,
              onChanged: (value) {
                setState(() => manualAllocation = value);
                if (value) _syncAllocControllers();
              },
            ),
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: manualAllocation
                ? context.semantic.warningContainer
                : context.semantic.successContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: manualAllocation
                  ? context.semantic.warningContainer
                  : context.semantic.successContainer,
            ),
          ),
          child: Row(
            children: [
              Icon(
                manualAllocation
                    ? Icons.edit_note_rounded
                    : Icons.auto_mode_rounded,
                size: 16,
                color: manualAllocation
                    ? context.semantic.onWarningContainer
                    : context.semantic.success,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  manualAllocation
                      ? 'يدوي — اختر الدفعات التي ستسحب منها'
                      : 'تلقائي — FEFO: تُسحب الكمية من الدفعات الأقرب انتهاءً أولاً',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: manualAllocation
                        ? context.semantic.onWarningContainer
                        : context.semantic.onSuccessContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (manualAllocation) ...[
          const SizedBox(height: 12),
          if (isLoadingBatches)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (batches.isEmpty)
            _errorBox('لا توجد دفعات متوفرة لهذا المنتج في المستودع المختار')
          else ...[
            ...batches.map(_buildBatchRow),
            const SizedBox(height: 8),
            _allocationFooter(),
          ],
        ] else if (!isLoadingBatches &&
            batches.isNotEmpty &&
            availableTotalSum < requestedBaseQty) ...[
          const SizedBox(height: 8),
          _errorBox(
            'الكمية المطلوبة (${_fmtQty(requestedBaseQty)}) أكبر من المتوفر '
            'في المستودع (${_fmtQty(availableTotalSum)})',
          ),
        ],
      ],
    );
  }

  Widget _buildBatchRow(BatchStock stock) {
    final batch = stock.batch;
    final ctrl = allocCtrls.putIfAbsent(
      batch.id!,
      () => TextEditingController(),
    );
    final statusColor = batch.isExpired
        ? context.semantic.error
        : batch.isExpiringSoon
        ? context.semantic.warning
        : context.semantic.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  batch.batchNumber ?? 'بدون رقم',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  batch.expiryStatus,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'الصلاحية: ${_fmtDate(batch.expiryDate)} · المتاح: ${_fmtQty(stock.available)}',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'الكمية المسحوبة:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '0',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _allocationFooter() {
    final consistent = allocationsConsistent;
    final overAvailable = allocatedBaseQty > availableTotalSum + 0.0001;

    String? warning;
    if (overAvailable) {
      warning = 'المجموع المخصص يتجاوز الكمية المتوفرة فعلياً';
    } else if (!consistent) {
      warning =
          'المخصص (${_fmtQty(allocatedBaseQty)}) لا يطابق المطلوب '
          '(${_fmtQty(requestedBaseQty)})';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: warning == null
            ? context.semantic.successContainer
            : context.semantic.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: warning == null
              ? context.semantic.successContainer
              : context.semantic.errorContainer,
        ),
      ),
      child: Row(
        children: [
          Icon(
            warning == null
                ? Icons.check_circle_rounded
                : Icons.warning_rounded,
            size: 16,
            color: warning == null
                ? context.semantic.success
                : context.semantic.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              warning ??
                  'تم تخصيص ${_fmtQty(allocatedBaseQty)} من '
                      '${_fmtQty(requestedBaseQty)} بالكامل',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: warning == null
                    ? context.semantic.onSuccessContainer
                    : context.semantic.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── الشراء: معلومات دفعة جديدة ──

  Future<void> _pickDate({required bool isProduction}) async {
    final initial = isProduction
        ? (productionDate ?? DateTime.now())
        : (expiryDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isProduction) {
        productionDate = picked;
      } else {
        expiryDate = picked;
      }
    });
  }

  Widget _buildPurchaseBatchFields() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.semantic.warningContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.semantic.warningContainer),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.label_outline_rounded,
                size: 16,
                color: context.semantic.onWarningContainer,
              ),
              const SizedBox(width: 6),
              Text(
                'معلومات الدفعة (اختياري)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: context.semantic.onWarningContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'يُقترح رقم الدفعة تلقائياً، ويمكنك تعديله أو مسحه',
            style: TextStyle(
              fontSize: 10,
              color: context.semantic.onWarningContainer,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: batchNumberCtrl,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'رقم الدفعة',
              hintText: 'مثال: B-2026-081',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _dateField(
                  label: 'تاريخ الإنتاج',
                  value: productionDate,
                  onTap: () => _pickDate(isProduction: true),
                ),
              ),
              if (featureEnabled(AppFeature.expiry)) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _dateField(
                    label: 'تاريخ الانتهاء',
                    value: expiryDate,
                    onTap: () => _pickDate(isProduction: false),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value == null
                        ? 'اختر...'
                        : _fmtDate(value.toIso8601String()),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: value == null
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_month_rounded,
                  size: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── التأكيد ──

  Widget _buildConfirmButton() {
    final qty = _parseQty(qtyCtrl.text);
    final price = effectivePrice;

    String? blockingReason;
    if (isLoadingUnits) {
      blockingReason = null; // الزر معطل أثناء التحميل فقط
    } else if (units.isEmpty) {
      blockingReason = 'لا توجد وحدات متاحة لهذا المنتج';
    } else if (qty <= 0) {
      blockingReason = 'الكمية يجب أن تكون أكبر من صفر';
    } else if (price < 0) {
      blockingReason = 'السعر غير صحيح';
    } else if (isSale &&
        manualAllocation &&
        batches.isNotEmpty &&
        !allocationsConsistent) {
      blockingReason = 'توزيع الدفعات لا يطابق الكمية المطلوبة';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(
                'الإجمالي',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                MoneyUtils.formatMoney(computedTotal),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (blockingReason != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              blockingReason,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.semantic.error,
              ),
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: isLoadingUnits || blockingReason != null
                ? null
                : _confirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              disabledBackgroundColor: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: Icon(
              isEditMode ? Icons.check_rounded : Icons.add_rounded,
              size: 18,
            ),
            label: Text(
              isEditMode ? 'حفظ التعديلات' : 'إضافة إلى الفاتورة',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  void _confirm() {
    final qty = _parseQty(qtyCtrl.text);
    final price = effectivePrice;
    final unit = selectedUnit;

    if (unit == null || qty <= 0 || price < 0) return;

    List<BatchAllocationSnapshot>? allocations;
    if (isSale && manualAllocation) {
      final result = <BatchAllocationSnapshot>[];
      for (final stock in batches) {
        final ctrl = allocCtrls[stock.batch.id];
        if (ctrl == null) continue;
        final amount = _parseQty(ctrl.text);
        if (amount <= 0) continue;
        if (amount > stock.available + 0.0001) {
          setState(() {
            errorMessage =
                'الكمية المسحوبة من الدفعة "${stock.batch.batchNumber ?? 'بدون رقم'}" '
                'تتجاوز المتاح (${_fmtQty(stock.available)})';
          });
          return;
        }
        result.add(
          BatchAllocationSnapshot(
            batchId: stock.batch.id!,
            quantity: amount,
            batchNumber: stock.batch.batchNumber ?? 'بدون رقم',
            expiryDate: stock.batch.expiryDate,
          ),
        );
      }
      allocations = result;
    }

    if (isEditMode) {
      controller.updateDraftItem(
        widget.editIndex!,
        quantity: qty,
        unitPrice: price,
        unitId: unit.id,
        unitNameSnapshot: unit.unitName,
        conversionFactorSnapshot: unit.conversionFactor,
        batchAllocations: allocations ?? const [],
        newBatchNumber: batchNumberCtrl.text.trim().isEmpty
            ? null
            : batchNumberCtrl.text.trim(),
        newProductionDate: productionDate?.toIso8601String().split('T').first,
        newExpiryDate: expiryDate?.toIso8601String().split('T').first,
        clearBatchInfo: batchNumberCtrl.text.trim().isEmpty,
      );
    } else {
      controller.addDraftItem(
        product: widget.product,
        quantity: qty,
        unitPrice: price,
        unitId: unit.id,
        unitName: unit.unitName,
        conversionFactor: unit.conversionFactor,
        batchAllocations: allocations ?? const [],
        newBatchNumber: batchNumberCtrl.text.trim().isEmpty
            ? null
            : batchNumberCtrl.text.trim(),
        newProductionDate: productionDate?.toIso8601String().split('T').first,
        newExpiryDate: expiryDate?.toIso8601String().split('T').first,
      );
    }

    Get.back();
  }

  Widget _errorBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.semantic.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.semantic.errorContainer),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: context.semantic.error,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.semantic.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================
// قائمة اختيار الوحدة
// ==============================

class _UnitPickerSheet extends StatelessWidget {
  final List<ProductUnitModel> units;
  final int? selectedId;
  final bool isSale;
  final ValueChanged<ProductUnitModel> onSelect;

  const _UnitPickerSheet({
    required this.units,
    required this.selectedId,
    required this.isSale,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'اختر الوحدة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: units.length,
                itemBuilder: (context, index) {
                  final unit = units[index];
                  final isSelected = unit.id == selectedId;
                  final price = isSale
                      ? unit.defaultSalePrice
                      : (unit.costPrice ?? 0);

                  return ListTile(
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      unit.unitName,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w900
                            : FontWeight.w600,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      'معامل التحويل: ${_fmtQty(unit.conversionFactor)}'
                      '${unit.isBaseUnit ? ' (الوحدة الأساسية)' : ''}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Text(
                      MoneyUtils.formatMoney(price),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: isSale
                            ? context.semantic.success
                            : context.semantic.warning,
                      ),
                    ),
                    onTap: () {
                      onSelect(unit);
                      Get.back();
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ==============================
// ملخص الفاتورة
// ==============================

class _TotalSection extends GetView<InvoiceController> {
  const _TotalSection();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.draftDiscountAmount.value > 0
                            ? 'صافي الفاتورة'
                            : 'إجمالي الفاتورة',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        MoneyUtils.formatMoney(controller.draftNetTotal),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${controller.draftItems.length} منتج',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'الكمية: ${_fmtQty(controller.draftTotalBaseQuantity)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================
// الدفع
// ==============================

class _PaymentSection extends GetView<InvoiceController> {
  const _PaymentSection();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final subtotal = controller.draftTotal;
      final discount = controller.draftDiscountAmount.value;
      final total = controller.draftNetTotal;
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
        PaymentStatus.unpaid => Theme.of(context).colorScheme.error,
        PaymentStatus.partial => context.semantic.warning,
        PaymentStatus.paid => context.semantic.success,
      };

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.payments_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text('الدفع', style: Theme.of(context).textTheme.titleSmall),
                if (featureEnabled(AppFeature.debts)) ...[
                  const Spacer(),
                  AppStatusBadge(label: status.label, color: statusColor),
                ],
              ],
            ),
            const SizedBox(height: 12),
            _PaymentStat(
              label: 'الإجمالي قبل الحسم',
              value: MoneyUtils.formatMoney(subtotal),
              color: Theme.of(context).colorScheme.onSurface,
            ),
            if (discount > 0) ...[
              const SizedBox(height: 8),
              _PaymentStat(
                label: 'الحسم',
                value: '- ${MoneyUtils.formatMoney(discount)}',
                color: Theme.of(context).colorScheme.error,
              ),
            ],
            const SizedBox(height: 8),
            _PaymentStat(
              label: 'الصافي',
              value: MoneyUtils.formatMoney(total),
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            TextFormField(
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              initialValue:
                  discount > 0 ? MoneyUtils.formatInput(discount) : '',
              onChanged: (v) {
                final amount = MoneyUtils.parseAmount(v) ?? 0;
                controller.setDiscountAmount(amount);
              },
              decoration: InputDecoration(
                hintText: 'الحسم (قيمة مالية)',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainer,
                prefixIcon: const Icon(Icons.discount_outlined, size: 20),
                suffixText: 'من ${MoneyUtils.formatMoney(subtotal)}',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                errorText: discount > subtotal ? 'الحسم أكبر من الإجمالي' : null,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              initialValue: paid > 0 ? MoneyUtils.formatInput(paid) : '',
              onChanged: (v) {
                final amount = MoneyUtils.parseAmount(v) ?? 0;
                controller.setInitialPayment(amount.clamp(0, total));
              },
              decoration: InputDecoration(
                hintText: 'المبلغ المدفوع الآن',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainer,
                prefixIcon: const Icon(Icons.payments_rounded, size: 20),
                suffixText: 'من ${MoneyUtils.formatMoney(total)}',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (featureEnabled(AppFeature.debts) && total > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (paid / total).clamp(0.0, 1.0),
                  minHeight: 8,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  backgroundColor: Theme.of(context).colorScheme.outlineVariant,
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
                    color: context.semantic.success,
                  ),
                ),
                if (featureEnabled(AppFeature.debts))
                  Expanded(
                    child: _PaymentStat(
                      label: 'المتبقي',
                      value: MoneyUtils.formatMoney(remaining),
                      color: remaining > 0
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurfaceVariant,
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

// ==============================
// حقل إدخال مخصص لإضافة المنتج السريعة
// ==============================

class _QuickAddField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;

  const _QuickAddField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textDirection: TextDirection.rtl,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: maxLines > 1 ? AppSpacing.lg : AppSpacing.md,
        ),
      ),
    );
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
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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

// ==============================
// الملاحظات
// ==============================

class _NotesField extends GetView<InvoiceController> {
  const _NotesField();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sticky_note_2_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'ملاحظات',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
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
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
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

// ==============================
// رسالة خطأ النموذج
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
          color: context.semantic.errorContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.semantic.errorContainer),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: context.semantic.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                controller.invoiceFormError.value!,
                style: TextStyle(
                  color: context.semantic.error,
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