import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/packaging_controller.dart';
import '../../core/services/app_event_bus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/utils/money_utils.dart';
import '../../core/utils/packaging_quantity_format.dart';
import '../../core/utils/unit_conversion.dart';
import '../../models/party_model.dart';
import '../../models/returnable_packaging_model.dart';
import '../../models/warehouse_model.dart';
import '../shared/app_ui.dart';
import '../shared/shared_components.dart';

class PackagingHubScreen extends StatelessWidget {
  const PackagingHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PackagingController>();
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('العبوات القابلة للإرجاع'),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'رصيد افتتاحي',
              icon: const Icon(Icons.post_add_outlined),
              onPressed: () => Get.to(() => const PackagingOpeningScreen()),
            ),
            IconButton(
              tooltip: 'تسوية',
              icon: const Icon(Icons.assignment_turned_in_outlined),
              onPressed: () => Get.to(() => const PackagingSettlementScreen()),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: controller.loadAll,
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.inventory_2_outlined), text: 'الأنواع'),
              Tab(icon: Icon(Icons.warehouse_outlined), text: 'المخزون'),
              Tab(icon: Icon(Icons.history), text: 'الحركات'),
              Tab(icon: Icon(Icons.bar_chart_outlined), text: 'تقرير'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Get.to(() => const PackagingTypeFormScreen()),
          icon: const Icon(Icons.add),
          label: const Text('نوع عبوة'),
        ),
        body: Obx(() {
          if (controller.isLoading.value && controller.types.isEmpty) {
            return const AppLoadingState();
          }
          return TabBarView(
            children: [
              _TypesTab(controller: controller),
              _EmptyStockTab(controller: controller),
              _TransactionsTab(controller: controller),
              _ReportTab(controller: controller),
            ],
          );
        }),
      ),
    );
  }
}

class _TypesTab extends StatelessWidget {
  const _TypesTab({required this.controller});
  final PackagingController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.types.isEmpty) {
        return const AppEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'لا توجد أنواع عبوات',
          message: 'أضف نوع عبوة مثل زجاجة مياه ثم اربطه بالمنتجات.',
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: controller.types.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final type = controller.types[index];
          final units = controller.unitsByType[type.id] ?? [];
          return AppCard(
            onTap: () => Get.to(() => PackagingTypeFormScreen(type: type)),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                  child: const Icon(Icons.liquor_outlined, color: AppColors.info),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'القيمة: ${MoneyUtils.formatMoney(type.value)}'
                        '${units.isEmpty ? '' : ' • ${units.map((u) => u.unitName).join(' / ')}'}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                AppStatusBadge(
                  label: type.isActive ? 'فعال' : 'متوقف',
                  color: type.isActive ? AppColors.success : AppColors.textMuted,
                ),
              ],
            ),
          );
        },
      );
    });
  }
}

class _EmptyStockTab extends StatelessWidget {
  const _EmptyStockTab({required this.controller});
  final PackagingController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final summary = controller.ownership.value;
      if (summary == null) {
        return const AppLoadingState();
      }
      if (summary.byType.isEmpty) {
        return AppEmptyState(
          icon: Icons.warehouse_outlined,
          title: 'لا توجد أرصدة عبوات',
          message: 'سجّل رصيداً افتتاحياً أو استلم فوارغ من العملاء.',
          action: TextButton.icon(
            onPressed: () => Get.to(() => const PackagingOpeningScreen()),
            icon: const Icon(Icons.post_add_outlined),
            label: const Text('رصيد افتتاحي'),
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: summary.byType.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final row = summary.byType[index];
          return _PackagingTypeStockCard(
            row: row,
            emptyLabel: controller.formatQty(row.empty, row.typeId),
            fullLabel: controller.formatQty(row.fullInStock, row.typeId),
          );
        },
      );
    });
  }
}

class _PackagingTypeStockCard extends StatelessWidget {
  const _PackagingTypeStockCard({
    required this.row,
    required this.emptyLabel,
    required this.fullLabel,
  });

