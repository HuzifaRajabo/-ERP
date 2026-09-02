import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:erp/repositories/invoice_repository.dart';

import 'helpers/test_db.dart';

void main() {
  late Database db;
  late InvoiceRepository repo;

  setUp(() async {
    enableSqfliteFfi();
    db = await createTestDatabase();
    repo = InvoiceRepository();
  });

  tearDown(() async {
    await closeTestDatabase(db);
  });

  Future<int> insertParty() async {
    return db.insert('parties', {
      'type': 'CUSTOMER',
      'name': 'عميل تجريبي',
    });
  }

  Future<int> insertProduct() async {
    return db.insert('products', {
      'name': 'منتج',
      'cost_price': 100,
      'sale_price': 150,
    });
  }

  Future<int> insertInvoice({
    required int partyId,
    required String number,
    String type = 'SALE',
  }) async {
    return db.insert('invoices', {
      'invoice_number': number,
      'type': type,
      'party_id': partyId,
      'party_name_snapshot': 'عميل تجريبي',
      'party_address_snapshot': '',
      'total_amount': 0,
      'original_total_amount': 0,
      'paid_amount': 0,
      'payment_status': 'UNPAID',
    });
  }

  Future<int> insertBatch(int productId) async {
    return db.insert('batches', {
      'product_id': productId,
    });
  }

  Future<void> insertInventoryTransaction({
    required int productId,
    required String type,
    required double quantity,
    int? invoiceId,
    int? batchId,
  }) async {
    await db.insert('inventory_transactions', {
      'product_id': productId,
      'type': type,
      'quantity': quantity,
      'invoice_id': invoiceId,
      'batch_id': batchId,
    });
  }

  group('deleteInvoice', () {
    test('deletes a standalone invoice that has a payment but no batches',
        () async {
      final partyId = await insertParty();
      final productId = await insertProduct();
      final invoiceId = await insertInvoice(
        partyId: partyId,
        number: 'INV-0001',
      );

      // دفعة + حركة مالية + حركة مخزون (بلا batch_id) → لا تمنع الحذف
      await insertInventoryTransaction(
        productId: productId,
        type: 'SALE',
        quantity: 2,
        invoiceId: invoiceId,
      );
      await db.insert('payments', {
        'party_id': partyId,
        'invoice_id': invoiceId,
        'amount': 100,
        'type': 'INBOUND',
      });
      await db.insert('financial_transactions', {
        'party_id': partyId,
        'invoice_id': invoiceId,
        'type': 'SALE',
        'direction': 'IN',
        'amount': 100,
      });

      final result = await repo.deleteInvoice(invoiceId);

      expect(result, InvoiceDeleteResult.allowed);
      final invoiceRows = await db.query(
        'invoices',
        where: 'id = ?',
        whereArgs: [invoiceId],
      );
      expect(invoiceRows, isEmpty);

      // الدفعات والحركات المالية تُنظَّف تلقائياً
      final payments = await db.query(
        'payments',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      );
      expect(payments, isEmpty);
    });

    test('blocks when a return is linked to the invoice', () async {
      final partyId = await insertParty();
      final invoiceId = await insertInvoice(
        partyId: partyId,
        number: 'INV-0002',
      );

      await db.insert('returns', {
        'return_number': 'RET-0001',
        'original_invoice_id': invoiceId,
        'type': 'SALE_RETURN',
        'party_id': partyId,
        'party_name_snapshot': 'عميل تجريبي',
        'party_address_snapshot': '',
        'total_amount': 0,
      });

      final result = await repo.deleteInvoice(invoiceId);

      expect(result.isBlocked, isTrue);
      expect(result.reason, contains('مرتجعات'));
      // الفاتورة ما زالت موجودة
      final rows = await db.query(
        'invoices',
        where: 'id = ?',
        whereArgs: [invoiceId],
      );
      expect(rows, isNotEmpty);
    });

    test('blocks when the batch is later reused by another transaction',
        () async {
      final partyId = await insertParty();
      final productId = await insertProduct();
      final invoiceId = await insertInvoice(
        partyId: partyId,
        number: 'INV-0003',
      );
      final batchId = await insertBatch(productId);

      // الحركة الأصلية على الفاتورة
      await insertInventoryTransaction(
        productId: productId,
        type: 'PURCHASE',
        quantity: 10,
        invoiceId: invoiceId,
        batchId: batchId,
      );

      // حركة لاحقة (تحويل) تستخدم نفس الدفعة → يجب أن يمنع الحذف
      await insertInventoryTransaction(
        productId: productId,
        type: 'TRANSFER_OUT',
        quantity: 5,
        batchId: batchId,
      );

      final result = await repo.deleteInvoice(invoiceId);

      expect(result.isBlocked, isTrue);
      expect(result.reason, contains('سلسلة'));
    });

    test('blocks when a later SALE invoice uses the same batch', () async {
      final partyId = await insertParty();
      final productId = await insertProduct();
      final purchaseId = await insertInvoice(
        partyId: partyId,
        number: 'INV-0004',
        type: 'PURCHASE',
      );
      final batchId = await insertBatch(productId);

      await insertInventoryTransaction(
        productId: productId,
        type: 'PURCHASE',
        quantity: 10,
        invoiceId: purchaseId,
        batchId: batchId,
      );

      // بيع لاحق من نفس الدفعة
      final saleId = await insertInvoice(
        partyId: partyId,
        number: 'INV-0005',
      );
      await insertInventoryTransaction(
        productId: productId,
        type: 'SALE',
        quantity: 3,
        invoiceId: saleId,
        batchId: batchId,
      );

      final result = await repo.deleteInvoice(purchaseId);

      expect(result.isBlocked, isTrue);
      expect(result.reason, contains('سلسلة'));
    });

    test('allows deletion when the batch is used only by this invoice',
        () async {
      final partyId = await insertParty();
      final productId = await insertProduct();
      final invoiceId = await insertInvoice(
        partyId: partyId,
        number: 'INV-0006',
        type: 'PURCHASE',
      );
      final batchId = await insertBatch(productId);

      await insertInventoryTransaction(
        productId: productId,
        type: 'PURCHASE',
        quantity: 10,
        invoiceId: invoiceId,
        batchId: batchId,
      );

      final result = await repo.deleteInvoice(invoiceId);

      expect(result, InvoiceDeleteResult.allowed);
    });

    test('returns blocked when invoice does not exist', () async {
      final result = await repo.deleteInvoice(99999);
      expect(result.isBlocked, isTrue);
      expect(result.reason, contains('غير موجودة'));
    });
  });
}
