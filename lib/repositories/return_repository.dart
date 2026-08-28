// lib/repositories/return_repository.dart

import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/return_model.dart';

class ReturnRepository {
  ReturnRepository({Future<Database> Function()? dbProvider})
      : _dbProvider =
            dbProvider ?? (() async => DatabaseHelper.instance.database);

  final Future<Database> Function() _dbProvider;

  Future<Database> get _db async => _dbProvider();

  static const int _defaultPageSize = 20;

  // ====================================================================
  // إنشاء مرتجع — transaction ذري كامل
  // ====================================================================

  Future<int> createReturn({
    required int originalInvoiceId,
    required ReturnType type,
    required String? notes,
    required List<ReturnableItem> items, // الأسطر التي اختارها المستخدم
  }) async {
    // فلترة: فقط الأسطر التي فيها كمية > 0
    final activeItems = items.where((i) => i.selectedQuantity > 0).toList();

    if (activeItems.isEmpty) {
      throw Exception('يجب اختيار كمية واحدة على الأقل للإرجاع');
    }

    final db = await _db;

    return await db.transaction<int>((txn) async {
      // ----------------------------------------------------------------
      // الخطوة 0: جلب الفاتورة الأصلية والتحقق منها
      // ----------------------------------------------------------------
      final invoiceResult = await txn.query(
        'invoices',
        where: 'id = ?',
        whereArgs: [originalInvoiceId],
        limit: 1,
      );

      if (invoiceResult.isEmpty) {
        throw Exception('الفاتورة الأصلية غير موجودة');
      }

      final invoice = invoiceResult.first;
      final invoiceType = invoice['type'] as String;
      final expectedType =
          type == ReturnType.saleReturn ? 'SALE' : 'PURCHASE';
      if (invoiceType != expectedType) {
        throw Exception('نوع المرتجع لا يطابق نوع الفاتورة الأصلية');
      }
      final partyId = invoice['party_id'] as int;
      final partyName = invoice['party_name_snapshot'] as String;
      final partyAddress = invoice['party_address_snapshot'] as String;
      final invoiceWarehouseId = invoice['warehouse_id'] as int?;

      // ----------------------------------------------------------------
      // الخطوة 1: التحقق من الكميات المتاحة لكل سطر بالوحدة الأساسية
      // ----------------------------------------------------------------
      for (final item in activeItems) {
        // جلب الكمية الأصلية و معامل تحويلها و الكمية المرجعة (بالأساسية)
        final itemResult = await txn.query(
          'invoice_items',
          columns: [
            'quantity',
            'conversion_factor_snapshot',
            'returned_quantity',
          ],
          where: 'id = ?',
          whereArgs: [item.invoiceItemId],
          limit: 1,
        );

        if (itemResult.isEmpty) {
          throw Exception('سطر الفاتورة غير موجود');
        }

        final originalQty = (itemResult.first['quantity'] as num).toDouble();
        final conversionFactor =
            (itemResult.first['conversion_factor_snapshot'] as num?)?.toDouble() ?? 1;
        final originalBase = originalQty * conversionFactor;
        // returned_quantity مخزّنة بالوحدة الأساسية (منذ v8 وأيضاً بعد backfill)
        final returnedBase =
            (itemResult.first['returned_quantity'] as num).toDouble();
        final remainingBase = originalBase - returnedBase;

        // الحد الفعلي: لمتجريات المشتريات يُقصّ على المخزون الفعلي الفائض
        // في مستودع الفاتورة (لأن بعض البضاعة قد بيع أو نُقل بعد الشراء).
        double effectiveRemaining = remainingBase;
        if (type == ReturnType.purchaseReturn) {
          // المستودع: مستودع الفاتورة، وإلا مستودع أول حركة أصلية للمنتج
          int? whId = invoiceWarehouseId;
          if (whId == null) {
            final origTxn = await txn.query(
              'inventory_transactions',
              columns: ['warehouse_id'],
              where: 'invoice_id = ? AND product_id = ?',
              whereArgs: [originalInvoiceId, item.productId],
              orderBy: 'id DESC',
              limit: 1,
            );
            whId = origTxn.isNotEmpty
                ? origTxn.first['warehouse_id'] as int?
                : null;
          }
          final stockAvailable = whId == null
              ? 0.0
              : await _stockForProductInWarehouse(
                  txn, item.productId, whId);
          effectiveRemaining = remainingBase < stockAvailable
              ? remainingBase
              : (stockAvailable < 0 ? 0 : stockAvailable);
        }

        final requestedBase = item.selectedBaseQuantity;

        if (requestedBase > effectiveRemaining + 0.0001) {
          final unitLabel = item.selectedUnitName ??
              item.baseUnitName ??
              'وحدة أساسية';
          throw ReturnQuantityExceededException(
            productName: item.productName,
            requested: requestedBase,
            available: effectiveRemaining,
            unitLabel: unitLabel,
          );
        }
      }

      // ----------------------------------------------------------------
      // الخطوة 2: حساب قيمة المرتجع الإجمالية
      // ----------------------------------------------------------------
      final returnTotal = activeItems.fold(0, (sum, i) => sum + i.lineTotal);

      // ----------------------------------------------------------------
      // الخطوة 3: توليد رقم المرتجع
      // ----------------------------------------------------------------
      final returnNumber = await _generateNextReturnNumber(txn);

      // ----------------------------------------------------------------
      // الخطوة 4: إدراج مستند المرتجع
      // ----------------------------------------------------------------
      final returnId = await txn.insert('returns', {
        'return_number': returnNumber,
        'original_invoice_id': originalInvoiceId,
        'type': type.dbValue,
        'party_id': partyId,
        'party_name_snapshot': partyName,
        'party_address_snapshot': partyAddress,
        'total_amount': returnTotal,
        'notes': notes,
      });

      // تحديث صافي الفاتورة بعد المرتجع
      final invoiceTotalResult = await txn.query(
        'invoices',
        columns: ['total_amount', 'paid_amount'],
        where: 'id = ?',
        whereArgs: [originalInvoiceId],
        limit: 1,
      );
      if (invoiceTotalResult.isEmpty) {
        throw Exception('الفاتورة الأصلية غير موجودة بعد إنشاء المرتجع');
      }

      final currentInvoiceTotal =
          invoiceTotalResult.first['total_amount'] as int;
      final currentPaidAmount = invoiceTotalResult.first['paid_amount'] as int;
      final updatedInvoiceTotal = currentInvoiceTotal - returnTotal;
      final overpaidAmount = currentPaidAmount - updatedInvoiceTotal;
      final adjustedPaidAmount = overpaidAmount > 0
          ? currentPaidAmount - overpaidAmount
          : currentPaidAmount;
      final invoiceStatus = adjustedPaidAmount >= updatedInvoiceTotal
          ? 'PAID'
          : (adjustedPaidAmount > 0 ? 'PARTIAL' : 'UNPAID');

      await txn.update(
        'invoices',
        {
          'total_amount': updatedInvoiceTotal,
          'paid_amount': adjustedPaidAmount,
          'payment_status': invoiceStatus,
        },
        where: 'id = ?',
        whereArgs: [originalInvoiceId],
      );

      await txn.insert('financial_transactions', {
        'invoice_id': originalInvoiceId,
        'return_id': returnId,
        'party_id': partyId,
        'type': type.dbValue,
        'direction': type == ReturnType.saleReturn ? 'OUT' : 'IN',
        'amount': returnTotal,
        'notes':
            'مرتجع ${type == ReturnType.saleReturn ? 'مبيعات' : 'مشتريات'}',
      });

      // إذا أصبحت الدفعات أكبر من صافي الفاتورة بعد المرتجع، سجّل دفعة راجعة
      if (overpaidAmount > 0) {
        final refundPaymentId = await txn.insert('payments', {
          'party_id': partyId,
          'invoice_id': originalInvoiceId,
          'return_id': returnId,
          'amount': overpaidAmount,
          'type': type == ReturnType.saleReturn ? 'OUTBOUND' : 'INBOUND',
          'notes': 'دفعة راجعة بعد المرتجع',
        });

        await txn.insert('financial_transactions', {
          'invoice_id': originalInvoiceId,
          'payment_id': refundPaymentId,
          'return_id': returnId,
          'party_id': partyId,
          'type': 'REFUND',
          'direction': type == ReturnType.saleReturn ? 'OUT' : 'IN',
          'amount': overpaidAmount,
          'notes': 'رصيد دائن بعد المرتجع',
        });
      }

      // ----------------------------------------------------------------
      // الخطوة 5: إدراج أسطر المرتجع + تحديث returned_quantity
      //           + حركات المخزون
      // ----------------------------------------------------------------
      for (final item in activeItems) {
        final baseReturnedQuantity = item.selectedBaseQuantity;
        final originBatchId = item.batchId;
        // سعر الوحدة الأساسية الواحدة (للتخزين/العرض)
        final baseUnitPrice = item.pricePerBase.round();

        // سطر المرتجع (يحمل معلومات الوحدة ومعامل التحويل والكمية الأساسية)
        await txn.insert('return_items', {
          'return_id': returnId,
          'product_id': item.productId,
          'batch_id': originBatchId,
          'product_name_snapshot': item.productName,
          'quantity': item.selectedQuantity,
          'unit_id': item.selectedUnitId,
          'unit_name_snapshot': item.selectedUnitName,
          'conversion_factor_snapshot': item.selectedUnitConversionFactor,
          'base_quantity': baseReturnedQuantity,
          'unit_price': baseUnitPrice,
          'line_total': item.lineTotal,
        });

        // تحديث returned_quantity في سطر الفاتورة الأصلية
        // (مخزّنة بالوحدة الأساسية دائماً)
        await txn.rawUpdate(
          '''
          UPDATE invoice_items
          SET returned_quantity = returned_quantity + ?
          WHERE id = ?
        ''',
          [baseReturnedQuantity, item.invoiceItemId],
        );

        // حركة مخزون عكسية بالوحدة الأساسية
        // مرتجع مبيعات → يزيد المخزون (SALE_RETURN)
        // مرتجع مشتريات → يقلل المخزون (PURCHASE_RETURN)
        //
        // نبحث عن أصل الحركة المخزنية المرتبطة بالنفس المنتج والفاتورة،
        // مع مراعاة تعدد الدفعات/المستودعات عند نفس المنتج.
        final originalTxns = await txn.query(
          'inventory_transactions',
          columns: ['warehouse_id', 'batch_id'],
          where: 'invoice_id = ? AND product_id = ?',
          whereArgs: [originalInvoiceId, item.productId],
          orderBy: 'id DESC',
        );

        int? origWarehouseId;
        int? origBatchId;
        for (final row in originalTxns) {
          origWarehouseId ??= row['warehouse_id'] as int?;
          origBatchId ??= row['batch_id'] as int?;
          if (origWarehouseId != null && origBatchId != null) break;
        }

        await txn.insert('inventory_transactions', {
          'product_id': item.productId,
          'type': type.inventoryType,
          'quantity': baseReturnedQuantity,
          'invoice_id': originalInvoiceId,
          'return_id': returnId,
          'warehouse_id': origWarehouseId,
          'batch_id': origBatchId,
        });
      }
      return returnId;
    });
  }