  final PackagingTypeOwnership row;
  final String emptyLabel;
  final String fullLabel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => Get.to(() => PackagingTypeStockScreen(ownership: row)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.liquor_outlined,
                color: AppColors.info,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.typeName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'فارغ: $emptyLabel • ممتلئ: $fullLabel',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (row.warehouseCount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${row.warehouseCount} مستودع',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _TransactionsTab extends StatelessWidget {
  const _TransactionsTab({required this.controller});
  final PackagingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Obx(
            () => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'كل الحركات',
                        selected: controller.filterMovement.value == null,
                        color: Theme.of(context).colorScheme.primary,
                        onTap: () => controller.setMovementFilter(null),
                      ),
                      const SizedBox(width: 8),
                      for (final type in PackagingMovementType.values) ...[
                        _FilterChip(
                          label: type.label,
                          selected: controller.filterMovement.value == type,
                          color: _movementColor(type),
                          onTap: () => controller.setMovementFilter(type),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        key: ValueKey('pkg-party-${controller.filterPartyId.value}'),
                        isExpanded: true,
                        decoration: _filterDecoration('العميل'),
                        initialValue: controller.filterPartyId.value,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('كل العملاء'),
                          ),
                          for (final party in controller.parties)
                            if (party.id != null)
                              DropdownMenuItem<int?>(
                                value: party.id,
                                child: Text(party.name),
                              ),
                        ],
                        onChanged: controller.setPartyFilter,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        key: ValueKey('pkg-type-${controller.filterTypeId.value}'),
                        isExpanded: true,
                        decoration: _filterDecoration('النوع'),
                        initialValue: controller.filterTypeId.value,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('كل الأنواع'),
                          ),
                          for (final type in controller.types)
                            if (type.id != null)
                              DropdownMenuItem<int?>(
                                value: type.id,
                                child: Text(type.name),
                              ),
                        ],
                        onChanged: controller.setTypeFilter,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  key: ValueKey(
                    'pkg-wh-${controller.filterWarehouseId.value}',
                  ),
                  isExpanded: true,
                  decoration: _filterDecoration('المستودع'),
                  initialValue: controller.filterWarehouseId.value,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('كل المستودعات'),
                    ),
                    for (final warehouse in controller.warehouses)
                      if (warehouse.id != null)
                        DropdownMenuItem<int?>(
                          value: warehouse.id,
                          child: Text(warehouse.name),
                        ),
                  ],
                  onChanged: controller.setWarehouseFilter,
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (range == null) {
                        await controller.setDateFilter(null, null);
                        return;
                      }
                      await controller.setDateFilter(
                        DateTime(range.start.year, range.start.month, range.start.day),
                        DateTime(
                          range.end.year,
                          range.end.month,
                          range.end.day,
                          23,
                          59,
                          59,
                        ),
                      );
                    },
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(
                      controller.hasDateFilter.value
                          ? 'فترة محددة'
                          : 'كل التواريخ',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Obx(() {
            if (controller.transactions.isEmpty) {
              return const AppEmptyState(
                icon: Icons.history,
                title: 'لا توجد حركات',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: controller.transactions.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final txn = controller.transactions[index];
                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AppStatusBadge(
                            label: txn.movementType.label,
                            color: _movementColor(txn.movementType),
                          ),
                          const Spacer(),
                          Text(
                            controller.formatQty(txn.quantity, txn.typeId),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(txn.typeName ?? ''),
                      Text(
                        [
                          if (txn.partyName != null) txn.partyName!,
                          if (txn.warehouseName != null) txn.warehouseName!,
                          if (txn.invoiceNumber != null) txn.invoiceNumber!,
                          if (txn.settlementNumber != null) txn.settlementNumber!,
                          if (txn.createdAt != null) txn.createdAt!,
                        ].join(' • '),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}

class _ReportTab extends StatelessWidget {
  const _ReportTab({required this.controller});
  final PackagingController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final summary = controller.report.value;
      if (summary == null) {
        return const AppLoadingState();
      }
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: controller.exportReportPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('تصدير PDF'),
            ),
          ),
          _ReportRow('مسلّم', controller.formatQty(summary.issued, null)),
          _ReportRow('مستلم سليم', controller.formatQty(summary.returned, null)),
          _ReportRow('مكسر', controller.formatQty(summary.broken, null)),
          _ReportRow('مفقود', controller.formatQty(summary.lost, null)),
          _ReportRow('عكس مرتجع بيع', controller.formatQty(summary.reversed, null)),
          _ReportRow('غير مسوّى', controller.formatQty(summary.unsettled, null)),
          _ReportRow('مخزون فارغ', controller.formatQty(summary.emptyStock, null)),
          _ReportRow(
            'ممتلئ في المخزون',
            controller.formatQty(summary.fullInStock, null),
          ),
          _ReportRow(
            'إجمالي قيمة العبوات',
            MoneyUtils.formatMoney(summary.totalValue),
          ),
          _ReportRow(
            'مطالبات مستحقة',
            MoneyUtils.formatMoney(summary.chargeDue),
          ),
        ],
      );
    });
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      labelStyle: TextStyle(
        color: selected ? Colors.white : color,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    );
  }
}

