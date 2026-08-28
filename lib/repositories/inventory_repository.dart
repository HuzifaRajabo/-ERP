import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/inventory_transaction_model.dart';

/// نموذج مُعزَّز يضم بيانات الحركة + اسم المنتج + رقم الفاتورة
/// يُستخدم في الواجهة لعرض معلومات كاملة بدون joins إضافية
class InventoryTransactionView {
  final InventoryTransactionModel transaction;
  final String productName;

  /// رقم الفاتورة (فارغ لحركات التحويل بين المستودعات).
  final String? invoiceNumber;

  /// اسم المستودع الذي تنتمي إليه هذه الحركة
  /// (مصدر التحويل لأجل TRANSFER_OUT، والوجهة لأجل TRANSFER_IN).
  final String? warehouseName;

  /// اسم المستودع المقابل في عمليات التحويل
  /// (الوجهة لأجل TRANSFER_OUT، والمصدر لأجل TRANSFER_IN).
  final String? counterpartyWarehouseName;

  final String? batchNumber;
  final String? expiryDate;
  final String? unitName;

  InventoryTransactionView({
    required this.transaction,
    required this.productName,
    this.invoiceNumber,
    this.warehouseName,
    this.counterpartyWarehouseName,
    this.batchNumber,
    this.expiryDate,
    this.unitName,
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
  final String? unitName;
  final int value; // قيمة المتاح بالسنت (بسعر التكلفة)

  ProductStockSummary({
    required this.productId,
    required this.productName,
    required this.productDescription,
    required this.totalPurchased,
    required this.totalSold,
    required this.available,
    this.unitName,
    this.value = 0,
  });
}

/// تفاصيل مخزون دفعة منتج معين ضمن مستودع معين.
class WarehouseProductBatchStock {
  final int batchId;
  final String? batchNumber;
  final String? expiryDate;
  final double available;
  final int costPrice; // تكلفة الوحدة الأساسية (من الدفعة أو المنتج)

  WarehouseProductBatchStock({
    required this.batchId,
    required this.batchNumber,
    required this.expiryDate,
    required this.available,
    required this.costPrice,
  });
}

class InventoryRepository {
  InventoryRepository({Future<Database> Function()? dbProvider})
      : _dbProvider =
            dbProvider ?? (() async => DatabaseHelper.instance.database);

  final Future<Database> Function() _dbProvider;

  Future<Database> get _db async => _dbProvider();

  static const int _defaultPageSize = 20;

  // ====================================================================
  // جلب حركات المخزون مع JOIN لجلب اسم المنتج ورقم الفاتورة
  // ====================================================================
  //
  // نستخدم rawQuery لأن db.query() لا تدعم JOIN مباشرة.
  // الـ JOIN هنا ضروري لعرض اسم المنتج ورقم الفاتورة في القائمة
  // بدون الحاجة لاستعلامات إضافية لكل سطر (N+1 problem).
  //
  // حركات التحويل بين المستودعات لا تملك فاتورة، لذلك نستخدم LEFT JOIN
  // مع invoices، ونربط المستودع المقابل عبر مساواة transfer_id بذاتها.

  static String get _selectClause => '''
        SELECT DISTINCT
          it.id,
          it.product_id,
          it.type,
          it.quantity,
          it.invoice_id,
          it.warehouse_id,
          it.batch_id,
          it.unit_id,
          it.created_at,
          p.name            AS product_name,
          inv.invoice_number,
          w.name            AS warehouse_name,
          w2.name           AS counterparty_warehouse_name,
          b.batch_number    AS batch_number,
          b.expiry_date     AS expiry_date,
          pu.unit_name      AS unit_name
        FROM inventory_transactions it
        INNER JOIN products p        ON p.id   = it.product_id
        LEFT  JOIN invoices inv      ON inv.id = it.invoice_id
        LEFT  JOIN warehouses w      ON w.id   = it.warehouse_id
        LEFT  JOIN batches b         ON b.id   = it.batch_id
        LEFT  JOIN product_units pu  ON pu.id  = it.unit_id
        LEFT  JOIN inventory_transactions it2
          ON it2.transfer_id = it.transfer_id
         AND it2.id <> it.id
        LEFT  JOIN warehouses w2     ON w2.id  = it2.warehouse_id
  ''';

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
      $_selectClause
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
      $_selectClause
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
      $_selectClause
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
  // فلترة حسب النوع (SALE / PURCHASE / TRANSFER ...)
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
      $_selectClause
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
  // حركات مستودع معين (اختيارياً مفلترة حسب النوع)
  // ====================================================================

  Future<InventoryTransactionPage> getTransactionsByWarehouse({
    required int warehouseId,
    InventoryTransactionType? type,
    int? lastId,
    int pageSize = _defaultPageSize,
  }) async {
    final db = await _db;
    final params = <Object?>[warehouseId];
    if (type != null) {
      params.add(type.name.toUpperCase());
    }
    if (lastId != null) {
      params.add(lastId);
    }
    params.add(pageSize + 1);

    final result = await db.rawQuery(
      '''
      $_selectClause
      WHERE it.warehouse_id = ?
      ${type != null ? 'AND it.type = ?' : ''}
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
          WHEN it.type = 'TRANSFER_IN'    THEN it.quantity
          ELSE 0
        END
      ), 0) AS total_in,
      COALESCE(SUM(
        CASE
          WHEN it.type = 'SALE'            THEN it.quantity
          WHEN it.type = 'PURCHASE_RETURN' THEN it.quantity
          WHEN it.type = 'TRANSFER_OUT'    THEN it.quantity
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
          WHEN it.type = 'TRANSFER_IN'    THEN it.quantity
          ELSE 0
        END
      ), 0) AS total_in,
      COALESCE(SUM(
        CASE
          WHEN it.type = 'SALE'            THEN it.quantity
          WHEN it.type = 'PURCHASE_RETURN' THEN it.quantity
          WHEN it.type = 'TRANSFER_OUT'    THEN it.quantity
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
      pu.unit_name AS unit_name,
      COALESCE(SUM(
        CASE
          WHEN it.type = 'PURCHASE'       THEN it.quantity
          WHEN it.type = 'SALE_RETURN'    THEN it.quantity
          WHEN it.type = 'TRANSFER_IN'    THEN it.quantity
          ELSE 0
        END
      ), 0) AS total_in,
      COALESCE(SUM(
        CASE
          WHEN it.type = 'SALE'            THEN it.quantity
          WHEN it.type = 'PURCHASE_RETURN' THEN it.quantity
          WHEN it.type = 'TRANSFER_OUT'    THEN it.quantity
          ELSE 0
        END
      ), 0) AS total_out,
      COALESCE((
        SELECT SUM(b.available * COALESCE(b2.cost_price, p.cost_price, 0))
        FROM (
          SELECT b3.id AS batch_id,
                 COALESCE(SUM(
                   CASE
                     WHEN it3.type = 'PURCHASE'       THEN it3.quantity
                     WHEN it3.type = 'SALE_RETURN'    THEN it3.quantity
                     WHEN it3.type = 'TRANSFER_IN'    THEN it3.quantity
                     WHEN it3.type = 'SALE'            THEN -it3.quantity
                     WHEN it3.type = 'PURCHASE_RETURN' THEN -it3.quantity
                     WHEN it3.type = 'TRANSFER_OUT'    THEN -it3.quantity
                     ELSE 0
                   END
                 ), 0) AS available
          FROM batches b3
          LEFT JOIN inventory_transactions it3
            ON it3.batch_id = b3.id AND it3.warehouse_id = ?
          WHERE b3.product_id = p.id
          GROUP BY b3.id
          HAVING available > 0
        ) b
        LEFT JOIN batches b2 ON b2.id = b.batch_id
      ), 0) AS value
    FROM products p
    LEFT JOIN inventory_transactions it
      ON it.product_id = p.id AND it.warehouse_id = ?
    LEFT JOIN product_units pu
      ON pu.product_id = p.id AND pu.is_base_unit = 1
    GROUP BY p.id, p.name, p.description, pu.unit_name
    ORDER BY p.name ASC
  ''',
      [warehouseId, warehouseId],
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
        unitName: row['unit_name'] as String?,
        value: (row['value'] as num).round(),
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
          WHEN type = 'TRANSFER_IN'    THEN quantity
          WHEN type = 'SALE'            THEN -quantity
          WHEN type = 'PURCHASE_RETURN' THEN -quantity
          WHEN type = 'TRANSFER_OUT'    THEN -quantity
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
  // تفاصيل مخزون منتج ضمن مستودع حسب الدفعات (للتحويل والحفظ)
  // ====================================================================

  /// تفاصيل الدفعات المتاحة لمنتج معين داخل مستودع معين،
  /// مع الكمية المتاحة والتكلفة لكل دفعة، مرتبة FEFO.
  /// يُستخدم في شاشة تفاصيل المخزون وعملية التحويل.
  Future<List<WarehouseProductBatchStock>> getWarehouseProductBatches({
    required int warehouseId,
    required int productId,
  }) async {
    final db = await _db;
    final result = await db.rawQuery(
      '''
      SELECT
        b.id            AS batch_id,
        b.batch_number,
        b.expiry_date,
        b.cost_price    AS batch_cost_price,
        p.cost_price    AS product_cost_price,
        p.name          AS product_name,
        COALESCE(SUM(
          CASE
            WHEN it.type = 'PURCHASE'       THEN it.quantity
            WHEN it.type = 'SALE_RETURN'    THEN it.quantity
            WHEN it.type = 'TRANSFER_IN'    THEN it.quantity
            WHEN it.type = 'SALE'            THEN -it.quantity
            WHEN it.type = 'PURCHASE_RETURN' THEN -it.quantity
            WHEN it.type = 'TRANSFER_OUT'    THEN -it.quantity
            ELSE 0
          END
        ), 0) AS available
      FROM batches b
      INNER JOIN products p ON p.id = b.product_id
      LEFT JOIN inventory_transactions it
        ON it.batch_id = b.id AND it.warehouse_id = ?
      WHERE b.product_id = ?
      GROUP BY b.id
      HAVING available > 0
      ORDER BY
        CASE WHEN b.expiry_date IS NULL THEN 1 ELSE 0 END,
        b.expiry_date ASC
    ''',
      [warehouseId, productId],
    );

    return result.map((row) {
      final available = (row['available'] as num).toDouble();
      return WarehouseProductBatchStock(
        batchId: row['batch_id'] as int,
        batchNumber: row['batch_number'] as String?,
        expiryDate: row['expiry_date'] as String?,
        available: available,
        costPrice: (row['batch_cost_price'] as int?) ??
            (row['product_cost_price'] as int?) ??
            0,
      );
    }).toList();
  }

  // ====================================================================
  // قيمة مخزون مستودع (بسعر التكلفة)
  // ====================================================================

  /// القيمة الإجمالية لمخزون مستودع معين بالسنت، محسوبة كمجموع
  /// (الكمية المتاحة × تكلفة الوحدة الأساسية) عبر كل دفعة.
  /// التكلفة تُؤخذ من الدفعة إن وُجدت وإلا من المنتج.
  Future<int> getWarehouseInventoryValue(int warehouseId) async {
    final db = await _db;
    final result = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(q.available * COALESCE(q.batch_cost, q.product_cost, 0)), 0) AS value
      FROM (
        SELECT
          b.id AS batch_id,
          b.cost_price AS batch_cost,
          p.cost_price AS product_cost,
          COALESCE(SUM(
            CASE
              WHEN it.type = 'PURCHASE'       THEN it.quantity
              WHEN it.type = 'SALE_RETURN'    THEN it.quantity
              WHEN it.type = 'TRANSFER_IN'    THEN it.quantity
              WHEN it.type = 'SALE'            THEN -it.quantity
              WHEN it.type = 'PURCHASE_RETURN' THEN -it.quantity
              WHEN it.type = 'TRANSFER_OUT'    THEN -it.quantity
              ELSE 0
            END
          ), 0) AS available
        FROM batches b
        INNER JOIN products p ON p.id = b.product_id
        LEFT JOIN inventory_transactions it
          ON it.batch_id = b.id AND it.warehouse_id = ?
        GROUP BY b.id
        HAVING available > 0
      ) q
    ''',
      [warehouseId],
    );

    return (result.first['value'] as num).round();
  }

  /// عدد التحويلات الفريدة الصادرة أو الواردة لمستودع معين.
  Future<int> getWarehouseTransferCount(int warehouseId) async {
    final db = await _db;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT transfer_id) AS c
      FROM inventory_transactions
      WHERE warehouse_id = ? AND transfer_id IS NOT NULL
      ''',
      [warehouseId],
    );
    return (result.first['c'] as int?) ?? 0;
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
        invoiceNumber: row['invoice_number'] as String?,
        warehouseName: row['warehouse_name'] as String?,
        counterpartyWarehouseName:
            row['counterparty_warehouse_name'] as String?,
        batchNumber: row['batch_number'] as String?,
        expiryDate: row['expiry_date'] as String?,
        unitName: row['unit_name'] as String?,
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