  // ====================================================================
  // جلب الأسطر القابلة للإرجاع من فاتورة معينة
  // ====================================================================

  Future<List<ReturnableItem>> getReturnableItems(int invoiceId) async {
    final db = await _db;

    final result = await db.rawQuery(
      '''
      SELECT
        ii.id           AS invoice_item_id,
        ii.product_id,
        ii.product_name_snapshot AS product_name,
        ii.quantity     AS original_quantity,
        ii.returned_quantity,
        ii.unit_price,
        ii.unit_id,
        ii.unit_name_snapshot,
        ii.conversion_factor_snapshot,
        (SELECT pu.unit_name
         FROM product_units pu
         WHERE pu.product_id = ii.product_id AND pu.is_base_unit = 1
         LIMIT 1)       AS base_unit_name,
        COALESCE(
          (SELECT it.batch_id
           FROM inventory_transactions it
           WHERE it.invoice_id = ?
             AND it.product_id = ii.product_id
             AND it.batch_id IS NOT NULL
           ORDER BY it.id DESC
           LIMIT 1),
          NULL
        ) AS batch_id,
        -- الكمية المتاحة فعلياً في مستودع الفاتورة (بالوحدة الأساسية)
        -- تُقصّ عليها مرتجعات المشتريات لأن البضاعة قد بيعت بعد الشراء
        COALESCE((
          SELECT COALESCE(SUM(
            CASE
              WHEN it2.type = 'PURCHASE'        THEN it2.quantity
              WHEN it2.type = 'SALE_RETURN'     THEN it2.quantity
              WHEN it2.type = 'TRANSFER_IN'     THEN it2.quantity
              WHEN it2.type = 'SALE'             THEN -it2.quantity
              WHEN it2.type = 'PURCHASE_RETURN'  THEN -it2.quantity
              WHEN it2.type = 'TRANSFER_OUT'     THEN -it2.quantity
              ELSE 0
            END
          ), 0)
          FROM inventory_transactions it2
          WHERE it2.product_id = ii.product_id
            AND it2.warehouse_id = COALESCE(
              inv.warehouse_id,
              (SELECT it3.warehouse_id
               FROM inventory_transactions it3
               WHERE it3.invoice_id = ii.invoice_id
                 AND it3.product_id = ii.product_id
               ORDER BY it3.id DESC
               LIMIT 1)
            )
        ), 0) AS stock_available
      FROM invoice_items ii
      INNER JOIN invoices inv ON inv.id = ii.invoice_id
      WHERE ii.invoice_id = ?
        AND (ii.quantity * ii.conversion_factor_snapshot - ii.returned_quantity) > 0
      ORDER BY ii.id ASC
    ''',
      [invoiceId, invoiceId],
    );

    return result
        .map(
          (row) => ReturnableItem(
            invoiceItemId: row['invoice_item_id'] as int,
            productId: row['product_id'] as int,
            batchId: row['batch_id'] as int?,
            productName: row['product_name'] as String,
            originalQuantity: (row['original_quantity'] as num).toDouble(),
            invoiceConversionFactor:
                (row['conversion_factor_snapshot'] as num?)?.toDouble() ?? 1,
            invoiceUnitId: row['unit_id'] as int?,
            invoiceUnitName: row['unit_name_snapshot'] as String?,
            unitPrice: row['unit_price'] as int,
            returnedBaseQuantity:
                (row['returned_quantity'] as num?)?.toDouble() ?? 0,
            baseUnitName: row['base_unit_name'] as String?,
            stockAvailable:
                (row['stock_available'] as num?)?.toDouble() ?? 0,
            selectedUnitId: row['unit_id'] as int?,
            selectedUnitName: row['unit_name_snapshot'] as String?,
            selectedUnitConversionFactor:
                (row['conversion_factor_snapshot'] as num?)?.toDouble() ?? 1,
          ),
        )
        .toList();
  }

