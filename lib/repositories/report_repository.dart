// lib/repositories/report_repository.dart

import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/report_model.dart';

class ReportRepository {
  ReportRepository({Future<Database> Function()? dbProvider})
    : _dbProvider =
          dbProvider ?? (() async => DatabaseHelper.instance.database);

  final Future<Database> Function() _dbProvider;

  Future<Database> get _db async => _dbProvider();

  int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

  String _formatDateTimeForSqlite(DateTime dateTime) {
    final value = dateTime.toUtc().toIso8601String().split('.').first;
    return value.replaceFirst('T', ' ');
  }

  // ====================================================================
  // التقرير العام
  // ====================================================================

  Future<ReportOverview> getOverview({DateTime? from, DateTime? to}) async {
    final db = await _db;

    final invWhere = <String>[];
    final retWhere = <String>[];
    final expWhere = <String>[];
    final payWhere = <String>[];

    if (from != null) {
      final f = _formatDateTimeForSqlite(from);
      // Use unqualified column name so the filter can be reused
      // across queries that alias the invoices table differently
      invWhere.add("created_at >= '$f'");
      retWhere.add("r.created_at >= '$f'");
      expWhere.add("created_at >= '$f'");
      payWhere.add("p.created_at >= '$f'");
    }
    if (to != null) {
      final t = _formatDateTimeForSqlite(to);
      invWhere.add("created_at <= '$t'");
      retWhere.add("r.created_at <= '$t'");
      expWhere.add("created_at <= '$t'");
      payWhere.add("p.created_at <= '$t'");
    }

    final invFilter = invWhere.isEmpty ? '' : 'AND ${invWhere.join(' AND ')}';
    final retWhereClause = retWhere.isEmpty
        ? ''
        : 'WHERE ${retWhere.join(' AND ')}';
    final expFilter = expWhere.isEmpty ? '' : 'WHERE ${expWhere.join(' AND ')}';
    final payFilter = payWhere.isEmpty ? '' : 'AND ${payWhere.join(' AND ')}';

    // ── فواتير المبيعات ──
    final saleQ = await db.rawQuery('''
      SELECT
        COUNT(*) AS count,
        COALESCE(SUM(i.original_total_amount), 0) AS total,
        COALESCE(SUM(i.paid_amount), 0) AS paid,
        COALESCE(SUM(
          CASE WHEN (i.total_amount - i.paid_amount) > 0
            THEN (i.total_amount - i.paid_amount)
            ELSE 0
          END
        ), 0) AS remaining
      FROM invoices i
      WHERE i.type = 'SALE' $invFilter
    ''');

    // ── فواتير المشتريات ──
    final purchaseQ = await db.rawQuery('''
      SELECT
        COUNT(*) AS count,
        COALESCE(SUM(i.original_total_amount), 0) AS total,
        COALESCE(SUM(i.paid_amount), 0) AS paid,
        COALESCE(SUM(
          CASE WHEN (i.total_amount - i.paid_amount) > 0
            THEN (i.total_amount - i.paid_amount)
            ELSE 0
          END
        ), 0) AS remaining
      FROM invoices i
      WHERE i.type = 'PURCHASE' $invFilter
    ''');

    // ── مرتجعات المبيعات ──
    final saleRetQ = await db.rawQuery('''
      SELECT COUNT(*) AS count, COALESCE(SUM(total_amount), 0) AS total
      FROM returns r
      WHERE r.type = 'SALE_RETURN'
      ${retWhereClause.isEmpty ? '' : 'AND ${retWhereClause.substring(6)}'}
    ''');

    // ── مرتجعات المشتريات ──
    final purchRetQ = await db.rawQuery('''
      SELECT COUNT(*) AS count, COALESCE(SUM(total_amount), 0) AS total
      FROM returns r
      WHERE r.type = 'PURCHASE_RETURN'
      ${retWhereClause.isEmpty ? '' : 'AND ${retWhereClause.substring(6)}'}
    ''');

    // ── المصاريف ──
    final expQ = await db.rawQuery('''
      SELECT COUNT(*) AS count, COALESCE(SUM(amount), 0) AS total
      FROM expenses $expFilter
    ''');

    // ── المدفوعات داخل الفترة ──
    final payInQ = await db.rawQuery('''
      SELECT COALESCE(SUM(
        CASE
          WHEN i.type = 'SALE' THEN CASE WHEN p.type = 'INBOUND' THEN p.amount ELSE -p.amount END
          ELSE 0
        END
      ), 0) AS total
      FROM payments p
      INNER JOIN invoices i ON i.id = p.invoice_id
      WHERE i.type = 'SALE' $payFilter
    ''');
    final payOutQ = await db.rawQuery('''
      SELECT COALESCE(SUM(
        CASE
          WHEN i.type = 'PURCHASE' THEN CASE WHEN p.type = 'OUTBOUND' THEN p.amount ELSE -p.amount END
          ELSE 0
        END
      ), 0) AS total
      FROM payments p
      INNER JOIN invoices i ON i.id = p.invoice_id
      WHERE i.type = 'PURCHASE' $payFilter
    ''');

    // ── الذمم المدينة (مستحق لنا من عملاء) ──
    final debtsToUsQ = await db.rawQuery('''
      SELECT COALESCE(SUM(i.total_amount - i.paid_amount), 0) AS total
      FROM invoices i
      WHERE i.type = 'SALE'
        AND (i.total_amount - i.paid_amount) > 0
    ''');

    // ── الذمم الدائنة (مستحق للموردين) ──
    final debtsByUsQ = await db.rawQuery('''
      SELECT COALESCE(SUM(i.total_amount - i.paid_amount), 0) AS total
      FROM invoices i
      WHERE i.type = 'PURCHASE'
        AND (i.total_amount - i.paid_amount) > 0
    ''');

    // ── تكلفة البضاعة المباعة (COGS) ──
    // تُحسب بطريقة FIFO وفق الكميات الفعلية (بالوحدة الأساسية) التي
    // استهلكتها المبيعات، مع الأخذ في الاعتبار تحويل الوحدات والتكلفة
    // الفعلية لكل دفعة/فاتورة شراء. لا تُستخدم أسعار المشتريات كصافي
    // لكل الوحدات المباعة (كان ذلك يضاعف التكلفة عند بيع جزء صغير).
    final cogsTotal = await _periodCogs(db, from: from, to: to);

    // ── قيمة المخزون الحالية ──
    // تُحسب بنفس طبقات FIFO: بعد استهلاك كل المبيعات (بكل الفترات، لأن
    // المخزون الحالي كمية لحظية)، تُقيَّم الكمية المتبقية من كل طبقة
    // بتكلفتها الفعلية — وبذلك تُؤخذ تكلفة الدفعات المختلفة في الحسبان.
    final inventoryValue = await _currentInventoryValue(db);

    final sale = saleQ.first;
    final purchase = purchaseQ.first;
    final saleRet = saleRetQ.first;
    final purchRet = purchRetQ.first;
    final exp = expQ.first;
    final payIn = payInQ.first;
    final payOut = payOutQ.first;
    final debtsToUs = debtsToUsQ.first;
    final debtsByUs = debtsByUsQ.first;

    final saleTotal = _toInt(sale['total']);
    final saleRetTotal = _toInt(saleRet['total']);
    final saleNetTotal = ReportMath.netSales(saleTotal, saleRetTotal);

    final purchTotal = _toInt(purchase['total']);
    final purchRetTotal = _toInt(purchRet['total']);
    final purchNetTotal = purchTotal - purchRetTotal;

    final grossProfit = ReportMath.grossProfit(saleNetTotal, cogsTotal);
    final expTotal = _toInt(exp['total']);
    final netProfit = ReportMath.netProfit(grossProfit, expTotal);
    final warehouseSummaries = await _getWarehouseSummaries(
      db,
      from: from,
      to: to,
    );

    return ReportOverview(
      saleInvoiceCount: _toInt(sale['count']),
      saleTotal: saleTotal,
      salePaid: _toInt(payIn['total']),
      saleRemaining: _toInt(debtsToUs['total']),
      saleReturnTotal: saleRetTotal,
      saleReturnCount: _toInt(saleRet['count']),
      saleNetTotal: saleNetTotal,
      purchaseInvoiceCount: _toInt(purchase['count']),
      purchaseTotal: purchTotal,
      purchasePaid: _toInt(payOut['total']),
      purchaseRemaining: _toInt(debtsByUs['total']),
      purchaseReturnTotal: purchRetTotal,
      purchaseReturnCount: _toInt(purchRet['count']),
      purchaseNetTotal: purchNetTotal,
      expenseCount: _toInt(exp['count']),
      expenseTotal: expTotal,
      debtsOwedToUs: _toInt(debtsToUs['total']),
      debtsOwedByUs: _toInt(debtsByUs['total']),
      inventoryValue: inventoryValue,
      cogsTotal: cogsTotal,
      grossProfit: grossProfit,
      netProfit: netProfit,
      warehouseSummaries: warehouseSummaries,
    );
  }

