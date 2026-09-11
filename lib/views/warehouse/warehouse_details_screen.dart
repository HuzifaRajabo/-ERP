import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/warehouse_detail_controller.dart';
import '../../controllers/feature_controller.dart';
import '../../controllers/packaging_controller.dart';
import '../../models/business_config.dart';
import '../../core/services/app_event_bus.dart';
import '../../core/utils/money_utils.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../models/inventory_transaction_model.dart';
import '../../models/warehouse_model.dart';
import '../../models/returnable_packaging_model.dart';
import '../../core/utils/packaging_quantity_format.dart';
import '../packaging/packaging_screens.dart';
import 'transfer_screen.dart';
import 'warehouse_form_screen.dart';

class WarehouseDetailsScreen extends StatefulWidget {
  final WarehouseModel warehouse;
  final int? focusProductId;

  const WarehouseDetailsScreen({
    super.key,
    required this.warehouse,
    this.focusProductId,
  });

  @override
  State<WarehouseDetailsScreen> createState() => _WarehouseDetailsScreenState();
}

class _WarehouseDetailsScreenState extends State<WarehouseDetailsScreen> {
  late final WarehouseDetailController controller;
  bool _didOpenFocus = false;

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      WarehouseDetailController.create(warehouseId: widget.warehouse.id!),
    );
    if (widget.focusProductId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openFocusedProduct();
      });
    }
  }

  Future<void> _openFocusedProduct() async {
    if (_didOpenFocus || !mounted) return;
    await controller.loadStock();
    if (!mounted) return;
    final productId = widget.focusProductId;
    if (productId == null) return;
    ProductStockSummary? summary;
    for (final item in controller.stockSummaries) {
      if (item.productId == productId) {
        summary = item;
        break;
      }
    }
    _didOpenFocus = true;
    if (summary == null) return;
    openWarehouseProductBatches(
      context,
      controller: controller,
      summary: summary,
    );
  }

  @override
  void dispose() {
    Get.delete<WarehouseDetailController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showTransfer = featureEnabled(AppFeature.multipleWarehouses);
    final showWaste = featureEnabled(AppFeature.waste);
    return DefaultTabController(
      length: showTransfer ? 4 : 3,
      initialIndex: widget.focusProductId != null ? 1 : 0,
      child: Scaffold(
        appBar: AppBar(
          title: Obx(() => Text(controller.warehouse.value?.name ?? widget.warehouse.name)),
          centerTitle: true,
          actions: [
            if (showWaste)
              IconButton(
                tooltip: 'إتلاف بضاعة',
                icon: const Icon(Icons.delete_forever_outlined),
                onPressed: () => Get.toNamed(
                  '/waste-form',
                  arguments: controller.warehouseId,
                ),
              ),
            IconButton(
              tooltip: 'تعديل',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Get.to(
                () => const WarehouseFormScreen(),
                arguments: controller.warehouse.value ?? widget.warehouse,
              ),
            ),
            IconButton(
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh),
              onPressed: controller.refreshAll,
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              const Tab(text: 'نظرة عامة'),
              const Tab(text: 'المخزون'),
              const Tab(text: 'الحركات'),
              if (showTransfer) const Tab(text: 'تحويل'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(controller: controller),
            _InventoryTab(controller: controller),
            _MovementsTab(controller: controller),
            if (showTransfer)
              TransferTab(initialFromWarehouseId: widget.warehouse.id),
          ],
        ),
      ),
    );
  }
}