InputDecoration _filterDecoration(String label) {
  return InputDecoration(
    labelText: label,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  );
}

Color _movementColor(PackagingMovementType type) => switch (type) {
      PackagingMovementType.issued => AppColors.info,
      PackagingMovementType.returned => AppColors.success,
      PackagingMovementType.broken => AppColors.error,
      PackagingMovementType.lost => AppColors.warning,
      PackagingMovementType.reversed => AppColors.secondary,
      PackagingMovementType.openingEmpty => AppColors.primary,
      PackagingMovementType.openingIssued => AppColors.primary,
      PackagingMovementType.purchasedEmpty => AppColors.info,
      PackagingMovementType.filled => AppColors.warning,
      PackagingMovementType.unfilled => AppColors.success,
    };

class PackagingTypeFormScreen extends StatefulWidget {
  const PackagingTypeFormScreen({super.key, this.type});
  final PackagingType? type;

  @override
  State<PackagingTypeFormScreen> createState() => _PackagingTypeFormScreenState();
}

class _PackagingTypeFormScreenState extends State<PackagingTypeFormScreen> {
  final _controller = Get.find<PackagingController>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _value = TextEditingController();
  final _unitName = TextEditingController(text: 'صندوق');
  final _unitFactor = TextEditingController(text: '24');
  bool _isActive = true;
  bool _saving = false;
  List<PackagingUnit> _units = [];
  List<PackagingProductMapping> _mappings = [];

  bool get _isEditing => widget.type?.id != null;

