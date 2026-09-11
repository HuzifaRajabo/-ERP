import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  NotificationRepository({Future<Database> Function()? dbProvider})
      : _dbProvider =
            dbProvider ?? (() async => DatabaseHelper.instance.database);

  final Future<Database> Function() _dbProvider;

  Future<Database> get _db async => _dbProvider();

  static const _orderBy = '''
    CASE status WHEN 'ACTIVE' THEN 0 ELSE 1 END,
    CASE priority
      WHEN 'CRITICAL' THEN 0
      WHEN 'HIGH' THEN 1
      WHEN 'MEDIUM' THEN 2
      ELSE 3
    END,
    datetime(created_at) DESC,
    id DESC
  ''';

  Future<List<NotificationModel>> getNotifications({
    NotificationListFilter filter = NotificationListFilter.all,
  }) async {
    final db = await _db;
    String? where;
    List<Object?>? args;
    switch (filter) {
      case NotificationListFilter.unread:
        where = 'is_read = 0';
      case NotificationListFilter.active:
        where = "status = 'ACTIVE'";
      case NotificationListFilter.all:
        where = null;
    }
    final rows = await db.query(
      'notifications',
      where: where,
      whereArgs: args,
      orderBy: _orderBy,
    );
    return rows.map(NotificationModel.fromMap).toList();
  }

  Future<List<NotificationModel>> getUnreadNotifications() {
    return getNotifications(filter: NotificationListFilter.unread);
  }

  Future<List<NotificationModel>> getActiveNotifications() {
    return getNotifications(filter: NotificationListFilter.active);
  }

  Future<int> getUnreadCount() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM notifications WHERE is_read = 0',
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<List<NotificationModel>> getActiveExpiryNotifications() async {
    final db = await _db;
    final placeholders =
        List.filled(NotificationType.expiryDbValues.length, '?').join(',');
    final rows = await db.query(
      'notifications',
      where: "status = 'ACTIVE' AND type IN ($placeholders)",
      whereArgs: NotificationType.expiryDbValues,
    );
    return rows.map(NotificationModel.fromMap).toList();
  }

  Future<NotificationModel?> findActive({
    required String type,
    required int batchId,
    required int warehouseId,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'notifications',
      where:
          "status = 'ACTIVE' AND type = ? AND batch_id = ? AND warehouse_id = ?",
      whereArgs: [type, batchId, warehouseId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return NotificationModel.fromMap(rows.first);
  }

  Future<List<NotificationModel>> getActiveByTypes(List<String> types) async {
    if (types.isEmpty) return const [];
    final db = await _db;
    final placeholders = List.filled(types.length, '?').join(',');
    final rows = await db.query(
      'notifications',
      where: "status = 'ACTIVE' AND type IN ($placeholders)",
      whereArgs: types,
    );
    return rows.map(NotificationModel.fromMap).toList();
  }

  Future<void> resolveActiveByTypes(List<String> types) async {
    if (types.isEmpty) return;
    final db = await _db;
    final placeholders = List.filled(types.length, '?').join(',');
    await db.update(
      'notifications',
      {
        'status': NotificationStatus.resolved.dbValue,
        'resolved_at': DateTime.now().toIso8601String(),
      },
      where: "status = 'ACTIVE' AND type IN ($placeholders)",
      whereArgs: types,
    );
  }

  Future<NotificationModel?> findActiveByEntity({
    required String type,
    required String entityType,
    required int entityId,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'notifications',
      where:
          "status = 'ACTIVE' AND type = ? AND entity_type = ? AND entity_id = ?",
      whereArgs: [type, entityType, entityId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return NotificationModel.fromMap(rows.first);
  }

  Future<int> createNotification(NotificationModel notification) async {
    final db = await _db;
    final data = notification.toMap()..remove('id');
    if (data['created_at'] == null) data.remove('created_at');
    return db.insert('notifications', data);
  }

  Future<void> updateActiveSnapshot({
    required int id,
    required String title,
    required String message,
    required NotificationPriority priority,
    required Map<String, dynamic> metadata,
  }) async {
    final db = await _db;
    await db.update(
      'notifications',
      {
        'title': title,
        'message': message,
        'priority': priority.dbValue,
        'metadata': jsonEncode(metadata),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAsRead(int id) async {
    final db = await _db;
    await db.update(
      'notifications',
      {
        'is_read': 1,
        'read_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND is_read = 0',
      whereArgs: [id],
    );
  }

  Future<void> markAllAsRead() async {
    final db = await _db;
    await db.update(
      'notifications',
      {
        'is_read': 1,
        'read_at': DateTime.now().toIso8601String(),
      },
      where: 'is_read = 0',
    );
  }

  Future<void> resolveNotification(int id) async {
    final db = await _db;
    await db.update(
      'notifications',
      {
        'status': NotificationStatus.resolved.dbValue,
        'resolved_at': DateTime.now().toIso8601String(),
      },
      where: "id = ? AND status = 'ACTIVE'",
      whereArgs: [id],
    );
  }
}
