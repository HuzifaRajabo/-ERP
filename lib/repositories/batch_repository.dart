import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../models/batch_model.dart';

/// دفعة مع الكمية المتاحة منها (محسوبة من inventory_transactions،
/// بنفس نمط حساب المخزون المستخدم في بقية المشروع).
class BatchStock {
  final BatchModel batch;
  final double available; // بالوحدة الأساسية

  BatchStock({required this.batch, required this.available});
}

class BatchAllocation {
  final int batchId;
  final String batchNumber;
  final double quantity;
  final String? expiryDate;

  const BatchAllocation({
    required this.batchId,
    required this.batchNumber,
    required this.quantity,
    this.expiryDate,
  });
}

class BatchRepository {
  BatchRepository({Future<Database> Function()? dbProvider})
      : _dbProvider =
            dbProvider ?? (() async => DatabaseHelper.instance.database);

  final Future<Database> Function() _dbProvider;

  Future<Database> get _db async => _dbProvider();

  Future<int> insertBatch(BatchModel batch) async {
    try {
      final db = await _db;
      final data = batch.toMap()..remove('id');
      return await db.insert(
        'batches',
        data,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } on DatabaseException catch (e) {
      throw Exception('خطأ في قاعدة البيانات أثناء إضافة الدفعة: $e');
    }
  }

  Future<BatchModel?> getBatchById(int id) async {
    final db = await _db;
    final result = await db.query(
      'batches',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isEmpty ? null : BatchModel.fromMap(result.first);
  }

  Future<List<BatchModel>> getBatchesForProduct(int productId) async {
    final db = await _db;
    final result = await db.query(
      'batches',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'expiry_date ASC',
    );
    return result.map((e) => BatchModel.fromMap(e)).toList();
  }

  /// دفعات منتج معين مع الكمية المتاحة من كل دفعة، مرتبة حسب الأقرب
  /// انتهاءً أولاً (لدعم منطق البيع FEFO: First-Expiry-First-Out).
  /// تُستبعد الدفعات التي نفدت كميتها (available <= 0).
  ///
  /// [executor] اختياري: عند استدعاء هذا الأسلوب من داخل transaction خارجية
  /// (مثل حفظ فاتورة بيع) يجب تمرير نفس الـ transaction حتى لا يُنفَّذ
  /// الاستعلام على الاتصال الرئيسي المتزامن، ما يسبب قفل قاعدة البيانات.
  Future<List<BatchStock>> getAvailableBatchesForProduct(
    int productId, {
    int? warehouseId,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _db;

    final params = <Object?>[];
    if (warehouseId != null) {
      params.add(warehouseId);
    }
    params.add(productId);

    final result = await db.rawQuery(
      '''
      SELECT
        b.*,
        COALESCE(SUM(
          CASE
            WHEN it.type = 'PURCHASE'       THEN it.quantity
            WHEN it.type = 'SALE_RETURN'    THEN it.quantity
            WHEN it.type = 'TRANSFER_IN'    THEN it.quantity
            WHEN it.type = 'SALE'            THEN -it.quantity
            WHEN it.type = 'PURCHASE_RETURN' THEN -it.quantity
            WHEN it.type = 'TRANSFER_OUT'    THEN -it.quantity
            ELSE 0
          END
        ), 0) AS available
      FROM batches b
      LEFT JOIN inventory_transactions it
        ON it.batch_id = b.id
        ${warehouseId != null ? 'AND it.warehouse_id = ?' : ''}
      WHERE b.product_id = ?
      GROUP BY b.id
      HAVING available > 0
      ORDER BY
        CASE WHEN b.expiry_date IS NULL THEN 1 ELSE 0 END,
        b.expiry_date ASC
    ''',
      params,
    );

    return result.map((row) {
      return BatchStock(
        batch: BatchModel.fromMap(row),
        available: (row['available'] as num).toDouble(),
      );
    }).toList();
  }

  /// كل الدفعات (لكل المنتجات) التي تنتهي صلاحيتها خلال عدد أيام معين
  /// وما زال لديها مخزون متاح. مفيد لشاشة تنبيهات الصلاحية.
  Future<List<BatchStock>> getExpiringBatches({
    int withinDays = 30,
    int? warehouseId,
  }) async {
    final db = await _db;
    final thresholdDate = DateTime.now()
        .add(Duration(days: withinDays))
        .toIso8601String()
        .split('T')
        .first;

    final params = <Object?>[];
    if (warehouseId != null) {
      params.add(warehouseId);
    }
    params.add(thresholdDate);

    final result = await db.rawQuery(
      '''
      SELECT
        b.*,
        p.name AS product_name,
        COALESCE(SUM(
          CASE
            WHEN it.type = 'PURCHASE'       THEN it.quantity
            WHEN it.type = 'SALE_RETURN'    THEN it.quantity
            WHEN it.type = 'TRANSFER_IN'    THEN it.quantity
            WHEN it.type = 'SALE'            THEN -it.quantity
            WHEN it.type = 'PURCHASE_RETURN' THEN -it.quantity
            WHEN it.type = 'TRANSFER_OUT'    THEN -it.quantity
            ELSE 0
          END
        ), 0) AS available
      FROM batches b
      INNER JOIN products p ON p.id = b.product_id
      LEFT JOIN inventory_transactions it
        ON it.batch_id = b.id
        ${warehouseId != null ? 'AND it.warehouse_id = ?' : ''}
      WHERE b.expiry_date IS NOT NULL AND b.expiry_date <= ?
      GROUP BY b.id
      HAVING available > 0
      ORDER BY b.expiry_date ASC
    ''',
      params,
    );

    return result.map((row) {
      return BatchStock(
        batch: BatchModel.fromMap(row),
        available: (row['available'] as num).toDouble(),
      );
    }).toList();
  }

  /// يوزّع الكمية المطلوبة من منتج على دفعاته المتاحة وفق FEFO.
  ///
  /// عند الاستدعاء من داخل transaction خارجية (حفظ فاتورة) يجب تمرير نفس
  /// الـ [executor] ليُستخدم الاتصال نفسه داخل الـ transaction ويعمل بشكل
  /// ذرّي، بدلاً من استخدام الاتصال الرئيسي الذي يتسبب بقفل قاعدة البيانات.
  Future<List<BatchAllocation>> allocateAvailableQuantity(
    int productId,
    double requiredQuantity, {
    int? warehouseId,
    DatabaseExecutor? executor,
  }) async {
    final available = await getAvailableBatchesForProduct(
      productId,
      warehouseId: warehouseId,
      executor: executor,
    );
    final allocations = <BatchAllocation>[];
    double remaining = requiredQuantity;

    for (final item in available) {
      if (remaining <= 0) break;
      final actual = remaining > item.available ? item.available : remaining;
      if (actual <= 0) continue;
      allocations.add(
        BatchAllocation(
          batchId: item.batch.id!,
          batchNumber: item.batch.batchNumber ?? 'N/A',
          quantity: actual,
          expiryDate: item.batch.expiryDate,
        ),
      );
      remaining -= actual;
    }

    if (remaining > 0.0001) {
      throw Exception('الكمية المطلوبة أكبر من المخزون المتاح في الموقع المحدد');
    }

    return allocations;
  }

  Future<int> updateBatch(BatchModel batch) async {
    final db = await _db;
    return await db.update(
      'batches',
      batch.toMap(),
      where: 'id = ?',
      whereArgs: [batch.id],
    );
  }

  /// يبحث عن دفعة بنفس المنتج ورقم الدفعة، وينشئها إن لم توجد.
  /// يعمل داخل transaction خارجية (حفظ فاتورة الشراء) لضمان الذرية،
  /// ويُعيد id الدفعة. لا يُنشئ دفعة إذا كان رقم الدفعة فارغاً.
  Future<int?> findOrCreateBatchInTransaction(
    DatabaseExecutor txn, {
    required int productId,
    String? batchNumber,
    String? productionDate,
    String? expiryDate,
    int? costPrice,
  }) async {
    final number = batchNumber?.trim();
    if (number == null || number.isEmpty) return null;

    final existing = await txn.query(
      'batches',
      columns: ['id'],
      where: 'product_id = ? AND batch_number = ?',
      whereArgs: [productId, number],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.first['id'] as int;

    return await txn.insert('batches', {
      'product_id': productId,
      'batch_number': number,
      'production_date': productionDate,
      'expiry_date': expiryDate,
      'cost_price': costPrice,
    });
  }
}
