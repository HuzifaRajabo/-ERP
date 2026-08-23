import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/inventory_transaction_model.dart';

/// نموذج مُعزَّز يضم بيانات الحركة + اسم المنتج + رقم الفاتورة
/// يُستخدم في الواجهة لعرض معلومات كاملة بدون joins إضافية
class InventoryTransactionView {
  final InventoryTransactionModel transaction;
  final String productName;
  final String invoiceNumber;

  InventoryTransactionView({
    required this.transaction,
    required this.productName,
    required this.invoiceNumber,
  });
}

class InventoryTransactionPage {
  final List<InventoryTransactionView> transactions;
  final bool hasNextPage;
  final int? nextCursor;

  const InventoryTransactionPage({
    required this.transactions,
    required this.hasNextPage,
    this.nextCursor,
  });
}

/// ملخص مخزون منتج معين
class ProductStockSummary {
  final int productId;
  final String productName;
  final String productDescription;
  final double totalPurchased;
  final double totalSold;
  final double available;

  ProductStockSummary({
    required this.productId,
    required this.productName,
    required this.productDescription,
    required this.totalPurchased,
    required this.totalSold,
    required this.available,
  });
}

class InventoryRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  static const int _defaultPageSize = 20;

  // ====================================================================
  // جلب حركات المخزون مع JOIN لجلب اسم المنتج ورقم الفاتورة
  // ====================================================================
  //
  // نستخدم rawQuery لأن db.query() لا تدعم JOIN مباشرة.
  // الـ JOIN هنا ضروري لعرض اسم المنتج ورقم الفاتورة في القائمة
  // بدون الحاجة لاستعلامات إضافية لكل سطر (N+1 problem).

  Future<InventoryTransactionPage> getAllTransactions({
    int? lastId,
    int pageSize = _defaultPageSize,
  }) async {
    final db = await _db;
    final params = <Object?>[];
    if (lastId != null) {
      params.add(lastId);
    }
    params.add(pageSize + 1);

    final result = await db.rawQuery(
      '''
      SELECT
        it.id,
        it.product_id,
        it.type,
        it.quantity,
        it.invoice_id,
        it.created_at,
        p.name   AS product_name,
        inv.invoice_number
      FROM inventory_transactions it
      INNER JOIN products p   ON p.id   = it.product_id
      INNER JOIN invoices inv ON inv.id = it.invoice_id
      ${lastId != null ? 'WHERE it.id < ?' : ''}
      ORDER BY it.id DESC
      LIMIT ?
    ''',
      params,
    );

    return _buildPage(result, pageSize);
  }

  // ====================================================================
  // فلترة حركات منتج معين
  // ====================================================================

  Future<InventoryTransactionPage> getTransactionsByProduct({
    required int productId,
    int? lastId,
    int pageSize = _defaultPageSize,
  }) async {
    final db = await _db;
    final params = <Object?>[productId];
    if (lastId != null) {
      params.add(lastId);
    }
    params.add(pageSize + 1);

    final result = await db.rawQuery(
      '''
      SELECT
        it.id,
        it.product_id,
        it.type,
        it.quantity,
        it.invoice_id,
        it.created_at,
        p.name   AS product_name,
        inv.invoice_number
      FROM inventory_transactions it
      INNER JOIN products p   ON p.id   = it.product_id
      INNER JOIN invoices inv ON inv.id = it.invoice_id
      WHERE it.product_id = ?
      ${lastId != null ? 'AND it.id < ?' : ''}
      ORDER BY it.id DESC
      LIMIT ?
    ''',
      params,
    );

    return _buildPage(result, pageSize);
  }

  // ====================================================================
  // فلترة حركات فاتورة معينة
  // ====================================================================

  Future<InventoryTransactionPage> getTransactionsByInvoice({
    required int invoiceId,
    int? lastId,
    int pageSize = _defaultPageSize,
  }) async {
    final db = await _db;
    final params = <Object?>[invoiceId];
    if (lastId != null) {
      params.add(lastId);
    }
    params.add(pageSize + 1);

    final result = await db.rawQuery(
      '''
      SELECT
        it.id,
        it.product_id,
        it.type,
        it.quantity,
        it.invoice_id,
        it.created_at,
        p.name   AS product_name,
        inv.invoice_number
      FROM inventory_transactions it
      INNER JOIN products p   ON p.id   = it.product_id
      INNER JOIN invoices inv ON inv.id = it.invoice_id
      WHERE it.invoice_id = ?
      ${lastId != null ? 'AND it.id < ?' : ''}
      ORDER BY it.id DESC
      LIMIT ?
    ''',
      params,
    );

    return _buildPage(result, pageSize);
  }

  // ====================================================================
  // فلترة حسب النوع (SALE / PURCHASE)
  // ====================================================================

  Future<InventoryTransactionPage> getTransactionsByType({
    required InventoryTransactionType type,
    int? lastId,
    int pageSize = _defaultPageSize,
  }) async {
    final db = await _db;
    final params = <Object?>[type.name.toUpperCase()];
    if (lastId != null) {
      params.add(lastId);
    }
    params.add(pageSize + 1);

    final result = await db.rawQuery(
      '''
      SELECT
        it.id,
        it.product_id,
        it.type,
        it.quantity,
        it.invoice_id,
        it.created_at,
        p.name   AS product_name,
        inv.invoice_number
      FROM inventory_transactions it
      INNER JOIN products p   ON p.id   = it.product_id
      INNER JOIN invoices inv ON inv.id = it.invoice_id
      WHERE it.type = ?
      ${lastId != null ? 'AND it.id < ?' : ''}
      ORDER BY it.id DESC
      LIMIT ?
    ''',
      params,
    );

    return _buildPage(result, pageSize);
  }

  // ====================================================================
  // ملخص المخزون لكل المنتجات (لصفحة نظرة عامة على المستودع)
  // ====================================================================
  //
  // استعلام واحد يحسب مشتريات ومبيعات كل منتج معاً باستخدام
  // CASE WHEN داخل SUM، أسرع من استعلامين منفصلين.

  Future<List<ProductStockSummary>> getAllProductsStock() async {
    final db = await _db;

    final result = await db.rawQuery('''
    SELECT
      p.id   AS product_id,
      p.name AS product_name,
      p.description  AS product_description,
      COALESCE(SUM(
        CASE
          WHEN it.type = 'PURCHASE'       THEN it.quantity
          WHEN it.type = 'SALE_RETURN'    THEN it.quantity
          ELSE 0
        END
      ), 0) AS total_in,
      COALESCE(SUM(
        CASE
          WHEN it.type = 'SALE'            THEN it.quantity
          WHEN it.type = 'PURCHASE_RETURN' THEN it.quantity
          ELSE 0
        END
      ), 0) AS total_out
    FROM products p
    LEFT JOIN inventory_transactions it ON it.product_id = p.id
    GROUP BY p.id, p.name, p.description
    ORDER BY p.name ASC
  ''');

    return result.map((row) {
      final totalIn = (row['total_in'] as num).toDouble();
      final totalOut = (row['total_out'] as num).toDouble();
      return ProductStockSummary(
        productId: row['product_id'] as int,
        productName: row['product_name'] as String,
        productDescription: row['product_description'] as String,
        totalPurchased: totalIn,
        totalSold: totalOut,
        available: totalIn - totalOut,
      );
    }).toList();
  }

  // ====================================================================
  // مخزون منتج واحد فقط
  // ====================================================================

  Future<ProductStockSummary?> getProductStock(int productId) async {
    final db = await _db;

    final result = await db.rawQuery('''
    SELECT
      p.id   AS product_id,
      p.name AS product_name,
      p.description  AS product_description,
      COALESCE(SUM(
        CASE
          WHEN it.type = 'PURCHASE'       THEN it.quantity
          WHEN it.type = 'SALE_RETURN'    THEN it.quantity
          ELSE 0
        END
      ), 0) AS total_in,
      COALESCE(SUM(
        CASE
          WHEN it.type = 'SALE'            THEN it.quantity
          WHEN it.type = 'PURCHASE_RETURN' THEN it.quantity
          ELSE 0
        END
      ), 0) AS total_out
    FROM products p
    LEFT JOIN inventory_transactions it ON it.product_id = p.id
    WHERE p.id = ?
    GROUP BY p.id, p.name, p.description
  ''', [productId]);

    if (result.isEmpty) return null;

    final row = result.first;
    final totalIn = (row['total_in'] as num).toDouble();
    final totalOut = (row['total_out'] as num).toDouble();

    return ProductStockSummary(
      productId: row['product_id'] as int,
      productName: row['product_name'] as String,
      productDescription: row['product_description'] as String,
      totalPurchased: totalIn,
      totalSold: totalOut,
      available: totalIn - totalOut,
    );
  }

  // ====================================================================
  // ملخص مخزون كل منتج ضمن مستودع معين (لدعم تعدد المستودعات/السيارات)
  // ====================================================================

  Future<List<ProductStockSummary>> getAllProductsStockByWarehouse(
    int warehouseId,
  ) async {
    final db = await _db;

    final result = await db.rawQuery(
      '''
    SELECT
      p.id   AS product_id,
      p.name AS product_name,
      p.description  AS product_description,
      COALESCE(SUM(
        CASE
          WHEN it.type = 'PURCHASE'       THEN it.quantity
          WHEN it.type = 'SALE_RETURN'    THEN it.quantity
          ELSE 0
        END
      ), 0) AS total_in,
      COALESCE(SUM(
        CASE
          WHEN it.type = 'SALE'            THEN it.quantity
          WHEN it.type = 'PURCHASE_RETURN' THEN it.quantity
          ELSE 0
        END
      ), 0) AS total_out
    FROM products p
    LEFT JOIN inventory_transactions it
      ON it.product_id = p.id AND it.warehouse_id = ?
    GROUP BY p.id, p.name, p.description
    ORDER BY p.name ASC
  ''',
      [warehouseId],
    );

    return result.map((row) {
      final totalIn = (row['total_in'] as num).toDouble();
      final totalOut = (row['total_out'] as num).toDouble();
      return ProductStockSummary(
        productId: row['product_id'] as int,
        productName: row['product_name'] as String,
        productDescription: row['product_description'] as String,
        totalPurchased: totalIn,
        totalSold: totalOut,
        available: totalIn - totalOut,
      );
    }).toList();
  }

  /// مخزون منتج واحد ضمن مستودع معين تحديداً.
  Future<double> getProductStockInWarehouse({
    required int productId,
    required int warehouseId,
  }) async {
    final db = await _db;

    final result = await db.rawQuery(
      '''
    SELECT
      COALESCE(SUM(
        CASE
          WHEN type = 'PURCHASE'       THEN quantity
          WHEN type = 'SALE_RETURN'    THEN quantity
          WHEN type = 'SALE'            THEN -quantity
          WHEN type = 'PURCHASE_RETURN' THEN -quantity
          ELSE 0
        END
      ), 0) AS available
    FROM inventory_transactions
    WHERE product_id = ? AND warehouse_id = ?
  ''',
      [productId, warehouseId],
    );

    return (result.first['available'] as num).toDouble();
  }

  // ====================================================================
  // Helper: بناء الصفحة من نتيجة الاستعلام
  // ====================================================================

  InventoryTransactionPage _buildPage(
      List<Map<String, dynamic>> result,
      int pageSize,
      ) {
    final hasNextPage = result.length > pageSize;
    final items = hasNextPage ? result.sublist(0, pageSize) : result;

    final transactions = items.map((row) {
      return InventoryTransactionView(
        transaction: InventoryTransactionModel.fromMap(row),
        productName: row['product_name'] as String,
        invoiceNumber: row['invoice_number'] as String,
      );
    }).toList();

    return InventoryTransactionPage(
      transactions: transactions,
      hasNextPage: hasNextPage,
      nextCursor: hasNextPage && items.isNotEmpty
          ? items.last['id'] as int?
          : null,
    );
  }
}