  Future<List<WarehouseReportSummary>> _getWarehouseSummaries(
    Database db, {
    DateTime? from,
    DateTime? to,
  }) async {
    final dateArgs = <Object?>[];
    var dateFilter = '';
    if (from != null) {
      dateFilter += ' AND i.created_at >= ?';
      dateArgs.add(_formatDateTimeForSqlite(from));
    }
    if (to != null) {
      dateFilter += ' AND i.created_at <= ?';
      dateArgs.add(_formatDateTimeForSqlite(to));
    }

    final salesRows = await db.rawQuery('''
      SELECT i.warehouse_id, COALESCE(SUM(i.original_total_amount), 0) AS total
      FROM invoices i
      WHERE i.type = 'SALE' AND i.warehouse_id IS NOT NULL $dateFilter
      GROUP BY i.warehouse_id
    ''', dateArgs);
    final returnRows = await db.rawQuery('''
      SELECT i.warehouse_id, COALESCE(SUM(r.total_amount), 0) AS total
      FROM returns r
      INNER JOIN invoices i ON i.id = r.original_invoice_id
      WHERE r.type = 'SALE_RETURN' AND i.warehouse_id IS NOT NULL
        ${from == null ? '' : ' AND r.created_at >= ?'}
        ${to == null ? '' : ' AND r.created_at <= ?'}
      GROUP BY i.warehouse_id
    ''', [
      if (from != null) _formatDateTimeForSqlite(from),
      if (to != null) _formatDateTimeForSqlite(to),
    ]);
    final cogsRows = await db.rawQuery('''
      SELECT warehouse_id, batch_id, product_id, type, quantity
      FROM inventory_transactions
      WHERE warehouse_id IS NOT NULL
        AND type IN ('SALE', 'SALE_RETURN')
        ${from == null ? '' : ' AND created_at >= ?'}
        ${to == null ? '' : ' AND created_at <= ?'}
    ''', [
      if (from != null) _formatDateTimeForSqlite(from),
      if (to != null) _formatDateTimeForSqlite(to),
    ]);
    final costs = await _loadUnitCosts(db);
    final sales = <int, int>{};
    final returns = <int, int>{};
    final cogs = <int, double>{};
    for (final row in salesRows) {
      sales[row['warehouse_id'] as int] = _toInt(row['total']);
    }
    for (final row in returnRows) {
      returns[row['warehouse_id'] as int] = _toInt(row['total']);
    }
    for (final row in cogsRows) {
      final warehouseId = row['warehouse_id'] as int;
      final productId = row['product_id'] as int;
      final batchId = row['batch_id'] as int?;
      final unitCost =
          costs.batchCosts[batchId] ?? costs.productCosts[productId] ?? 0;
      final quantity = (row['quantity'] as num).toDouble();
      cogs[warehouseId] =
          (cogs[warehouseId] ?? 0) +
          (row['type'] == 'SALE' ? quantity : -quantity) * unitCost;
    }

    final inventoryRows = await db.rawQuery('''
      SELECT warehouse_id, product_id, batch_id,
        SUM(CASE
          WHEN type IN ('PURCHASE','SALE_RETURN','TRANSFER_IN') THEN quantity
          WHEN type IN ('SALE','PURCHASE_RETURN','TRANSFER_OUT') THEN -quantity
          ELSE 0 END) AS quantity
      FROM inventory_transactions
      WHERE warehouse_id IS NOT NULL
      GROUP BY warehouse_id, product_id, batch_id
      HAVING quantity > 0
    ''');
    final inventory = <int, double>{};
    for (final row in inventoryRows) {
      final warehouseId = row['warehouse_id'] as int;
      final productId = row['product_id'] as int;
      final batchId = row['batch_id'] as int?;
      final unitCost =
          costs.batchCosts[batchId] ?? costs.productCosts[productId] ?? 0;
      inventory[warehouseId] =
          (inventory[warehouseId] ?? 0) +
          (row['quantity'] as num).toDouble() * unitCost;
    }

    final warehouses = await db.query(
      'warehouses',
      where: 'is_active = 1',
      orderBy: 'name ASC',
    );
    return warehouses.map((warehouse) {
      final id = warehouse['id'] as int;
      final grossSales = sales[id] ?? 0;
      final salesReturns = returns[id] ?? 0;
      final netSales = ReportMath.netSales(grossSales, salesReturns);
      final warehouseCogs = (cogs[id] ?? 0).round();
      return WarehouseReportSummary(
        warehouseId: id,
        warehouseName: warehouse['name'] as String,
        sales: grossSales,
        salesReturns: salesReturns,
        cogs: warehouseCogs,
        grossProfit: ReportMath.grossProfit(netSales, warehouseCogs),
        inventoryValue: (inventory[id] ?? 0).round(),
      );
    }).where((summary) =>
        summary.sales != 0 ||
        summary.cogs != 0 ||
        summary.inventoryValue != 0).toList();
  }

