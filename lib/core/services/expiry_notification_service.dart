import '../utils/app_dates.dart';
import '../../models/notification_model.dart';
import '../../repositories/app_settings_repository.dart';
import '../../repositories/batch_repository.dart';
import '../../repositories/notification_repository.dart';

class ExpiryNotificationService {
  ExpiryNotificationService({
    required this.settingsRepo,
    required this.notificationRepo,
    required this.batchRepo,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppSettingsRepository settingsRepo;
  final NotificationRepository notificationRepo;
  final BatchRepository batchRepo;
  final DateTime Function() _clock;

  static const _minScanInterval = Duration(seconds: 2);

  bool _scanning = false;
  DateTime? _lastScanAt;

  Future<void> scanExpiringBatches({bool force = false}) async {
    if (_scanning) return;
    final now = _clock();
    if (!force &&
        _lastScanAt != null &&
        now.difference(_lastScanAt!) < _minScanInterval) {
      return;
    }

    _scanning = true;
    try {
      await _scan(now);
      _lastScanAt = _clock();
    } finally {
      _scanning = false;
    }
  }

  Future<void> _scan(DateTime now) async {
    final warningDays = await settingsRepo.getExpiryWarningDays();
    final enabled = await settingsRepo.isExpiryAlertsEnabled();
    final today = AppDates.dateOnly(now);
    final threshold = AppDates.toIsoDate(today.add(Duration(days: warningDays)));

    final stocks = await batchRepo.getAlertableExpiryStocks(
      expiryOnOrBefore: threshold,
    );

    final desired = <_DesiredExpiry>[];
    for (final stock in stocks) {
      final classified = _classify(stock, today, warningDays);
      if (classified != null) desired.add(classified);
    }

    final active = await notificationRepo.getActiveExpiryNotifications();
    final byTypeKey = <String, NotificationModel>{};
    for (final item in active) {
      final batchId = item.batchId;
      final warehouseId = item.warehouseId;
      if (batchId == null || warehouseId == null) continue;
      byTypeKey[_typeKey(item.type, batchId, warehouseId)] = item;
    }

    final desiredTypeKeys = <String>{};
    final matchingLocations = <String>{};

    for (final item in desired) {
      matchingLocations.add(_locationKey(item.batchId, item.warehouseId));
      final typeKey =
          _typeKey(item.type.dbValue, item.batchId, item.warehouseId);
      desiredTypeKeys.add(typeKey);

      final existingSame = byTypeKey[typeKey];
      if (existingSame?.id != null) {
        await notificationRepo.updateActiveSnapshot(
          id: existingSame!.id!,
          title: item.title,
          message: item.message,
          priority: item.priority,
          metadata: item.metadata,
        );
        continue;
      }

      if (!enabled) continue;

      await notificationRepo.createNotification(
        NotificationModel(
          type: item.type.dbValue,
          title: item.title,
          message: item.message,
          priority: item.priority,
          status: NotificationStatus.active,
          entityType: 'batch',
          entityId: item.batchId,
          productId: item.productId,
          batchId: item.batchId,
          warehouseId: item.warehouseId,
          metadata: item.metadata,
        ),
      );
    }

    for (final item in active) {
      final id = item.id;
      final batchId = item.batchId;
      final warehouseId = item.warehouseId;
      if (id == null || batchId == null || warehouseId == null) continue;

      if (enabled) {
        final key = _typeKey(item.type, batchId, warehouseId);
        if (!desiredTypeKeys.contains(key)) {
          await notificationRepo.resolveNotification(id);
        }
      } else {
        final location = _locationKey(batchId, warehouseId);
        if (!matchingLocations.contains(location)) {
          await notificationRepo.resolveNotification(id);
        }
      }
    }
  }

  _DesiredExpiry? _classify(
    AlertableExpiryStock stock,
    DateTime today,
    int warningDays,
  ) {
    final days = AppDates.daysUntil(stock.expiryDate, today);
    if (days == null) return null;

    final NotificationType type;
    if (days <= 0) {
      type = NotificationType.expiryExpired;
    } else if (days <= warningDays) {
      type = NotificationType.expiryWarning;
    } else {
      return null;
    }

    final batchNumber = (stock.batchNumber ?? '').trim().isEmpty
        ? 'بدون رقم'
        : stock.batchNumber!.trim();
    final unit = (stock.unitName ?? '').trim();
    final qtyText = AppDates.formatQuantity(stock.available);
    final qtyLine = unit.isEmpty ? qtyText : '$qtyText $unit';
    final expiryText = AppDates.formatDisplay(stock.expiryDate);

    final title = type.label;
    final message = type == NotificationType.expiryExpired
        ? (days == 0
            ? 'انتهت اليوم — الكمية الحالية: $qtyLine'
            : 'انتهت في $expiryText — الكمية الحالية: $qtyLine')
        : 'تنتهي بعد $days يوم — الكمية: $qtyLine';

    return _DesiredExpiry(
      type: type,
      productId: stock.productId,
      batchId: stock.batchId,
      warehouseId: stock.warehouseId,
      title: title,
      message: message,
      priority: type == NotificationType.expiryExpired
          ? NotificationPriority.critical
          : NotificationPriority.high,
      metadata: {
        'productName': stock.productName,
        'batchNumber': batchNumber,
        'warehouseName': stock.warehouseName,
        'expiryDate': stock.expiryDate,
        'quantity': stock.available,
        'daysRemaining': days,
        if (unit.isNotEmpty) 'unitName': unit,
      },
    );
  }

  String _typeKey(String type, int batchId, int warehouseId) =>
      '$type|$batchId|$warehouseId';

  String _locationKey(int batchId, int warehouseId) => '$batchId|$warehouseId';
}

class _DesiredExpiry {
  const _DesiredExpiry({
    required this.type,
    required this.productId,
    required this.batchId,
    required this.warehouseId,
    required this.title,
    required this.message,
    required this.priority,
    required this.metadata,
  });

  final NotificationType type;
  final int productId;
  final int batchId;
  final int warehouseId;
  final String title;
  final String message;
  final NotificationPriority priority;
  final Map<String, dynamic> metadata;
}
