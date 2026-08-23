// lib/models/return_model.dart

enum ReturnType {
  saleReturn,
  purchaseReturn;

  String get label => switch (this) {
    ReturnType.saleReturn     => 'مرتجع مبيعات',
    ReturnType.purchaseReturn => 'مرتجع مشتريات',
  };

  String get inventoryType => switch (this) {
    ReturnType.saleReturn     => 'SALE_RETURN',
    ReturnType.purchaseReturn => 'PURCHASE_RETURN',
  };

  // ← للحفظ في قاعدة البيانات يطابق الـ CHECK constraint
  String get dbValue => switch (this) {
    ReturnType.saleReturn     => 'SALE_RETURN',
    ReturnType.purchaseReturn => 'PURCHASE_RETURN',
  };

  // ← للقراءة من قاعدة البيانات
  static ReturnType fromDb(String value) => switch (value.toUpperCase()) {
    'SALE_RETURN'     => ReturnType.saleReturn,
    'PURCHASE_RETURN' => ReturnType.purchaseReturn,
    _ => throw Exception('Unknown return type: $value'),
  };
}

class ReturnModel {
  final int? id;
  final String returnNumber;       // RTN-0001
  final int originalInvoiceId;
  final ReturnType type;
  final int partyId;
  final String partyNameSnapshot;
  final String partyAddressSnapshot;
  final int totalAmount;
  final String? notes;
  final String? createdAt;

  ReturnModel({
    this.id,
    required this.returnNumber,
    required this.originalInvoiceId,
    required this.type,
    required this.partyId,
    required this.partyNameSnapshot,
    required this.partyAddressSnapshot,
    required this.totalAmount,
    this.notes,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'return_number': returnNumber,
    'original_invoice_id': originalInvoiceId,
    'type': type.dbValue,          // ← SALE_RETURN / PURCHASE_RETURN
    'party_id': partyId,
    'party_name_snapshot': partyNameSnapshot,
    'party_address_snapshot': partyAddressSnapshot,
    'total_amount': totalAmount,
    'notes': notes,
    'created_at': createdAt,
  };

  factory ReturnModel.fromMap(Map<String, dynamic> map) => ReturnModel(
    id: map['id'],
    returnNumber: map['return_number'],
    originalInvoiceId: map['original_invoice_id'],
    type: ReturnType.fromDb(map['type']),  // ← يقرأ SALE_RETURN
    partyId: map['party_id'],
    partyNameSnapshot: map['party_name_snapshot'],
    partyAddressSnapshot: map['party_address_snapshot'],
    totalAmount: map['total_amount'],
    notes: map['notes'],
    createdAt: map['created_at'],
  );
}

class ReturnItemModel {
  final int? id;
  final int returnId;
  final int productId;
  final int? batchId;
  final String productNameSnapshot;
  final double quantity;
  final int unitPrice;
  final int lineTotal;

  ReturnItemModel({
    this.id,
    required this.returnId,
    required this.productId,
    this.batchId,
    required this.productNameSnapshot,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'return_id': returnId,
    'product_id': productId,
    'batch_id': batchId,
    'product_name_snapshot': productNameSnapshot,
    'quantity': quantity,
    'unit_price': unitPrice,
    'line_total': lineTotal,
  };

  factory ReturnItemModel.fromMap(Map<String, dynamic> map) => ReturnItemModel(
    id: map['id'],
    returnId: map['return_id'],
    productId: map['product_id'],
    batchId: map['batch_id'],
    productNameSnapshot: map['product_name_snapshot'],
    quantity: (map['quantity'] as num).toDouble(),
    unitPrice: map['unit_price'],
    lineTotal: map['line_total'],
  );
}

// ==============================
// كائنات مساعدة
// ==============================

/// سطر فاتورة مع معلومات الكمية المتاحة للإرجاع
class ReturnableItem {
  final int invoiceItemId;
  final int productId;
  final int? batchId;
  final String productName;
  final double originalQuantity;   // الكمية الأصلية في الفاتورة
  final double returnedSoFar;      // ما أُرجع مسبقاً
  final double availableToReturn;  // ما يمكن إرجاعه الآن
  final int unitPrice;
  final double conversionFactor;   // معامل تحويل الوحدة المختارة إلى الوحدة الأساسية
  final int? unitId;
  final String? unitName;
  double selectedQuantity;         // ما يريد المستخدم إرجاعه الآن

  ReturnableItem({
    required this.invoiceItemId,
    required this.productId,
    this.batchId,
    required this.productName,
    required this.originalQuantity,
    required this.returnedSoFar,
    required this.unitPrice,
    this.conversionFactor = 1,
    this.unitId,
    this.unitName,
    this.selectedQuantity = 0,
  }) : availableToReturn = originalQuantity - returnedSoFar;

  double get baseQuantity => selectedQuantity * conversionFactor;
  int get lineTotal => (selectedQuantity * unitPrice).round();
}

/// مرتجع كامل مع أسطره
class ReturnWithItems {
  final ReturnModel returnModel;
  final List<ReturnItemModel> items;

  ReturnWithItems({required this.returnModel, required this.items});
}