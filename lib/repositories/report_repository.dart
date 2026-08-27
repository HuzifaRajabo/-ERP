// lib/repositories/report_repository.dart

import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/report_model.dart';

class ReportRepository {
  ReportRepository({Future<Database> Function()? dbProvider})
      : _dbProvider = dbProvider ?? (() async => DatabaseHelper.instance.database);

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
    // تُحسب بطريقة FIFO وفق الكميات الفعلية (بالوحدة الأساسية) التي
    // استهلكتها المبيعات، مع الأخذ في الاعتبار تحويل الوحدات والتكلفة
    // الفعلية لكل دفعة/فاتورة شراء. لا تُستخدم أسعار المشتريات كصافي
    // لكل الوحدات المباعة (كان ذلك يضاعف التكلفة عند بيع جزء صغير).
    final layers = await _buildFifoLayers(db);
    final soldBase = await _netSoldBaseQuantities(db, from: from, to: to);
    var cogsCents = 0.0;
    for (final entry in soldBase.entries) {
      final productId = entry.key;
      final netQty = entry.value;
      if (netQty <= 0) continue;
      cogsCents += await _fifoConsumeCost(
        layers,
        productId,
        netQty,
        mutate: false,
      );
    }
    final cogsTotal = cogsCents.round();

    // ── قيمة المخزون الحالية ──
    // تُحسب بنفس طبقات FIFO: بعد استهلاك كل المبيعات (بكل الفترات، لأن
    // المخزون الحالي كمية لحظية)، تُقيَّم الكمية المتبقية من كل طبقة
    // بتكلفتها الفعلية — وبذلك تُؤخذ تكلفة الدفعات المختلفة في الحسبان.
    final allTimeSold = await _netSoldBaseQuantities(db);
    final inventoryValueCents = await _remainingInventoryValue(
      layers,
      allTimeSold,
    );
    final inventoryValue = inventoryValueCents.round();

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
    final saleNetTotal = saleTotal - saleRetTotal;

    final purchTotal = _toInt(purchase['total']);
    final purchRetTotal = _toInt(purchRet['total']);
    final purchNetTotal = purchTotal - purchRetTotal;

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
      inventoryValue: inventoryValue,
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

    // الكمية الصافية (بالوحدة الأساسية) المباعة لكل فاتورة،
    // تتضمن المرتجعات (SALE - SALE_RETURN) بالوحدة الأساسية لضمان الاتساق.
    final soldQtyRows = await db.rawQuery('''
      SELECT
        invoice_id,
        product_id,
        SUM(CASE WHEN type = 'SALE' THEN quantity ELSE -quantity END) AS qty
      FROM inventory_transactions
      WHERE type IN ('SALE','SALE_RETURN')
      GROUP BY invoice_id, product_id
      HAVING SUM(CASE WHEN type = 'SALE' THEN quantity ELSE -quantity END) > 0
    ''');

    final qtyByInvoice = <int, Map<int, double>>{};
    for (final row in soldQtyRows) {
      final invoiceId = row['invoice_id'] as int;
      final productId = row['product_id'] as int;
      final qty = (row['qty'] as num).toDouble();
      qtyByInvoice
          .putIfAbsent(invoiceId, () => {})
          .putIfAbsent(productId, () => 0.0);
      qtyByInvoice[invoiceId]![productId] = qty;
    }

    // تكلفة FIFO منقولة عبر الفواتير (الأقدم أولاً)
    final layers = await _buildFifoLayers(db);

