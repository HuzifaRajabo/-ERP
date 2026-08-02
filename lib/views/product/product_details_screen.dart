import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/utils/money_utils.dart';
import '../../controllers/product_controller.dart';
import '../../core/services/app_event_bus.dart';
import '../../models/product_model.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late ProductModel product;
  final controller = Get.find<ProductController>();

  @override
  void initState() {
    super.initState();
    product = Get.arguments as ProductModel;

    // عند أي تغيير في المنتجات أعد جلب هذا المنتج
    AppEventBus.instance.listenToProducts(() async {
      final updated = await controller.repo.getProductById(product.id!);
      if (updated != null && mounted) {
        setState(() => product = updated);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final margin = product.salePrice - product.costPrice;
    final isLoss = margin < 0;
    final marginColor = isLoss ? Colors.red : Colors.green;
    final marginIcon = isLoss ? Icons.trending_down : Icons.trending_up;
    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Get.toNamed('/product-form', arguments: product),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ==============================
          // Header
          // ==============================
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 40,
                color: Colors.blue.shade400,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              product.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'SKU: ${product.sku}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 24),

          // ==============================
          // Info Cards
          // ==============================
          Row(
            children: [
              Expanded(
                child: _InfoCard(
                  label: 'سعر التكلفة',
                  value: MoneyUtils.formatMoney(product.costPrice),
                  icon: Icons.price_change_outlined,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoCard(
                  label: 'سعر البيع',
                  value: MoneyUtils.formatMoney(product.salePrice),
                  icon: Icons.sell_outlined,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoCard(
            label: isLoss ? 'خسارة' : 'هامش الربح',
            value: MoneyUtils.formatMoney(margin.abs()),
            icon: marginIcon,
            color: marginColor,
          ),
          const SizedBox(height: 12),

          if (product.createdAt != null)
            _InfoCard(
              label: 'تاريخ الإضافة',
              value: product.createdAt!,
              icon: Icons.calendar_today_outlined,
              color: Colors.purple,
            ),

          const SizedBox(height: 32),

          // ==============================
          // Edit Button
          // ==============================
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => Get.toNamed('/product-form', arguments: product),
              icon: const Icon(Icons.edit),
              label: const Text('تعديل المنتج'),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text('هل تريد حذف "${product.name}"؟'),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              Get.back();
              await controller.deleteProduct(product.id!);
              if (!controller.hasError) Get.back();
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ==============================
// Info Card
// ==============================

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
