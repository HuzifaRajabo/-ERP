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

  /// ينقل كمية بالوحدة الأساسية من [fromWarehouseId] إلى [toWarehouseId]
  /// لمنتج معين، مع توزيعها على الدفعات وفق FEFO من المصدر،
  /// كل ذلك داخل transaction واحدة لضمان الذرية.
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
