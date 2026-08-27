import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/warehouse_controller.dart';
import '../../models/warehouse_model.dart';
import 'warehouse_details_screen.dart';
import 'warehouse_form_screen.dart';

class WarehouseListScreen extends GetView<WarehouseController> {
  const WarehouseListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('المستودعات'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: controller.loadWarehouses,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.to(() => const WarehouseFormScreen()),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('مستودع جديد'),
      ),
      body: Obx(() {
        switch (controller.state.value) {
          case WarehouseLoadState.loading:
            return const Center(child: CircularProgressIndicator());
          case WarehouseLoadState.error:
            return _ErrorState(
              message: controller.errorMessage.value ??
                  'تعذر تحميل المستودعات',
              onRetry: () => controller.loadWarehouses(),
            );
          case WarehouseLoadState.idle:
            if (controller.warehouses.isEmpty) {
              return _EmptyState(onAdd: () => Get.to(() => const WarehouseFormScreen()));
            }
            return RefreshIndicator(
              onRefresh: controller.loadWarehouses,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: controller.warehouses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final w = controller.warehouses[index];
                  return _WarehouseCard(
                    warehouse: w,
                    onTap: () => Get.to(
                      () => WarehouseDetailsScreen(warehouse: w),
                    ),
                  );
                },
              ),
            );
        }
      }),
    );
  }
}

class _WarehouseCard extends StatelessWidget {
  final WarehouseModel warehouse;
  final VoidCallback onTap;

  const _WarehouseCard({required this.warehouse, required this.onTap});

  Color get _typeColor => switch (warehouse.type) {
        WarehouseType.main => const Color(0xFF2563EB),
        WarehouseType.van => const Color(0xFFF59E0B),
        WarehouseType.branch => const Color(0xFF16A34A),
      };

  IconData get _typeIcon => switch (warehouse.type) {
        WarehouseType.main => Icons.warehouse_rounded,
        WarehouseType.van => Icons.local_shipping_rounded,
        WarehouseType.branch => Icons.store_mall_directory_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_typeIcon, color: _typeColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            warehouse.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (warehouse.isDefault) ...[
                          const SizedBox(width: 6),
                          const _Badge(text: 'افتراضي', color: Color(0xFF2563EB)),
                        ],
                        if (!warehouse.isActive) ...[
                          const SizedBox(width: 6),
                          const _Badge(text: 'معطل', color: Color(0xFFDC2626)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          warehouse.type.label,
                          style: TextStyle(
                            color: _typeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (warehouse.address != null &&
                            warehouse.address!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              warehouse.address!,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.warehouse_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('لا توجد مستودعات',
              style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('إضافة مستودع'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFDC2626)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