  // ====================================================================
  // جلب مرتجعات فاتورة معينة
  // ====================================================================

  Future<List<ReturnModel>> getReturnsByInvoice(int invoiceId) async {
    final db = await _db;

    final result = await db.query(
      'returns',
      where: 'original_invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'id DESC',
    );

    debugPrint('invoiceId = $invoiceId');
    debugPrint('returns count = ${result.length}');
    debugPrint(result.toString());

    return result.map((e) => ReturnModel.fromMap(e)).toList();
  }

  // ====================================================================
  // جلب مرتجع كامل مع أسطره
  // ====================================================================

  Future<ReturnWithItems?> getReturnWithItems(int returnId) async {
    final db = await _db;

    final returnResult = await db.query(
      'returns',
      where: 'id = ?',
      whereArgs: [returnId],
      limit: 1,
    );

    if (returnResult.isEmpty) return null;

    final itemsResult = await db.query(
      'return_items',
      where: 'return_id = ?',
      whereArgs: [returnId],
    );

    return ReturnWithItems(
      returnModel: ReturnModel.fromMap(returnResult.first),
      items: itemsResult.map((e) => ReturnItemModel.fromMap(e)).toList(),
    );
  }

  // ====================================================================
  // قائمة المرتجعات مع Pagination
  // ====================================================================

