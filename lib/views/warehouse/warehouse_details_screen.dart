import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/warehouse_detail_controller.dart';
import '../../core/utils/money_utils.dart';
import '../../models/inventory_transaction_model.dart';
import '../../models/warehouse_model.dart';
import '../../repositories/inventory_repository.dart';
import 'transfer_screen.dart';
import 'warehouse_form_screen.dart';

class WarehouseDetailsScreen extends StatefulWidget {
  final WarehouseModel warehouse;

  const WarehouseDetailsScreen({super.key, required this.warehouse});

  @override
  State<WarehouseDetailsScreen> createState() => _WarehouseDetailsScreenState();
}

class _WarehouseDetailsScreenState extends State<WarehouseDetailsScreen> {
  late final WarehouseDetailController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      WarehouseDetailController(
        warehouseId: widget.warehouse.id!,
        warehouseRepo: Get.find(),
        inventoryRepo: Get.find(),
      ),
    );
  }

  @override
  void dispose() {
    Get.delete<WarehouseDetailController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Obx(() => Text(controller.warehouse.value?.name ?? widget.warehouse.name)),
          centerTitle: true,
          actions: [
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
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'نظرة عامة'),
              Tab(text: 'المخزون'),
              Tab(text: 'الحركات'),
              Tab(text: 'تحويل'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(controller: controller),
            _InventoryTab(controller: controller),
            _MovementsTab(controller: controller),
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
    return Obx(() {
      final w = controller.warehouse.value;
      return RefreshIndicator(
        onRefresh: controller.refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _InfoCard(w: w),
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
                    color: const Color(0xFF2563EB),
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
                    color: const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'الحركات المتاحة',
                    value: '${controller.movements.length}',
                    icon: Icons.history_rounded,
                    color: const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _InfoCard({required WarehouseModel? w}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(w?.name ?? '',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                if (w?.isDefault ?? false) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 20),
                ],
              ],
            ),
            const SizedBox(height: 8),
            _row(Icons.business_rounded, w?.type.label ?? ''),
            if (w?.address != null && w!.address!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _row(Icons.location_on_outlined, w.address!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: Colors.grey[700])),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
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
        return _empty('لا توجد منتجات في هذا المستودع', Icons.inventory_outlined);
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
              onTap: () => _showBatches(context, s),
            );
          },
        ),
      );
    });
  }

  void _showBatches(BuildContext context, ProductStockSummary sum) {
    controller.loadProductBatches(sum.productId);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BatchesSheet(controller: controller, summary: sum),
    );
  }
}

class _BatchesSheet extends StatelessWidget {
  final WarehouseDetailController controller;
  final ProductStockSummary summary;