// ==============================
// النظرة العامة
// ==============================

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.controller});
  final WarehouseDetailController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Obx(() {
      final w = controller.warehouse.value;
      return RefreshIndicator(
        onRefresh: controller.refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _infoCard(context, w: w),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'قيمة المخزون',
                    value: _money(controller.inventoryValue.value),
                    icon: Icons.inventory_2_rounded,
                    color: const Color(0xFF7C3AED),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'عدد الأصناف',
                    value: '${controller.productCount.value}',
                    icon: Icons.category_rounded,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'عمليات التحويل',
                    value: '${controller.transferCount.value}',
                    icon: Icons.swap_horiz_rounded,
                    color: context.semantic.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'الحركات المتاحة',
                    value: '${controller.movements.length}',
                    icon: Icons.history_rounded,
                    color: context.semantic.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (featureEnabled(AppFeature.waste)) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () => Get.toNamed(
                    '/waste-form',
                    arguments: controller.warehouseId,
                  ),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('إتلاف بضاعة'),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.semantic.error,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _WarehousePackagingStock(warehouseId: controller.warehouseId),
          ],
        ),
      );
    });
  }

  Widget _infoCard(BuildContext context, {required WarehouseModel? w}) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(w?.name ?? '',
                    style: textTheme.titleLarge),
                if (w?.isDefault ?? false) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.star_rounded, color: context.semantic.warning, size: 20),
                ],
              ],
            ),
            const SizedBox(height: 8),
            _row(context, Icons.business_rounded, w?.type.label ?? ''),
            if (w?.address != null && w!.address!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _row(context, Icons.location_on_outlined, w.address!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String text) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(text, style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
      ],
    );
  }

  String _money(int v) => MoneyUtils.formatMoney(v);
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              )),
        ],
      ),
    );
  }
}

// ==============================
// المخزون
// ==============================

class _InventoryTab extends StatelessWidget {
  const _InventoryTab({required this.controller});
  final WarehouseDetailController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingStock.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.stockSummaries.isEmpty) {
        return _empty(context, 'لا توجد منتجات في هذا المستودع', Icons.inventory_outlined);
      }
      return RefreshIndicator(
        onRefresh: controller.loadStock,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: controller.stockSummaries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final s = controller.stockSummaries[index];
            return _ProductStockTile(
              summary: s,
              onTap: () => openWarehouseProductBatches(
                context,
                controller: controller,
                summary: s,
              ),
            );
          },
        ),
      );
    });
  }
}

void openWarehouseProductBatches(
  BuildContext context, {
  required WarehouseDetailController controller,
  required ProductStockSummary summary,
}) {
  controller.loadProductBatches(summary.productId);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BatchesSheet(controller: controller, summary: summary),
  );
}

class _BatchesSheet extends StatelessWidget {
  final WarehouseDetailController controller;
  final ProductStockSummary summary;

