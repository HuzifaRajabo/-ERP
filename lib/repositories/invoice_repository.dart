import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/invoice_model.dart';
import '../models/invoice_item_model.dart';
import '../models/Invoice_draft.dart';

class InvoiceRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  static const int _defaultPageSize = 20;

  Future<int> createInvoice(InvoiceDraft draft) async {
    if (draft.items.isEmpty) {
      throw Exception('لا يمكن إنشاء فاتورة بدون أسطر');
    }

    // التحقق من أن المبلغ المدفوع لا يتجاوز الإجمالي
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

      // الخطوة 0.5: التحقق من وجود المنتجات
      for (final item in draft.items) {
        final productExists = await txn.query(
          'products',
          where: 'id = ?',
          whereArgs: [item.productId],
          limit: 1,
        );
        if (productExists.isEmpty) {
          throw ProductNotFoundException(
            item.productId,
            item.productNameSnapshot,
          );
        }
      }

      // الخطوة 1: التحقق من المخزون (للبيع فقط)
      if (draft.type == InvoiceType.sale) {
        for (final item in draft.items) {
          final available = await _getAvailableQuantity(txn, item.productId);
          if (available < item.quantity) {
            throw InsufficientStockException(
              productId: item.productId,
              productName: item.productNameSnapshot,
              requested: item.quantity,
              available: available,
            );
          }
        }
      }

      // الخطوة 2: توليد رقم الفاتورة
      final invoiceNumber = await _generateNextInvoiceNumber(txn);

      // الخطوة 3: إدراج الفاتورة مع بيانات الدفع الأولية
      final invoiceId = await txn.insert('invoices', {
        'invoice_number': invoiceNumber,
        'type': draft.type.name.toUpperCase(),
        'party_id': draft.partyId,
        'party_name_snapshot': draft.partyNameSnapshot,
        'party_address_snapshot': draft.partyAddressSnapshot,
        'total_amount': draft.totalAmount,
        'original_total_amount': draft.totalAmount, // ← نفس القيمة عند الإنشاء
        'paid_amount': draft.initialPayment,
        'payment_status': draft.paymentStatus.name.toUpperCase(),
        'notes': draft.notes,
      });

      // سجل الحركة المالية للفاتورة (أثر على الذمم)
      await txn.insert('financial_transactions', {
        'invoice_id': invoiceId,
        'party_id': draft.partyId,
        'type': draft.type == InvoiceType.sale ? 'SALE' : 'PURCHASE',
        'direction': draft.type == InvoiceType.sale ? 'IN' : 'OUT',
        'amount': draft.totalAmount,
        'notes': 'فاتورة ${draft.type == InvoiceType.sale ? 'بيع' : 'شراء'}',
      });

      // الخطوة 4: إدراج أسطر الفاتورة + حركات المخزون
      for (final item in draft.items) {
        await txn.insert('invoice_items', {
          'invoice_id': invoiceId,
          'product_id': item.productId,
          'product_name_snapshot': item.productNameSnapshot,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'line_total': item.lineTotal,
        });

        await txn.insert('inventory_transactions', {
          'product_id': item.productId,
          'type': draft.type.name.toUpperCase(),
          'quantity': item.quantity,
          'invoice_id': invoiceId,
        });
      }

      // الخطوة 5: إذا كان هناك دفعة أولية سجّلها في جدول payments
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

      // حذف الدفعات المرتبطة أولاً لضمان عدم بقاء دفعات مع invoice_id فارغ
      await txn.delete(
        'payments',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      );

      // حذف المرتجعات المرتبطة بالفاتورة الأصلية
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

      // حذف الفاتورة نفسها. سيؤدي هذا أيضاً إلى حذف أي حركات مخزون
      // وحركات مالية مرتبطة عبر علاقة invoice_id.
      final rows = await txn.delete(
        'invoices',
        where: 'id = ?',
        whereArgs: [invoiceId],
      );
      return rows > 0;
    });
  }

  Future<double> _getAvailableQuantity(
    DatabaseExecutor txn,
    int productId,
  ) async {
    final result = await txn.rawQuery(
      '''
      SELECT
        COALESCE(SUM(
          CASE WHEN type = 'PURCHASE' THEN quantity ELSE 0 END
        ), 0) -
        COALESCE(SUM(
          CASE WHEN type = 'SALE' THEN quantity ELSE 0 END
        ), 0) AS available
      FROM inventory_transactions
      WHERE product_id = ?
    ''',
      [productId],
    );

    return (result.first['available'] as num).toDouble();
  }

  Future<double> getAvailableQuantity(int productId) async {
    final db = await _db;
    return _getAvailableQuantity(db, productId);
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

    return InvoiceWithItems(
      invoice: InvoiceModel.fromMap(invoiceResult.first),
      items: itemsResult.map((e) => InvoiceItemModel.fromMap(e)).toList(),
    );
  }

  Future<InvoicePage> getAllInvoices({
    int? lastId,
    int pageSize = _defaultPageSize,
  }) async {
    final db = await _db;
    final result = await db.query(
      'invoices',
      where: lastId != null ? 'id < ?' : null,
      whereArgs: lastId != null ? [lastId] : null,
      orderBy: 'id DESC',
      limit: pageSize + 1,
    );

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

  Future<InvoicePage> getInvoicesByType({
    required InvoiceType type,
    int? lastId,
    int pageSize = _defaultPageSize,
  }) async {
    final db = await _db;
    final result = await db.query(
      'invoices',
      where: lastId != null ? 'type = ? AND id < ?' : 'type = ?',
      whereArgs: lastId != null
          ? [type.name.toUpperCase(), lastId]
          : [type.name.toUpperCase()],
      orderBy: 'id DESC',
      limit: pageSize + 1,
    );

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

  Future<InvoiceModel?> getInvoiceById(int id) async {
    try {
      final db = await _db;
      final result = await db.query(
        'invoices',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      return result.isEmpty ? null : InvoiceModel.fromMap(result.first);
    } catch (e) {
      throw Exception('Failed to fetch invoice by id: $e');
    }
  }

  Future<InvoicePage> getInvoicesByParty({
    required int partyId,
    int? lastId,
    int pageSize = _defaultPageSize,
  }) async {
    final db = await _db;
    final result = await db.query(
      'invoices',
      where: lastId != null ? 'party_id = ? AND id < ?' : 'party_id = ?',
      whereArgs: lastId != null ? [partyId, lastId] : [partyId],
      orderBy: 'id DESC',
      limit: pageSize + 1,
    );

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
// InvoicePage Model
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
// Exceptions مخصصة برسائل عربية واضحة
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
  String toString() {
    return 'الكمية غير متوفرة لـ "$productName": '
        'المطلوب $requested، المتوفر $available فقط';
  }
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
