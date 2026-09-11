import '../../models/notification_model.dart';
import '../../models/returnable_packaging_model.dart';
import '../../repositories/notification_repository.dart';
import '../../repositories/returnable_packaging_repository.dart';
import '../utils/app_dates.dart';

class PackagingNotificationService {
  PackagingNotificationService({
    required this.packagingRepo,
    required this.notificationRepo,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ReturnablePackagingRepository packagingRepo;
  final NotificationRepository notificationRepo;
  final DateTime Function() _clock;

  Future<void> scan({
    required bool unsettledEnabled,
    required bool overdueEnabled,
    required int overdueDays,
  }) async {
    if (!unsettledEnabled && !overdueEnabled) {
      await notificationRepo
          .resolveActiveByTypes(NotificationType.packagingDbValues);
      return;
    }

    final rows = await packagingRepo.getUnsettledAlertRows();
    final active = await notificationRepo.getActiveByTypes(
      NotificationType.packagingDbValues,
    );
    final byKey = <String, NotificationModel>{
      for (final item in active) _itemKey(item): item,
    };

    final today = AppDates.dateOnly(_clock());
    final desiredKeys = <String>{};

    for (final row in rows) {
      if (row.unsettled <= ReturnablePackagingRepository.epsilon) continue;
      final classified = _classify(
        row,
        today: today,
        unsettledEnabled: unsettledEnabled,
        overdueEnabled: overdueEnabled,
        overdueDays: overdueDays,
      );
      if (classified == null) continue;

      final key = _rowKey(classified.type.dbValue, row.partyId, row.typeId);
      desiredKeys.add(key);
      final existing = byKey[key];
      if (existing?.id != null) {
        await notificationRepo.updateActiveSnapshot(
          id: existing!.id!,
          title: classified.title,
          message: classified.message,
          priority: classified.priority,
          metadata: classified.metadata,
        );
        continue;
      }

      await notificationRepo.createNotification(
        NotificationModel(
          type: classified.type.dbValue,
          title: classified.title,
          message: classified.message,
          priority: classified.priority,
          entityType: 'packaging',
          entityId: row.partyId,
          metadata: classified.metadata,
        ),
      );
    }

    for (final item in active) {
      final id = item.id;
      if (id == null) continue;
      if (!desiredKeys.contains(_itemKey(item))) {
        await notificationRepo.resolveNotification(id);
      }
    }
  }

  _DesiredPackaging? _classify(
    PackagingAlertRow row, {
    required DateTime today,
    required bool unsettledEnabled,
    required bool overdueEnabled,
    required int overdueDays,
  }) {
    final qty = AppDates.formatQuantity(row.unsettled);
    final issued = DateTime.tryParse(row.oldestIssuedAt ?? '');
    final age = issued == null
        ? 0
        : today.difference(AppDates.dateOnly(issued)).inDays;

    if (overdueEnabled && issued != null && age >= overdueDays) {
      return _DesiredPackaging(
        type: NotificationType.packagingOverdue,
        title: NotificationType.packagingOverdue.label,
        message:
            'عبوات «${row.typeName}» لدى «${row.partyName}» متأخرة $age يوم — غير مسوّى $qty',
        priority: NotificationPriority.high,
        metadata: {
          'partyName': row.partyName,
          'typeName': row.typeName,
          'typeId': row.typeId,
          'unsettled': row.unsettled,
          'ageDays': age,
        },
      );
    }

    if (!unsettledEnabled) return null;
    return _DesiredPackaging(
      type: NotificationType.packagingUnsettled,
      title: NotificationType.packagingUnsettled.label,
      message:
          'عبوات «${row.typeName}» غير مسوّاة لدى «${row.partyName}»: $qty',
      priority: NotificationPriority.medium,
      metadata: {
        'partyName': row.partyName,
        'typeName': row.typeName,
        'typeId': row.typeId,
        'unsettled': row.unsettled,
      },
    );
  }

  String _rowKey(String type, int partyId, int typeId) =>
      '$type|$partyId|$typeId';

  String _itemKey(NotificationModel item) {
    final typeId = item.metadata['typeId'];
    final parsed = typeId is int ? typeId : int.tryParse('$typeId') ?? 0;
    return _rowKey(item.type, item.entityId ?? 0, parsed);
  }
}

class _DesiredPackaging {
  const _DesiredPackaging({
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
