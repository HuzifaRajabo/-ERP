// lib/repositories/report_repository.dart

import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/report_model.dart';

class ReportRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

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
    final retSubFilterRet = retWhere.isEmpty
        ? ''
        : ' AND ${retWhere.join(' AND ').replaceAll('r.', 'ret.')}';
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
      WHERE i.type = 'SALE' $invFilter
        AND (i.total_amount - i.paid_amount) > 0
    ''');

    // ── الذمم الدائنة (مستحق للموردين) ──
    final debtsByUsQ = await db.rawQuery('''
      SELECT COALESCE(SUM(i.total_amount - i.paid_amount), 0) AS total
      FROM invoices i
      WHERE i.type = 'PURCHASE' $invFilter
        AND (i.total_amount - i.paid_amount) > 0
    ''');

    // ── تكلفة البضاعة المباعة (COGS) ──
    final cogsQ = await db.rawQuery('''
      SELECT COALESCE(SUM(
        (
          SELECT ii_p.unit_price
          FROM invoice_items ii_p
          INNER JOIN invoices inv_p ON inv_p.id = ii_p.invoice_id
          WHERE inv_p.type = 'PURCHASE'
            AND ii_p.product_id = si.product_id
          ORDER BY inv_p.created_at DESC
          LIMIT 1
        ) *
        (si.quantity - COALESCE((
          SELECT SUM(ri.quantity)
          FROM return_items ri
          INNER JOIN returns ret ON ret.id = ri.return_id
          WHERE ret.type = 'SALE_RETURN'
            AND ret.original_invoice_id = si.invoice_id
            AND ri.product_id = si.product_id
            $retSubFilterRet
        ), 0))
      ), 0) AS total
      FROM invoice_items si
      INNER JOIN invoices inv ON inv.id = si.invoice_id
      WHERE inv.type = 'SALE' $invFilter
    ''');

    // ── قيمة المخزون الحالية ──
    final inventoryValueQ = await db.rawQuery('''
      SELECT COALESCE(SUM(stock * cost_price), 0) AS value
      FROM (
        SELECT
          p.cost_price,
          COALESCE(SUM(CASE WHEN it.type IN ('PURCHASE','SALE_RETURN') THEN it.quantity ELSE 0 END), 0)
          - COALESCE(SUM(CASE WHEN it.type IN ('SALE','PURCHASE_RETURN') THEN it.quantity ELSE 0 END), 0)
          AS stock
        FROM products p
        LEFT JOIN inventory_transactions it ON it.product_id = p.id
        GROUP BY p.id, p.cost_price
      )
    ''');

    final sale = saleQ.first;
    final purchase = purchaseQ.first;
    final saleRet = saleRetQ.first;
    final purchRet = purchRetQ.first;
    final exp = expQ.first;
    final payIn = payInQ.first;
    final payOut = payOutQ.first;
    final debtsToUs = debtsToUsQ.first;
    final debtsByUs = debtsByUsQ.first;
    final cogs = cogsQ.first;
    final inventory = inventoryValueQ.first;

    final saleTotal = _toInt(sale['total']);
    final saleRetTotal = _toInt(saleRet['total']);
    final saleNetTotal = saleTotal - saleRetTotal;

    final purchTotal = _toInt(purchase['total']);
    final purchRetTotal = _toInt(purchRet['total']);
    final purchNetTotal = purchTotal - purchRetTotal;

    final cogsTotal = _toInt(cogs['total']);
    final grossProfit = saleNetTotal - cogsTotal;
    final expTotal = _toInt(exp['total']);
    final netProfit = grossProfit - expTotal;

    return ReportOverview(
      saleInvoiceCount: _toInt(sale['count']),
      saleTotal: saleTotal,
      salePaid: _toInt(payIn['total']),
      saleRemaining: _toInt(sale['remaining']),
      saleReturnTotal: saleRetTotal,
      saleReturnCount: _toInt(saleRet['count']),
      saleNetTotal: saleNetTotal,
      purchaseInvoiceCount: _toInt(purchase['count']),
      purchaseTotal: purchTotal,
      purchasePaid: _toInt(payOut['total']),
      purchaseRemaining: _toInt(purchase['remaining']),
      purchaseReturnTotal: purchRetTotal,
      purchaseReturnCount: _toInt(purchRet['count']),
      purchaseNetTotal: purchNetTotal,
      expenseCount: _toInt(exp['count']),
      expenseTotal: expTotal,
      debtsOwedToUs: _toInt(debtsToUs['total']),
      debtsOwedByUs: _toInt(debtsByUs['total']),
      inventoryValue: _toInt(inventory['value']),
      cogsTotal: cogsTotal,
      grossProfit: grossProfit,
      netProfit: netProfit,
    );
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

    // جلب فواتير البيع مع حساب صافي البيع والتكلفة لكل فاتورة
    final result = await db.rawQuery('''
      SELECT
        inv.id              AS invoice_id,
        inv.invoice_number,
        inv.party_name_snapshot AS party_name,
        inv.created_at,
        -- صافي البيع = أصلي - مرتجعات هذه الفاتورة
        inv.total_amount AS sale_amount,
        -- تكلفة البضاعة المباعة لهذه الفاتورة
        COALESCE((
          SELECT SUM(
            (
              SELECT ii_p.unit_price
              FROM invoice_items ii_p
              INNER JOIN invoices inv_p ON inv_p.id = ii_p.invoice_id
              WHERE inv_p.type = 'PURCHASE'
                AND ii_p.product_id = si.product_id
              ORDER BY inv_p.created_at DESC
              LIMIT 1
            ) *
            (si.quantity - COALESCE((
              SELECT SUM(ri.quantity)
              FROM return_items ri
              INNER JOIN returns ret ON ret.id = ri.return_id
              WHERE ret.type = 'SALE_RETURN'
                AND ret.original_invoice_id = inv.id
                AND ri.product_id = si.product_id
            ), 0))
          )
          FROM invoice_items si
          WHERE si.invoice_id = inv.id
        ), 0) AS cost_amount
      FROM invoices inv
      $filter
      ORDER BY inv.created_at DESC
    ''');

    return result.map((row) {
      final saleAmount = _toInt(row['sale_amount']);
      final costAmount = _toInt(row['cost_amount']);
      final profit = saleAmount - costAmount;
      final margin = saleAmount > 0 ? (profit / saleAmount * 100) : 0.0;

      return InvoiceProfitDetail(
        invoiceId: row['invoice_id'] as int,
        invoiceNumber: row['invoice_number'] as String,
        partyName: row['party_name'] as String,
        createdAt: row['created_at'] as String? ?? '',
        saleAmount: saleAmount,
        costAmount: costAmount,
        profit: profit,
        margin: margin,
      );
    }).toList();
  }
}