  Future<int> _periodCogs(Database db, {DateTime? from, DateTime? to}) async {
    final predicates = <String>["it.type IN ('SALE','SALE_RETURN')"];
    final args = <Object?>[];
    if (from != null) {
      predicates.add('it.created_at >= ?');
      args.add(_formatDateTimeForSqlite(from));
    }
    if (to != null) {
      predicates.add('it.created_at <= ?');
      args.add(_formatDateTimeForSqlite(to));
    }

    final rows = await db.rawQuery('''
      SELECT it.product_id, it.batch_id, it.type, it.quantity
      FROM inventory_transactions it
      WHERE ${predicates.join(' AND ')}
      ORDER BY it.created_at, it.id
    ''', args);
    final costs = await _loadUnitCosts(db);
    var total = 0.0;
    for (final row in rows) {
      final productId = row['product_id'] as int;
      final batchId = row['batch_id'] as int?;
      final unitCost =
          costs.batchCosts[batchId] ?? costs.productCosts[productId] ?? 0;
      final quantity = (row['quantity'] as num).toDouble();
      total += (row['type'] == 'SALE' ? quantity : -quantity) * unitCost;
    }
    return total.round();
  }

  Future<int> _currentInventoryValue(Database db) async {
    final costs = await _loadUnitCosts(db);
    final rows = await db.rawQuery('''
      SELECT product_id, batch_id,
        COALESCE(warehouse_id, 0) AS warehouse_id,
        SUM(CASE
          WHEN type IN ('PURCHASE','SALE_RETURN','TRANSFER_IN') THEN quantity
          WHEN type IN ('SALE','PURCHASE_RETURN','TRANSFER_OUT') THEN -quantity
          ELSE 0 END) AS quantity
      FROM inventory_transactions
      GROUP BY product_id, batch_id, warehouse_id
      HAVING quantity > 0
    ''');
    var total = 0.0;
    for (final row in rows) {
      final productId = row['product_id'] as int;
      final batchId = row['batch_id'] as int?;
      final quantity = (row['quantity'] as num).toDouble();
      total +=
          quantity *
          (costs.batchCosts[batchId] ?? costs.productCosts[productId] ?? 0);
    }
    return total.round();
  }

