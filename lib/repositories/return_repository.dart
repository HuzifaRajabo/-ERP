// lib/repositories/return_repository.dart

import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/return_model.dart';

class ReturnRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

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
      final partyId = invoice['party_id'] as int;
      final partyName = invoice['party_name_snapshot'] as String;
      final partyAddress = invoice['party_address_snapshot'] as String;

      // ----------------------------------------------------------------
      // الخطوة 1: التحقق من الكميات المتاحة لكل سطر
      // ----------------------------------------------------------------
      for (final item in activeItems) {
        // جلب الكمية الأصلية في سطر الفاتورة
        final itemResult = await txn.query(
          'invoice_items',
          columns: ['quantity', 'returned_quantity'],
          where: 'id = ?',
          whereArgs: [item.invoiceItemId],
          limit: 1,
        );

        if (itemResult.isEmpty) {
          throw Exception('سطر الفاتورة غير موجود');
        }

        final originalQty = (itemResult.first['quantity'] as num).toDouble();
        final returnedSoFar = (itemResult.first['returned_quantity'] as num)
            .toDouble();
        final available = originalQty - returnedSoFar;

        if (item.selectedQuantity > available) {
          throw ReturnQuantityExceededException(
            productName: item.productName,
            requested: item.selectedQuantity,
            available: available,
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
        // سطر المرتجع
        await txn.insert('return_items', {
          'return_id': returnId,
          'product_id': item.productId,
          'product_name_snapshot': item.productName,
          'quantity': item.selectedQuantity,
          'unit_price': item.unitPrice,
          'line_total': item.lineTotal,
        });

        // تحديث returned_quantity في سطر الفاتورة الأصلية
        await txn.rawUpdate(
          '''
          UPDATE invoice_items
          SET returned_quantity = returned_quantity + ?
          WHERE id = ?
        ''',
          [item.selectedQuantity, item.invoiceItemId],
        );

        // حركة مخزون عكسية
        // مرتجع مبيعات → يزيد المخزون (SALE_RETURN)
        // مرتجع مشتريات → يقلل المخزون (PURCHASE_RETURN)
        await txn.insert('inventory_transactions', {
          'product_id': item.productId,
          'type': type.inventoryType,
          'quantity': item.selectedQuantity,
          'invoice_id': originalInvoiceId,
          'return_id': returnId,
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
        ii.unit_price
      FROM invoice_items ii
      WHERE ii.invoice_id = ?
        AND (ii.quantity - ii.returned_quantity) > 0
      ORDER BY ii.id ASC
    ''',
      [invoiceId],
    );

    return result
        .map(
          (row) => ReturnableItem(
            invoiceItemId: row['invoice_item_id'] as int,
            productId: row['product_id'] as int,
            productName: row['product_name'] as String,
            originalQuantity: (row['original_quantity'] as num).toDouble(),
            returnedSoFar: (row['returned_quantity'] as num).toDouble(),
            unitPrice: row['unit_price'] as int,
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

  ReturnQuantityExceededException({
    required this.productName,
    required this.requested,
    required this.available,
  });

  @override
  String toString() =>
      'الكمية المرتجعة ($requested) تتجاوز المتاح للإرجاع '
      '($available) للمنتج "$productName"';
}
