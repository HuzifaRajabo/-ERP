import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/product_controller.dart';
import '../../models/product_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../views/shared/shared_components.dart';

class ProductListScreen extends GetView<ProductController> {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المنتجات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'الأصناف',
            onPressed: () => Get.toNamed('/product-categories'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.refreshProducts,
          ),
        ],
      ),
      body: Column(
        children: [
          _SearchBar(controller: controller),
          _CategoryFilterBar(controller: controller),
          const Expanded(child: _ProductList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.toNamed('/product-form'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ==============================
// Category Filter Bar
// ==============================

class _CategoryFilterBar extends StatelessWidget {
  final ProductController controller;

  const _CategoryFilterBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.categories.isEmpty) return const SizedBox.shrink();

      return SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            _CategoryChip(
              label: 'الكل',
              selected: controller.selectedCategoryId.value == null,
              onTap: controller.clearCategoryFilter,
            ),
            const SizedBox(width: 8),
            ...controller.categories.map(
              (category) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _CategoryChip(
                  label: category.name,
                  selected: controller.selectedCategoryId.value == category.id,
                  onTap: () => controller.filterByCategory(category.id),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppStatusBadge(
        label: label,
        color: selected ? Theme.of(context).colorScheme.primary : null,
        icon: null,
      ),
    );
  }
}

// ==============================
// Search Bar
// ==============================

class _SearchBar extends StatelessWidget {
  final ProductController controller;

  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Obx(() => AppSearchField(
        hint: 'بحث عن منتج...',
        onChanged: controller.search,
        onClear: controller.searchKeyword.value.isNotEmpty
            ? controller.clearSearch
            : null,
      )),
    );
  }
}

// ==============================
// Product List
// ==============================

class _ProductList extends GetView<ProductController> {
  const _ProductList();

  @override
  Widget build(BuildContext context) {
    return Obx(() {

      // Loading
      if (controller.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      // Error
      if (controller.hasError) {
        return _ErrorView(
          message: controller.errorMessage.value ?? 'خطأ غير معروف',
          onRetry: controller.refreshProducts,
        );
      }

      // Empty
      if (controller.isEmpty) {
        return _EmptyView(
          isSearching: controller.searchKeyword.value.isNotEmpty,
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
          onRefresh: controller.refreshProducts,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: controller.products.length + (controller.hasMore.value ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {

              // Loading More Indicator
              if (index == controller.products.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              return _ProductCard(product: controller.products[index]);
            },
          ),
        ),
      );
    });
  }
}

// ==============================
// Product Card
// ==============================

class _ProductCard extends GetView<ProductController> {
  final ProductModel product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        title: Text(
          product.name,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.description.isNotEmpty)
              Text(
                product.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (product.categoryName != null)
              Padding(
                padding: EdgeInsets.only(top: AppSpacing.xs),
                child: AppStatusBadge(
                  label: product.categoryName!,
                  color: Theme.of(context).colorScheme.primary,
                  icon: Icons.category_outlined,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Get.toNamed('/product-form', arguments: product),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
        onTap: () => Get.toNamed('/product-details', arguments: product),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text('هل تريد حذف "${product.name}"؟'),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.deleteProduct(product.id!);
            },
            child: const Text('حذف', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ==============================
// Empty View
// ==============================

// ==============================
// Empty View
// ==============================

class _EmptyView extends StatelessWidget {
  final bool isSearching;

  const _EmptyView({required this.isSearching});

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: isSearching ? Icons.search_off : Icons.inventory_2_outlined,
      title: isSearching ? 'لا توجد نتائج' : 'لا توجد منتجات',
    );
  }
}

// ==============================
// Error View
// ==============================

// ==============================
// Error View
// ==============================

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AppErrorState(
      message: message,
      title: 'حدث خطأ',
      onRetry: onRetry,
    );
  }
}