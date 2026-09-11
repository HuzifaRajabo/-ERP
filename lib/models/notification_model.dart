import 'dart:convert';

enum NotificationType {
  expiryWarning('EXPIRY_WARNING'),
  expiryExpired('EXPIRY_EXPIRED'),
  lowStock('LOW_STOCK'),
  outOfStock('OUT_OF_STOCK'),
  debtDue('DEBT_DUE'),
  debtOverdue('DEBT_OVERDUE'),
  packagingUnsettled('PACKAGING_UNSETTLED'),
  packagingOverdue('PACKAGING_OVERDUE'),
  vehicleLoad('VEHICLE_LOAD'),
  vehicleUnload('VEHICLE_UNLOAD'),
  vehicleMaintenance('VEHICLE_MAINTENANCE');

  const NotificationType(this.dbValue);
  final String dbValue;

  static const expiryDbValues = ['EXPIRY_WARNING', 'EXPIRY_EXPIRED'];
  static const stockDbValues = ['LOW_STOCK', 'OUT_OF_STOCK'];
  static const debtDbValues = ['DEBT_DUE', 'DEBT_OVERDUE'];
  static const packagingDbValues = [
    'PACKAGING_UNSETTLED',
    'PACKAGING_OVERDUE',
  ];
  static const vehicleDbValues = [
    'VEHICLE_LOAD',
    'VEHICLE_UNLOAD',
    'VEHICLE_MAINTENANCE',
  ];

  static NotificationType? fromDb(String? value) {
    for (final type in NotificationType.values) {
      if (type.dbValue == value) return type;
    }
    return null;
  }

  String get label => switch (this) {
        NotificationType.expiryWarning => 'قرب انتهاء الصلاحية',
        NotificationType.expiryExpired => 'انتهت الصلاحية',
        NotificationType.lowStock => 'انخفاض المخزون',
        NotificationType.outOfStock => 'نفاد المخزون',
        NotificationType.debtDue => 'دين مستحق',
        NotificationType.debtOverdue => 'دين متأخر',
        NotificationType.packagingUnsettled => 'عبوات غير مسوّاة',
        NotificationType.packagingOverdue => 'عبوات متأخرة التسوية',
        NotificationType.vehicleLoad => 'تحميل مركبة',
        NotificationType.vehicleUnload => 'تفريغ مركبة',
        NotificationType.vehicleMaintenance => 'صيانة مركبة',
      };
}

enum NotificationPriority {
  low('LOW'),
  medium('MEDIUM'),
  high('HIGH'),
  critical('CRITICAL');

  const NotificationPriority(this.dbValue);
  final String dbValue;

  static NotificationPriority fromDb(String? value) {
    for (final item in NotificationPriority.values) {
      if (item.dbValue == value) return item;
    }
    return NotificationPriority.medium;
  }
}

enum NotificationStatus {
  active('ACTIVE'),
  resolved('RESOLVED');

  const NotificationStatus(this.dbValue);
  final String dbValue;

  static NotificationStatus fromDb(String? value) {
    return value == NotificationStatus.resolved.dbValue
        ? NotificationStatus.resolved
        : NotificationStatus.active;
  }

  String get label => switch (this) {
        NotificationStatus.active => 'نشط',
        NotificationStatus.resolved => 'تم الحل',
      };
}

class NotificationModel {
  final int? id;
  final String type;
  final String title;
  final String message;
  final NotificationPriority priority;
  final NotificationStatus status;
  final bool isRead;
  final String? createdAt;
  final String? readAt;
  final String? resolvedAt;
  final String? entityType;
  final int? entityId;
  final int? productId;
  final int? batchId;
  final int? warehouseId;
  final Map<String, dynamic> metadata;

  const NotificationModel({
    this.id,
    required this.type,
    required this.title,
    required this.message,
    this.priority = NotificationPriority.medium,
    this.status = NotificationStatus.active,
    this.isRead = false,
    this.createdAt,
    this.readAt,
    this.resolvedAt,
    this.entityType,
    this.entityId,
    this.productId,
    this.batchId,
    this.warehouseId,
    this.metadata = const {},
  });

  NotificationType? get typed => NotificationType.fromDb(type);

  bool get isActive => status == NotificationStatus.active;

  String get productName => metadata['productName'] as String? ?? '';

  String get batchNumber => metadata['batchNumber'] as String? ?? '';

  String get warehouseName => metadata['warehouseName'] as String? ?? '';

  String? get expiryDate => metadata['expiryDate'] as String?;

  String get unitName => metadata['unitName'] as String? ?? '';

  double get quantity {
    final value = metadata['quantity'];
    if (value is num) return value.toDouble();
    return 0;
  }

  int? get daysRemaining {
    final value = metadata['daysRemaining'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      'priority': priority.dbValue,
      'status': status.dbValue,
      'is_read': isRead ? 1 : 0,
      'created_at': createdAt,
      'read_at': readAt,
      'resolved_at': resolvedAt,
      'entity_type': entityType,
      'entity_id': entityId,
      'product_id': productId,
      'batch_id': batchId,
      'warehouse_id': warehouseId,
      'metadata': metadata.isEmpty ? null : jsonEncode(metadata),
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] as int?,
      type: map['type'] as String? ?? '',
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      priority: NotificationPriority.fromDb(map['priority'] as String?),
      status: NotificationStatus.fromDb(map['status'] as String?),
      isRead: (map['is_read'] as int? ?? 0) == 1,
      createdAt: map['created_at'] as String?,
      readAt: map['read_at'] as String?,
      resolvedAt: map['resolved_at'] as String?,
      entityType: map['entity_type'] as String?,
      entityId: map['entity_id'] as int?,
      productId: map['product_id'] as int?,
      batchId: map['batch_id'] as int?,
      warehouseId: map['warehouse_id'] as int?,
      metadata: _parseMetadata(map['metadata']),
    );
  }

  static Map<String, dynamic> _parseMetadata(dynamic raw) {
    if (raw == null) return const {};
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return const {};
  }
}