  const _BatchesSheet({required this.controller, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(summary.productName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('المتاح: ${_fmt(summary.available)}',
              style: TextStyle(
                  color: Color(0xFF16A34A), fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          const Text('الدفعات',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
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
                      const Text('إجمالي القيمة',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      Text(_moneyText,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Color(0xFF2563EB))),
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
                          tileColor: const Color(0xFFF9FAFB),
                          leading: const Icon(Icons.inventory_2_outlined,
                              color: Color(0xFF2563EB)),
                          title: Text(
                            b.batchNumber ?? 'بدون رقم دفعة',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.expiryDate == null
                                    ? 'بدون تاريخ صلاحية'
                                    : 'انتهاء: ${b.expiryDate}',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12),
                              ),
                              Text('التكلفة: ${MoneyUtils.formatMoney(b.costPrice)}',
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 11)),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_fmt(b.available),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16)),
                              Text(MoneyUtils.formatMoney(lineValue),
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 11)),
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
    final color = summary.available <= 0
        ? Colors.red
        : summary.available <= 5
            ? Colors.orange
            : const Color(0xFF16A34A);
    final stockLabel = summary.available <= 0
        ? 'نفد المخزون'
        : summary.available <= 5
            ? 'مخزون منخفض'
            : 'متوفر';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
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
                  color: color.withOpacity(0.12),
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
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    if (summary.productDescription.isNotEmpty)
                      Text(
                        summary.productDescription,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.circle, size: 8, color: color),
                        const SizedBox(width: 4),
                        Text(stockLabel,
                            style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
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
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 20),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        summary.unitName ?? 'وحدة',
                        style:
                            TextStyle(color: Colors.grey[400], fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(MoneyUtils.formatMoney(summary.value),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
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
              return _empty(controller.errorMessage.value ?? 'خطأ',
                  Icons.error_outline);
            }
            if (controller.isEmptyMovements) {
              return _empty('لا توجد حركات', Icons.history);
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
    final types = InventoryTransactionType.values
        .where((t) => t == InventoryTransactionType.purchase ||
            t == InventoryTransactionType.sale ||
            t == InventoryTransactionType.saleReturn ||
            t == InventoryTransactionType.purchaseReturn ||
            t.isTransfer)
        .toList();

    return Obx(() => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _chip('الكل', null, controller.selectedType.value == null),
              const SizedBox(width: 8),
              for (final t in types) ...[
                _chip(t.label, t, controller.selectedType.value == t),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ));
  }

  Widget _chip(String label, InventoryTransactionType? type, bool selected) {
    return GestureDetector(
      onTap: () => controller.filterByType(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF2563EB)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF374151),
                fontWeight: FontWeight.w600,
                fontSize: 12)),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final InventoryTransactionView view;

  const _MovementTile({required this.view});

  @override
  Widget build(BuildContext context) {
    final type = view.transaction.type;
    final qty = view.transaction.quantity;
    final qtyStr = _fmt(qty);
    final color = _colorFor(type);
    final icon = _iconFor(type);
    final prefix = type.increasesStock ? '+' : '-';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
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
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(type.label,
                            style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                      if (view.invoiceNumber != null) ...[
                        const SizedBox(width: 6),
                        Text(view.invoiceNumber!,
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 11)),
                      ],
                    ],
                  ),
                  if (type.isTransfer && view.counterpartyWarehouseName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '↔ ${view.counterpartyWarehouseName}',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 11),
                      ),
                    ),
                  if (view.batchNumber != null)
                    Text('دفعة: ${view.batchNumber}',
                        style: TextStyle(
                            color: Colors.grey[400], fontSize: 10)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$prefix$qtyStr',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                Text('وحدة',
                    style:
                        TextStyle(color: Colors.grey[400], fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _colorFor(InventoryTransactionType t) => switch (t) {
        InventoryTransactionType.sale => const Color(0xFF2563EB),
        InventoryTransactionType.purchase => const Color(0xFFF59E0B),
        InventoryTransactionType.saleReturn => const Color(0xFF7C3AED),
        InventoryTransactionType.purchaseReturn => const Color(0xFF0891B2),
        InventoryTransactionType.transferOut => const Color(0xFFDC2626),
        InventoryTransactionType.transferIn => const Color(0xFF16A34A),
      };

  IconData _iconFor(InventoryTransactionType t) => switch (t) {
        InventoryTransactionType.sale => Icons.arrow_upward_rounded,
        InventoryTransactionType.purchase => Icons.arrow_downward_rounded,
        InventoryTransactionType.saleReturn => Icons.undo_rounded,
        InventoryTransactionType.purchaseReturn => Icons.redo_rounded,
        InventoryTransactionType.transferOut => Icons.arrow_forward_rounded,
        InventoryTransactionType.transferIn => Icons.arrow_back_rounded,
      };
}

// ==============================
// أدوات مساعدة
// ==============================

Widget _empty(String msg, IconData icon) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Text(msg, style: TextStyle(color: Colors.grey[600], fontSize: 15)),
      ],
    ),
  );
}

String _fmt(double qty) =>
    qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(2);
