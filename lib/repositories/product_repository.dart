import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../models/product_model.dart';
import '../models/product_unit_model.dart';
import '../core/services/product_unit_validator.dart';

class ProductRepository {
  Future<Database> get _db async =>
      DatabaseHelper.instance.database;

  static const int _defaultPageSize = 20;

  // JOIN ثابت يُستخدم في كل استعلامات القراءة لجلب category_name
  static const String _selectWithCategory = '''
    SELECT p.*, c.name AS category_name
    FROM products p
    LEFT JOIN product_categories c ON c.id = p.category_id
  ''';

  // ==============================
  // Insert
  // ==============================

  Future<int> insertProduct(ProductModel product) async {
    try {
      final db = await _db;

      // category_name للعرض فقط ولا يُكتب في جدول products
      final data = product.toMap()..remove('category_name');

      // لا نرسل ID عند إنشاء منتج جديد.
      data.remove('id');

      final id = await db.insert(
        'products',
        data,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      if (id <= 0) {
        throw Exception('لم يتم الحصول على ID صالح للمنتج');
      }

      return id;
    } on DatabaseException catch (e) {
      throw Exception('خطأ في قاعدة البيانات أثناء إضافة المنتج: $e');
    } catch (e) {
      throw Exception('Failed to insert product: $e');
    }
  }

  // ==============================
  // Read with Cursor Pagination
  // ==============================

  Future<ProductPage> getAllProducts({
    int? lastId,
    int pageSize = _defaultPageSize,
    int? categoryId,
  }) async {
    try {
      final db = await _db;

      final conditions = <String>[];
      final args = <Object?>[];

      if (categoryId != null) {
        conditions.add('p.category_id = ?');
        args.add(categoryId);
      }
      if (lastId != null) {
        conditions.add('p.id < ?');
        args.add(lastId);
      }

      final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

      final result = await db.rawQuery(
        '''
        $_selectWithCategory
        $where
        ORDER BY p.id DESC
        LIMIT ${pageSize + 1}
        ''',
        args,
      );

      final hasNextPage = result.length > pageSize;
      final items = hasNextPage ? result.sublist(0, pageSize) : result;

      return ProductPage(
        products: items.map((e) => ProductModel.fromMap(e)).toList(),
        hasNextPage: hasNextPage,
        nextCursor: hasNextPage && items.isNotEmpty
            ? items.last['id'] as int?
            : null,
      );
    } catch (e) {
      throw Exception('Failed to fetch products: $e');
    }
  }

  Future<ProductModel?> getProductById(int id) async {
    try {
      final db = await _db;
      final result = await db.rawQuery(
        '$_selectWithCategory WHERE p.id = ? LIMIT 1',
        [id],
      );

      return result.isEmpty ? null : ProductModel.fromMap(result.first);
    } catch (e) {
      throw Exception('Failed to fetch product by id: $e');
    }
  }

  Future<int> updateProduct(ProductModel product,) async {
    try {
      final db = await _db;
      final data = product.toMap()..remove('category_name');
      return await db.update(
        'products',
        data,
        where: 'id = ?',
        whereArgs: [product.id],
      );
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  Future<int> deleteProduct(int id,) async {
    try {
      final db = await _db;
      return await db.delete(
        'products',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }


  Future<ProductPage> searchProductsByName(
      String keyword, {
        int? lastId,
        int pageSize = _defaultPageSize,
        int? categoryId,
      }) async {
    try {
      final db = await _db;

      final conditions = <String>['p.name LIKE ?'];
      final args = <Object?>['%$keyword%'];

      if (categoryId != null) {
        conditions.add('p.category_id = ?');
        args.add(categoryId);
      }
      if (lastId != null) {
        conditions.add('p.id < ?');
        args.add(lastId);
      }

      final result = await db.rawQuery(
        '''
        $_selectWithCategory
        WHERE ${conditions.join(' AND ')}
        ORDER BY p.id DESC
        LIMIT ${pageSize + 1}
        ''',
        args,
      );

      final hasNextPage = result.length > pageSize;
      final items = hasNextPage ? result.sublist(0, pageSize) : result;

      return ProductPage(
        products: items.map((e) => ProductModel.fromMap(e)).toList(),
        hasNextPage: hasNextPage,
        nextCursor: hasNextPage && items.isNotEmpty
            ? items.last['id'] as int?
            : null,
      );
    } catch (e) {
      throw Exception('Failed to search products by name: $e');
    }
  }

  /// كل منتجات صنف معين (بدون ترقيم صفحات) — لقوائم مختصرة مثل
  /// اختيار منتج ضمن صنف عند إنشاء فاتورة.
  Future<List<ProductModel>> getProductsByCategory(int categoryId) async {
    try {
      final db = await _db;
      final result = await db.rawQuery(
        '$_selectWithCategory WHERE p.category_id = ? ORDER BY p.name ASC',
        [categoryId],
      );
      return result.map((e) => ProductModel.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Failed to fetch products by category: $e');
    }
  }

  // ==============================
  // Atomic: حفظ المنتج مع وحداته في transaction واحدة
  // ==============================

  /// يُنشئ منتجاً جديداً مع وحداته ضمن transaction واحدة.
  /// إذا فشل حفظ أي وحدة يتم ROLLBACK للمنتج أيضاً.
  /// يُعيد id المنتج المُنشأ.
  Future<int> createProductWithUnits(
    ProductModel product,
    List<ProductUnitModel> units,
  ) async {
    // التحقق قبل فتح الـ transaction
    ProductUnitValidator.validate(product.name, units);

    final db = await _db;
    return await db.transaction<int>((txn) async {
      final data = product.toMap()
        ..remove('id')
        ..remove('category_name');
      final productId = await txn.insert(
        'products',
        data,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      final now = DateTime.now().toIso8601String();
      for (final unit in units) {
        final unitData = unit.toMap()
          ..remove('id')
          ..['product_id'] = productId
          ..['updated_at'] = now;
        await txn.insert(
          'product_units',
          unitData,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }

      return productId;
    });
  }

  /// يُعدّل منتجاً موجوداً مع مزامنة وحداته ضمن transaction واحدة.
  /// الوحدات الجديدة تُضاف، الموجودة تُحدَّث، المحذوفة تُزال أو تُعطَّل.
  Future<void> updateProductWithUnits(
    ProductModel product,
    List<ProductUnitModel> units,
  ) async {
    if (product.id == null) {
      throw ArgumentError('product.id مطلوب للتعديل');
    }

    ProductUnitValidator.validate(product.name, units);

    final db = await _db;
    await db.transaction<void>((txn) async {
      // تحديث بيانات المنتج
      final data = product.toMap()..remove('category_name');
      await txn.update(
        'products',
        data,
        where: 'id = ?',
        whereArgs: [product.id],
      );

      // جلب وحدات المنتج الموجودة حالياً
      final existing = await txn.query(
        'product_units',
        columns: ['id'],
        where: 'product_id = ?',
        whereArgs: [product.id],
      );
      final existingIds = existing.map((r) => r['id'] as int).toList();

      final now = DateTime.now().toIso8601String();
      final processedIds = <int>[];

      for (final unit in units) {
        final unitData = unit.toMap()
          ..['product_id'] = product.id
          ..['updated_at'] = now;

        if (unit.id != null && existingIds.contains(unit.id)) {
          await txn.update(
            'product_units',
            unitData,
            where: 'id = ?',
            whereArgs: [unit.id],
          );
          processedIds.add(unit.id!);
        } else {
          unitData.remove('id');
          final newId = await txn.insert(
            'product_units',
            unitData,
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
          processedIds.add(newId);
        }
      }

      // وحدات لم تعد موجودة في القائمة الجديدة
      final toRemove = existingIds.where((id) => !processedIds.contains(id));
      for (final id in toRemove) {
        final usedInItems = await txn.rawQuery(
          'SELECT 1 FROM invoice_items WHERE unit_id = ? LIMIT 1', [id],
        );
        final usedInInv = usedInItems.isEmpty
            ? await txn.rawQuery(
                'SELECT 1 FROM inventory_transactions WHERE unit_id = ? LIMIT 1',
                [id],
              )
            : <Map<String, dynamic>>[];

        if (usedInItems.isNotEmpty || usedInInv.isNotEmpty) {
          // soft delete — لا نفقد تاريخ الفواتير
          await txn.update(
            'product_units',
            {'is_active': 0, 'updated_at': now},
            where: 'id = ?',
            whereArgs: [id],
          );
        } else {
          await txn.delete(
            'product_units',
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
    });
  }
}

// ==============================
// ProductPage Model
// ==============================

class ProductPage{
  final List<ProductModel> products;
  final bool hasNextPage;
  final int? nextCursor;

  const ProductPage({
    required this.products,
    required this.hasNextPage,
    this.nextCursor,
  });
}