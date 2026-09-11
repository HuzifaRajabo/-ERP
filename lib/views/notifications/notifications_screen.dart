import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/notification_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/utils/app_dates.dart';
import '../../models/notification_model.dart';
import '../shared/shared_components.dart';
import '../warehouse/warehouse_details_screen.dart';

class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<NotificationController>()) {
      return IconButton(
        tooltip: 'الإشعارات',
        onPressed: () => Get.toNamed('/notifications'),
        icon: const Icon(Icons.notifications_outlined),
      );
    }
    final controller = Get.find<NotificationController>();
    return Obx(() {
      final count = controller.unreadCount.value;
      return IconButton(
        tooltip: 'الإشعارات',
        onPressed: () => Get.toNamed('/notifications'),
        icon: Badge(
          isLabelVisible: count > 0,
          backgroundColor: AppColors.error,
          label: Text(count > 99 ? '99+' : '$count'),
          child: const Icon(Icons.notifications_outlined),
        ),
      );
    });
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<NotificationController>();
    controller.refreshNotifications(forceScan: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          IconButton(
            tooltip: 'تحديد الكل كمقروء',
            icon: const Icon(Icons.done_all_outlined),
            onPressed: _markAllRead,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Obx(() {
              final current = controller.filter.value;
              return Wrap(
                spacing: AppSpacing.sm,
                children: [
                  _FilterChip(
                    label: 'الكل',
                    selected: current == NotificationListFilter.all,
                    onSelected: () => controller.changeFilter(
                      NotificationListFilter.all,
                    ),
                  ),
                  _FilterChip(
                    label: 'غير مقروء',
                    selected: current == NotificationListFilter.unread,
                    onSelected: () => controller.changeFilter(
                      NotificationListFilter.unread,
                    ),
                  ),
                  _FilterChip(
                    label: 'نشط',
                    selected: current == NotificationListFilter.active,
                    onSelected: () => controller.changeFilter(
                      NotificationListFilter.active,
                    ),
                  ),
                ],
              );
            }),
          ),
          Expanded(
            child: Obx(() {
              if (controller.loading.value &&
                  controller.notifications.isEmpty) {
                return const AppLoadingState();
              }
              if (controller.error.value != null &&
                  controller.notifications.isEmpty) {
                return AppErrorState(
                  title: 'تعذر تحميل الإشعارات',
                  message: controller.error.value!,
                  onRetry: () =>
                      controller.refreshNotifications(forceScan: true),
                );
              }
              final items = controller.notifications;
              if (items.isEmpty) {
                return AppEmptyState(
                  icon: Icons.notifications_none_outlined,
                  title: _emptyTitle(controller.filter.value),
                );
              }
              return RefreshIndicator(
                onRefresh: () =>
                    controller.refreshNotifications(forceScan: true),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.xl,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _NotificationCard(
                      notification: item,
                      onTap: () => _open(item),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _emptyTitle(NotificationListFilter filter) {
    return switch (filter) {
      NotificationListFilter.active =>
        'لا توجد تنبيهات تحتاج إلى إجراء حاليًا',
      NotificationListFilter.unread => 'لا توجد إشعارات غير مقروءة',
      NotificationListFilter.all => 'لا توجد إشعارات',
    };
  }

  Future<void> _markAllRead() async {
    if (controller.unreadCount.value <= 0) return;
    await controller.markAllAsRead();
  }

  Future<void> _open(NotificationModel item) async {
    if (item.id != null) {
      await controller.markAsRead(item.id!);
    }
    final target = await controller.resolveNavigation(item);
    if (target.invoice != null) {
      Get.toNamed('/invoice-details', arguments: target.invoice);
      return;
    }
    if (target.warehouse != null) {
      await Get.to(
        () => WarehouseDetailsScreen(
          warehouse: target.warehouse!,
          focusProductId: target.focusProductId,
        ),
      );
      return;
    }
    if (target.product != null) {
      Get.toNamed('/product-details', arguments: target.product);
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  final NotificationModel notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = notification.typed;
    final color = switch (type) {
      NotificationType.expiryExpired ||
      NotificationType.outOfStock ||
      NotificationType.debtOverdue =>
        AppColors.error,
      NotificationType.lowStock ||
      NotificationType.packagingOverdue ||
      NotificationType.debtDue =>
        AppColors.warning,
      _ => AppColors.warning,
    };
    final icon = switch (type) {
      NotificationType.expiryExpired => Icons.event_busy_outlined,
      NotificationType.lowStock || NotificationType.outOfStock =>
        Icons.inventory_2_outlined,
      NotificationType.debtDue || NotificationType.debtOverdue =>
        Icons.account_balance_wallet_outlined,
      NotificationType.packagingUnsettled ||
      NotificationType.packagingOverdue =>
        Icons.liquor_outlined,
      _ => Icons.warning_amber_rounded,
    };
    final unread = !notification.isRead;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  notification.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                ),
              ),
              if (unread)
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (notification.productName.isNotEmpty)
            Text(
              notification.productName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'الدفعة ${notification.batchNumber}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            'المستودع ${notification.warehouseName}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            notification.message,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (notification.expiryDate != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'تاريخ الانتهاء: ${AppDates.formatDisplay(notification.expiryDate)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              AppStatusBadge(
                label: type?.label ?? 'تنبيه',
                color: color,
              ),
              const SizedBox(width: AppSpacing.sm),
              AppStatusBadge(
                label: notification.status.label,
                color: notification.isActive
                    ? AppColors.info
                    : AppColors.textMuted,
              ),
              if (unread) ...[
                const SizedBox(width: AppSpacing.sm),
                const AppStatusBadge(
                  label: 'غير مقروء',
                  color: AppColors.primary,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