  Future<_UnitCosts> _loadUnitCosts(Database db) async {
    final batchRows = await db.rawQuery('''
      SELECT b.id AS batch_id, COALESCE(
        b.cost_price,
        (SELECT SUM(ii.line_total) /
          NULLIF(SUM(ii.quantity * ii.conversion_factor_snapshot), 0)
         FROM invoice_items ii
         INNER JOIN invoices i ON i.id = ii.invoice_id
         INNER JOIN inventory_transactions pit
           ON pit.invoice_id = i.id AND pit.product_id = ii.product_id
         WHERE i.type = 'PURCHASE' AND pit.batch_id = b.id),
        p.cost_price, 0) AS cost
      FROM batches b
      INNER JOIN products p ON p.id = b.product_id
    ''');
    final batchCosts = <int, double>{};
    for (final row in batchRows) {
      batchCosts[row['batch_id'] as int] = (row['cost'] as num).toDouble();
    }

    final productRows = await db.rawQuery('''
      SELECT p.id AS product_id,
        COALESCE(
          SUM(CASE WHEN i.type = 'PURCHASE' THEN ii.line_total ELSE 0 END) /
          NULLIF(SUM(CASE WHEN i.type = 'PURCHASE'
            THEN ii.quantity * ii.conversion_factor_snapshot ELSE 0 END), 0),
          p.cost_price, 0) AS cost
      FROM products p
      LEFT JOIN invoice_items ii ON ii.product_id = p.id
      LEFT JOIN invoices i ON i.id = ii.invoice_id
      GROUP BY p.id
    ''');
    final productCosts = <int, double>{};
    for (final row in productRows) {
      productCosts[row['product_id'] as int] = (row['cost'] as num).toDouble();
    }
    return _UnitCosts(batchCosts: batchCosts, productCosts: productCosts);
  }

