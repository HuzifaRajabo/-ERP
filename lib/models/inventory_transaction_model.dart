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
  transferIn,
  waste,
  expiredReturn;

  String get label => switch (this) {
    InventoryTransactionType.sale            => 'بيع',
    InventoryTransactionType.purchase        => 'شراء',
    InventoryTransactionType.saleReturn      => 'مرتجع مبيعات',
    InventoryTransactionType.purchaseReturn  => 'مرتجع مشتريات',
    InventoryTransactionType.transferOut     => 'تحويل خارج',
    InventoryTransactionType.transferIn      => 'تحويل داخل',
    InventoryTransactionType.waste           => 'إتلاف',
    InventoryTransactionType.expiredReturn   => 'مرتجع منتهي الصلاحية',
  };

  String get dbValue => switch (this) {
    InventoryTransactionType.sale            => 'SALE',
    InventoryTransactionType.purchase        => 'PURCHASE',
    InventoryTransactionType.saleReturn      => 'SALE_RETURN',
    InventoryTransactionType.purchaseReturn  => 'PURCHASE_RETURN',
    InventoryTransactionType.transferOut     => 'TRANSFER_OUT',
    InventoryTransactionType.transferIn      => 'TRANSFER_IN',
    InventoryTransactionType.waste           => 'WASTE',
    InventoryTransactionType.expiredReturn   => 'EXPIRED_RETURN',
  };

  static InventoryTransactionType fromDb(String value) =>
      switch (value.toUpperCase()) {
        'SALE'             => InventoryTransactionType.sale,
        'PURCHASE'         => InventoryTransactionType.purchase,
        'SALE_RETURN'      => InventoryTransactionType.saleReturn,
        'PURCHASE_RETURN'  => InventoryTransactionType.purchaseReturn,
        'TRANSFER_OUT'     => InventoryTransactionType.transferOut,
        'TRANSFER_IN'      => InventoryTransactionType.transferIn,
        'WASTE'            => InventoryTransactionType.waste,
        'EXPIRED_RETURN'   => InventoryTransactionType.expiredReturn,
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
    InventoryTransactionType.waste           => false,
    InventoryTransactionType.expiredReturn   => false,
  };

  /// هل هذه الحركة ضمن عمليات التحويل بين المستودعات؟
  bool get isTransfer =>
      this == InventoryTransactionType.transferOut ||
      this == InventoryTransactionType.transferIn;
}

/// نموذج مُعزَّز يضم بيانات الحركة + اسم المنتج + رقم الفاتورة
/// يُستخدم في الواجهة لعرض معلومات كاملة بدون joins إضافية
class InventoryTransactionView {
  final InventoryTransactionModel transaction;
  final String productName;

  /// رقم الفاتورة (فارغ لحركات التحويل بين المستودعات).
  final String? invoiceNumber;

  /// اسم المستودع الذي تنتمي إليه هذه الحركة
  /// (مصدر التحويل لأجل TRANSFER_OUT، والوجهة لأجل TRANSFER_IN).
  final String? warehouseName;

  /// اسم المستودع المقابل في عمليات التحويل
  /// (الوجهة لأجل TRANSFER_OUT، والمصدر لأجل TRANSFER_IN).
  final String? counterpartyWarehouseName;

  final String? batchNumber;
  final String? expiryDate;
  final String? unitName;

  InventoryTransactionView({
    required this.transaction,
    required this.productName,
    this.invoiceNumber,
    this.warehouseName,
    this.counterpartyWarehouseName,
    this.batchNumber,
    this.expiryDate,
    this.unitName,
  });
}

class InventoryTransactionPage {
  final List<InventoryTransactionView> transactions;
  final bool hasNextPage;
  final int? nextCursor;

  const InventoryTransactionPage({
    required this.transactions,
    required this.hasNextPage,
    this.nextCursor,
  });
}

/// ملخص مخزون منتج معين
class ProductStockSummary {
  final int productId;
  final String productName;
  final String productDescription;
  final double totalPurchased;
  final double totalSold;
  final double available;
  final String? unitName;
  final int value; // قيمة المتاح بالسنت (بسعر التكلفة)
  final double? minStock;

  ProductStockSummary({
    required this.productId,
    required this.productName,
    required this.productDescription,
    required this.totalPurchased,
    required this.totalSold,
    required this.available,
    this.unitName,
    this.value = 0,
    this.minStock,
  });
}

/// تفاصيل مخزون دفعة منتج معين ضمن مستودع معين.
class WarehouseProductBatchStock {
  final int batchId;
  final String? batchNumber;
  final String? expiryDate;
  final double available;
  final int costPrice; // تكلفة الوحدة الأساسية (من الدفعة أو المنتج)

  WarehouseProductBatchStock({
    required this.batchId,
    required this.batchNumber,
    required this.expiryDate,
    required this.available,
    required this.costPrice,
  });
}
