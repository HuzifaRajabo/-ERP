import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/invoice_model.dart';
import '../models/debt_report_model.dart';
import '../models/payment_model.dart';
import 'returnable_packaging_repository.dart';

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
  // توزيع دفعة عامة على فواتير الطرف ومطالبات تعويض العبوات
  // ====================================================================
  //
  // يستقبل قائمة PaymentDistributionItem التي بناها المستخدم
  // (تلقائياً أو يدوياً) ويحفظها كدفعات مستقلة لكل فاتورة أو مطالبة عبوات.
  // كل هذا في transaction واحدة لضمان الذرية.

  Future<void> distributePayment(PaymentDistribution distribution) async {
    if (distribution.items.isEmpty) {
      throw Exception('لا توجد بنود لتوزيع الدفعة عليها');
    }

    if (distribution.items.any((i) => i.amount <= 0)) {
      throw Exception('جميع المبالغ يجب أن تكون أكبر من صفر');
    }

    final db = await _db;
    final packagingRepo = ReturnablePackagingRepository();

    await db.transaction((txn) async {
      // التحقق من أن مجموع التوزيع لا يتجاوز مجموع المتبقي
      int totalDistributed = 0;

      for (final item in distribution.items) {
        if (item.packagingChargeId != null) {
          await packagingRepo.payChargeInTxn(
            txn,
            chargeId: item.packagingChargeId!,
            amount: item.amount,
            notes: distribution.notes,
          );
          totalDistributed += item.amount;
          continue;
        }

        if (item.invoiceId == null) {
          throw Exception('بند التوزيع غير صالح');
        }

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
    bool includePackagingCompensation = false,
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

    int remaining = availableAmount;
    final invoices = <InvoicePaymentInfo>[];

    void addItem({
      int? invoiceId,
      int? packagingChargeId,
      required String invoiceNumber,
      required int totalAmount,
      required int paidAmount,
      required int itemRemaining,
    }) {
      final suggested = remaining >= itemRemaining ? itemRemaining : remaining;
      invoices.add(
        InvoicePaymentInfo(
          invoiceId: invoiceId,
          packagingChargeId: packagingChargeId,
          invoiceNumber: invoiceNumber,
          totalAmount: totalAmount,
          paidAmount: paidAmount,
          remaining: itemRemaining,
          suggestedPayment: suggested < 0 ? 0 : suggested,
        ),
      );
      remaining -= suggested < 0 ? 0 : suggested;
      if (remaining < 0) remaining = 0;
    }

    for (final row in result) {
      final totalAmount = row['total_amount'] as int;
      final paidAmount = row['paid_amount'] as int;
      addItem(
        invoiceId: row['id'] as int,
        invoiceNumber: row['invoice_number'] as String,
        totalAmount: totalAmount,
        paidAmount: paidAmount,
        itemRemaining: totalAmount - paidAmount,
      );
    }

    if (includePackagingCompensation) {
      final charges = await db.rawQuery(
        '''
        SELECT
          c.id,
          c.amount,
          c.paid_amount,
          s.settlement_number
        FROM returnable_packaging_charges c
        LEFT JOIN returnable_packaging_settlements s ON s.id = c.settlement_id
        WHERE c.party_id = ? AND (c.amount - c.paid_amount) > 0
        ORDER BY c.id ASC
        ''',
        [partyId],
      );
      for (final row in charges) {
        final totalAmount = row['amount'] as int;
        final paidAmount = row['paid_amount'] as int;
        final settlementNumber = row['settlement_number'] as String?;
        final label = settlementNumber == null || settlementNumber.isEmpty
            ? 'تعويض عبوات'
            : 'تعويض عبوات • $settlementNumber';
        addItem(
          packagingChargeId: row['id'] as int,
          invoiceNumber: label,
          totalAmount: totalAmount,
          paidAmount: paidAmount,
          itemRemaining: totalAmount - paidAmount,
        );
      }
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
      COALESCE(inv.invoice_count, 0) AS invoice_count,
      COALESCE(inv.total_remaining, 0) AS invoice_remaining,
      CASE WHEN ? = 'SALE' THEN COALESCE(chg.charge_remaining, 0) ELSE 0 END
        AS packaging_compensation_remaining,
      COALESCE(inv.total_remaining, 0)
        + CASE WHEN ? = 'SALE' THEN COALESCE(chg.charge_remaining, 0) ELSE 0 END
        AS total_remaining
    FROM parties p
    LEFT JOIN (
      SELECT
        party_id,
        COUNT(
          CASE WHEN (total_amount - paid_amount) > 0 THEN id END
        ) AS invoice_count,
        COALESCE(SUM(
          CASE WHEN (total_amount - paid_amount) > 0
            THEN (total_amount - paid_amount)
            ELSE 0
          END
        ), 0) AS total_remaining
      FROM invoices
      WHERE type = ?
      GROUP BY party_id
    ) inv ON inv.party_id = p.id
    LEFT JOIN (
      SELECT
        party_id,
        SUM(amount - paid_amount) AS charge_remaining
      FROM returnable_packaging_charges
      WHERE (amount - paid_amount) > 0
      GROUP BY party_id
    ) chg ON chg.party_id = p.id
    WHERE COALESCE(inv.total_remaining, 0)
      + CASE WHEN ? = 'SALE' THEN COALESCE(chg.charge_remaining, 0) ELSE 0 END > 0
    ORDER BY total_remaining DESC
  ''',
      [invoiceType, invoiceType, invoiceType, invoiceType],
    );

    return result
        .map(
          (row) => PartyDebtSummary(
            partyId: row['party_id'] as int,
            partyName: row['party_name'] as String,
            partyPhone: row['party_phone'] as String?,
            invoiceCount: row['invoice_count'] as int,
            invoiceRemaining: (row['invoice_remaining'] as num).toInt(),
            packagingCompensationRemaining:
                (row['packaging_compensation_remaining'] as num).toInt(),
          ),
        )
        .toList();
  }

  /// مصادر الديون غير المسددة حسب نوع الفاتورة (بيع أو شراء).
  /// تعويض العبوات يُضاف فقط لديون الزبائن عندما [includePackaging] = true.
  Future<List<PartyDebtStatement>> getDebtStatements({
    required InvoiceType invoiceType,
    int? partyId,
    bool includePackaging = false,
  }) async {
    final db = await _db;
    final owedToUs = invoiceType == InvoiceType.sale;
    final typeDb = invoiceType.name.toUpperCase();

    final invoiceWhere = <String>[
      'i.type = ?',
      '(i.total_amount - i.paid_amount) > 0',
    ];
    final invoiceArgs = <Object?>[typeDb];
    if (partyId != null) {
      invoiceWhere.add('i.party_id = ?');
      invoiceArgs.add(partyId);
    }

    final invoiceRows = await db.rawQuery(
      '''
      SELECT
        i.invoice_number,
        i.party_id,
        i.total_amount,
        i.paid_amount,
        i.created_at,
        p.name AS party_name,
        p.phone AS party_phone
      FROM invoices i
      INNER JOIN parties p ON p.id = i.party_id
      WHERE ${invoiceWhere.join(' AND ')}
      ORDER BY i.id DESC
      ''',
      invoiceArgs,
    );

    final chargeRows = <Map<String, Object?>>[];
    if (includePackaging && owedToUs) {
      final chargeWhere = <String>['(c.amount - c.paid_amount) > 0'];
      final chargeArgs = <Object?>[];
      if (partyId != null) {
        chargeWhere.add('c.party_id = ?');
        chargeArgs.add(partyId);
      }
      chargeRows.addAll(
        await db.rawQuery(
          '''
          SELECT
            c.party_id,
            c.amount,
            c.paid_amount,
            c.created_at,
            p.name AS party_name,
            p.phone AS party_phone,
            t.name AS type_name,
            s.settlement_number
          FROM returnable_packaging_charges c
          INNER JOIN parties p ON p.id = c.party_id
          INNER JOIN returnable_packaging_types t ON t.id = c.type_id
          LEFT JOIN returnable_packaging_settlements s
            ON s.id = c.settlement_id
          WHERE ${chargeWhere.join(' AND ')}
          ORDER BY c.id DESC
          ''',
          chargeArgs,
        ),
      );
    }

    final grouped = <int, _PartyStatementDraft>{};

    void ensureParty(Map<String, Object?> row) {
      final id = row['party_id'] as int;
      grouped.putIfAbsent(
        id,
        () => _PartyStatementDraft(
          partyId: id,
          partyName: row['party_name'] as String? ?? '',
          partyPhone: row['party_phone'] as String?,
          owedToUs: owedToUs,
        ),
      );
    }

    for (final row in invoiceRows) {
      ensureParty(row);
      grouped[row['party_id'] as int]!.lines.add(
        DebtSourceLine(
          kind: DebtSourceKind.invoice,
          documentNumber: row['invoice_number'] as String,
          sourceTypeLabel: owedToUs ? 'فاتورة بيع' : 'فاتورة شراء',
          date: row['created_at'] as String?,
          totalAmount: (row['total_amount'] as num).toInt(),
          paidAmount: (row['paid_amount'] as num).toInt(),
        ),
      );
    }

    for (final row in chargeRows) {
      ensureParty(row);
      final settlement = (row['settlement_number'] as String?)?.trim();
      final typeName = (row['type_name'] as String?)?.trim();
      final number = (settlement != null && settlement.isNotEmpty)
          ? 'تعويض عبوات • $settlement'
          : 'تعويض عبوات';
      final typeLabel = (typeName != null && typeName.isNotEmpty)
          ? 'تعويض عبوات • $typeName'
          : 'تعويض عبوات';
      grouped[row['party_id'] as int]!.lines.add(
        DebtSourceLine(
          kind: DebtSourceKind.packagingCharge,
          documentNumber: number,
          sourceTypeLabel: typeLabel,
          date: row['created_at'] as String?,
          totalAmount: (row['amount'] as num).toInt(),
          paidAmount: (row['paid_amount'] as num).toInt(),
        ),
      );
    }

    final statements = grouped.values
        .map(
          (draft) => PartyDebtStatement(
            partyId: draft.partyId,
            partyName: draft.partyName,
            partyPhone: draft.partyPhone,
            owedToUs: draft.owedToUs,
            lines: draft.lines,
          ),
        )
        .toList()
      ..sort((a, b) => b.totalRemaining.compareTo(a.totalRemaining));
    return statements;
  }
}

// ==============================
// Models مساعدة
// ==============================

class _PartyStatementDraft {
  _PartyStatementDraft({
    required this.partyId,
    required this.partyName,
    required this.owedToUs,
    this.partyPhone,
  });

  final int partyId;
  final String partyName;
  final String? partyPhone;
  final bool owedToUs;
  final List<DebtSourceLine> lines = [];
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
