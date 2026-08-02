import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/utils/money_utils.dart';
import '../../controllers/product_controller.dart';
import '../../models/product_model.dart';

class ProductFormScreen extends GetView<ProductController> {
  const ProductFormScreen({super.key});

  bool get isEditing => Get.arguments != null;
  ProductModel? get product => Get.arguments as ProductModel?;

  @override
  Widget build(BuildContext context) {
    final nameController = TextEditingController(text: product?.name);
    final skuController = TextEditingController(text: product?.sku);
    final costController = TextEditingController(
      text: product != null ? MoneyUtils.formatInput(product!.costPrice) : null,
    );
    final saleController = TextEditingController(
      text: product != null ? MoneyUtils.formatInput(product!.salePrice) : null,
    );
    final formKey = GlobalKey<FormState>();

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'تعديل منتج' : 'إضافة منتج')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            children: [
              // ==============================
              // Name
              // ==============================
              _FormField(
                controller: nameController,
                label: 'اسم المنتج',
                icon: Icons.inventory_2_outlined,
                validator: (v) => v!.trim().isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 16),

              // ==============================
              // SKU
              // ==============================
              _FormField(
                controller: skuController,
                label: 'SKU',
                icon: Icons.qr_code,
                validator: (v) => v!.trim().isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 16),

              // ==============================
              // Prices
              // ==============================
              Row(
                children: [
                  Expanded(
                    child: _FormField(
                      controller: costController,
                      label: 'سعر التكلفة',
                      icon: Icons.price_change_outlined,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) {
                        if (v!.trim().isEmpty) return 'مطلوب';
                        if (MoneyUtils.parseAmount(v) == null)
                          return 'أدخل مبلغاً صحيحاً';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FormField(
                      controller: saleController,
                      label: 'سعر البيع',
                      icon: Icons.sell_outlined,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) {
                        if (v!.trim().isEmpty) return 'مطلوب';
                        if (MoneyUtils.parseAmount(v) == null)
                          return 'أدخل مبلغاً صحيحاً';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ==============================
              // Submit Button
              // ==============================
              Obx(
                () => SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: controller.isLoading
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;

                            final newProduct = ProductModel(
                              id: product?.id,
                              name: nameController.text.trim(),
                              sku: skuController.text.trim(),
                              costPrice:
                                  MoneyUtils.parseAmount(costController.text) ??
                                  0,
                              salePrice:
                                  MoneyUtils.parseAmount(saleController.text) ??
                                  0,
                            );

                            if (isEditing) {
                              await controller.updateProduct(newProduct);
                            } else {
                              await controller.addProduct(newProduct);
                            }

                            if (!controller.hasError) Get.back();
                          },
                    icon: controller.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(isEditing ? Icons.save : Icons.add),
                    label: Text(isEditing ? 'حفظ التعديلات' : 'إضافة المنتج'),
                  ),
                ),
              ),

              // ==============================
              // Error Message
              // ==============================
              Obx(
                () => controller.hasError
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          controller.errorMessage.value ?? '',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================
// Reusable Form Field
// ==============================

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      textDirection: TextDirection.rtl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
