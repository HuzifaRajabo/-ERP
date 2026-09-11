class ExpiredReturnRecord {
  final int? id;
  final String returnNumber;
  final int partyId;
  final String partyNameSnapshot;
  final int warehouseId;
  final String? warehouseName;
  final int inventoryCost;
  final int compensationAmount;
  final int paidAmount;
  final String? reason;
  final String? notes;
  final String? createdAt;

  ExpiredReturnRecord({
    this.id,
    required this.returnNumber,
    required this.partyId,
    required this.partyNameSnapshot,
    required this.warehouseId,
    this.warehouseName,
    required this.inventoryCost,
    required this.compensationAmount,
    this.paidAmount = 0,
    this.reason,
    this.notes,
    this.createdAt,
  });

  int get netLoss => inventoryCost - compensationAmount;

  int get remainingCompensation {
    final remaining = compensationAmount - paidAmount;
    return remaining < 0 ? 0 : remaining;
  }

  factory ExpiredReturnRecord.fromMap(Map<String, dynamic> map) =>
      ExpiredReturnRecord(
        id: map['id'] as int?,
        returnNumber: map['return_number'] as String,
        partyId: map['party_id'] as int,
        partyNameSnapshot: map['party_name_snapshot'] as String,
        warehouseId: map['warehouse_id'] as int,
        warehouseName: map['warehouse_name'] as String?,
        inventoryCost: map['inventory_cost'] as int? ?? 0,
        compensationAmount: map['compensation_amount'] as int? ?? 0,
        paidAmount: map['paid_amount'] as int? ?? 0,
        reason: map['reason'] as String?,
        notes: map['notes'] as String?,
        createdAt: map['created_at'] as String?,
      );
}

class ExpiredReturnItem {
  final int? id;
  final int expiredReturnId;
  final int productId;
  final int batchId;
  final int? unitId;
  final String productNameSnapshot;
  final String? unitNameSnapshot;
  final String? batchNumberSnapshot;
  final String? expiryDateSnapshot;
  final double quantity;
  final double conversionFactor;
  final double baseQuantity;
  final int unitCost;
  final int lineCost;

  ExpiredReturnItem({
    this.id,
    required this.expiredReturnId,
    required this.productId,
    required this.batchId,
    this.unitId,
    required this.productNameSnapshot,
    this.unitNameSnapshot,
    this.batchNumberSnapshot,
    this.expiryDateSnapshot,
    required this.quantity,
    this.conversionFactor = 1,
    required this.baseQuantity,
    required this.unitCost,
    required this.lineCost,
  });

  factory ExpiredReturnItem.fromMap(Map<String, dynamic> map) =>
      ExpiredReturnItem(
        id: map['id'] as int?,
        expiredReturnId: map['expired_return_id'] as int,
        productId: map['product_id'] as int,
        batchId: map['batch_id'] as int,
        unitId: map['unit_id'] as int?,
        productNameSnapshot: map['product_name_snapshot'] as String,
        unitNameSnapshot: map['unit_name_snapshot'] as String?,
        batchNumberSnapshot: map['batch_number_snapshot'] as String?,
        expiryDateSnapshot: map['expiry_date_snapshot'] as String?,
        quantity: (map['quantity'] as num).toDouble(),
        conversionFactor:
            (map['conversion_factor_snapshot'] as num?)?.toDouble() ?? 1,
        baseQuantity: (map['base_quantity'] as num).toDouble(),
        unitCost: map['unit_cost'] as int,
        lineCost: map['line_cost'] as int,
      );
}

class ExpiredReturnWithItems {
  final ExpiredReturnRecord record;
  final List<ExpiredReturnItem> items;

  ExpiredReturnWithItems({required this.record, required this.items});
}
