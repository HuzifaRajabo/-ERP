// تحسين الموديل قبل البناء
class InventoryTransactionModel {
  final int? id;
  final int productId;
  final InventoryTransactionType type; // ← String إلى enum
  final double quantity; // ← دائماً بالوحدة الأساسية (القطعة)
  final int? invoiceId; // ← اختياري (تحويلات المخزون لا تملك فاتورة)
  final int? warehouseId;
  final int? batchId;
  final int? unitId;

  /// معرّف يُربط حركتي التحويل معاً (تحويل خارج + تحويل داخل) في عملية واحدة.
  final int? transferId;

  final String? createdAt;

  InventoryTransactionModel({
    this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    this.invoiceId,
    this.warehouseId,
    this.batchId,
    this.unitId,
    this.transferId,
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
      'transfer_id': transferId,
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
      transferId: map['transfer_id'],
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
    int? transferId,
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
      transferId: transferId ?? this.transferId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// تحديث InventoryTransactionType enum
enum InventoryTransactionType {
  sale,
  purchase,
  saleReturn,
  purchaseReturn,
  transferOut,
  transferIn;

  String get label => switch (this) {
    InventoryTransactionType.sale            => 'بيع',
    InventoryTransactionType.purchase        => 'شراء',
    InventoryTransactionType.saleReturn      => 'مرتجع مبيعات',
    InventoryTransactionType.purchaseReturn  => 'مرتجع مشتريات',
    InventoryTransactionType.transferOut     => 'تحويل خارج',
    InventoryTransactionType.transferIn      => 'تحويل داخل',
  };

  String get dbValue => switch (this) {
    InventoryTransactionType.sale            => 'SALE',
    InventoryTransactionType.purchase        => 'PURCHASE',
    InventoryTransactionType.saleReturn      => 'SALE_RETURN',
    InventoryTransactionType.purchaseReturn  => 'PURCHASE_RETURN',
    InventoryTransactionType.transferOut     => 'TRANSFER_OUT',
    InventoryTransactionType.transferIn      => 'TRANSFER_IN',
  };

  static InventoryTransactionType fromDb(String value) =>
      switch (value.toUpperCase()) {
        'SALE'             => InventoryTransactionType.sale,
        'PURCHASE'         => InventoryTransactionType.purchase,
        'SALE_RETURN'      => InventoryTransactionType.saleReturn,
        'PURCHASE_RETURN'  => InventoryTransactionType.purchaseReturn,
        'TRANSFER_OUT'     => InventoryTransactionType.transferOut,
        'TRANSFER_IN'      => InventoryTransactionType.transferIn,
        _ => throw Exception('Unknown type: $value'),
      };

  // يزيد المخزون أم يقلله؟
  bool get increasesStock => switch (this) {
    InventoryTransactionType.sale            => false,
    InventoryTransactionType.purchase        => true,
    InventoryTransactionType.saleReturn      => true,
    InventoryTransactionType.purchaseReturn  => false,
    InventoryTransactionType.transferOut     => false,
    InventoryTransactionType.transferIn      => true,
  };

  /// هل هذه الحركة ضمن عمليات التحويل بين المستودعات؟
  bool get isTransfer =>
      this == InventoryTransactionType.transferOut ||
      this == InventoryTransactionType.transferIn;
}
