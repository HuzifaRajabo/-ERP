import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../models/product_unit_model.dart';

class ProductUnitRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  // ==============================
  // Read
  // ==============================

  Future<List<ProductUnitModel>> getUnitsForProduct(
    int productId, {
    bool activeOnly = true,
  }) async {
    final db = await _db;
    final result = await db.query(
      'product_units',
      where: activeOnly
          ? 'product_id = ? AND is_active = 1'
          : 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'is_base_unit DESC, conversion_factor ASC',
    );
    return result.map((e) => ProductUnitModel.fromMap(e)).toList();
  }

  Future<ProductUnitModel?> getUnitById(int id) async {
    final db = await _db;
    final result = await db.query(
      'product_units',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isEmpty ? null : ProductUnitModel.fromMap(result.first);
  }

  Future<ProductUnitModel?> getBaseUnitForProduct(int productId) async {
    final db = await _db;
    final result = await db.query(
      'product_units',
      where: 'product_id = ? AND is_base_unit = 1',
      whereArgs: [productId],
      limit: 1,
    );
    return result.isEmpty ? null : ProductUnitModel.fromMap(result.first);
  }

  Future<ProductUnitModel?> getDefaultSellUnitForProduct(int productId) async {
    final db = await _db;
    final result = await db.query(
      'product_units',
      where: 'product_id = ? AND is_default_sell_unit = 1 AND is_active = 1',
      whereArgs: [productId],
      limit: 1,
    );
    return result.isEmpty ? null : ProductUnitModel.fromMap(result.first);
  }

  Future<List<ProductUnitModel>> getSellableUnits(int productId) async {
    final db = await _db;
    final result = await db.query(
      'product_units',
      where: 'product_id = ? AND can_sell = 1 AND is_active = 1',
      whereArgs: [productId],
      orderBy: 'is_default_sell_unit DESC, is_base_unit DESC, conversion_factor ASC',
    );
    return result.map((e) => ProductUnitModel.fromMap(e)).toList();
  }

  Future<List<ProductUnitModel>> getBuyableUnits(int productId) async {
    final db = await _db;
    final result = await db.query(
      'product_units',
      where: 'product_id = ? AND can_buy = 1 AND is_active = 1',
      whereArgs: [productId],
      orderBy: 'is_base_unit DESC, conversion_factor ASC',
    );
    return result.map((e) => ProductUnitModel.fromMap(e)).toList();
  }

  /// هل الوحدة مستخدمة في أي فاتورة أو حركة مخزون؟
  /// إذا نعم لا يمكن حذفها فعلياً، فقط soft-delete.
  Future<bool> isUnitUsedInHistory(int unitId) async {
    final db = await _db;
    final r1 = await db.rawQuery(
      'SELECT 1 FROM invoice_items WHERE unit_id = ? LIMIT 1',
      [unitId],
    );
    if (r1.isNotEmpty) return true;
    final r2 = await db.rawQuery(
      'SELECT 1 FROM inventory_transactions WHERE unit_id = ? LIMIT 1',
      [unitId],
    );
    return r2.isNotEmpty;
  }

  // ==============================
  // Write (single unit — بدون transaction، للاستخدام داخل saveProductWithUnits)
  // ==============================

  Future<int> insertUnit(ProductUnitModel unit) async {
    try {
      final db = await _db;
      final data = unit.toMap()..remove('id');
      data['updated_at'] = _now();
      return await db.insert(
        'product_units',
        data,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } on DatabaseException catch (e) {
      throw Exception('خطأ في قاعدة البيانات أثناء إضافة الوحدة: $e');
    }
  }

  Future<int> updateUnit(ProductUnitModel unit) async {
    try {
      final db = await _db;
      final data = unit.toMap();
      data['updated_at'] = _now();
      return await db.update(
        'product_units',
        data,
        where: 'id = ?',
        whereArgs: [unit.id],
      );
    } on DatabaseException catch (e) {
      throw Exception('خطأ في قاعدة البيانات أثناء تعديل الوحدة: $e');
    }
  }

  /// يحذف الوحدة فعلياً إذا لم تُستخدم في أي تاريخ،
  /// وإلا يُعطّلها (soft delete).
  /// يُعيد true إذا تم الحذف الفعلي.
  Future<bool> deleteOrDeactivateUnit(int id) async {
    if (await isUnitUsedInHistory(id)) {
      final db = await _db;
      await db.update(
        'product_units',
        {'is_active': 0, 'updated_at': _now()},
        where: 'id = ?',
        whereArgs: [id],
      );
      return false; // soft delete
    } else {
      final db = await _db;
      await db.delete('product_units', where: 'id = ?', whereArgs: [id]);
      return true; // hard delete
    }
  }

  /// حذف مباشر (يُستخدم من داخل transaction الحفظ الكامل فقط)
  Future<int> deleteUnit(int id) async {
    final db = await _db;
    return await db.delete(
      'product_units',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deactivateUnit(int id) async {
    final db = await _db;
    return await db.update(
      'product_units',
      {'is_active': 0, 'updated_at': _now()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==============================
  // Atomic bulk ops (تُستدعى من داخل transaction خارجية)
  // ==============================

  /// يحفظ قائمة الوحدات داخل transaction موجودة.
  /// [existingIds] وحدات المنتج الموجودة حالياً في DB (لمعرفة ما يجب حذفه)
  Future<void> syncUnitsInTransaction(
    DatabaseExecutor txn,
    int productId,
    List<ProductUnitModel> newUnits,
    List<int> existingIds,
  ) async {
    final now = _now();
    final newIds = <int>[];

    for (final unit in newUnits) {
      final data = unit.toMap()
        ..remove('id')
        ..['product_id'] = productId
        ..['updated_at'] = now;

      if (unit.id != null && existingIds.contains(unit.id)) {
        // تحديث موجود
        data['id'] = unit.id;
        await txn.update(
          'product_units',
          data,
          where: 'id = ?',
          whereArgs: [unit.id],
        );
        newIds.add(unit.id!);
      } else {
        // إدراج جديد
        final id = await txn.insert(
          'product_units',
          data,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
        newIds.add(id);
      }
    }

    // حذف أو تعطيل الوحدات المحذوفة من القائمة
    final toRemove = existingIds.where((id) => !newIds.contains(id)).toList();
    for (final id in toRemove) {
      // نتحقق من الاستخدام داخل التransaction
      final used1 = await txn.rawQuery(
        'SELECT 1 FROM invoice_items WHERE unit_id = ? LIMIT 1', [id],
      );
      final used2 = used1.isEmpty
          ? await txn.rawQuery(
              'SELECT 1 FROM inventory_transactions WHERE unit_id = ? LIMIT 1', [id],
            )
          : <Map<String, dynamic>>[];

      if (used1.isNotEmpty || used2.isNotEmpty) {
        await txn.update(
          'product_units',
          {'is_active': 0, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        await txn.delete('product_units', where: 'id = ?', whereArgs: [id]);
      }
    }
  }

  String _now() => DateTime.now().toIso8601String();
}
