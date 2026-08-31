import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../repositories/batch_repository.dart';
import '../repositories/product_unit_repository.dart';
import '../models/inventory_transaction_model.dart';

/// نتيجة تحويل مخزون لمنتج واحد عبر دفعاته (FEFO).
class StockTransferResult {
  final int transferId;
  final int productId;
  final int fromWarehouseId;
  final int toWarehouseId;
  final double quantity; // بالوحدة الأساسية
  final List<BatchAllocation> allocations;

  StockTransferResult({
    required this.transferId,
    required this.productId,
    required this.fromWarehouseId,
    required this.toWarehouseId,
    required this.quantity,
    required this.allocations,
  });
}

/// عنصر واحد ضمن عملية تحويل متعددة المنتجات — منتج + كمية بالوحدة
/// الأساسية.
class StockTransferItemInput {
  final int productId;
  final double quantity;

  const StockTransferItemInput({
    required this.productId,
    required this.quantity,
  });
}

/// نتيجة تحويل يضم عدة منتجات، منفَّذة كلها ضمن نفس transferId ونفس
/// transaction قاعدة بيانات واحدة (إما تنجح كلها معاً أو لا يُحفظ شيء).
class StockTransferBatchResult {
  final int transferId;
  final int fromWarehouseId;
  final int toWarehouseId;
  final List<StockTransferResult> items;

  StockTransferBatchResult({
    required this.transferId,
    required this.fromWarehouseId,
    required this.toWarehouseId,
    required this.items,
  });
}

/// مسؤول عن نقل المخزون بين المستودعات بشكل ذرّي.
///
/// النقل يُسجَّل كحركتين في inventory_transactions:
///   - TRANSFER_OUT: warehouse_id = المصدر (يُنقص المخزون منه)
///   - TRANSFER_IN : warehouse_id = الوجهة (يزيد مخزونها)
/// كلتا الحركتين تحتفظان بنفس batch_id و unit_id و transfer_id،
/// للحفاظ على الدفعة وتكلفتها وتاريخ الصلاحية، ولربط الحركتين معاً.
class StockTransferRepository {
  final BatchRepository _batchRepo;
  final ProductUnitRepository _unitRepo;

  StockTransferRepository(
    this._batchRepo,
    this._unitRepo, {
    Future<Database> Function()? dbProvider,
  }) : _dbProvider =
            dbProvider ?? (() async => DatabaseHelper.instance.database);

  final Future<Database> Function() _dbProvider;

  Future<Database> get _db async => _dbProvider();

  /// ينقل عدة منتجات دفعة واحدة من [fromWarehouseId] إلى [toWarehouseId]
  /// ضمن عملية ذرّية واحدة: إمّا تُنقل كل المنتجات بنجاح، أو لا يُحفظ أي
  /// تغيير على الإطلاق (لو فشل التحقق من توفر أي منتج ضمن القائمة).
  /// كل أسطر التحويل — لكل المنتجات — تشترك في نفس transferId، لتبقى
  /// عملية "تحويل واحدة" في السجل رغم تعدد المنتجات.
  Future<StockTransferBatchResult> transferStockBatch({
    required int fromWarehouseId,
    required int toWarehouseId,
    required List<StockTransferItemInput> items,
    String? notes,
  }) async {
    if (fromWarehouseId == toWarehouseId) {
      throw Exception('لا يمكن النقل إلى نفس المستودع');
    }
    if (items.isEmpty) {
      throw Exception('أضف منتجاً واحداً على الأقل قبل تنفيذ التحويل');
    }
    for (final item in items) {
      if (item.quantity <= 0) {
        throw Exception('الكمية يجب أن تكون أكبر من صفر لكل منتج');
      }
    }

    final db = await _db;

    // نجلب الوحدة الأساسية لكل منتج مسبقاً وخارج الـ transaction تماماً.
    // السبب: getBaseUnitForProduct تستخدم اتصال القاعدة الخام (_db) وليس
    // كائن الـ transaction، فاستدعاؤها من داخل db.transaction() يجعلها
    // تنتظر دورها في طابور نفس الاتصال بينما الـ transaction نفسها
    // تنتظرها هي — قفل متبادل (deadlock) يظهر في اللوج كـ
    // "database has been locked for 0:00:10". لذلك يجب أن يكتمل أي
    // استعلام لا يستخدم txn قبل بدء db.transaction وليس بعده.
    final baseUnitByProduct = <int, int?>{};
    for (final item in items) {
      if (baseUnitByProduct.containsKey(item.productId)) continue;
      final unit = await _unitRepo.getBaseUnitForProduct(item.productId);
      baseUnitByProduct[item.productId] = unit?.id;
    }

    return db.transaction((txn) async {
      final results = <StockTransferResult>[];
      var transferSeed = DateTime.now().millisecondsSinceEpoch;

      for (final item in items) {
        // مهم جداً: كل منتج يحصل على transfer_id خاص به وفريد، رغم أن
        // كل منتجات السلة تُنفَّذ معاً ضمن نفس transaction الذرّية.
        // السبب: استعلام عرض "الحركات" (getTransactionsByWarehouse)
        // يفترض أن كل transfer_id يربط سطرين فقط بالضبط (خروج + دخول
        // لمنتج واحد) عبر self-join لجلب اسم المستودع المقابل. لو
        // شارك عدة منتجات نفس transfer_id، يتطابق كل سطر مع أسطر
        // منتجات أخرى ضمن نفس العملية، فتظهر كل حركة مكررة في شاشة
        // الحركات (وأحياناً باسم مستودع مقابل خاطئ). زيادة العدّاد
        // يدوياً (بدل الاعتماد فقط على millisecondsSinceEpoch) تضمن
        // عدم تكرار نفس transfer_id حتى لو نُفِّذت عدة أسطر خلال نفس
        // المليثانية.
        final transferId = transferSeed++;
        final baseUnitId = baseUnitByProduct[item.productId];

        // يتحقق من توفر الكمية في المصدر ويوزّعها على الدفعات وفق FEFO؛
        // إن فشل أي منتج (كمية غير متوفرة)، يُرمى استثناء فيتراجع
        // db.transaction تلقائياً عن كل ما تم تسجيله للمنتجات السابقة
        // ضمن نفس هذه العملية — لا تحويل جزئي.
        final allocations = await _batchRepo.allocateAvailableQuantity(
          item.productId,
          item.quantity,
          warehouseId: fromWarehouseId,
          executor: txn,
        );

        for (final alloc in allocations) {
          await txn.insert('inventory_transactions', {
            'product_id': item.productId,
            'type': InventoryTransactionType.transferOut.dbValue,
            'quantity': alloc.quantity,
            'invoice_id': null,
            'warehouse_id': fromWarehouseId,
            'batch_id': alloc.batchId,
            'unit_id': baseUnitId,
            'transfer_id': transferId,
            'notes': notes,
          });

          await txn.insert('inventory_transactions', {
            'product_id': item.productId,
            'type': InventoryTransactionType.transferIn.dbValue,
            'quantity': alloc.quantity,
            'invoice_id': null,
            'warehouse_id': toWarehouseId,
            'batch_id': alloc.batchId,
            'unit_id': baseUnitId,
            'transfer_id': transferId,
            'notes': notes,
          });
        }

        results.add(StockTransferResult(
          transferId: transferId,
          productId: item.productId,
          fromWarehouseId: fromWarehouseId,
          toWarehouseId: toWarehouseId,
          quantity: item.quantity,
          allocations: allocations,
        ));
      }

      return StockTransferBatchResult(
        // معرّف مرجعي لعملية السلة ككل (وليس transfer_id فعلياً مشتركاً
        // في قاعدة البيانات) — يُستخدم فقط لعرض "تمت العملية بنجاح"،
        // وليس لأي استعلام أو ربط بيانات.
        transferId: results.first.transferId,
        fromWarehouseId: fromWarehouseId,
        toWarehouseId: toWarehouseId,
        items: results,
      );
    });
  }