  Future<ReturnPage> getAllReturns({
    int? lastId,
    int pageSize = _defaultPageSize,
  }) async {
    final db = await _db;

    final result = await db.query(
      'returns',
      where: lastId != null ? 'id < ?' : null,
      whereArgs: lastId != null ? [lastId] : null,
      orderBy: 'id DESC',
      limit: pageSize + 1,
    );

    final hasNextPage = result.length > pageSize;
    final items = hasNextPage ? result.sublist(0, pageSize) : result;

    return ReturnPage(
      returns: items.map((e) => ReturnModel.fromMap(e)).toList(),
      hasNextPage: hasNextPage,
      nextCursor: hasNextPage && items.isNotEmpty
          ? items.last['id'] as int?
          : null,
    );
  }

  // ====================================================================
  // Helpers
  // ====================================================================

  /// المخزون المتاح حالياً لمنتج داخل مستودع معيّن بالوحدة الأساسية.
  Future<double> _stockForProductInWarehouse(
    DatabaseExecutor txn,
    int productId,
    int warehouseId,
  ) async {
    final result = await txn.rawQuery(
      '''
      SELECT COALESCE(SUM(
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

  Future<String> _generateNextReturnNumber(DatabaseExecutor txn) async {
    final result = await txn.rawQuery('SELECT COUNT(*) as count FROM returns');
    final count = (result.first['count'] as int) + 1;
    return 'RTN-${count.toString().padLeft(4, '0')}';
  }
}

// ==============================
// Models مساعدة
// ==============================

class ReturnPage {
  final List<ReturnModel> returns;
  final bool hasNextPage;
  final int? nextCursor;

  const ReturnPage({
    required this.returns,
    required this.hasNextPage,
    this.nextCursor,
  });
}

// ==============================
// Exceptions
// ==============================

class ReturnQuantityExceededException implements Exception {
  final String productName;
  final double requested;
  final double available;
  final String unitLabel;

  ReturnQuantityExceededException({
    required this.productName,
    required this.requested,
    required this.available,
    this.unitLabel = 'وحدة أساسية',
  });

  @override
  String toString() {
    final req = _fmt(requested);
    final avail = _fmt(available);
    return 'لا يمكن إرجاع هذه الكمية. الكمية المتبقية القابلة للإرجاع '
        'هي $avail $unitLabel من المنتج "$productName". '
        '(المطلوب $req $unitLabel)';
  }

  static String _fmt(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);
}
