import '../../models/business_config.dart';
import '../../models/notification_model.dart';
import '../../repositories/business_settings_repository.dart';
import '../../repositories/notification_repository.dart';
import 'debt_notification_service.dart';
import 'expiry_notification_service.dart';
import 'packaging_notification_service.dart';
import 'stock_notification_service.dart';

class NotificationScanCoordinator {
  NotificationScanCoordinator({
    required this.settingsRepo,
    required this.notificationRepo,
    required this.expiryService,
    required this.stockService,
    required this.debtService,
    required this.packagingService,
  });

  final BusinessSettingsRepository settingsRepo;
  final NotificationRepository notificationRepo;
  final ExpiryNotificationService expiryService;
  final StockNotificationService stockService;
  final DebtNotificationService debtService;
  final PackagingNotificationService packagingService;

  static const _minScanInterval = Duration(seconds: 2);

  bool _scanning = false;
  DateTime? _lastScanAt;

  Future<void> scan({
    bool force = false,
    BusinessSettings? settings,
    DateTime Function()? clock,
  }) async {
    if (_scanning) return;
    final now = (clock ?? DateTime.now)();
    if (!force &&
        _lastScanAt != null &&
        now.difference(_lastScanAt!) < _minScanInterval) {
      return;
    }

    _scanning = true;
    try {
      final current = settings ?? await settingsRepo.load();
      await _run(current, force: force);
      _lastScanAt = (clock ?? DateTime.now)();
    } finally {
      _scanning = false;
    }
  }

  Future<void> _run(BusinessSettings settings, {required bool force}) async {
    final features = settings.features;
    final notify = settings.notifications;

    final expiryOn = features[AppFeature.expiry] == true;
    if (expiryOn) {
      await expiryService.scanExpiringBatches(force: true);
    } else {
      await notificationRepo.resolveActiveByTypes(
        NotificationType.expiryDbValues,
      );
    }

    await stockService.scan(
      lowStockEnabled: notify.lowStock,
      outOfStockEnabled: notify.outOfStock,
    );

    final debtsOn = features[AppFeature.debts] == true;
    if (debtsOn) {
      await debtService.scan(
        dueEnabled: notify.debtDue,
        overdueEnabled: notify.debtOverdue,
        dueDays: notify.debtDueDays,
        overdueDays: notify.debtOverdueDays,
      );
    } else {
      await notificationRepo.resolveActiveByTypes(NotificationType.debtDbValues);
    }

    final packagingOn = features[AppFeature.returnablePackaging] == true;
    if (packagingOn) {
      await packagingService.scan(
        unsettledEnabled: notify.packagingUnsettled,
        overdueEnabled: notify.packagingOverdue,
        overdueDays: notify.packagingOverdueDays,
      );
    } else {
      await notificationRepo
          .resolveActiveByTypes(NotificationType.packagingDbValues);
    }
  }
}
