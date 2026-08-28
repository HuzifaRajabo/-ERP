import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/invoice_model.dart';
import '../models/invoice_item_model.dart';
import '../models/invoice_draft.dart';
import 'batch_repository.dart';

class InvoiceRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  static const int _defaultPageSize = 20;

  Future<int> createInvoice(InvoiceDraft draft) async {
    if (draft.items.isEmpty) {
      throw Exception('لا يمكن إنشاء فاتورة بدون أسطر');
    }

    if (draft.initialPayment > draft.totalAmount) {
      throw Exception(
        'المبلغ المدفوع (${draft.initialPayment}) '
        'يتجاوز إجمالي الفاتورة (${draft.totalAmount})',
      );
    }

    final db = await _db;

    return await db.transaction<int>((txn) async {
      // الخطوة 0: التحقق من وجود الطرف
      final partyExists = await txn.query(
        'parties',
        where: 'id = ?',
        whereArgs: [draft.partyId],
        limit: 1,
      );
      if (partyExists.isEmpty) throw PartyNotFoundException(draft.partyId);

      // الخطوة 0.5: التحقق من وجود المستودع إذا حُدِّد
      if (draft.warehouseId != null) {
        final warehouseExists = await txn.query(
          'warehouses',
          where: 'id = ?',
          whereArgs: [draft.warehouseId],
          limit: 1,
        );
        if (warehouseExists.isEmpty) {
          throw Exception('المستودع المحدد (#${draft.warehouseId}) غير موجود');
        }
      }

      // الخطوة 0.6: التحقق من وجود المنتجات
      for (final item in draft.items) {
        final productExists = await txn.query(
          'products',
          where: 'id = ?',
          whereArgs: [item.productId],
          limit: 1,
        );
        if (productExists.isEmpty) {
          throw ProductNotFoundException(item.productId, item.productNameSnapshot);
        }
      }

      // الخطوة 1: التحقق من المخزون (للبيع فقط)
      final batchRepo = BatchRepository();
      if (draft.type == InvoiceType.sale) {
        for (final item in draft.items) {
          final requestedBaseQty = item.baseQuantity;
          final available = await _getAvailableQuantity(
            txn,
            item.productId,
            warehouseId: draft.warehouseId,
          );
          if (available < requestedBaseQty) {
            throw InsufficientStockException(
              productId: item.productId,
              productName: item.productNameSnapshot,
              requested: requestedBaseQty,
              available: available,
            );
          }

          final allocations = await batchRepo.allocateAvailableQuantity(
            item.productId,
            requestedBaseQty,
            warehouseId: draft.warehouseId,
            executor: txn,
          );

          final allocated = allocations.fold<double>(0, (sum, e) => sum + e.quantity);
          if ((allocated - requestedBaseQty).abs() > 0.0001) {
            throw InsufficientStockException(
              productId: item.productId,
              productName: item.productNameSnapshot,
              requested: requestedBaseQty,
              available: available,
            );
          }
        }
      }

      // الخطوة 2: توليد رقم الفاتورة
      final invoiceNumber = await _generateNextInvoiceNumber(txn);

      // الخطوة 3: إدراج الفاتورة
      final invoiceId = await txn.insert('invoices', {
        'invoice_number': invoiceNumber,
        'type': draft.type.name.toUpperCase(),
        'party_id': draft.partyId,
        'party_name_snapshot': draft.partyNameSnapshot,
        'party_address_snapshot': draft.partyAddressSnapshot,
        'total_amount': draft.totalAmount,
        'original_total_amount': draft.totalAmount,
        'paid_amount': draft.initialPayment,
        'payment_status': draft.paymentStatus.name.toUpperCase(),
        'warehouse_id': draft.warehouseId,
        'notes': draft.notes,
      });

      // سجل الحركة المالية للفاتورة
      await txn.insert('financial_transactions', {
        'invoice_id': invoiceId,
        'party_id': draft.partyId,
        'type': draft.type == InvoiceType.sale ? 'SALE' : 'PURCHASE',
        'direction': draft.type == InvoiceType.sale ? 'IN' : 'OUT',
        'amount': draft.totalAmount,
        'notes': 'فاتورة ${draft.type == InvoiceType.sale ? 'بيع' : 'شراء'}',
      });

      // الخطوة 4: أسطر الفاتورة + حركات المخزون
      for (final item in draft.items) {
        // السطر يُخزَّن بالوحدة المختارة (قطعة/باكيت/كرتون)
        await txn.insert('invoice_items', {
          'invoice_id': invoiceId,
          'product_id': item.productId,
          'product_name_snapshot': item.productNameSnapshot,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'line_total': item.lineTotal,
          'unit_id': item.unitId,
          'unit_name_snapshot': item.unitNameSnapshot,
          'conversion_factor_snapshot': item.conversionFactorSnapshot,
        });

        final allocations = item.batchAllocations.isNotEmpty
            ? item.batchAllocations
            : (draft.type == InvoiceType.sale
                ? (await batchRepo.allocateAvailableQuantity(
                    item.productId,
                    item.baseQuantity,
                    warehouseId: draft.warehouseId,
                    executor: txn,
                  )).map((allocation) => BatchAllocationSnapshot(
                    batchId: allocation.batchId,
                    quantity: allocation.quantity,
                    batchNumber: allocation.batchNumber,
                    expiryDate: allocation.expiryDate,
                  )).toList()
                : const <BatchAllocationSnapshot>[]);

        if (draft.type == InvoiceType.sale) {
          for (final allocation in allocations) {
            await txn.insert('inventory_transactions', {
              'product_id': item.productId,
              'type': draft.type.name.toUpperCase(),
              'quantity': allocation.quantity,
              'invoice_id': invoiceId,
              'warehouse_id': draft.warehouseId,
              'batch_id': allocation.batchId,
              'unit_id': item.unitId,
            });
          }
        } else {
          // شراء: إن أدخل المستخدم معلومات دفعة جديدة نبحث عنها أو
          // ننشئها داخل نفس الـ transaction، وإلا تبقى الدفعة null.
          final purchaseBatchId = await batchRepo.findOrCreateBatchInTransaction(
            txn,
            productId: item.productId,
            batchNumber: item.newBatchNumber,
            productionDate: item.newProductionDate,
            expiryDate: item.newExpiryDate,
            costPrice: item.baseQuantity <= 0
                ? null
                : (item.lineTotal / item.baseQuantity).round(),
          );

          await txn.insert('inventory_transactions', {
            'product_id': item.productId,
            'type': draft.type.name.toUpperCase(),
            'quantity': item.baseQuantity,
            'invoice_id': invoiceId,
            'warehouse_id': draft.warehouseId,
            'batch_id': item.batchId ?? purchaseBatchId,
            'unit_id': item.unitId,
          });
        }
      }

      // الخطوة 5: الدفعة الأولية
      if (draft.initialPayment > 0) {
        final paymentId = await txn.insert('payments', {
          'party_id': draft.partyId,
          'invoice_id': invoiceId,
          'amount': draft.initialPayment,
          'type': draft.type == InvoiceType.sale ? 'INBOUND' : 'OUTBOUND',
          'notes': 'دفعة عند الإنشاء',
        });

        await txn.insert('financial_transactions', {
          'invoice_id': invoiceId,
          'payment_id': paymentId,
          'party_id': draft.partyId,
          'type': draft.type == InvoiceType.sale ? 'PAYMENT_IN' : 'PAYMENT_OUT',
          'direction': draft.type == InvoiceType.sale ? 'IN' : 'OUT',
          'amount': draft.initialPayment,
          'notes': 'دفعة عند الإنشاء',
        });
      }

      return invoiceId;
    });
  }

  Future<bool> deleteInvoice(int invoiceId) async {
    final db = await _db;

    return await db.transaction<bool>((txn) async {
      final invoiceResult = await txn.query(
        'invoices',
        where: 'id = ?',
        whereArgs: [invoiceId],
        limit: 1,
      );
      if (invoiceResult.isEmpty) return false;

      await txn.delete('payments', where: 'invoice_id = ?', whereArgs: [invoiceId]);

      final returnRows = await txn.query(
        'returns',
        columns: ['id'],
        where: 'original_invoice_id = ?',
        whereArgs: [invoiceId],
      );
      if (returnRows.isNotEmpty) {
        final returnIds = returnRows.map((row) => row['id'] as int).toList();
        final placeholders = List.filled(returnIds.length, '?').join(', ');
        await txn.delete(
          'returns',
          where: 'id IN ($placeholders)',
          whereArgs: returnIds,
        );
      }

      final rows = await txn.delete(
        'invoices',
        where: 'id = ?',
        whereArgs: [invoiceId],
      );
      return rows > 0;
    });
  }

  // الكمية المتاحة — اختيارياً مفلترة حسب المستودع
  Future<double> _getAvailableQuantity(
    DatabaseExecutor txn,
    int productId, {
    int? warehouseId,
  }) async {
    final warehouseFilter =
        warehouseId != null ? 'AND warehouse_id = $warehouseId' : '';

    final result = await txn.rawQuery(
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
      WHERE product_id = ? $warehouseFilter
    ''',
      [productId],
    );

    return (result.first['available'] as num).toDouble();
  }

  Future<double> getAvailableQuantity(
    int productId, {
    int? warehouseId,
  }) async {
    final db = await _db;
    return _getAvailableQuantity(db, productId, warehouseId: warehouseId);
  }

  Future<String> _generateNextInvoiceNumber(DatabaseExecutor txn) async {
    final result = await txn.rawQuery('SELECT COUNT(*) as count FROM invoices');
    final count = (result.first['count'] as int) + 1;
    return 'INV-${count.toString().padLeft(4, '0')}';
  }

  Future<InvoiceWithItems?> getInvoiceWithItems(int invoiceId) async {
    final db = await _db;

    final invoiceResult = await db.query(
      'invoices',
      where: 'id = ?',
      whereArgs: [invoiceId],
      limit: 1,
    );
    if (invoiceResult.isEmpty) return null;

    final itemsResult = await db.query(
      'invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );

    // اسم المستودع (قد يكون null في بيانات قديمة جداً)
    final warehouseId = invoiceResult.first['warehouse_id'] as int?;
    String? warehouseName;
    if (warehouseId != null) {
      final warehouseRows = await db.query(
        'warehouses',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [warehouseId],
        limit: 1,
      );
      if (warehouseRows.isNotEmpty) {
        warehouseName = warehouseRows.first['name'] as String?;
      }
    }

    final batchAllocations = await _getAllocatedBatchesByProduct(db, invoiceId);

    return InvoiceWithItems(
      invoice: InvoiceModel.fromMap(invoiceResult.first),
      items: itemsResult.map((e) => InvoiceItemModel.fromMap(e)).toList(),
      warehouseName: warehouseName,
      batchesByProductId: batchAllocations,
    );
  }

  /// الدفعات المخصصة فعلياً لأسطر فاتورة معينة، مجمعة حسب المنتج.
  /// المصدر: inventory_transactions المرتبطة بالفاتورة (نوع SALE/PURCHASE
  /// فقط — نستثني حركات المرتجعات لأنها تحمل نفس invoice_id).
  /// الفواتير المحفوظة قبل تتبع الدفعات تُعيد خريطة فارغة.
  Future<Map<int, List<BatchAllocationSnapshot>>> _getAllocatedBatchesByProduct(
    DatabaseExecutor db,
    int invoiceId,
  ) async {
    final rows = await db.rawQuery(
      '''
      SELECT
        it.product_id,
        it.batch_id,
        b.batch_number,
        b.expiry_date,
        SUM(
          CASE
            WHEN it.type = 'SALE' THEN -it.quantity
            ELSE it.quantity
          END
        ) AS allocated
      FROM inventory_transactions it
      LEFT JOIN batches b ON b.id = it.batch_id
      WHERE it.invoice_id = ?
        AND it.type IN ('SALE','PURCHASE')
        AND it.batch_id IS NOT NULL
      GROUP BY it.product_id, it.batch_id
      HAVING allocated > 0
      ORDER BY b.expiry_date ASC
    ''',
      [invoiceId],
    );

    final result = <int, List<BatchAllocationSnapshot>>{};
    for (final row in rows) {
      final productId = row['product_id'] as int;
      final batchId = row['batch_id'] as int;
      final quantity = (row['allocated'] as num).toDouble();

      final entry = result.putIfAbsent(productId, () => []);
      entry.add(
        BatchAllocationSnapshot(
          batchId: batchId,
          quantity: quantity,
          batchNumber:
              (row['batch_number'] as String?) ?? 'بدون رقم',
          expiryDate: row['expiry_date'] as String?,
        ),
      );
    }
    return result;
  }

  Future<InvoicePage> getAllInvoices({
    int? lastId,
    int pageSize = _defaultPageSize,
    int? warehouseId,
  }) async {
    final db = await _db;
    final where = <String>[];
    final args = <dynamic>[];

    if (lastId != null) { where.add('id < ?'); args.add(lastId); }
    if (warehouseId != null) { where.add('warehouse_id = ?'); args.add(warehouseId); }

    final result = await db.query(
      'invoices',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'id DESC',
      limit: pageSize + 1,
    );
    return _buildPage(result, pageSize);
  }

  Future<InvoicePage> getInvoicesByType({
    required InvoiceType type,
    int? lastId,
    int pageSize = _defaultPageSize,
    int? warehouseId,
  }) async {
    final db = await _db;
    final where = <String>['type = ?'];
    final args = <dynamic>[type.name.toUpperCase()];

    if (lastId != null) { where.add('id < ?'); args.add(lastId); }
    if (warehouseId != null) { where.add('warehouse_id = ?'); args.add(warehouseId); }

    final result = await db.query(
      'invoices',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'id DESC',
      limit: pageSize + 1,
    );
    return _buildPage(result, pageSize);
  }

  Future<InvoiceModel?> getInvoiceById(int id) async {
    final db = await _db;
    final result = await db.query(
      'invoices',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isEmpty ? null : InvoiceModel.fromMap(result.first);
  }

  Future<InvoicePage> getInvoicesByParty({
    required int partyId,
    int? lastId,
    int pageSize = _defaultPageSize,
  }) async {
    final db = await _db;
    final where = <String>['party_id = ?'];
    final args = <dynamic>[partyId];

    if (lastId != null) { where.add('id < ?'); args.add(lastId); }

    final result = await db.query(
      'invoices',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'id DESC',
      limit: pageSize + 1,
    );
    return _buildPage(result, pageSize);
  }

  InvoicePage _buildPage(List<Map<String, dynamic>> result, int pageSize) {
    final hasNextPage = result.length > pageSize;
    final items = hasNextPage ? result.sublist(0, pageSize) : result;
    return InvoicePage(
      invoices: items.map((e) => InvoiceModel.fromMap(e)).toList(),
      hasNextPage: hasNextPage,
      nextCursor: hasNextPage && items.isNotEmpty
          ? items.last['id'] as int?
          : null,
    );
  }
}

// ==============================
// InvoicePage
// ==============================

class InvoicePage {
  final List<InvoiceModel> invoices;
  final bool hasNextPage;
  final int? nextCursor;

  const InvoicePage({
    required this.invoices,
    required this.hasNextPage,
    this.nextCursor,
  });
}

// ==============================
// Exceptions
// ==============================

class InsufficientStockException implements Exception {
  final int productId;
  final String productName;
  final double requested;
  final double available;

  InsufficientStockException({
    required this.productId,
    required this.productName,
    required this.requested,
    required this.available,
  });

  @override
  String toString() =>
      'الكمية غير متوفرة لـ "$productName": '
      'المطلوب $requested، المتوفر $available فقط';
}

class PartyNotFoundException implements Exception {
  final int partyId;
  PartyNotFoundException(this.partyId);

  @override
  String toString() => 'الطرف المحدد (#$partyId) غير موجود';
}

class ProductNotFoundException implements Exception {
  final int productId;
  final String productName;
  ProductNotFoundException(this.productId, this.productName);

  @override
  String toString() => 'المنتج "$productName" (#$productId) غير موجود';
}