    final details = <InvoiceProfitDetail>[];
    for (final row in invoices) {
      final invoiceId = row['invoice_id'] as int;
      final saleAmount = _toInt(row['sale_amount']);

      var costAmount = 0.0;
      final productsToSell = qtyByInvoice[invoiceId] ?? const <int, double>{};
      for (final entry in productsToSell.entries) {
        final netQty = entry.value;
        if (netQty <= 0) continue;
        costAmount += await _fifoConsumeCost(
          layers,
          entry.key,
          netQty,
          mutate: true,
        );
      }
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

  // ====================================================================
  // FIFO: طبقات تكلفة المخزون واستهلاكها
  // ====================================================================

  /// يبني طبقات التكلفة (FIFO) لكل منتج من جميع فواتير الشراء حتى الآن،
  /// مع خصم مرتجعات المشتريات من كمية الطبقات. التكلفة لكل وحدة أساسية
  /// تُشتق من سطر الشراء: (line_total / الكمية بالوحدة الأساسية) لتُؤخذ
  /// حقيقة تحويل الوحدات (مثلاً 1 باكيت = 12 كرتون) في الحسبان.
  Future<Map<int, List<_CostLayer>>> _buildFifoLayers(Database db) async {
    final rows = await db.rawQuery('''
      SELECT
        inv.id AS invoice_id,
        ii.product_id AS product_id,
        COALESCE(SUM(ii.quantity * ii.conversion_factor_snapshot), 0) AS qty,
        COALESCE(SUM(ii.line_total), 0) AS cost_total
      FROM invoice_items ii
      INNER JOIN invoices inv ON inv.id = ii.invoice_id
      WHERE inv.type = 'PURCHASE'
      GROUP BY inv.id, ii.product_id
      ORDER BY inv.created_at ASC, inv.id ASC
    ''');

    // مرتجعات المشتريات لكل (فاتورة، منتج) بالوحدة الأساسية
    final retRows = await db.rawQuery('''
      SELECT
        invoice_id,
        product_id,
        SUM(quantity) AS ret_qty
      FROM inventory_transactions
      WHERE type = 'PURCHASE_RETURN'
      GROUP BY invoice_id, product_id
    ''');
    final retByKey = <String, double>{};
    for (final row in retRows) {
      final key = '${row['invoice_id']}_${row['product_id']}';
      retByKey[key] = (row['ret_qty'] as num).toDouble();
    }

    final layers = <int, List<_CostLayer>>{};
    for (final row in rows) {
      final productId = row['product_id'] as int;
      final qty = (row['qty'] as num).toDouble();
      final costTotal = (row['cost_total'] as num).toDouble();
      if (qty <= 0) continue;

      final key = '${row['invoice_id']}_$productId';
      final retQty = retByKey[key] ?? 0;
      final netQty = qty - retQty;
      if (netQty <= 0.0001) continue;

      final unitCost = costTotal / netQty;
      layers.putIfAbsent(productId, () => []).add(
        _CostLayer(netQty, unitCost),
      );
    }
    return layers;
  }

  /// الكمية الصافية المباعة (بالوحدة الأساسية) لكل منتج في الفترة،
  /// من inventory_transactions، وتشمل المرتجعات تلقائياً.
  Future<Map<int, double>> _netSoldBaseQuantities(
    Database db, {
    DateTime? from,
    DateTime? to,
  }) async {
    final where = <String>["it.type IN ('SALE','SALE_RETURN')"];
    if (from != null) {
      where.add("it.created_at >= '${_formatDateTimeForSqlite(from)}'");
    }
    if (to != null) {
      where.add("it.created_at <= '${_formatDateTimeForSqlite(to)}'");
    }
    final filter = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final rows = await db.rawQuery('''
      SELECT
        it.product_id AS product_id,
        SUM(CASE WHEN it.type = 'SALE' THEN it.quantity ELSE -it.quantity END) AS qty
      FROM inventory_transactions it
      $filter
      GROUP BY it.product_id
      HAVING SUM(CASE WHEN it.type = 'SALE' THEN it.quantity ELSE -it.quantity END) > 0
    ''');

    final result = <int, double>{};
    for (final row in rows) {
      result[row['product_id'] as int] = (row['qty'] as num).toDouble();
    }
    return result;
  }

  /// يستهلِك [qty] من الطبقات FIFO للمنتج ويُعيد التكلفة (بالسنت).
  /// [mutate] = false يعني نسخة غير معدَّلة (لا تُغيَّر الطبقات)،
  /// ويُستخدم للتقرير العام. مع [mutate] = true تُنقص الكميات فعلياً
  /// لتتبع الاستهلاك عبر فواتير متعددة بترتيب زمني.
  Future<double> _fifoConsumeCost(
    Map<int, List<_CostLayer>> layers,
    int productId,
    double qty, {
    required bool mutate,
  }) async {
    final productLayers = layers[productId];
    if (productLayers == null || productLayers.isEmpty || qty <= 0) return 0;

    final list = mutate
        ? productLayers
        : productLayers.map((l) => _CostLayer(l.remainingQty, l.unitCost)).toList();

    double remaining = qty;
    double cost = 0;
    for (final layer in list) {
      if (remaining <= 0.0001) break;
      final take = remaining > layer.remainingQty ? layer.remainingQty : remaining;
      if (take <= 0) continue;
      cost += take * layer.unitCost;
      layer.remainingQty -= take;
      remaining -= take;
    }
    return cost;
  }

  /// قيمة المخزون الحالي: يستهلك كل المبيعات (الكميات الصافية بالوحدة
  /// الأساسية) من نسخة من طبقات FIFO، ثم يقيِّم الكمية المتبقية من كل
  /// طبقة بتكلفتها الفعلية.
  Future<double> _remainingInventoryValue(
    Map<int, List<_CostLayer>> layers,
    Map<int, double> allTimeSold,
  ) async {
    final working = <int, List<_CostLayer>>{
      for (final e in layers.entries)
        e.key: e.value.map((l) => _CostLayer(l.remainingQty, l.unitCost)).toList(),
    };

    for (final entry in allTimeSold.entries) {
      final netQty = entry.value;
      if (netQty <= 0) continue;
      await _fifoConsumeCost(working, entry.key, netQty, mutate: true);
    }

    double value = 0;
    for (final list in working.values) {
      for (final layer in list) {
        if (layer.remainingQty > 0.0001) {
          value += layer.remainingQty * layer.unitCost;
        }
      }
    }
    return value;
  }
}

/// طبقة تكلفة واحدة في مخزون منتج (وحدة أساسية + تكلفة الوحدة).
class _CostLayer {
  double remainingQty;
  final double unitCost;

  _CostLayer(this.remainingQty, this.unitCost);
}
