import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/category_controller.dart';
import '../../models/category_model.dart';

class ProductCategoryListScreen extends StatefulWidget {
  const ProductCategoryListScreen({super.key});

  @override
  State<ProductCategoryListScreen> createState() => ProductCategoryListScreenState();
}

class ProductCategoryListScreenState extends State<ProductCategoryListScreen> {
  final CategoryController controller = Get.find<CategoryController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الأصناف'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCategoryDialog,
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        if (controller.state.value == CategoryLoadState.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.categories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.category_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 12),
                const Text('لا توجد أصناف'),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: controller.categories.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final category = controller.categories[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: category.isPreset ? Colors.blue.shade100 : Colors.green.shade100,
                  child: Icon(
                    category.isPreset ? Icons.star : Icons.category,
                    color: category.isPreset ? Colors.blue : Colors.green,
                  ),
                ),
                title: Text(category.name),
                subtitle: Text(category.isPreset ? 'صنف جاهز' : 'صنف مضاف يدويًا'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'تعديل الصنف',
                      onPressed: () => _editCategory(category),
                    ),
                    if (category.isPreset)
                      const Icon(Icons.lock_outline, color: Colors.grey)
                    else
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'حذف الصنف',
                        onPressed: () => _deleteCategory(category),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }

  Future<void> _showAddCategoryDialog() async {
    final nameController = TextEditingController();

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('إضافة صنف جديد'),
        content: TextField(
          controller: nameController,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(
            hintText: 'اسم الصنف',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final name = nameController.text.trim();
    if (name.isEmpty) {
      Get.snackbar('تنبيه', 'اسم الصنف مطلوب');
      return;
    }

    await controller.addCategory(CategoryModel(name: name));

    if (controller.errorMessage.value == null) {
      Get.snackbar('نجاح', 'تمت إضافة الصنف بنجاح');
      await controller.loadCategories();
    } else {
      Get.snackbar('خطأ', controller.errorMessage.value ?? 'تعذر إضافة الصنف');
    }
  }

  Future<void> _editCategory(CategoryModel category) async {
    final nameController = TextEditingController(text: category.name);

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('تعديل اسم الصنف'),
        content: TextField(
          controller: nameController,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(
            hintText: 'اسم الصنف',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final name = nameController.text.trim();
    if (name.isEmpty) {
      Get.snackbar('تنبيه', 'اسم الصنف مطلوب');
      return;
    }

    await controller.updateCategory(category.copyWith(name: name));

    if (controller.errorMessage.value == null) {
      Get.snackbar('نجاح', 'تم تعديل اسم الصنف بنجاح');
    } else {
      Get.snackbar('خطأ', controller.errorMessage.value ?? 'تعذر تعديل الصنف');
    }
  }

  Future<void> _deleteCategory(CategoryModel category) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('حذف الصنف'),
        content: Text('هل تريد حذف الصنف "${category.name}"؟'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await controller.deleteOrDeactivateCategory(category);
    if (controller.errorMessage.value == null) {
      Get.snackbar('نجاح', 'تم حذف الصنف');
    } else {
      Get.snackbar('خطأ', controller.errorMessage.value ?? 'تعذر حذف الصنف');
    }
  }
}