  const _BatchesSheet({required this.controller, required this.summary});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(summary.productName,
              style: textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('المتاح: ${_fmt(summary.available)}',
              style: textTheme.titleSmall?.copyWith(color: context.semantic.success)),
          const SizedBox(height: 16),
          Text('الدفعات',
              style: textTheme.titleSmall),
          const SizedBox(height: 8),
          Expanded(
            child: Obx(() {
              if (controller.isLoadingBatches.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = controller.selectedProductBatches.value;
              if (data == null) return const SizedBox.shrink();
              final batches =
                  (data['batches'] as List<WarehouseProductBatchStock>);
              if (batches.isEmpty) {
                return const Center(child: Text('لا توجد دفعات'));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('إجمالي القيمة',
                          style: textTheme.titleSmall),
                      Text(_moneyText,
                          style: textTheme.titleMedium?.copyWith(color: colors.primary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: batches.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final b = batches[i];
                        final lineValue = (b.costPrice * b.available).round();
                        return ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          tileColor: colors.surfaceContainerLowest,
                          leading: Icon(Icons.inventory_2_outlined,
                              color: colors.primary),
                          title: Text(
                            b.batchNumber ?? 'بدون رقم دفعة',
                            style:
                                textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.expiryDate == null
                                    ? 'بدون تاريخ صلاحية'
                                    : 'انتهاء: ${b.expiryDate}',
                                style:
                                    textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                              ),
                              Text('التكلفة: ${MoneyUtils.formatMoney(b.costPrice)}',
                                  style: textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 11)),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_fmt(b.available),
                                  style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800)),
                              Text(MoneyUtils.formatMoney(lineValue),
                                  style: textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 11)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  String get _moneyText {
    final batches =
        (controller.selectedProductBatches.value?['batches']
                as List<WarehouseProductBatchStock>?) ??
            const [];
    final total = batches.fold<int>(
        0, (acc, b) => acc + (b.costPrice * b.available).round());
    return MoneyUtils.formatMoney(total);
  }
}

class _ProductStockTile extends StatelessWidget {
  final ProductStockSummary summary;
  final VoidCallback onTap;

  const _ProductStockTile({required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final semantic = context.semantic;
    final color = summary.available <= 0
        ? semantic.error
        : summary.available <= 5
            ? semantic.warning
            : semantic.success;
    final stockLabel = summary.available <= 0
        ? 'نفد المخزون'
        : summary.available <= 5
            ? 'مخزون منخفض'
            : 'متوفر';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.inventory_2_outlined, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(summary.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall),
                    const SizedBox(height: 2),
                    if (summary.productDescription.isNotEmpty)
                      Text(
                        summary.productDescription,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.circle, size: 8, color: color),
                        const SizedBox(width: 4),
                        Text(stockLabel,
                            style: textTheme.labelMedium?.copyWith(color: color)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _fmt(summary.available),
                        style: textTheme.titleLarge?.copyWith(
                            color: color, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        summary.unitName ?? 'وحدة',
                        style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(MoneyUtils.formatMoney(summary.value),
                      style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================
// الحركات
// ==============================

class _MovementsTab extends StatelessWidget {
  const _MovementsTab({required this.controller});
  final WarehouseDetailController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Filters(controller: controller),
        Expanded(
          child: Obx(() {
            if (controller.isLoadingMovement) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.hasMovementError) {
              return _empty(context, controller.errorMessage.value ?? 'خطأ',
                  Icons.error_outline);
            }
            if (controller.isEmptyMovements) {
              return _empty(context, 'لا توجد حركات', Icons.history);
            }
            return NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels >=
                    n.metrics.maxScrollExtent - 200) {
                  controller.loadMoreMovements();
                }
                return false;
              },
              child: RefreshIndicator(
                onRefresh: controller.resetMovements,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  itemCount: controller.movements.length +
                      (controller.hasMore.value ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    if (index == controller.movements.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _MovementTile(
                        view: controller.movements[index]);
                  },
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _Filters extends StatelessWidget {
  final WarehouseDetailController controller;

  const _Filters({required this.controller});

  @override
  Widget build(BuildContext context) {
    final types = InventoryTransactionType.values.toList();

    return Obx(() => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _chip('الكل', null, controller.selectedType.value == null, context),
              const SizedBox(width: 8),
              for (final t in types) ...[
                _chip(t.label, t, controller.selectedType.value == t, context),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ));
  }

  Widget _chip(
      String label,
      InventoryTransactionType? type,
      bool selected,
      BuildContext chipContext) {
    final colors = Theme.of(chipContext).colorScheme;
    final textTheme = Theme.of(chipContext).textTheme;
    return GestureDetector(
      onTap: () => controller.filterByType(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
        ),
        child: Text(label,
            style: textTheme.labelMedium?.copyWith(
                color: selected ? colors.onPrimary : colors.onSurface)),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final InventoryTransactionView view;

  const _MovementTile({required this.view});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final semantic = context.semantic;
    final type = view.transaction.type;
    final qty = view.transaction.quantity;
    final qtyStr = _fmt(qty);
    final color = _colorFor(type, colors, semantic);
    final icon = _iconFor(type);
    final prefix = type.increasesStock ? '+' : '-';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(view.productName,
                      style: textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(type.label,
                            style: textTheme.labelMedium?.copyWith(color: color)),
                      ),
                      if (view.invoiceNumber != null) ...[
                        const SizedBox(width: 6),
                        Text(view.invoiceNumber!,
                            style: textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant)),
                      ],
                    ],
                  ),
                  if (type.isTransfer && view.counterpartyWarehouseName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '↔ ${view.counterpartyWarehouseName}',
                        style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant),
                      ),
                    ),
                  if (view.batchNumber != null)
                    Text('دفعة: ${view.batchNumber}',
                        style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant, fontSize: 10)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$prefix$qtyStr',
                    style: textTheme.titleLarge?.copyWith(
                        color: color, fontWeight: FontWeight.bold)),
                Text('وحدة',
                    style: textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _colorFor(InventoryTransactionType t, ColorScheme colors, AppSemanticColors semantic) =>
      switch (t) {
        InventoryTransactionType.sale => colors.primary,
        InventoryTransactionType.purchase => semantic.warning,
        InventoryTransactionType.saleReturn => const Color(0xFF7C3AED),
        InventoryTransactionType.purchaseReturn => semantic.info,
        InventoryTransactionType.transferOut => semantic.error,
        InventoryTransactionType.transferIn => semantic.success,
        InventoryTransactionType.waste => semantic.error,
        InventoryTransactionType.expiredReturn => const Color(0xFF9A3412),
      };

  IconData _iconFor(InventoryTransactionType t) => switch (t) {
        InventoryTransactionType.sale => Icons.arrow_upward_rounded,
        InventoryTransactionType.purchase => Icons.arrow_downward_rounded,
        InventoryTransactionType.saleReturn => Icons.undo_rounded,
        InventoryTransactionType.purchaseReturn => Icons.redo_rounded,
        InventoryTransactionType.transferOut => Icons.arrow_forward_rounded,
        InventoryTransactionType.transferIn => Icons.arrow_back_rounded,
        InventoryTransactionType.waste => Icons.delete_forever_outlined,
        InventoryTransactionType.expiredReturn => Icons.event_busy_outlined,
      };
}

// ==============================
// أدوات مساعدة
// ==============================

Widget _empty(BuildContext context, String msg, IconData icon) {
  final colors = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 64, color: colors.onSurfaceVariant),
        const SizedBox(height: 12),
        Text(msg, style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
      ],
    ),
  );
}

String _fmt(double qty) =>
    qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(2);

class _WarehousePackagingStock extends StatefulWidget {
  const _WarehousePackagingStock({required this.warehouseId});
  final int warehouseId;

  @override
  State<_WarehousePackagingStock> createState() =>
      _WarehousePackagingStockState();
}

class _WarehousePackagingStockState extends State<_WarehousePackagingStock> {
  List<PackagingWarehouseStock> _rows = [];
  Worker? _packagingWorker;
  Worker? _inventoryWorker;

  @override
  void initState() {
    super.initState();
    _load();
    _packagingWorker = AppEventBus.instance.listenToPackaging(_load);
    _inventoryWorker = AppEventBus.instance.listenToInventory(_load);
  }

  @override
  void dispose() {
    _packagingWorker?.dispose();
    _inventoryWorker?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!Get.isRegistered<PackagingController>()) return;
    final rows = await Get.find<PackagingController>()
        .getWarehouseStock(warehouseId: widget.warehouseId);
    if (!mounted) return;
    setState(() => _rows = rows);
  }

  @override
  Widget build(BuildContext context) {
    if (_rows.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مخزون العبوات',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final row in _rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(row.typeName)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'فارغ: ${PackagingQuantityFormat.formatQuantity(row.empty)}',
                          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'ممتلئ: ${PackagingQuantityFormat.formatQuantity(row.fullInStock)}',
                          style: textTheme.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      tooltip: 'تسوية مخزون',
                      icon: const Icon(Icons.assignment_turned_in_outlined),
                      onPressed: () => Get.to(
                        () => PackagingSettlementScreen(
                          typeId: row.typeId,
                          warehouseId: widget.warehouseId,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}