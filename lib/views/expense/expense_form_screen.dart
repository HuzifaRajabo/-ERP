import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/utils/money_utils.dart';
import '../../controllers/expense_controller.dart';
import '../../models/expense_model.dart';

class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final controller = Get.find<ExpenseController>();
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final expense = Get.arguments as ExpenseModel?;
    if (expense != null) {
      controller.initExpenseForm(expense);
    } else {
      controller.initNewExpense();
    }
    amountController.text = controller.amount.value > 0
        ? MoneyUtils.formatInput(controller.amount.value)
        : '';
    descriptionController.text = controller.description.value;
  }

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() {
          final isEditing = controller.editingExpense.value != null;
          return Text(isEditing ? 'تعديل المصروف' : 'مصروف جديد');
        }),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'المبلغ',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              onChanged: controller.setAmount,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'الوصف',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: controller.setDescription,
            ),
            const SizedBox(height: 16),
            Obx(
              () => DropdownButtonFormField<ExpenseCategory>(
                initialValue: controller.category.value,
                decoration: const InputDecoration(
                  labelText: 'التصنيف',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
                items: ExpenseCategory.values
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    controller.setCategory(value);
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            Obx(() {
              if (controller.formError.value != null) {
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    controller.formError.value!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
            const SizedBox(height: 24),
            Obx(
              () => SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: controller.isSaving.value
                      ? null
                      : () async {
                          final success = await controller.saveExpense();
                          if (success) {
                            Get.back();
                            Get.snackbar(
                              'تم',
                              'تم حفظ المصروف بنجاح',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: AppColors.success,
                              colorText: Colors.white,
                            );
                          }
                        },
                  child: controller.isSaving.value
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        )
                      : const Text('حفظ المصروف'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
