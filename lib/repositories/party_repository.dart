import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/party_model.dart';

class PartyRepository {
  Future<Database> get _db async =>
      DatabaseHelper.instance.database;

  static const int _defaultPageSize = 20;

  // ==============================
  // Insert
  // ==============================

  Future<int> insertParty(PartyModel party) async {
    try {
      final db = await _db;
      return await db.insert(
        'parties',
        party.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } catch (e) {
      throw Exception('Failed to insert party: $e');
    }
  }

  // ==============================
  // Read with Cursor Pagination
  // ==============================

  /// جلب الصفحة الأولى (بدون cursor)
  /// جلب الصفحات التالية بتمرير آخر id وصلت إليه
  Future<PartyPage> getParties({
    String? keyword,
    PartyType? type,
    int? lastId,
    int pageSize = _defaultPageSize,
  }) async {
    try {
      final db = await _db;

      final List<String> conditions = [];
      final List<dynamic> args = [];

      // البحث بالاسم
      if (keyword != null && keyword.trim().isNotEmpty) {
        conditions.add('name LIKE ?');
        args.add('%${keyword.trim()}%');
      }

      // الفلترة حسب النوع
      if (type != null) {
        switch (type) {
          case PartyType.customer:
            conditions.add("(type = ? OR type = ?)");
            args.add("CUSTOMER");
            args.add("BOTH");
            break;

          case PartyType.supplier:
            conditions.add("(type = ? OR type = ?)");
            args.add("SUPPLIER");
            args.add("BOTH");
            break;

          case PartyType.both:
            conditions.add("type = ?");
            args.add("BOTH");
            break;
        }
      }

      // Pagination
      if (lastId != null) {
        conditions.add("id < ?");
        args.add(lastId);
      }

      final result = await db.query(
        'parties',
        where: conditions.isEmpty ? null : conditions.join(' AND '),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'id DESC',
        limit: pageSize + 1,
      );

      final hasNextPage = result.length > pageSize;
      final items = hasNextPage ? result.sublist(0, pageSize) : result;

      return PartyPage(
        parties: items.map((e) => PartyModel.fromMap(e)).toList(),
        hasNextPage: hasNextPage,
        nextCursor: hasNextPage && items.isNotEmpty
            ? items.last['id'] as int
            : null,
      );
    } catch (e) {
      throw Exception('Failed to fetch parties: $e');
    }
  }

  Future<PartyModel?> getPartyById(int id) async {
    try {
      final db = await _db;
      final result = await db.query(
        'parties',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return result.isEmpty ? null : PartyModel.fromMap(result.first);
    } catch (e) {
      throw Exception('Failed to fetch party by id: $e');
    }
  }

  Future<PartyModel?> getPartyByPhone(String phone) async {
    try {
      final db = await _db;
      final result = await db.query(
        'parties',
        where: 'phone = ?',
        whereArgs: [phone],
        limit: 1,
      );
      return result.isEmpty ? null : PartyModel.fromMap(result.first);
    } catch (e) {
      throw Exception('Failed to fetch party by phone: $e');
    }
  }

  Future<bool> partyExists(int id) async {
    final db = await _db;
    final result = await db.query(
      'parties',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  // ==============================
  // Update
  // ==============================

  Future<int> updateParty(PartyModel party) async {
    try {
      final db = await _db;
      return await db.update(
        'parties',
        party.toMap(),
        where: 'id = ?',
        whereArgs: [party.id],
      );
    } catch (e) {
      throw Exception('Failed to update party: $e');
    }
  }

  // ==============================
  // Delete
  // ==============================

  Future<int> deleteParty(int id) async {
    try {
      final db = await _db;
      return await db.delete(
        'parties',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('Failed to delete party: $e');
    }
  }
}

// ==============================
// PartyPage Model
// ==============================

class PartyPage {
  final List<PartyModel> parties;
  final bool hasNextPage;
  final int? nextCursor;

  const PartyPage({
    required this.parties,
    required this.hasNextPage,
    this.nextCursor,
  });
}