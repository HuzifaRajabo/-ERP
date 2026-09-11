class WasteRecord {
  final int? id;
  final String wasteNumber;
  final int warehouseId;
  final String? warehouseName;
  final int totalCost;
  final String reason;
  final String? notes;
  final String? createdAt;

  WasteRecord({
    this.id,
    required this.wasteNumber,
    required this.warehouseId,
    this.warehouseName,
    required this.totalCost,
    required this.reason,
    this.notes,
    this.createdAt,
  });

  factory WasteRecord.fromMap(Map<String, dynamic> map) => WasteRecord(
        id: map['id'] as int?,
        wasteNumber: map['waste_number'] as String,
        warehouseId: map['warehouse_id'] as int,
        warehouseName: map['warehouse_name'] as String?,
        totalCost: map['total_cost'] as int? ?? 0,
        reason: map['reason'] as String? ?? '',
        notes: map['notes'] as String?,
        createdAt: map['created_at'] as String?,
      );
}

class WasteItem {
  final int? id;
  final int wasteId;
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

  WasteItem({
    this.id,
    required this.wasteId,
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

  factory WasteItem.fromMap(Map<String, dynamic> map) => WasteItem(
        id: map['id'] as int?,
        wasteId: map['waste_id'] as int,
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

class WasteWithItems {
  final WasteRecord record;
  final List<WasteItem> items;

  WasteWithItems({required this.record, required this.items});
}

class WasteItemDraft {
  final int productId;
  final String productName;
  final int batchId;
  final String batchNumber;
  final String? expiryDate;
  final int? unitId;
  final String? unitName;
  final double conversionFactor;
  final double quantity;
  final double baseQuantity;
  final int unitCost;

  WasteItemDraft({
    required this.productId,
    required this.productName,
    required this.batchId,
    required this.batchNumber,
    this.expiryDate,
    this.unitId,
    this.unitName,
    this.conversionFactor = 1,
    required this.quantity,
    required this.baseQuantity,
    required this.unitCost,
  });

  int get lineCost => (baseQuantity * unitCost).round();
}
