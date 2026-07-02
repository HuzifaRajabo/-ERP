import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/inventory_controller.dart';
import '../../models/inventory_transaction_model.dart';
import '../../repositories/inventory_repository.dart';

class InventoryScreen extends GetView<InventoryController> {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المستودع'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: controller.refreshAll,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.inventory_outlined), text: 'المخزون'),
              Tab(icon: Icon(Icons.history), text: 'الحركات'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _StockTab(),
            _TransactionsTab(),
          ],
        ),
      ),
    );
  }
}

// ==============================
// Tab 1: ملخص المخزون
// ==============================

class _StockTab extends GetView<InventoryController> {
  const _StockTab();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingStock.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.stockSummaries.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warehouse_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('لا توجد منتجات في المستودع',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: controller.loadStockSummaries,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: controller.stockSummaries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            return _StockCard(
              summary: controller.stockSummaries[index],
            );
          },
        ),
      );
    });
  }
}

class _StockCard extends GetView<InventoryController> {
  final ProductStockSummary summary;

  const _StockCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    // تحديد لون المخزون بناء على الكمية المتاحة
    final stockColor = summary.available <= 0
        ? Colors.red
        : summary.available <= 5
        ? Colors.orange
        : Colors.green;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => controller.filterByProduct(summary.productId),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  // أيقونة المنتج
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: stockColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.inventory_2_outlined,
                        color: stockColor),
                  ),
                  const SizedBox(width: 12),

                  // اسم المنتج والـ SKU
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.productName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          'SKU: ${summary.productSku}',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  // الكمية المتاحة
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatQty(summary.available),
                        style: TextStyle(
                          color: stockColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      Text(
                        'متاح',
                        style: TextStyle(
                            color: Colors.grey[400], fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // مشتريات ومبيعات
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'مشتريات',
                      value: _formatQty(summary.totalPurchased),
                      icon: Icons.arrow_downward_rounded,
                      color: Colors.orange,
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      label: 'مبيعات',
                      value: _formatQty(summary.totalSold),
                      icon: Icons.arrow_upward_rounded,
                      color: Colors.blue,
                    ),
                  ),
                  // شريط التقدم (نسبة المباع)
                  Expanded(
                    child: summary.totalPurchased > 0
                        ? Column(
                      children: [
                        Text(
                          '${((summary.totalSold / summary.totalPurchased) * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: stockColor,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: (summary.totalSold /
                              summary.totalPurchased)
                              .clamp(0, 1),
                          color: stockColor,
                          backgroundColor:
                          stockColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        Text(
                          'نسبة المباع',
                          style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 10),
                        ),
                      ],
                    )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatQty(double qty) =>
      qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(2);
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: color)),
            Text(label,
                style:
                TextStyle(color: Colors.grey[400], fontSize: 10)),
          ],
        ),
      ],
    );
  }
}

// ==============================
// Tab 2: سجل الحركات
// ==============================

class _TransactionsTab extends GetView<InventoryController> {
  const _TransactionsTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TransactionFilters(controller: controller),
        const Expanded(child: _TransactionList()),
      ],
    );
  }
}

class _TransactionFilters extends StatelessWidget {
  final InventoryController controller;

  const _TransactionFilters({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // زر إلغاء الفلتر إن كان فلتر منتج نشطاً
          if (controller.selectedProductId.value != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ActionChip(
                label: const Text('إلغاء فلتر المنتج'),
                avatar: const Icon(Icons.close, size: 16),
                onPressed: controller.clearFilters,
              ),
            ),

          _FilterChip(
            label: 'الكل',
            selected: controller.selectedType.value == null &&
                controller.selectedProductId.value == null,
            color: Colors.blueGrey,
            onTap: controller.clearFilters,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'مشتريات',
            selected: controller.selectedType.value ==
                InventoryTransactionType.purchase,
            color: Colors.orange,
            onTap: () => controller
                .filterByType(InventoryTransactionType.purchase),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'مبيعات',
            selected: controller.selectedType.value ==
                InventoryTransactionType.sale,
            color: Colors.blue,
            onTap: () =>
                controller.filterByType(InventoryTransactionType.sale),
          ),
        ],
      ),
    ));
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _TransactionList extends GetView<InventoryController> {
  const _TransactionList();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.hasError) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 12),
              Text(controller.errorMessage.value ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: controller.refreshAll,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        );
      }

      if (controller.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('لا توجد حركات مخزون',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            ],
          ),
        );
      }

      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >=
              notification.metrics.maxScrollExtent - 200) {
            controller.loadMore();
          }
          return false;
        },
        child: RefreshIndicator(
          onRefresh: controller.refreshAll,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: controller.transactions.length +
                (controller.hasMore.value ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              if (index == controller.transactions.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _TransactionCard(
                  view: controller.transactions[index]);
            },
          ),
        ),
      );
    });
  }
}

class _TransactionCard extends StatelessWidget {
  final InventoryTransactionView view;

  const _TransactionCard({required this.view});

  @override
  Widget build(BuildContext context) {
    final isSale =
        view.transaction.type == InventoryTransactionType.sale;
    final color = isSale ? Colors.blue : Colors.orange;
    final icon = isSale
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
    final label = isSale ? 'بيع' : 'شراء';
    final qty = view.transaction.quantity;
    final qtyStr = qty % 1 == 0
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // أيقونة النوع
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

            // المعلومات
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    view.productName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
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
                        child: Text(
                          label,
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        view.invoiceNumber,
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                  if (view.transaction.createdAt != null)
                    Text(
                      view.transaction.createdAt!,
                      style: TextStyle(
                          color: Colors.grey[400], fontSize: 11),
                    ),
                ],
              ),
            ),

            // الكمية
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isSale ? '-$qtyStr' : '+$qtyStr',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text('وحدة',
                    style: TextStyle(
                        color: Colors.grey[400], fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}