  @override
  void initState() {
    super.initState();
    final type = widget.type;
    if (type != null) {
      _name.text = type.name;
      _description.text = type.description ?? '';
      _value.text = MoneyUtils.formatInput(type.value);
      _isActive = type.isActive;
      _reload();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _value.dispose();
    _unitName.dispose();
    _unitFactor.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final id = widget.type?.id;
    if (id == null) return;
    final units = await _controller.getUnits(id, activeOnly: false);
    final mappings = await _controller.getMappingsForType(id);
    if (!mounted) return;
    setState(() {
      _units = units;
      _mappings = mappings;
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      AppUi.showError('اسم نوع العبوة مطلوب');
      return;
    }
    setState(() => _saving = true);
    try {
      final value = MoneyUtils.parseAmount(_value.text) ?? 0;
      if (_isEditing) {
        await _controller.updateType(
          id: widget.type!.id!,
          name: _name.text,
          description: _description.text,
          value: value,
          isActive: _isActive,
        );
      } else {
        await _controller.createType(
          name: _name.text,
          description: _description.text,
          value: value,
          isActive: _isActive,
        );
      }
      if (!mounted) return;
      if (_isEditing) {
        AppUi.showSuccess('تم حفظ نوع العبوة');
        await _reload();
      } else {
        Get.back();
        AppUi.showSuccess('تم إضافة نوع العبوة');
      }
    } catch (e) {
      AppUi.showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addUnit() async {
    final id = widget.type?.id;
    if (id == null) return;
    final factor = double.tryParse(_unitFactor.text.trim()) ?? 0;
    try {
      await _controller.addUnit(
        typeId: id,
        unitName: _unitName.text,
        conversionFactor: factor,
      );
      _unitName.text = 'صندوق';
      _unitFactor.text = '24';
      await _reload();
    } catch (e) {
      AppUi.showError(e.toString());
    }
  }

  Future<void> _deleteUnit(PackagingUnit unit) async {
    if (unit.id == null) return;
    try {
      await _controller.deleteUnit(unit.id!);
      await _reload();
    } catch (e) {
      AppUi.showError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل نوع العبوة' : 'إضافة نوع عبوة'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'الاسم',
                    hintText: 'زجاجة مياه',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'الوصف'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _value,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'قيمة العبوة',
                    hintText: '0.50',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('فعال'),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'جاري الحفظ...' : 'حفظ'),
            ),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 24),
            const Text(
              'وحدات العرض',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final unit in _units)
              AppCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${unit.unitName} • معامل ${PackagingQuantityFormat.formatQuantity(unit.conversionFactor)}'
                        '${unit.isBaseUnit ? ' (أساسية)' : ''}',
                      ),
                    ),
                    if (!unit.isBaseUnit)
                      IconButton(
                        onPressed: () => _deleteUnit(unit),
                        icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _unitName,
                    decoration: const InputDecoration(labelText: 'وحدة'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _unitFactor,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'المعامل'),
                  ),
                ),
                IconButton(
                  onPressed: _addUnit,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'المنتجات المرتبطة',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (_mappings.isEmpty)
              const Text(
                'اربط المنتجات من شاشة المنتج.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            for (final mapping in _mappings)
              AppCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${mapping.productName ?? 'منتج'} • '
                  '${PackagingQuantityFormat.formatQuantity(mapping.unitsPerProductBase)} عبوة لكل وحدة أساسية',
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class PackagingSettlementScreen extends StatefulWidget {
  const PackagingSettlementScreen({
    super.key,
    this.partyId,
    this.typeId,
    this.warehouseId,
  });

  final int? partyId;
  final int? typeId;
  final int? warehouseId;

  @override
  State<PackagingSettlementScreen> createState() =>
      _PackagingSettlementScreenState();
}

class _PackagingSettlementScreenState extends State<PackagingSettlementScreen> {
  final _controller = Get.find<PackagingController>();

  final _notes = TextEditingController();
  final _paidNow = TextEditingController();
  final _returnedCrates = TextEditingController();
  final _returnedBottles = TextEditingController();
  final _brokenCrates = TextEditingController();
  final _brokenBottles = TextEditingController();
  final _lostCrates = TextEditingController();
  final _lostBottles = TextEditingController();

  int? _partyId;
  int? _typeId;
  int? _warehouseId;
  double _unsettled = 0;
  List<PackagingUnit> _units = [];
  List<PartyModel> _parties = [];
  List<PackagingType> _types = [];
  List<WarehouseModel> _warehouses = [];
  bool _loading = true;
  bool _saving = false;

  PackagingUnit? get _crate => PackagingQuantityFormat.aggregateUnit(_units);

  @override
  void initState() {
    super.initState();
    _partyId = widget.partyId;
    _typeId = widget.typeId;
    _warehouseId = widget.warehouseId;
    final args = Get.arguments;
    if (args is Map) {
      _partyId ??= args['partyId'] as int?;
      _typeId ??= args['typeId'] as int?;
      _warehouseId ??= args['warehouseId'] as int?;
    }
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    _paidNow.dispose();
    _returnedCrates.dispose();
    _returnedBottles.dispose();
    _brokenCrates.dispose();
    _brokenBottles.dispose();
    _lostCrates.dispose();
    _lostBottles.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _parties = await _controller.loadCustomerParties();
      _types = await _controller.getTypes(activeOnly: true);
      _warehouses = await _controller.getAllWarehouses();
      if (_warehouseId == null) {
        for (final warehouse in _warehouses) {
          if (warehouse.isDefault && warehouse.id != null) {
            _warehouseId = warehouse.id;
            break;
          }
        }
      }
      if (_warehouseId == null) {
        for (final warehouse in _warehouses) {
          if (warehouse.id != null) {
            _warehouseId = warehouse.id;
            break;
          }
        }
      }
      await _refreshBalance();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshBalance() async {
    if (_partyId == null || _typeId == null) {
      _unsettled = 0;
      _units = [];
      return;
    }
    _units = await _controller.getUnits(_typeId!);
    _unsettled = await _controller.unsettled(partyId: _partyId!, typeId: _typeId!);
  }

  double _lineBase(TextEditingController crates, TextEditingController bottles) {
    final crateQty = double.tryParse(crates.text.trim()) ?? 0;
    final bottleQty = double.tryParse(bottles.text.trim()) ?? 0;
    final crateFactor = _crate?.conversionFactor ?? 0;
    final fromCrates = crateFactor > 0
        ? UnitConversion.toBaseQuantity(crateQty, crateFactor)
        : 0;
    return fromCrates + bottleQty;
  }

  int get _typeValue {
    for (final type in _types) {
      if (type.id == _typeId) return type.value;
    }
    return 0;
  }

  int get _compensationAmount {
    final qty =
        _lineBase(_brokenCrates, _brokenBottles) +
        _lineBase(_lostCrates, _lostBottles);
    if (qty <= 0 || _typeValue <= 0) return 0;
    return (qty * _typeValue).round();
  }

  int? _parsePaidNow() {
    final raw = _paidNow.text.trim();
    if (raw.isEmpty) return 0;
    return MoneyUtils.parseAmount(raw);
  }

  Future<void> _save() async {
    if (_partyId == null || _typeId == null || _warehouseId == null) {
      AppUi.showError('يجب اختيار العميل ونوع العبوة والمستودع');
      return;
    }
    final returned = _lineBase(_returnedCrates, _returnedBottles);
    final broken = _lineBase(_brokenCrates, _brokenBottles);
    final lost = _lineBase(_lostCrates, _lostBottles);
    final compensation = _compensationAmount;
    final paidNow = _parsePaidNow();
    if (paidNow == null) {
      AppUi.showError('يرجى إدخال مبلغ صحيح في حقل مدفوع الآن');
      return;
    }
    if (paidNow > compensation) {
      AppUi.showError('المبلغ المدفوع يتجاوز قيمة التعويض');
      return;
    }
    setState(() => _saving = true);
    try {
      await _controller.settle(
        partyId: _partyId!,
        typeId: _typeId!,
        warehouseId: _warehouseId!,
        returnedBase: returned,
        brokenBase: broken,
        lostBase: lost,
        compensationPaidNow: paidNow,
        notes: _notes.text,
      );
      if (!mounted) return;
      Get.back(result: true);
      AppUi.showSuccess('تم تسجيل التسوية');
    } catch (e) {
      AppUi.showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('تسوية العبوات')),
      body: _loading
          ? const AppLoadingState()
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                AppCard(
                  child: Column(
                    children: [
                      DropdownButtonFormField<int>(
                        key: ValueKey('settle-party-$_partyId'),
                        initialValue: _partyId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'العميل'),
                        items: [
                          for (final party in _parties)
                            if (party.id != null)
                              DropdownMenuItem(
                                value: party.id,
                                child: Text(party.name),
                              ),
                        ],
                        onChanged: (value) async {
                          setState(() => _partyId = value);
                          await _refreshBalance();
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        key: ValueKey('settle-type-$_typeId'),
                        initialValue: _typeId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'نوع العبوة'),
                        items: [
                          for (final type in _types)
                            if (type.id != null)
                              DropdownMenuItem(
                                value: type.id,
                                child: Text(type.name),
                              ),
                        ],
                        onChanged: (value) async {
                          setState(() => _typeId = value);
                          await _refreshBalance();
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        key: ValueKey('settle-wh-$_warehouseId'),
                        initialValue: _warehouseId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'مستودع الاستلام',
                        ),
                        items: [
                          for (final warehouse in _warehouses)
                            if (warehouse.id != null)
                              DropdownMenuItem(
                                value: warehouse.id,
                                child: Text(warehouse.name),
                              ),
                        ],
                        onChanged: (value) => setState(() => _warehouseId = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.info),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'غير مسوّى: ${PackagingQuantityFormat.format(_unsettled, units: _units)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _QtySection(
                  title: 'سليم',
                  color: AppColors.success,
                  showCrates: _crate != null,
                  crateLabel: _crate?.unitName ?? 'صندوق',
                  bottleLabel:
                      PackagingQuantityFormat.baseUnit(_units)?.unitName ??
                      'زجاجة',
                  crates: _returnedCrates,
                  bottles: _returnedBottles,
                ),
                _QtySection(
                  title: 'مكسر',
                  color: AppColors.error,
                  showCrates: _crate != null,
                  crateLabel: _crate?.unitName ?? 'صندوق',
                  bottleLabel:
                      PackagingQuantityFormat.baseUnit(_units)?.unitName ??
                      'زجاجة',
                  crates: _brokenCrates,
                  bottles: _brokenBottles,
                ),
                _QtySection(
                  title: 'مفقود',
                  color: AppColors.warning,
                  showCrates: _crate != null,
                  crateLabel: _crate?.unitName ?? 'صندوق',
                  bottleLabel:
                      PackagingQuantityFormat.baseUnit(_units)?.unitName ??
                      'زجاجة',
                  crates: _lostCrates,
                  bottles: _lostBottles,
                ),
                ListenableBuilder(
                  listenable: Listenable.merge([
                    _brokenCrates,
                    _brokenBottles,
                    _lostCrates,
                    _lostBottles,
                    _paidNow,
                  ]),
                  builder: (context, _) {
                    final compensation = _compensationAmount;
                    if (compensation <= 0) {
                      return const SizedBox.shrink();
                    }
                    final paidNow = _parsePaidNow() ?? 0;
                    final remaining = (compensation - paidNow).clamp(
                      0,
                      compensation,
                    );
                    return AppCard(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'تعويض العبوات',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                              Text(
                                MoneyUtils.formatMoney(compensation),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _paidNow,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textDirection: TextDirection.ltr,
                            decoration: const InputDecoration(
                              labelText: 'مدفوع الآن',
                              hintText: '0.00',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            remaining > 0
                                ? 'المتبقي يُسجَّل ديناً: تعويض عن العبوات المفقودة (${MoneyUtils.formatMoney(remaining)})'
                                : 'لا ذمة متبقية بعد هذه الدفعة',
                            style: TextStyle(
                              color: remaining > 0
                                  ? AppColors.warning
                                  : AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                TextField(
                  controller: _notes,
                  decoration: const InputDecoration(labelText: 'ملاحظات'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'جاري الحفظ...' : 'حفظ التسوية'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _QtySection extends StatelessWidget {
  const _QtySection({
    required this.title,
    required this.color,
    required this.showCrates,
    required this.crateLabel,
    required this.bottleLabel,
    required this.crates,
    required this.bottles,
  });

  final String title;
  final Color color;
  final bool showCrates;
  final String crateLabel;
  final String bottleLabel;
  final TextEditingController crates;
  final TextEditingController bottles;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (showCrates) ...[
                Expanded(
                  child: TextField(
                    controller: crates,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: crateLabel),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: bottles,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: bottleLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PartyPackagingSection extends StatefulWidget {
  const PartyPackagingSection({super.key, required this.partyId});
  final int partyId;

  @override
  State<PartyPackagingSection> createState() => _PartyPackagingSectionState();
}

class _PartyPackagingSectionState extends State<PartyPackagingSection> {
  final _controller = Get.find<PackagingController>();
  List<PartyPackagingBalance> _balances = [];
  List<PackagingCharge> _charges = [];
  final _units = <int, List<PackagingUnit>>{};
  bool _loading = true;
  final _workers = <Worker>[];

  @override
  void initState() {
    super.initState();
    _load();
    _workers.add(AppEventBus.instance.listenToPackaging(_load));
    _workers.add(AppEventBus.instance.listenToInvoices(_load));
  }

  @override
  void dispose() {
    for (final worker in _workers) {
      worker.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final balances = await _controller.getPartyBalances(widget.partyId);
      final charges = await _controller.getCharges(
        partyId: widget.partyId,
        unpaidOnly: true,
      );
      final units = <int, List<PackagingUnit>>{};
      for (final balance in balances) {
        units[balance.typeId] = await _controller.getUnits(balance.typeId);
      }
      if (!mounted) return;
      setState(() {
        _balances = balances;
        _charges = charges;
        _units
          ..clear()
          ..addAll(units);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _payCharge(PackagingCharge charge) async {
    final remaining = charge.remaining;
    try {
      await _controller.payCharge(chargeId: charge.id!, amount: remaining);
      AppUi.showSuccess('تم تسجيل دفعة مطالبة العبوات');
      await _load();
    } catch (e) {
      AppUi.showError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_balances.isEmpty && _charges.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'العبوات القابلة للإرجاع',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            TextButton(
              onPressed: () => Get.to(
                () => PackagingSettlementScreen(partyId: widget.partyId),
              )?.then((_) => _load()),
              child: const Text('تسوية'),
            ),
          ],
        ),
        for (final balance in _balances)
          AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  balance.typeName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                _kv('مسلّم', balance.issued, balance.typeId),
                _kv('مستلم', balance.returned, balance.typeId),
                _kv('مكسر', balance.broken, balance.typeId),
                _kv('مفقود', balance.lost, balance.typeId),
                _kv('غير مسوّى', balance.unsettled, balance.typeId),
                if (balance.chargeDue > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'قيمة الكسر والفقد: ${MoneyUtils.formatMoney(balance.chargeDue)}',
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
              ],
            ),
          ),
        for (final charge in _charges)
          AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${charge.typeName ?? 'عبوات'} • متبقي ${MoneyUtils.formatMoney(charge.remaining)}',
                  ),
                ),
                TextButton(
                  onPressed: () => _payCharge(charge),
                  child: const Text('تحصيل'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _kv(String label, double qty, int typeId) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Text(
            PackagingQuantityFormat.format(qty, units: _units[typeId] ?? []),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class PackagingTypeStockScreen extends StatefulWidget {
  const PackagingTypeStockScreen({super.key, required this.ownership});
  final PackagingTypeOwnership ownership;

  @override
  State<PackagingTypeStockScreen> createState() =>
      _PackagingTypeStockScreenState();
}

class _PackagingTypeStockScreenState extends State<PackagingTypeStockScreen> {
  final _packaging = Get.find<PackagingController>();
  List<PackagingWarehouseStock> _warehouses = [];
  bool _loading = true;
  Worker? _packagingWorker;
  Worker? _inventoryWorker;

  PackagingTypeOwnership get _row {
    final latest = _packaging.ownership.value?.byType
        .where((item) => item.typeId == widget.ownership.typeId)
        .firstOrNull;
    return latest ?? widget.ownership;
  }

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
    _packagingWorker = AppEventBus.instance.listenToPackaging(_loadWarehouses);
    _inventoryWorker = AppEventBus.instance.listenToInventory(_loadWarehouses);
  }

  @override
  void dispose() {
    _packagingWorker?.dispose();
    _inventoryWorker?.dispose();
    super.dispose();
  }

  Future<void> _loadWarehouses() async {
    final rows = await _packaging.warehouseStockForType(widget.ownership.typeId);
    if (!mounted) return;
    setState(() {
      _warehouses = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_row.typeName),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'تسوية',
            icon: const Icon(Icons.assignment_turned_in_outlined),
            onPressed: () => Get.to(
              () => PackagingSettlementScreen(
                typeId: widget.ownership.typeId,
              ),
            ),
          ),
          IconButton(
            tooltip: 'رصيد افتتاحي',
            icon: const Icon(Icons.post_add_outlined),
            onPressed: () => Get.to(
              () => PackagingOpeningScreen(typeId: widget.ownership.typeId),
            ),
          ),
        ],
      ),
      body: Obx(() {
        final row = _row;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _ReportRow(
              'فوارغ عندي',
              _packaging.formatQty(row.empty, row.typeId),
            ),
            _ReportRow(
              'ممتلئ في المخزون',
              _packaging.formatQty(row.fullInStock, row.typeId),
            ),
            _ReportRow(
              'لدى العملاء',
              _packaging.formatQty(row.unsettled, row.typeId),
            ),
            _ReportRow(
              'إجمالي الكمية',
              _packaging.formatQty(row.totalQty, row.typeId),
            ),
            _ReportRow(
              'إجمالي القيمة',
              MoneyUtils.formatMoney(row.totalValue),
            ),
            const SizedBox(height: 8),
            const Text(
              'حسب المستودع',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: AppLoadingState(),
              )
            else
              for (final warehouse in _warehouses)
                AppCard(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.warehouse_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  warehouse.warehouseName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'فارغ: ${_packaging.formatQty(warehouse.empty, warehouse.typeId)}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'ممتلئ: ${_packaging.formatQty(warehouse.fullInStock, warehouse.typeId)}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Get.to(
                            () => PackagingSettlementScreen(
                              typeId: widget.ownership.typeId,
                              warehouseId: warehouse.warehouseId,
                            ),
                          ),
                          icon: const Icon(
                            Icons.assignment_turned_in_outlined,
                            size: 18,
                          ),
                          label: const Text('تسوية مخزون'),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        );
      }),
    );
  }
}

class PackagingOpeningScreen extends StatefulWidget {
  const PackagingOpeningScreen({super.key, this.typeId});
  final int? typeId;

  @override
  State<PackagingOpeningScreen> createState() => _PackagingOpeningScreenState();
}

class _PackagingOpeningScreenState extends State<PackagingOpeningScreen> {
  final _packaging = Get.find<PackagingController>();

  final _emptyCrates = TextEditingController();
  final _emptyBottles = TextEditingController();
  final _issuedCrates = TextEditingController();
  final _issuedBottles = TextEditingController();
  final _emptyNotes = TextEditingController();
  final _issuedNotes = TextEditingController();

  int? _typeId;
  int? _warehouseId;
  int? _partyId;
  List<PackagingUnit> _units = [];
  bool _savingEmpty = false;
  bool _savingIssued = false;

  PackagingUnit? get _crate => PackagingQuantityFormat.aggregateUnit(_units);

  @override
  void initState() {
    super.initState();
    _typeId = widget.typeId;
    _loadUnits();
  }

  @override
  void dispose() {
    _emptyCrates.dispose();
    _emptyBottles.dispose();
    _issuedCrates.dispose();
    _issuedBottles.dispose();
    _emptyNotes.dispose();
    _issuedNotes.dispose();
    super.dispose();
  }

  Future<void> _loadUnits() async {
    if (_typeId == null) {
      _units = [];
      return;
    }
    _units = await _packaging.getUnits(_typeId!);
    if (mounted) setState(() {});
  }

  double _lineBase(TextEditingController crates, TextEditingController bottles) {
    final crateQty = double.tryParse(crates.text.trim()) ?? 0;
    final bottleQty = double.tryParse(bottles.text.trim()) ?? 0;
    final crateFactor = _crate?.conversionFactor ?? 0;
    final fromCrates = crateFactor > 0
        ? UnitConversion.toBaseQuantity(crateQty, crateFactor)
        : 0;
    return fromCrates + bottleQty;
  }

  Future<void> _saveEmpty() async {
    if (_typeId == null || _warehouseId == null) {
      AppUi.showError('يجب اختيار نوع العبوة والمستودع');
      return;
    }
    setState(() => _savingEmpty = true);
    try {
      await _packaging.recordOpeningEmpty(
        typeId: _typeId!,
        warehouseId: _warehouseId!,
        quantity: _lineBase(_emptyCrates, _emptyBottles),
        notes: _emptyNotes.text,
      );
      AppUi.showSuccess('تم تسجيل رصيد الفوارغ الافتتاحي');
      _emptyCrates.clear();
      _emptyBottles.clear();
    } catch (e) {
      AppUi.showError(e.toString());
    } finally {
      if (mounted) setState(() => _savingEmpty = false);
    }
  }

  Future<void> _saveIssued() async {
    if (_typeId == null || _partyId == null) {
      AppUi.showError('يجب اختيار نوع العبوة والعميل');
      return;
    }
    setState(() => _savingIssued = true);
    try {
      await _packaging.recordOpeningIssued(
        typeId: _typeId!,
        partyId: _partyId!,
        quantity: _lineBase(_issuedCrates, _issuedBottles),
        notes: _issuedNotes.text,
      );
      AppUi.showSuccess('تم تسجيل الرصيد لدى العميل');
      _issuedCrates.clear();
      _issuedBottles.clear();
    } catch (e) {
      AppUi.showError(e.toString());
    } finally {
      if (mounted) setState(() => _savingIssued = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottleLabel =
        PackagingQuantityFormat.baseUnit(_units)?.unitName ?? 'زجاجة';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('رصيد افتتاحي للعبوات')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: DropdownButtonFormField<int>(
              key: ValueKey('open-type-$_typeId'),
              initialValue: _typeId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'نوع العبوة'),
              items: [
                for (final type in _packaging.types)
                  if (type.id != null)
                    DropdownMenuItem(value: type.id, child: Text(type.name)),
              ],
              onChanged: (value) async {
                setState(() => _typeId = value);
                await _loadUnits();
              },
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'فوارغ أملكها',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _warehouseId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'المستودع'),
                  items: [
                    for (final warehouse in _packaging.warehouses)
                      if (warehouse.id != null)
                        DropdownMenuItem(
                          value: warehouse.id,
                          child: Text(warehouse.name),
                        ),
                  ],
                  onChanged: (value) => setState(() => _warehouseId = value),
                ),
                const SizedBox(height: 8),
                _QtySection(
                  title: 'الكمية',
                  color: AppColors.success,
                  showCrates: _crate != null,
                  crateLabel: _crate?.unitName ?? 'صندوق',
                  bottleLabel: bottleLabel,
                  crates: _emptyCrates,
                  bottles: _emptyBottles,
                ),
                TextField(
                  controller: _emptyNotes,
                  decoration: const InputDecoration(labelText: 'ملاحظات'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _savingEmpty ? null : _saveEmpty,
                    child: Text(
                      _savingEmpty ? 'جاري الحفظ...' : 'حفظ رصيد الفوارغ',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'لدى العملاء ولم يُسوَّ',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _partyId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'العميل'),
                  items: [
                    for (final party in _packaging.parties)
                      if (party.id != null)
                        DropdownMenuItem(
                          value: party.id,
                          child: Text(party.name),
                        ),
                  ],
                  onChanged: (value) => setState(() => _partyId = value),
                ),
                const SizedBox(height: 8),
                _QtySection(
                  title: 'الكمية',
                  color: AppColors.info,
                  showCrates: _crate != null,
                  crateLabel: _crate?.unitName ?? 'صندوق',
                  bottleLabel: bottleLabel,
                  crates: _issuedCrates,
                  bottles: _issuedBottles,
                ),
                TextField(
                  controller: _issuedNotes,
                  decoration: const InputDecoration(labelText: 'ملاحظات'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _savingIssued ? null : _saveIssued,
                    child: Text(
                      _savingIssued ? 'جاري الحفظ...' : 'حفظ رصيد العملاء',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
