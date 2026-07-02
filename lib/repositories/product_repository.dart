import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../models/product_model.dart';

class ProductRepository {
  Future<Database> get _db async =>
      DatabaseHelper.instance.database;

  static const int _defaultPageSize = 20;
  // ==============================
  // Insert
  // ==============================

  Future<int> insertProduct(ProductModel product,) async {
    try {
      final db = await _db;
      return await db.insert(
        'products',
        product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
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
  }) async {
    try {
      final db = await _db;
      final result = await db.query(
        'products',
        where: lastId != null ? 'id < ?' : null,
        whereArgs: lastId != null ? [lastId] : null,
        orderBy: 'id DESC',
        limit: pageSize + 1, // نجلب واحد زيادة لنعرف هل في صفحة تالية
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
      final result = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      return result.isEmpty ? null : ProductModel.fromMap(result.first);
    } catch (e) {
      throw Exception('Failed to fetch product by id: $e');
    }
  }

  Future<int> updateProduct(ProductModel product,) async {
    try {
      final db = await _db;
      return await db.update(
        'products',
        product.toMap(),
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

  Future<ProductModel?> getProductBySku(String sku) async {
    try {
      final db = await _db;
      final result = await db.query(
        'products',
        where: 'sku = ?',
        whereArgs: [sku],
        limit: 1,
      );

      return result.isEmpty ? null : ProductModel.fromMap(result.first);
    } catch (e) {
      throw Exception('Failed to fetch product by sku: $e');
    }
  }

  Future<ProductPage> searchProductsByName(
      String keyword, {
        int? lastId,
        int pageSize = _defaultPageSize,
      }) async {
    try {
      final db = await _db;
      final result = await db.query(
        'products',
        where: lastId != null ? 'name LIKE ? AND id < ?' : 'name LIKE ?',
        whereArgs: lastId != null ? ['%$keyword%', lastId] : ['%$keyword%'],
        orderBy: 'id DESC',
        limit: pageSize + 1,
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