  // ====================================================================
  // تفاصيل الأرباح لكل فاتورة بيع
  // ====================================================================

  Future<List<InvoiceProfitDetail>> getInvoiceProfitDetails({
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db;

    final invWhere = <String>['inv.type = \'SALE\''];
    if (from != null) {
      invWhere.add("inv.created_at >= '${_formatDateTimeForSqlite(from)}'");
    }
    if (to != null) {
      invWhere.add("inv.created_at <= '${_formatDateTimeForSqlite(to)}'");
    }

    final filter = 'WHERE ${invWhere.join(' AND ')}';

    // جلب فواتير البيع صعودياً (الأقدم أولاً) لاستهلاك طبقات التكلفة FIFO
    // بنفس ترتيب حدوث المخزون فعلياً.
    final invoices = await db.rawQuery('''
      SELECT
        inv.id              AS invoice_id,
        inv.invoice_number,
        inv.party_name_snapshot AS party_name,
        inv.created_at,
        inv.total_amount    AS sale_amount
      FROM invoices inv
      $filter
      ORDER BY inv.created_at ASC, inv.id ASC
    ''');

    final costs = await _loadUnitCosts(db);
    final transactionRows = await db.rawQuery('''
      SELECT invoice_id, product_id, batch_id, type, quantity
      FROM inventory_transactions
      WHERE invoice_id IS NOT NULL AND type IN ('SALE','SALE_RETURN')
    ''');
    final costByInvoice = <int, double>{};
    for (final tx in transactionRows) {
      final invoiceId = tx['invoice_id'] as int;
      final productId = tx['product_id'] as int;
      final batchId = tx['batch_id'] as int?;
      final unitCost =
          costs.batchCosts[batchId] ?? costs.productCosts[productId] ?? 0;
      final quantity = (tx['quantity'] as num).toDouble();
      costByInvoice[invoiceId] =
          (costByInvoice[invoiceId] ?? 0) +
          (tx['type'] == 'SALE' ? quantity : -quantity) * unitCost;
    }

    final details = <InvoiceProfitDetail>[];
    for (final row in invoices) {
      final invoiceId = row['invoice_id'] as int;
      final saleAmount = _toInt(row['sale_amount']);

      final costAmount = costByInvoice[invoiceId] ?? 0;
      final costCents = costAmount.round();
      final profit = saleAmount - costCents;
      final margin = saleAmount > 0 ? (profit / saleAmount * 100) : 0.0;

      details.add(
        InvoiceProfitDetail(
          invoiceId: invoiceId,
          invoiceNumber: row['invoice_number'] as String,
          partyName: row['party_name'] as String,
          createdAt: row['created_at'] as String? ?? '',
          saleAmount: saleAmount,
          costAmount: costCents,
          profit: profit,
          margin: margin,
        ),
      );
    }

    // العرض الأحدث أولاً
    return details.reversed.toList();
  }

}
class _UnitCosts {
  final Map<int, double> batchCosts;
  final Map<int, double> productCosts;

  const _UnitCosts({required this.batchCosts, required this.productCosts});
}
