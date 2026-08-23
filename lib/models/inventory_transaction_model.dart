// تحسين الموديل قبل البناء
class InventoryTransactionModel {
  final int? id;
  final int productId;
  final InventoryTransactionType type; // ← String إلى enum
  final double quantity; // ← دائماً بالوحدة الأساسية (القطعة)
  final int invoiceId;
  final int? warehouseId;
  final int? batchId;
  final int? unitId;
  final String? createdAt;

  InventoryTransactionModel({
    this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    required this.invoiceId,
    this.warehouseId,
    this.batchId,
    this.unitId,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'type': type.dbValue,
      'quantity': quantity,
      'invoice_id': invoiceId,
      'warehouse_id': warehouseId,
      'batch_id': batchId,
      'unit_id': unitId,
      'created_at': createdAt,
    };
  }

  factory InventoryTransactionModel.fromMap(Map<String, dynamic> map) {
    return InventoryTransactionModel(
      id: map['id'],
      productId: map['product_id'],
      type: InventoryTransactionType.fromDb(map['type']),
      quantity: (map['quantity'] as num).toDouble(),
      invoiceId: map['invoice_id'],
      warehouseId: map['warehouse_id'],
      batchId: map['batch_id'],
      unitId: map['unit_id'],
      createdAt: map['created_at'],
    );
  }

  InventoryTransactionModel copyWith({
    int? id,
    int? productId,
    InventoryTransactionType? type,
    double? quantity,
    int? invoiceId,
    int? warehouseId,
    int? batchId,
    int? unitId,
    String? createdAt,
  }) {
    return InventoryTransactionModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      invoiceId: invoiceId ?? this.invoiceId,
      warehouseId: warehouseId ?? this.warehouseId,
      batchId: batchId ?? this.batchId,
      unitId: unitId ?? this.unitId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// تحديث InventoryTransactionType enum
enum InventoryTransactionType {
  sale,
  purchase,
  saleReturn,
  purchaseReturn;

  String get label => switch (this) {
    InventoryTransactionType.sale            => 'بيع',
    InventoryTransactionType.purchase        => 'شراء',
    InventoryTransactionType.saleReturn      => 'مرتجع مبيعات',
    InventoryTransactionType.purchaseReturn  => 'مرتجع مشتريات',
  };

  String get dbValue => switch (this) {
    InventoryTransactionType.sale            => 'SALE',
    InventoryTransactionType.purchase        => 'PURCHASE',
    InventoryTransactionType.saleReturn      => 'SALE_RETURN',
    InventoryTransactionType.purchaseReturn  => 'PURCHASE_RETURN',
  };

  static InventoryTransactionType fromDb(String value) =>
      switch (value.toUpperCase()) {
        'SALE'             => InventoryTransactionType.sale,
        'PURCHASE'         => InventoryTransactionType.purchase,
        'SALE_RETURN'      => InventoryTransactionType.saleReturn,
        'PURCHASE_RETURN'  => InventoryTransactionType.purchaseReturn,
        _ => throw Exception('Unknown type: $value'),
      };

  // يزيد المخزون أم يقلله؟
  bool get increasesStock => switch (this) {
    InventoryTransactionType.sale            => false,
    InventoryTransactionType.purchase        => true,
    InventoryTransactionType.saleReturn      => true,
    InventoryTransactionType.purchaseReturn  => false,
  };
}