  /// ينقل كمية بالوحدة الأساسية من [fromWarehouseId] إلى [toWarehouseId]
  /// لمنتج معين، مع توزيعها على الدفعات وفق FEFO من المصدر،
  /// كل ذلك داخل transaction واحدة لضمان الذرية.
  ///
  /// (يبقى متاحاً لأي استخدام مستقبلي بمنتج واحد؛ [transferStockBatch]
  /// هو المسار المستخدم فعلياً من شاشة التحويل متعددة المنتجات.)
  Future<StockTransferResult> transferStock({
    required int fromWarehouseId,
    required int toWarehouseId,
    required int productId,
    required double quantity,
    String? notes,
  }) async {
    if (fromWarehouseId == toWarehouseId) {
      throw Exception('لا يمكن النقل إلى نفس المستودع');
    }
    if (quantity <= 0) {
      throw Exception('الكمية يجب أن تكون أكبر من صفر');
    }

    final db = await _db;
    final baseUnit = await _unitRepo.getBaseUnitForProduct(productId);

    return db.transaction((txn) async {
      // تحقق من توفر الكمية في المصدر ووزّعها على الدفعات FEFO
      final allocations = await _batchRepo.allocateAvailableQuantity(
        productId,
        quantity,
        warehouseId: fromWarehouseId,
        executor: txn,
      );

      // معرّف مشترك لربط حركتي التحويل
      final transferId = DateTime.now().millisecondsSinceEpoch;

      for (final alloc in allocations) {
        // مصدر (يُنقص المخزون)
        await txn.insert('inventory_transactions', {
          'product_id': productId,
          'type': InventoryTransactionType.transferOut.dbValue,
          'quantity': alloc.quantity,
          'invoice_id': null,
          'warehouse_id': fromWarehouseId,
          'batch_id': alloc.batchId,
          'unit_id': baseUnit?.id,
          'transfer_id': transferId,
          'notes': notes,
        });

        // وجهة (يزيد المخزون)
        await txn.insert('inventory_transactions', {
          'product_id': productId,
          'type': InventoryTransactionType.transferIn.dbValue,
          'quantity': alloc.quantity,
          'invoice_id': null,
          'warehouse_id': toWarehouseId,
          'batch_id': alloc.batchId,
          'unit_id': baseUnit?.id,
          'transfer_id': transferId,
          'notes': notes,
        });
      }

      return StockTransferResult(
        transferId: transferId,
        productId: productId,
        fromWarehouseId: fromWarehouseId,
        toWarehouseId: toWarehouseId,
        quantity: quantity,
        allocations: allocations,
      );
    });
  }
}