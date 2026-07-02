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
  final String productSku;
  final double totalPurchased;
  final double totalSold;
  final double available;

  ProductStockSummary({
    required this.productId,
    required this.productName,
    required this.productSku,
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

    final result = await db.rawQuery('''
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
    ''', [
      if (lastId != null) lastId,
      pageSize + 1,
    ]);

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

    final result = await db.rawQuery('''
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
    ''', [
      productId,
      if (lastId != null) lastId,
      pageSize + 1,
    ]);

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

    final result = await db.rawQuery('''
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
    ''', [
      invoiceId,
      if (lastId != null) lastId,
      pageSize + 1,
    ]);

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

    final result = await db.rawQuery('''
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
    ''', [
      type.name.toUpperCase(),
      if (lastId != null) lastId,
      pageSize + 1,
    ]);

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
        p.sku  AS product_sku,
        COALESCE(SUM(
          CASE WHEN it.type = 'PURCHASE' THEN it.quantity ELSE 0 END
        ), 0) AS total_purchased,
        COALESCE(SUM(
          CASE WHEN it.type = 'SALE' THEN it.quantity ELSE 0 END
        ), 0) AS total_sold
      FROM products p
      LEFT JOIN inventory_transactions it ON it.product_id = p.id
      GROUP BY p.id, p.name, p.sku
      ORDER BY p.name ASC
    ''');

    return result.map((row) {
      final purchased = (row['total_purchased'] as num).toDouble();
      final sold = (row['total_sold'] as num).toDouble();
      return ProductStockSummary(
        productId: row['product_id'] as int,
        productName: row['product_name'] as String,
        productSku: row['product_sku'] as String,
        totalPurchased: purchased,
        totalSold: sold,
        available: purchased - sold, // المخزون المتاح الحالي
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
        p.sku  AS product_sku,
        COALESCE(SUM(
          CASE WHEN it.type = 'PURCHASE' THEN it.quantity ELSE 0 END
        ), 0) AS total_purchased,
        COALESCE(SUM(
          CASE WHEN it.type = 'SALE' THEN it.quantity ELSE 0 END
        ), 0) AS total_sold
      FROM products p
      LEFT JOIN inventory_transactions it ON it.product_id = p.id
      WHERE p.id = ?
      GROUP BY p.id, p.name, p.sku
    ''', [productId]);

    if (result.isEmpty) return null;

    final row = result.first;
    final purchased = (row['total_purchased'] as num).toDouble();
    final sold = (row['total_sold'] as num).toDouble();

    return ProductStockSummary(
      productId: row['product_id'] as int,
      productName: row['product_name'] as String,
      productSku: row['product_sku'] as String,
      totalPurchased: purchased,
      totalSold: sold,
      available: purchased - sold,
    );
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