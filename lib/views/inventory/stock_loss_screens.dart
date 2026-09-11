import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/stock_loss_controller.dart';
import '../../core/services/app_event_bus.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/utils/money_utils.dart';
import '../../models/expired_return_model.dart';
import '../../models/waste_model.dart';
import '../shared/app_ui.dart';
import '../shared/shared_components.dart';

Color _wasteColor(BuildContext context) => context.semantic.error;
Color _expiredColor(BuildContext context) => context.semantic.warning;

String _fmtQty(double v) =>
    v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

String _fmtDocDate(String? value) {
  if (value == null || value.isEmpty) return '—';
  final parsed = DateTime.tryParse(value.replaceFirst(' ', 'T'));
  if (parsed == null) {
    return value.length >= 16 ? value.substring(0, 16) : value;
  }
  return '${parsed.day.toString().padLeft(2, '0')}/'
      '${parsed.month.toString().padLeft(2, '0')}/'
      '${parsed.year}  ${parsed.hour.toString().padLeft(2, '0')}:'
      '${parsed.minute.toString().padLeft(2, '0')}';
}

class StockLossFormScreen extends StatefulWidget {
  final bool isExpiredReturn;

  const StockLossFormScreen({super.key, this.isExpiredReturn = false});

  @override
  State<StockLossFormScreen> createState() => _StockLossFormScreenState();
}

class _StockLossFormScreenState extends State<StockLossFormScreen> {
  late final String _tag;
  late final StockLossController controller;

  @override
  void initState() {
    super.initState();
    _tag = widget.isExpiredReturn ? 'expired' : 'waste';
    controller = Get.put(
      StockLossController.create(isExpiredReturn: widget.isExpiredReturn),
      tag: _tag,
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<StockLossController>(tag: _tag)) {
      Get.delete<StockLossController>(tag: _tag);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isExpiredReturn ? _expiredColor(context) : _wasteColor(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isExpiredReturn
            ? 'مرتجع منتهي الصلاحية'
            : 'إتلاف بضاعة'),
        centerTitle: true,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const AppLoadingState();
        }
        return _StockLossFormBody(controller: controller, accent: color);
      }),
    );
  }
}

class _StockLossFormBody extends StatefulWidget {
  final StockLossController controller;
  final Color accent;
  const _StockLossFormBody({required this.controller, required this.accent});

  @override
  State<_StockLossFormBody> createState() => _StockLossFormBodyState();
}

class _StockLossFormBodyState extends State<_StockLossFormBody> {
  final _qtyCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _compensationCtrl = TextEditingController();

