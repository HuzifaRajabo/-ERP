import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../models/product_unit_model.dart';

class ProductUnitRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  /// إضافة وحدة جديدة لمنتج. إذا كانت هذه أول وحدة أساسية للمنتج،
  /// يجب أن تكون isBaseUnit = true (تُدار هذه القاعدة من الـ Controller).
  Future<int> insertUnit(ProductUnitModel unit) async {
    try {
      final db = await _db;
      final data = unit.toMap()..remove('id');
      return await db.insert(
        'product_units',
        data,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } on DatabaseException catch (e) {
      throw Exception('خطأ في قاعدة البيانات أثناء إضافة الوحدة: $e');
    }
  }

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

  Future<int> updateUnit(ProductUnitModel unit) async {
    try {
      final db = await _db;
      return await db.update(
        'product_units',
        unit.toMap(),
        where: 'id = ?',
        whereArgs: [unit.id],
      );
    } on DatabaseException catch (e) {
      throw Exception('خطأ في قاعدة البيانات أثناء تعديل الوحدة: $e');
    }
  }

  Future<int> deactivateUnit(int id) async {
    final db = await _db;
    return await db.update(
      'product_units',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
