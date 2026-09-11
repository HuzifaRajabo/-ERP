import '../../models/invoice_model.dart';
import '../../models/notification_model.dart';
import '../../repositories/invoice_repository.dart';
import '../../repositories/notification_repository.dart';
import '../utils/app_dates.dart';

class DebtNotificationService {
  DebtNotificationService({
    required this.invoiceRepo,
    required this.notificationRepo,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final InvoiceRepository invoiceRepo;
  final NotificationRepository notificationRepo;
  final DateTime Function() _clock;

  Future<void> scan({
    required bool dueEnabled,
    required bool overdueEnabled,
    required int dueDays,
    required int overdueDays,
  }) async {
    if (!dueEnabled && !overdueEnabled) {
      await notificationRepo.resolveActiveByTypes(NotificationType.debtDbValues);
      return;
    }

    final invoices = await invoiceRepo.getInvoicesWithRemaining();
    final active = await notificationRepo.getActiveByTypes(
      NotificationType.debtDbValues,
    );
    final byKey = <String, NotificationModel>{
      for (final item in active)
        if (item.entityId != null) _key(item.type, item.entityId!): item,
    };

    final today = AppDates.dateOnly(_clock());
    final desiredKeys = <String>{};

    for (final invoice in invoices) {
      final id = invoice.id;
      if (id == null || invoice.remaining <= 0) continue;
      final classified = _classify(
        invoice,
        today: today,
        dueEnabled: dueEnabled,
        overdueEnabled: overdueEnabled,
        dueDays: dueDays,
        overdueDays: overdueDays,
      );
      if (classified == null) continue;

      final key = _key(classified.type.dbValue, id);
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
          entityType: 'invoice',
          entityId: id,
          metadata: classified.metadata,
        ),
      );
    }

    for (final item in active) {
      final id = item.id;
      final entityId = item.entityId;
      if (id == null || entityId == null) continue;
      if (!desiredKeys.contains(_key(item.type, entityId))) {
        await notificationRepo.resolveNotification(id);
      }
    }
  }

  _DesiredDebt? _classify(
    InvoiceModel invoice, {
    required DateTime today,
    required bool dueEnabled,
    required bool overdueEnabled,
    required int dueDays,
    required int overdueDays,
  }) {
    final created = DateTime.tryParse(invoice.createdAt ?? '');
    if (created == null) return null;
    final age = today.difference(AppDates.dateOnly(created)).inDays;
    final party = invoice.partyNameSnapshot;
    final remainingText = invoice.remaining.toString();

    if (age >= overdueDays && overdueEnabled) {
      return _DesiredDebt(
        type: NotificationType.debtOverdue,
        title: NotificationType.debtOverdue.label,
        message:
            'فاتورة ${invoice.invoiceNumber} لـ«$party» متأخرة $age يوم — المتبقي $remainingText',
        priority: NotificationPriority.critical,
        metadata: {
          'invoiceNumber': invoice.invoiceNumber,
          'partyName': party,
          'remaining': invoice.remaining,
          'ageDays': age,
        },
      );
    }

    if (age >= dueDays && dueEnabled) {
      return _DesiredDebt(
        type: NotificationType.debtDue,
        title: NotificationType.debtDue.label,
        message:
            'فاتورة ${invoice.invoiceNumber} لـ«$party» مستحقة — المتبقي $remainingText',
        priority: NotificationPriority.high,
        metadata: {
          'invoiceNumber': invoice.invoiceNumber,
          'partyName': party,
          'remaining': invoice.remaining,
          'ageDays': age,
        },
      );
    }

    return null;
  }

  String _key(String type, int invoiceId) => '$type|$invoiceId';
}

class _DesiredDebt {
  const _DesiredDebt({
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
