import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../models/category_model.dart';

class CategoryRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<int> insertCategory(CategoryModel category) async {
    try {
      final db = await _db;
      final data = category.toMap()..remove('id');
      return await db.insert(
        'product_categories',
        data,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('يوجد صنف بنفس الاسم مسبقاً');
      }
      throw Exception('خطأ في قاعدة البيانات أثناء إضافة الصنف: $e');
    }
  }

  Future<List<CategoryModel>> getAllCategories({
    bool activeOnly = true,
  }) async {
    final db = await _db;
    final result = await db.query(
      'product_categories',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'is_preset DESC, name ASC',
    );
    return result.map((e) => CategoryModel.fromMap(e)).toList();
  }

  Future<CategoryModel?> getCategoryById(int id) async {
    final db = await _db;
    final result = await db.query(
      'product_categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isEmpty ? null : CategoryModel.fromMap(result.first);
  }

  Future<int> updateCategory(CategoryModel category) async {
    try {
      final db = await _db;
      return await db.update(
        'product_categories',
        category.toMap(),
        where: 'id = ?',
        whereArgs: [category.id],
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('يوجد صنف بنفس الاسم مسبقاً');
      }
      throw Exception('خطأ أثناء تعديل الصنف: $e');
    }
  }

  /// الأصناف الجاهزة (is_preset = 1) لا تُحذف — يتم تعطيلها فقط.
  /// الأصناف المضافة يدوياً يمكن حذفها نهائياً إذا لم يكن هناك
  /// منتجات مرتبطة بها (ON DELETE SET NULL يضمن سلامة البيانات).
  Future<void> deleteOrDeactivateCategory(CategoryModel category) async {
    final db = await _db;
    if (category.isPreset) {
      await db.update(
        'product_categories',
        {'is_active': 0},
        where: 'id = ?',
        whereArgs: [category.id],
      );
    } else {
      await db.delete(
        'product_categories',
        where: 'id = ?',
        whereArgs: [category.id],
      );
    }
  }

  /// عدد المنتجات في كل صنف (مفيد لواجهة عرض الأصناف)
  Future<Map<int, int>> getProductCountPerCategory() async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT category_id, COUNT(*) AS cnt
      FROM products
      WHERE category_id IS NOT NULL
      GROUP BY category_id
    ''');
    return {
      for (final row in result)
        row['category_id'] as int: row['cnt'] as int,
    };
  }
}
