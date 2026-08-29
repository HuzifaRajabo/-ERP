import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/warehouse_controller.dart';
import '../../models/warehouse_model.dart';
import 'warehouse_details_screen.dart';
import 'warehouse_form_screen.dart';
import '../shared/shared_components.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';

class WarehouseListScreen extends GetView<WarehouseController> {
  const WarehouseListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        icon: const Icon(Icons.add),
        label: const Text('مستودع جديد'),
      ),
      body: Obx(() {
        switch (controller.state.value) {
          case WarehouseLoadState.loading:
            return const AppLoadingState();
          case WarehouseLoadState.error:
            return AppErrorState(
              message: controller.errorMessage.value ?? 'تعذر تحميل المستودعات',
              onRetry: () => controller.loadWarehouses(),
            );
          case WarehouseLoadState.idle:
            if (controller.warehouses.isEmpty) {
              return AppEmptyState(
                icon: Icons.warehouse_outlined,
                title: 'لا توجد مستودعات',
                action: FilledButton.icon(
                  onPressed: () => Get.to(() => const WarehouseFormScreen()),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة مستودع'),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: controller.loadWarehouses,
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: controller.warehouses.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final w = controller.warehouses[index];
                  return _WarehouseCard(
                    warehouse: w,
                    onTap: () =>
                        Get.to(() => WarehouseDetailsScreen(warehouse: w)),
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
    WarehouseType.main => AppColors.primary,
    WarehouseType.van => AppColors.warning,
    WarehouseType.branch => AppColors.success,
  };

  IconData get _typeIcon => switch (warehouse.type) {
    WarehouseType.main => Icons.warehouse_rounded,
    WarehouseType.van => Icons.local_shipping_rounded,
    WarehouseType.branch => Icons.store_mall_directory_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
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
                        AppStatusBadge(
                          label: 'افتراضي',
                          color: AppColors.primary,
                        ),
                      ],
                      if (!warehouse.isActive) ...[
                        const SizedBox(width: 6),
                        AppStatusBadge(
                          label: 'معطل',
                          color: Theme.of(context).colorScheme.error,
                        ),
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
    );
  }
}
