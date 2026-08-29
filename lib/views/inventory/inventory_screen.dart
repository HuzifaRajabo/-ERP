import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/inventory_controller.dart';
import '../../models/inventory_transaction_model.dart';
import '../../repositories/inventory_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../shared/shared_components.dart';

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
        body: const TabBarView(children: [_StockTab(), _TransactionsTab()]),
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
        return const AppLoadingState();
      }

      if (controller.stockSummaries.isEmpty) {
        return const AppEmptyState(
          icon: Icons.warehouse_outlined,
          title: 'لا توجد منتجات في المستودع',
        );
      }

      return RefreshIndicator(
        onRefresh: controller.loadStockSummaries,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: controller.stockSummaries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            return _StockCard(summary: controller.stockSummaries[index]);
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
    // المؤثرات اللونية حسب الكمية المتاحة
    final Color stockColor;
    final IconData stockIcon;
    final String stockLabel;

    if (summary.available <= 0) {
      stockColor = Theme.of(context).colorScheme.error;
      stockIcon = Icons.warning_amber_rounded;
      stockLabel = 'نفد المخزون';
    } else if (summary.available <= 5) {
      stockColor = AppColors.warning;
      stockIcon = Icons.info_outline;
      stockLabel = 'مخزون منخفض';
    } else {
      stockColor = AppColors.success;
      stockIcon = Icons.check_circle_outline;
      stockLabel = 'متوفر';
    }

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => controller.filterByProduct(summary.productId),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            // أيقونة المنتج
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: stockColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                color: stockColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),

            // اسم المنتج والـ description وحالة المخزون
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (summary.productDescription.isNotEmpty)
                    Text(
                      summary.productDescription,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(stockIcon, size: 13, color: stockColor),
                      const SizedBox(width: 4),
                      Text(
                        stockLabel,
                        style: TextStyle(
                          color: stockColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // الكمية المتاحة فقط
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatQty(summary.available),
                  style: TextStyle(
                    color: stockColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ),
                ),
                Text(
                  summary.unitName ?? 'وحدة',
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatQty(double qty) =>
      qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(2);
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
    return Obx(
      () => SingleChildScrollView(
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
              selected:
                  controller.selectedType.value == null &&
                  controller.selectedProductId.value == null,
              color: Theme.of(context).colorScheme.secondary,
              onTap: controller.clearFilters,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'مشتريات',
              selected:
                  controller.selectedType.value ==
                  InventoryTransactionType.purchase,
              color: AppColors.warning,
              onTap: () =>
                  controller.filterByType(InventoryTransactionType.purchase),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'مبيعات',
              selected:
                  controller.selectedType.value ==
                  InventoryTransactionType.sale,
              color: Theme.of(context).colorScheme.primary,
              onTap: () =>
                  controller.filterByType(InventoryTransactionType.sale),
            ),
          ],
        ),
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      /* AnimatedContainer(
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
      ), */
    );
  }
}

class _TransactionList extends GetView<InventoryController> {
  const _TransactionList();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading) {
        return const AppLoadingState();
      }

      if (controller.hasError) {
        return AppErrorState(
          message: controller.errorMessage.value ?? 'تعذر تحميل الحركات',
          onRetry: controller.refreshAll,
        );
      }

      if (controller.isEmpty) {
        return const AppEmptyState(
          icon: Icons.history,
          title: 'لا توجد حركات مخزون',
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
            itemCount:
                controller.transactions.length +
                (controller.hasMore.value ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              if (index == controller.transactions.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _TransactionCard(view: controller.transactions[index]);
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
    final type = view.transaction.type;
    final qty = view.transaction.quantity;
    final qtyStr = qty % 1 == 0
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);

    final Color color = switch (type) {
      InventoryTransactionType.sale => Theme.of(context).colorScheme.primary,
      InventoryTransactionType.purchase => AppColors.warning,
      InventoryTransactionType.saleReturn => Theme.of(
        context,
      ).colorScheme.secondary,
      InventoryTransactionType.purchaseReturn => AppColors.info,
      InventoryTransactionType.transferOut => Theme.of(
        context,
      ).colorScheme.error,
      InventoryTransactionType.transferIn => AppColors.success,
    };

    final IconData icon = switch (type) {
      InventoryTransactionType.sale => Icons.arrow_upward_rounded,
      InventoryTransactionType.purchase => Icons.arrow_downward_rounded,
      InventoryTransactionType.saleReturn => Icons.undo_rounded,
      InventoryTransactionType.purchaseReturn => Icons.redo_rounded,
      InventoryTransactionType.transferOut => Icons.arrow_forward_rounded,
      InventoryTransactionType.transferIn => Icons.arrow_back_rounded,
    };

    final String label = type.label;
    final String qtyPrefix = type.increasesStock ? '+' : '-';

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
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      AppStatusBadge(label: label, color: color),
                      const SizedBox(width: 6),
                      if (view.invoiceNumber != null)
                        Text(
                          view.invoiceNumber!,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  if (view.transaction.createdAt != null)
                    Text(
                      view.transaction.createdAt!,
                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                    ),
                ],
              ),
            ),

            // الكمية
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$qtyPrefix$qtyStr',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  view.unitName ?? 'وحدة',
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
