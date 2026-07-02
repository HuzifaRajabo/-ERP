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

    final db = await _db;

    return await db.transaction<int>((txn) async {

      // ----------------------------------------------------------------
      // الخطوة 0: التحقق من وجود الطرف (Party) قبل أي شيء آخر
      // ----------------------------------------------------------------
      // هذا تحقق استباقي صريح، بدلاً من ترك SQLite يرمي خطأ
      // FOREIGN KEY constraint failed غير المفهوم للمستخدم.
      final partyExists = await txn.query(
        'parties',
        where: 'id = ?',
        whereArgs: [draft.partyId],
        limit: 1,
      );
      if (partyExists.isEmpty) {
        throw PartyNotFoundException(draft.partyId);
      }

      // ----------------------------------------------------------------
      // الخطوة 0.5: التحقق من وجود كل منتج مذكور في أسطر الفاتورة
      // ----------------------------------------------------------------
      // نتحقق من الجميع *قبل* إدراج أي شيء، حتى لا نُدرج بعض
      // الأسطر وتفشل البقية في منتصف الطريق.
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

      // ----------------------------------------------------------------
      // الخطوة 1: التحقق من توفر المخزون (فقط لفواتير البيع)
      // ----------------------------------------------------------------
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

      // ----------------------------------------------------------------
      // الخطوة 2: توليد رقم الفاتورة التسلسلي
      // ----------------------------------------------------------------
      final invoiceNumber = await _generateNextInvoiceNumber(txn);

      // ----------------------------------------------------------------
      // الخطوة 3: إدراج الفاتورة نفسها
      // ----------------------------------------------------------------
      final invoiceId = await txn.insert('invoices', {
        'invoice_number': invoiceNumber,
        'type': draft.type.name.toUpperCase(),
        'party_id': draft.partyId,
        'party_name_snapshot': draft.partyNameSnapshot,
        'party_address_snapshot': draft.partyAddressSnapshot,
        'total_amount': draft.totalAmount,
        'notes': draft.notes,
      });

      // ----------------------------------------------------------------
      // الخطوة 4: إدراج كل سطر فاتورة + حركة مخزون مقابلة له
      // ----------------------------------------------------------------
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

      return invoiceId;
    });
  }

  Future<bool> deleteInvoice(int invoiceId) async {
    final db = await _db;

    return await db.transaction<bool>((txn) async {
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
    final result = await txn.rawQuery('''
      SELECT
        COALESCE(SUM(
          CASE WHEN type = 'PURCHASE' THEN quantity ELSE 0 END
        ), 0) -
        COALESCE(SUM(
          CASE WHEN type = 'SALE' THEN quantity ELSE 0 END
        ), 0) AS available
      FROM inventory_transactions
      WHERE product_id = ?
    ''', [productId]);

    return (result.first['available'] as num).toDouble();
  }

  Future<double> getAvailableQuantity(int productId) async {
    final db = await _db;
    return _getAvailableQuantity(db, productId);
  }

  Future<String> _generateNextInvoiceNumber(DatabaseExecutor txn) async {
    final result = await txn.rawQuery(
      'SELECT COUNT(*) as count FROM invoices',
    );
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
      nextCursor:
      hasNextPage && items.isNotEmpty ? items.last['id'] as int? : null,
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
      nextCursor:
      hasNextPage && items.isNotEmpty ? items.last['id'] as int? : null,
    );
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
      nextCursor:
      hasNextPage && items.isNotEmpty ? items.last['id'] as int? : null,
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