  StockLossController get c => widget.controller;
  Color get accent => widget.accent;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    _notesCtrl.dispose();
    _compensationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    c.reason.value = _reasonCtrl.text;
    c.notes.value = _notesCtrl.text;
    final ok = await c.save();
    if (!mounted) return;
    if (!ok) {
      AppUi.showError(c.errorMessage.value ?? 'تعذر حفظ العملية');
      return;
    }
    final successMessage = c.isExpiredReturn
        ? 'تم تسجيل مرتجع انتهاء الصلاحية'
        : 'تم تسجيل الإتلاف';
    Navigator.of(context).pop(true);
    AppUi.showSuccess(successMessage);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Obx(() {
          final err = c.errorMessage.value;
          if (err == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(err, style: TextStyle(color: colors.error)),
          );
        }),
        _FormSection(
          icon: Icons.description_outlined,
          title: 'بيانات المستند',
          color: accent,
          children: [
            if (c.isExpiredReturn) ...[
              Obx(
                () => DropdownButtonFormField<int>(
                  isExpanded: true,
                  value: c.selectedPartyId.value,
                  decoration: AppUi.inputDecoration(
                    label: 'المورد',
                    icon: Icons.local_shipping_outlined,
                  ),
                  items: [
                    for (final p in c.suppliers)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => c.selectedPartyId.value = v,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Obx(
              () => DropdownButtonFormField<int>(
                isExpanded: true,
                value: c.selectedWarehouseId.value,
                decoration: AppUi.inputDecoration(
                  label: 'المستودع',
                  icon: Icons.warehouse_outlined,
                ),
                items: [
                  for (final w in c.warehouses)
                    DropdownMenuItem(
                      value: w.id,
                      child: Text(w.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: c.warehouseLocked.value ? null : c.selectWarehouse,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _reasonCtrl,
              decoration: AppUi.inputDecoration(
                label: c.isExpiredReturn ? 'سبب الإرجاع' : 'سبب الإتلاف',
                icon: Icons.report_gmailerrorred_outlined,
              ),
              onChanged: (v) => c.reason.value = v,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: AppUi.inputDecoration(
                label: 'ملاحظات',
                icon: Icons.notes_outlined,
              ),
            ),
            if (c.isExpiredReturn) ...[
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _compensationCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: AppUi.inputDecoration(
                  label: 'قيمة التعويض',
                  icon: Icons.payments_outlined,
                ),
                onChanged: (v) =>
                    c.compensationAmount.value = MoneyUtils.parseAmount(v) ?? 0,
              ),
              Obx(() {
                final loss = c.totalCost - c.compensationAmount.value;
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    'صافي الخسارة: ${MoneyUtils.formatMoney(loss)}',
                    style: TextStyle(
                      color: loss >= 0 ? colors.error : context.semantic.success,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _FormSection(
          icon: Icons.add_box_outlined,
          title: 'إضافة منتج',
          color: colors.primary,
          children: [
            Obx(
              () => DropdownButtonFormField<int>(
                isExpanded: true,
                value: c.selectedProductId.value,
                decoration: AppUi.inputDecoration(
                  label: 'المنتج',
                  icon: Icons.inventory_2_outlined,
                ),
                items: [
                  for (final p in c.products)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: c.selectProduct,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Obx(
              () => DropdownButtonFormField<int>(
                isExpanded: true,
                value: c.selectedBatchId.value,
                decoration: AppUi.inputDecoration(
                  label: 'الدفعة',
                  icon: Icons.qr_code_2_outlined,
                ),
                items: [
                  for (final b in c.batches)
                    DropdownMenuItem(
                      value: b.batchId,
                      child: Text(
                        '${b.batchNumber ?? 'بدون رقم'}'
                        '${b.expiryDate == null ? '' : ' · صلاحية ${b.expiryDate}'}'
                        ' · متاح ${_fmtQty(b.available)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => c.selectedBatchId.value = v,
              ),
            ),
            Obx(() {
              final batch = c.selectedBatch;
              if (batch == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'تكلفة الوحدة الأساسية: ${MoneyUtils.formatMoney(batch.costPrice)}'
                  ' · المتاح: ${_fmtQty(batch.available)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
            const SizedBox(height: AppSpacing.md),
            Obx(
              () => DropdownButtonFormField<int>(
                isExpanded: true,
                value: c.selectedUnitId.value,
                decoration: AppUi.inputDecoration(
                  label: 'الوحدة',
                  icon: Icons.straighten,
                ),
                items: [
                  for (final u in c.units)
                    DropdownMenuItem(
                      value: u.id,
                      child: Text(u.unitName, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => c.selectedUnitId.value = v,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _qtyCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: AppUi.inputDecoration(
                label: 'الكمية',
                icon: Icons.numbers,
              ),
              onChanged: (v) =>
                  c.quantity.value = double.tryParse(v.replaceAll(',', '.')),
            ),
            Obx(() {
              if ((c.quantity.value ?? 0) <= 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'الكمية الأساسية: ${_fmtQty(c.baseQuantity)}'
                  ' · قيمة السطر: ${MoneyUtils.formatMoney(c.lineCost)}',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final err = c.addLine();
                  if (err != null) {
                    c.errorMessage.value = err;
                    AppUi.showError(err);
                    return;
                  }
                  _qtyCtrl.clear();
                  c.errorMessage.value = null;
                },
                icon: const Icon(Icons.add),
                label: const Text('إضافة للعملية'),
              ),
            ),
          ],
        ),
        Obx(() {
          if (c.lines.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: _FormSection(
              icon: Icons.list_alt_outlined,
              title: 'بنود العملية (${c.lines.length})',
              color: accent,
              children: [
                for (var i = 0; i < c.lines.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.lines[i].productName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${c.lines[i].batchNumber}'
                                ' · ${_fmtQty(c.lines[i].quantity)} ${c.lines[i].unitName ?? ''}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          MoneyUtils.formatMoney(c.lines[i].lineCost),
                          style: TextStyle(
                            color: colors.error,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: colors.error,
                          ),
                          onPressed: () => c.removeLine(i),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                  child: Text(
                    'إجمالي التكلفة: ${MoneyUtils.formatMoney(c.totalCost)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: AppSpacing.xl),
        Obx(
          () => SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: c.isSaving.value ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: colors.onPrimary,
              ),
              child: Text(
                c.isSaving.value ? 'جاري الحفظ...' : 'حفظ العملية',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class WasteList extends StatefulWidget {
  const WasteList({super.key});

  @override
  State<WasteList> createState() => _WasteListState();
}

class _WasteListState extends State<WasteList> {
  late Future<List<WasteRecord>> _future;
  Worker? _inventoryListener;

  @override
  void initState() {
    super.initState();
    _future = StockLossController.getAllWaste();
    _inventoryListener = AppEventBus.instance.listenToInventory(_reload);
  }

  @override
  void dispose() {
    _inventoryListener?.dispose();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = StockLossController.getAllWaste();
    });
  }

  Future<void> _openForm() async {
    final saved = await Get.toNamed('/waste-form');
    if (!mounted) return;
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: FutureBuilder<List<WasteRecord>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const AppLoadingState(message: 'جارٍ تحميل عمليات الإتلاف...');
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const AppEmptyState(
              icon: Icons.delete_forever_outlined,
              title: 'لا توجد عمليات إتلاف',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                final w = items[i];
                return _StockLossListCard(
                  number: w.wasteNumber,
                  badge: 'إتلاف',
                  color: _wasteColor(context),
                  icon: Icons.delete_forever_outlined,
                  amount: w.totalCost,
                  warehouse: w.warehouseName,
                  extra: w.reason,
                  date: w.createdAt,
                  onTap: () => Get.to(() => WasteDetailsScreen(id: w.id!)),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        backgroundColor: _wasteColor(context),
        foregroundColor: colors.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text(
          'عملية إتلاف جديدة',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class ExpiredReturnList extends StatefulWidget {
  const ExpiredReturnList({super.key});

  @override
  State<ExpiredReturnList> createState() => _ExpiredReturnListState();
}

class _ExpiredReturnListState extends State<ExpiredReturnList> {
  late Future<List<ExpiredReturnRecord>> _future;
  Worker? _inventoryListener;

  @override
  void initState() {
    super.initState();
    _future = StockLossController.getAllExpired();
    _inventoryListener = AppEventBus.instance.listenToInventory(_reload);
  }

  @override
  void dispose() {
    _inventoryListener?.dispose();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = StockLossController.getAllExpired();
    });
  }

  Future<void> _openForm() async {
    final saved = await Get.toNamed('/expired-return-form');
    if (!mounted) return;
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: FutureBuilder<List<ExpiredReturnRecord>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const AppLoadingState(
              message: 'جارٍ تحميل المرتجعات المنتهية...',
            );
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const AppEmptyState(
              icon: Icons.event_busy_outlined,
              title: 'لا توجد مرتجعات منتهية الصلاحية',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                final r = items[i];
                return _StockLossListCard(
                  number: r.returnNumber,
                  badge: 'مرتجع منتهي',
                  color: _expiredColor(context),
                  icon: Icons.event_busy_outlined,
                  amount: r.netLoss,
                  warehouse: r.warehouseName,
                  extra: r.partyNameSnapshot,
                  date: r.createdAt,
                  onTap: () => Get.to(
                    () => ExpiredReturnDetailsScreen(id: r.id!),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        backgroundColor: _expiredColor(context),
        foregroundColor: colors.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text(
          'مرتجع منتهي جديد',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class WasteDetailsScreen extends StatelessWidget {
  final int id;
  const WasteDetailsScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WasteWithItems?>(
      future: StockLossController.getWasteById(id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: AppLoadingState());
        }
        final data = snapshot.data;
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('إتلاف'), centerTitle: true),
            body: const AppEmptyState(
              icon: Icons.delete_forever_outlined,
              title: 'المستند غير موجود',
            ),
          );
        }
        final r = data.record;
        return Scaffold(
          appBar: AppBar(
            title: Text(r.wasteNumber),
            centerTitle: true,
            actions: [
              IconButton(
                tooltip: 'تصدير PDF',
                icon: const Icon(Icons.picture_as_pdf_outlined),
                onPressed: () => StockLossController.exportWastePdf(data),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _DocumentHeader(
                number: r.wasteNumber,
                badge: 'إتلاف بضاعة',
                color: _wasteColor(context),
                icon: Icons.delete_forever_outlined,
                rows: [
                  _IconMeta(
                    icon: Icons.warehouse_outlined,
                    label: 'المستودع',
                    value: r.warehouseName ?? '—',
                  ),
                  _IconMeta(
                    icon: Icons.calendar_today_outlined,
                    label: 'التاريخ',
                    value: _fmtDocDate(r.createdAt),
                  ),
                  _IconMeta(
                    icon: Icons.report_gmailerrorred_outlined,
                    label: 'السبب',
                    value: r.reason,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _FinancialCard(
                rows: [
                  _MoneyLine(
                    label: 'إجمالي الإتلاف',
                    value: r.totalCost,
                    color: context.semantic.error,
                    large: true,
                  ),
                ],
              ),
              if (r.notes != null && r.notes!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _FormSection(
                  icon: Icons.notes_outlined,
                  title: 'الملاحظات',
                  color: Theme.of(context).colorScheme.secondary,
                  children: [
                    Text(
                      r.notes!,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              _ItemsSection(
                items: [
                  for (final item in data.items)
                    _StockLossItemCard(
                      productName: item.productNameSnapshot,
                      batchNumber: item.batchNumberSnapshot,
                      expiryDate: item.expiryDateSnapshot,
                      quantity: item.quantity,
                      unitName: item.unitNameSnapshot,
                      unitCost: item.unitCost,
                      lineCost: item.lineCost,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class ExpiredReturnDetailsScreen extends StatelessWidget {
  final int id;
  const ExpiredReturnDetailsScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ExpiredReturnWithItems?>(
      future: StockLossController.getExpiredById(id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: AppLoadingState());
        }
        final data = snapshot.data;
        if (data == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('مرتجع منتهي'),
              centerTitle: true,
            ),
            body: const AppEmptyState(
              icon: Icons.event_busy_outlined,
              title: 'المستند غير موجود',
            ),
          );
        }
        final r = data.record;
        return Scaffold(
          appBar: AppBar(
            title: Text(r.returnNumber),
            centerTitle: true,
            actions: [
              IconButton(
                tooltip: 'تصدير PDF',
                icon: const Icon(Icons.picture_as_pdf_outlined),
                onPressed: () =>
                    StockLossController.exportExpiredPdf(data),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _DocumentHeader(
                number: r.returnNumber,
                badge: 'مرتجع منتهي الصلاحية',
                color: _expiredColor(context),
                icon: Icons.event_busy_outlined,
                rows: [
                  _IconMeta(
                    icon: Icons.local_shipping_outlined,
                    label: 'المورد',
                    value: r.partyNameSnapshot,
                  ),
                  _IconMeta(
                    icon: Icons.warehouse_outlined,
                    label: 'المستودع',
                    value: r.warehouseName ?? '—',
                  ),
                  _IconMeta(
                    icon: Icons.calendar_today_outlined,
                    label: 'التاريخ',
                    value: _fmtDocDate(r.createdAt),
                  ),
                  if (r.reason != null && r.reason!.isNotEmpty)
                    _IconMeta(
                      icon: Icons.report_gmailerrorred_outlined,
                      label: 'السبب',
                      value: r.reason!,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _FinancialCard(
                rows: [
                  _MoneyLine(
                    label: 'تكلفة المخزون',
                    value: r.inventoryCost,
                    color: context.semantic.warning,
                  ),
                  _MoneyLine(
                    label: 'التعويض',
                    value: r.compensationAmount,
                    color: context.semantic.success,
                  ),
                  _MoneyLine(
                    label: 'صافي الخسارة',
                    value: r.netLoss,
                    color: context.semantic.error,
                    large: true,
                  ),
                ],
              ),
              if (r.notes != null && r.notes!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _FormSection(
                  icon: Icons.notes_outlined,
                  title: 'الملاحظات',
                  color: Theme.of(context).colorScheme.secondary,
                  children: [
                    Text(
                      r.notes!,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              _ItemsSection(
                items: [
                  for (final item in data.items)
                    _StockLossItemCard(
                      productName: item.productNameSnapshot,
                      batchNumber: item.batchNumberSnapshot,
                      expiryDate: item.expiryDateSnapshot,
                      quantity: item.quantity,
                      unitName: item.unitNameSnapshot,
                      unitCost: item.unitCost,
                      lineCost: item.lineCost,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StockLossListCard extends StatelessWidget {
  final String number;
  final String badge;
  final Color color;
  final IconData icon;
  final int amount;
  final String? warehouse;
  final String? extra;
  final String? date;
  final VoidCallback onTap;

  const _StockLossListCard({
    required this.number,
    required this.badge,
    required this.color,
    required this.icon,
    required this.amount,
    this.warehouse,
    this.extra,
    this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                AppStatusBadge(label: badge, color: color, icon: icon),
                if (warehouse != null && warehouse!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(warehouse!, style: Theme.of(context).textTheme.bodySmall),
                ],
                if (extra != null && extra!.isNotEmpty)
                  Text(extra!, style: Theme.of(context).textTheme.bodySmall),
                if (date != null)
                  Text(
                    _fmtDocDate(date),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
          Text(
            MoneyUtils.formatMoney(amount),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.error,
                ),
          ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final List<Widget> children;

  const _FormSection({
    required this.icon,
    required this.title,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _DocumentHeader extends StatelessWidget {
  final String number;
  final String badge;
  final Color color;
  final IconData icon;
  final List<_IconMeta> rows;

  const _DocumentHeader({
    required this.number,
    required this.badge,
    required this.color,
    required this.icon,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  number,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
              AppStatusBadge(label: badge, color: color, icon: icon),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(row.icon, size: 16, color: color),
                  const SizedBox(width: 8),
                  Text(
                    '${row.label}:',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      row.value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
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

class _IconMeta {
  final IconData icon;
  final String label;
  final String value;

  const _IconMeta({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _FinancialCard extends StatelessWidget {
  final List<_MoneyLine> rows;

  const _FinancialCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    rows[i].label,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontWeight:
                          rows[i].large ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  MoneyUtils.formatMoney(rows[i].value),
                  style: TextStyle(
                    color: rows[i].color,
                    fontWeight: FontWeight.w900,
                    fontSize: rows[i].large ? 20 : 16,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MoneyLine {
  final String label;
  final int value;
  final Color color;
  final bool large;

  const _MoneyLine({
    required this.label,
    required this.value,
    required this.color,
    this.large = false,
  });
}

class _ItemsSection extends StatelessWidget {
  final List<Widget> items;

  const _ItemsSection({required this.items});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.list_alt, color: colors.onSurfaceVariant, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'المنتجات',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...items,
        ],
      ),
    );
  }
}

class _StockLossItemCard extends StatelessWidget {
  final String productName;
  final String? batchNumber;
  final String? expiryDate;
  final double quantity;
  final String? unitName;
  final int unitCost;
  final int lineCost;

  const _StockLossItemCard({
    required this.productName,
    this.batchNumber,
    this.expiryDate,
    required this.quantity,
    this.unitName,
    required this.unitCost,
    required this.lineCost,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: colors.primary,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  productName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AppStatusBadge(
                label: batchNumber?.isNotEmpty == true
                    ? batchNumber!
                    : 'بدون رقم دفعة',
                color: colors.secondary,
                icon: Icons.qr_code_2_outlined,
              ),
              if (expiryDate != null && expiryDate!.isNotEmpty)
                AppStatusBadge(
                  label: expiryDate!,
                  color: context.semantic.warning,
                  icon: Icons.event_outlined,
                ),
              if (unitName != null && unitName!.isNotEmpty)
                AppStatusBadge(
                  label: unitName!,
                  color: context.semantic.info,
                  icon: Icons.straighten,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${_fmtQty(quantity)} ${unitName ?? ''}'.trim(),
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                MoneyUtils.formatMoney(unitCost),
                style: TextStyle(color: context.semantic.warning, fontSize: 12),
              ),
              const SizedBox(width: 10),
              Text(
                MoneyUtils.formatMoney(lineCost),
                style: TextStyle(
                  color: colors.error,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
