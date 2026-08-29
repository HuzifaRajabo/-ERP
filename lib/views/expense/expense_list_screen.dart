import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/expense_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../models/expense_model.dart';
import '../../core/utils/money_utils.dart';
import '../shared/shared_components.dart';

class ExpenseListScreen extends GetView<ExpenseController> {
  const ExpenseListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المصاريف'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.refreshExpenses,
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading) {
          return const AppLoadingState(message: 'جارٍ تحميل المصاريف...');
        }

        if (controller.hasError) {
          return AppErrorState(
            message: controller.errorMessage.value ?? 'خطأ غير معروف',
            onRetry: controller.refreshExpenses,
          );
        }

        if (controller.isEmpty) {
          return const AppEmptyState(
            icon: Icons.money_off_outlined,
            title: 'لا توجد مصاريف حتى الآن',
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refreshExpenses,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemCount:
                controller.expenses.length + (controller.hasMore.value ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == controller.expenses.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _ExpenseCard(expense: controller.expenses[index]);
            },
          ),
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          controller.initNewExpense();
          Get.toNamed('/expense-form');
        },
        icon: const Icon(Icons.add),
        label: const Text('مصروف جديد'),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final ExpenseModel expense;

  const _ExpenseCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ExpenseController>();

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () {
        controller.initExpenseForm(expense);
        Get.toNamed('/expense-form', arguments: expense);
      },
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: const Icon(Icons.money_off, color: AppColors.error),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  expense.category.label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (expense.createdAt != null)
                  Text(
                    expense.createdAt!,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                MoneyUtils.formatMoney(expense.amount),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: () =>
                    _confirmDelete(context, controller, expense.id!),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    ExpenseController controller,
    int id,
  ) {
    AppConfirmDialog.show(
      context,
      title: 'حذف المصروف',
      message: 'هل تريد حذف هذا المصروف؟',
      confirmLabel: 'حذف',
      cancelLabel: 'إلغاء',
      isDestructive: true,
    ).then((confirmed) async {
      if (confirmed != true) return;
      await controller.deleteExpense(id);
    });
  }
}
