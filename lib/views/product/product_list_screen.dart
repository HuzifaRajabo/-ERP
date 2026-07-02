import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/product_controller.dart';
import '../../models/product_model.dart';

class ProductListScreen extends GetView<ProductController> {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المنتجات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.refreshProducts,
          ),
        ],
      ),
      body: Column(
        children: [
          _SearchBar(controller: controller),
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
// Search Bar
// ==============================

class _SearchBar extends StatelessWidget {
  final ProductController controller;

  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Obx(() => TextField(
        onChanged: controller.search,
        decoration: InputDecoration(
          hintText: 'بحث عن منتج...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.searchKeyword.value.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: controller.clearSearch,
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
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
            separatorBuilder: (_, __) => const SizedBox(height: 8),
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'SKU: ${product.sku}',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
              onPressed: () => Get.toNamed('/product-form', arguments: product),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
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
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ==============================
// Empty View
// ==============================

class _EmptyView extends StatelessWidget {
  final bool isSearching;

  const _EmptyView({required this.isSearching});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off : Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            isSearching ? 'لا توجد نتائج' : 'لا توجد منتجات',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

// ==============================
// Error View
// ==============================

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}