import '../../models/notification_model.dart';
import '../../repositories/inventory_repository.dart';
import '../../repositories/notification_repository.dart';
import '../utils/app_dates.dart';

class StockNotificationService {
  StockNotificationService({
    required this.inventoryRepo,
    required this.notificationRepo,
  });

  final InventoryRepository inventoryRepo;
  final NotificationRepository notificationRepo;

  static const _epsilon = 0.0001;

  Future<void> scan({
    required bool lowStockEnabled,
    required bool outOfStockEnabled,
  }) async {
    if (!lowStockEnabled && !outOfStockEnabled) {
      await notificationRepo.resolveActiveByTypes(NotificationType.stockDbValues);
      return;
    }

    final stocks = await inventoryRepo.getAllProductsStock();
    final active = await notificationRepo.getActiveByTypes(
      NotificationType.stockDbValues,
    );
    final byKey = <String, NotificationModel>{
      for (final item in active)
        if (item.productId != null) _key(item.type, item.productId!): item,
    };

    final desiredKeys = <String>{};

    for (final stock in stocks) {
      final desired = _classify(
        stock,
        lowStockEnabled: lowStockEnabled,
        outOfStockEnabled: outOfStockEnabled,
      );
      if (desired == null) continue;

      final key = _key(desired.type.dbValue, stock.productId);
      desiredKeys.add(key);
      final existing = byKey[key];
      if (existing?.id != null) {
        await notificationRepo.updateActiveSnapshot(
          id: existing!.id!,
          title: desired.title,
          message: desired.message,
          priority: desired.priority,
          metadata: desired.metadata,
        );
        continue;
      }

      await notificationRepo.createNotification(
        NotificationModel(
          type: desired.type.dbValue,
          title: desired.title,
          message: desired.message,
          priority: desired.priority,
          entityType: 'product',
          entityId: stock.productId,
          productId: stock.productId,
          metadata: desired.metadata,
        ),
      );
    }

    for (final item in active) {
      final id = item.id;
      final productId = item.productId;
      if (id == null || productId == null) continue;
      final key = _key(item.type, productId);
      if (!desiredKeys.contains(key)) {
        await notificationRepo.resolveNotification(id);
      }
    }
  }

  _DesiredStock? _classify(
    ProductStockSummary stock, {
    required bool lowStockEnabled,
    required bool outOfStockEnabled,
  }) {
    final qtyText = AppDates.formatQuantity(stock.available);
    if (stock.available <= _epsilon) {
      if (!outOfStockEnabled) return null;
      return _DesiredStock(
        type: NotificationType.outOfStock,
        title: NotificationType.outOfStock.label,
        message: 'نفد مخزون «${stock.productName}»',
        priority: NotificationPriority.critical,
        metadata: {
          'productName': stock.productName,
          'quantity': stock.available,
        },
      );
    }

    final minStock = stock.minStock;
    if (!lowStockEnabled || minStock == null || minStock <= 0) {
      return null;
    }
    if (stock.available > minStock) return null;

    return _DesiredStock(
      type: NotificationType.lowStock,
      title: NotificationType.lowStock.label,
      message:
          'مخزون «${stock.productName}» منخفض: $qtyText (الحد الأدنى ${AppDates.formatQuantity(minStock)})',
      priority: NotificationPriority.high,
      metadata: {
        'productName': stock.productName,
        'quantity': stock.available,
        'minStock': minStock,
      },
    );
  }

  String _key(String type, int productId) => '$type|$productId';
}

class _DesiredStock {
  const _DesiredStock({
    required this.type,
    required this.title,
    required this.message,
    required this.priority,
    required this.metadata,
  });

  final NotificationType type;
  final String title;
  final String message;
  final NotificationPriority priority;
  final Map<String, dynamic> metadata;
}
