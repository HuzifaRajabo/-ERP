import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/payment_model.dart';

class PaymentRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  // ====================================================================
  // تسجيل دفعة على فاتورة محددة
  // ====================================================================

  Future<int> payInvoice({
    required int invoiceId,
    required int partyId,
    required int amount,
    required PaymentType type,
    String? notes,
  }) async {
    final db = await _db;

    return await db.transaction<int>((txn) async {
      // ----------------------------------------------------------------
      // التحقق من وجود الفاتورة والمبلغ المتبقي
      // ----------------------------------------------------------------
      final invoiceResult = await txn.query(
        'invoices',
        columns: ['id', 'total_amount', 'paid_amount', 'payment_status'],
        where: 'id = ?',
        whereArgs: [invoiceId],
        limit: 1,
      );

      if (invoiceResult.isEmpty) {
        throw Exception('الفاتورة غير موجودة');
      }

      final invoice = invoiceResult.first;
      final totalAmount = invoice['total_amount'] as int;
      final paidAmount = invoice['paid_amount'] as int;
      final remaining = totalAmount - paidAmount;

      if (amount <= 0) {
        throw Exception('يجب أن يكون المبلغ أكبر من صفر');
      }

      if (amount > remaining) {
        throw PaymentExceedsRemainingException(
          requested: amount,
          remaining: remaining,
          invoiceNumber: '', // سنحسنها لاحقاً
        );
      }

      // ----------------------------------------------------------------
      // إدراج الدفعة
      // ----------------------------------------------------------------
      final paymentId = await txn.insert('payments', {
        'party_id': partyId,
        'invoice_id': invoiceId,
        'amount': amount,
        'type': type.name.toUpperCase(),
        'notes': notes,
      });

      await txn.insert('financial_transactions', {
        'invoice_id': invoiceId,
        'payment_id': paymentId,
        'party_id': partyId,
        'type': type == PaymentType.inbound ? 'PAYMENT_IN' : 'PAYMENT_OUT',
        'direction': type == PaymentType.inbound ? 'IN' : 'OUT',
        'amount': amount,
        'notes': notes,
      });

      // ----------------------------------------------------------------
      // تحديث paid_amount و payment_status في الفاتورة
      // ----------------------------------------------------------------
      final newPaidAmount = paidAmount + amount;
      final newStatus = newPaidAmount >= totalAmount ? 'PAID' : 'PARTIAL';

      await txn.update(
        'invoices',
        {'paid_amount': newPaidAmount, 'payment_status': newStatus},
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      return paymentId;
    });
  }

  // ====================================================================
  // توزيع دفعة عامة على فواتير الطرف (التوزيع اليدوي/التلقائي)
  // ====================================================================
  //
  // يستقبل قائمة PaymentDistributionItem التي بناها المستخدم
  // (تلقائياً أو يدوياً) ويحفظها كدفعات مستقلة لكل فاتورة.
  // كل هذا في transaction واحدة لضمان الذرية.

  Future<void> distributePayment(PaymentDistribution distribution) async {
    if (distribution.items.isEmpty) {
      throw Exception('لا توجد فواتير لتوزيع الدفعة عليها');
    }

    if (distribution.items.any((i) => i.amount <= 0)) {
      throw Exception('جميع المبالغ يجب أن تكون أكبر من صفر');
    }

    final db = await _db;

    await db.transaction((txn) async {
      // التحقق من أن مجموع التوزيع لا يتجاوز مجموع المتبقي
      int totalDistributed = 0;

      for (final item in distribution.items) {
        // جلب الفاتورة والتحقق من المتبقي
        final invoiceResult = await txn.query(
          'invoices',
          columns: ['total_amount', 'paid_amount'],
          where: 'id = ?',
          whereArgs: [item.invoiceId],
          limit: 1,
        );

        if (invoiceResult.isEmpty) {
          throw Exception('الفاتورة ${item.invoiceNumber} غير موجودة');
        }

        final totalAmount = invoiceResult.first['total_amount'] as int;
        final paidAmount = invoiceResult.first['paid_amount'] as int;
        final remaining = totalAmount - paidAmount;

        if (item.amount > remaining) {
          throw PaymentExceedsRemainingException(
            requested: item.amount,
            remaining: remaining,
            invoiceNumber: item.invoiceNumber,
          );
        }

        totalDistributed += item.amount;

        // إدراج الدفعة لهذه الفاتورة
        final paymentId = await txn.insert('payments', {
          'party_id': distribution.partyId,
          'invoice_id': item.invoiceId,
          'amount': item.amount,
          'type': distribution.type.name.toUpperCase(),
          'notes': distribution.notes,
        });

        await txn.insert('financial_transactions', {
          'invoice_id': item.invoiceId,
          'payment_id': paymentId,
          'party_id': distribution.partyId,
          'type': distribution.type == PaymentType.inbound
              ? 'PAYMENT_IN'
              : 'PAYMENT_OUT',
          'direction': distribution.type == PaymentType.inbound ? 'IN' : 'OUT',
          'amount': item.amount,
          'notes': distribution.notes,
        });

        // تحديث الفاتورة
        final newPaidAmount = paidAmount + item.amount;
        final newStatus = newPaidAmount >= totalAmount ? 'PAID' : 'PARTIAL';

        await txn.update(
          'invoices',
          {'paid_amount': newPaidAmount, 'payment_status': newStatus},
          where: 'id = ?',
          whereArgs: [item.invoiceId],
        );
      }

      // التحقق النهائي: المجموع لا يتجاوز المبلغ المُدخَل
      if (totalDistributed > distribution.totalAmount) {
        throw Exception(
          'مجموع التوزيع ($totalDistributed) يتجاوز المبلغ المدفوع (${distribution.totalAmount})',
        );
      }
    });
  }

  // ====================================================================
  // جلب الفواتير غير المسددة/المسددة جزئياً لطرف معين
  // لعرضها للمستخدم قبل التوزيع
  // ====================================================================

  Future<List<InvoicePaymentInfo>> getUnpaidInvoicesForParty({
    required int partyId,
    required int availableAmount, // المبلغ المتاح للتوزيع
  }) async {
    final db = await _db;

    // جلب الفواتير غير المسددة أو المسددة جزئياً مرتبة من الأقدم للأحدث (FIFO)
    final result = await db.query(
      'invoices',
      columns: [
        'id',
        'invoice_number',
        'total_amount',
        'paid_amount',
        'payment_status',
      ],
      where: "party_id = ? AND payment_status IN ('UNPAID', 'PARTIAL')",
      whereArgs: [partyId],
      orderBy: 'id ASC', // الأقدم أولاً
    );

    // حساب التوزيع التلقائي (FIFO)
    int remaining = availableAmount;
    final invoices = <InvoicePaymentInfo>[];

    for (final row in result) {
      final totalAmount = row['total_amount'] as int;
      final paidAmount = row['paid_amount'] as int;
      final invoiceRemaining = totalAmount - paidAmount;

      // المقترح = أقل قيمة بين المتبقي على الفاتورة والمبلغ المتاح
      final suggested = remaining >= invoiceRemaining
          ? invoiceRemaining
          : remaining;

      invoices.add(
        InvoicePaymentInfo(
          invoiceId: row['id'] as int,
          invoiceNumber: row['invoice_number'] as String,
          totalAmount: totalAmount,
          paidAmount: paidAmount,
          remaining: invoiceRemaining,
          suggestedPayment: suggested,
        ),
      );

      remaining -= suggested;
      if (remaining <= 0) break; // لا داعي لتحميل المزيد
    }

    return invoices;
  }

  // ====================================================================
  // جلب إجمالي الديون المستحقة لطرف معين
  // ====================================================================

  Future<int> getTotalRemainingForParty(int partyId) async {
    final db = await _db;

    // الديون الصحيحة تعتمد على صافي الفاتورة بعد المرتجعات
    final result = await db.rawQuery(
      '''
    SELECT COALESCE(
      SUM(
        CASE WHEN (i.total_amount - i.paid_amount) > 0
          THEN (i.total_amount - i.paid_amount)
          ELSE 0
        END
      ), 0) AS total_remaining
    FROM invoices i
    WHERE i.party_id = ?
      AND (i.total_amount - i.paid_amount) > 0
  ''',
      [partyId],
    );

    return (result.first['total_remaining'] as num).toInt();
  }

  // ====================================================================
  // حذف دفعة (مع إعادة paid_amount و payment_status للفاتورة)
  // ====================================================================

  Future<void> deletePayment(int paymentId) async {
    final db = await _db;

    await db.transaction((txn) async {
      // جلب الدفعة أولاً
      final paymentResult = await txn.query(
        'payments',
        where: 'id = ?',
        whereArgs: [paymentId],
        limit: 1,
      );

      if (paymentResult.isEmpty) {
        throw Exception('الدفعة غير موجودة');
      }

      final payment = paymentResult.first;
      final invoiceId = payment['invoice_id'] as int?;
      final amount = payment['amount'] as int;

      // حذف الدفعة
      await txn.delete('payments', where: 'id = ?', whereArgs: [paymentId]);
      await txn.delete(
        'financial_transactions',
        where: 'payment_id = ?',
        whereArgs: [paymentId],
      );

      // إعادة paid_amount للفاتورة إن كانت مرتبطة بفاتورة
      if (invoiceId != null) {
        final invoiceResult = await txn.query(
          'invoices',
          columns: ['total_amount', 'paid_amount'],
          where: 'id = ?',
          whereArgs: [invoiceId],
          limit: 1,
        );

        if (invoiceResult.isNotEmpty) {
          final totalAmount = invoiceResult.first['total_amount'] as int;
          final paidAmount = invoiceResult.first['paid_amount'] as int;
          final newPaidAmount = (paidAmount - amount).clamp(0, totalAmount);

          final newStatus = newPaidAmount == 0
              ? 'UNPAID'
              : newPaidAmount >= totalAmount
              ? 'PAID'
              : 'PARTIAL';

          await txn.update(
            'invoices',
            {'paid_amount': newPaidAmount, 'payment_status': newStatus},
            where: 'id = ?',
            whereArgs: [invoiceId],
          );
        }
      }
    });
  }

  // ====================================================================
  // جلب دفعات فاتورة معينة
  // ====================================================================

  Future<List<PaymentModel>> getPaymentsByInvoice(int invoiceId) async {
    final db = await _db;

    final result = await db.query(
      'payments',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'id DESC',
    );

    return result.map((e) => PaymentModel.fromMap(e)).toList();
  }

  Future<List<PaymentModel>> getPaymentsByReturn(int returnId) async {
    final db = await _db;

    final result = await db.query(
      'payments',
      where: 'return_id = ?',
      whereArgs: [returnId],
      orderBy: 'id DESC',
    );

    return result.map((e) => PaymentModel.fromMap(e)).toList();
  }

  // ====================================================================
  // جلب دفعات طرف معين (لكشف الحساب)
  // ====================================================================

  Future<List<PaymentModel>> getPaymentsByParty(int partyId) async {
    final db = await _db;

    final result = await db.query(
      'payments',
      where: 'party_id = ?',
      whereArgs: [partyId],
      orderBy: 'id DESC',
    );

    return result.map((e) => PaymentModel.fromMap(e)).toList();
  }

  // ====================================================================
  // ملخص الديون الكاملة (لصفحة الديون)
  // ====================================================================

  Future<List<PartyDebtSummary>> getAllDebts({
    required String invoiceType,
  }) async {
    final db = await _db;

    final result = await db.rawQuery(
      '''
    SELECT
      p.id   AS party_id,
      p.name AS party_name,
      p.phone AS party_phone,
      COUNT(i.id) AS invoice_count,
      COALESCE(
        SUM(
          CASE WHEN (i.total_amount - i.paid_amount) > 0
            THEN (i.total_amount - i.paid_amount)
            ELSE 0
          END
        ), 0
      ) AS total_remaining
    FROM parties p
    INNER JOIN invoices i ON i.party_id = p.id
    WHERE i.type = ?
    GROUP BY p.id, p.name, p.phone
    HAVING total_remaining > 0
    ORDER BY total_remaining DESC
  ''',
      [invoiceType],
    );

    return result
        .map(
          (row) => PartyDebtSummary(
            partyId: row['party_id'] as int,
            partyName: row['party_name'] as String,
            partyPhone: row['party_phone'] as String?,
            invoiceCount: row['invoice_count'] as int,
            totalRemaining: (row['total_remaining'] as num).toInt(),
          ),
        )
        .toList();
  }
}

// ==============================
// Models مساعدة
// ==============================

class PartyDebtSummary {
  final int partyId;
  final String partyName;
  final String? partyPhone;
  final int invoiceCount;
  final int totalRemaining;

  PartyDebtSummary({
    required this.partyId,
    required this.partyName,
    this.partyPhone,
    required this.invoiceCount,
    required this.totalRemaining,
  });
}

// ==============================
// Exceptions
// ==============================

class PaymentExceedsRemainingException implements Exception {
  final int requested;
  final int remaining;
  final String invoiceNumber;

  PaymentExceedsRemainingException({
    required this.requested,
    required this.remaining,
    required this.invoiceNumber,
  });

  @override
  String toString() => invoiceNumber.isEmpty
      ? 'المبلغ ($requested) يتجاوز المتبقي ($remaining)'
      : 'المبلغ ($requested) يتجاوز المتبقي على الفاتورة $invoiceNumber ($remaining)';
}
