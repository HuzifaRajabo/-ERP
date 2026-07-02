// تحسين الموديل قبل البناء
class InventoryTransactionModel {
  final int? id;
  final int productId;
  final InventoryTransactionType type; // ← String إلى enum
  final double quantity;
  final int invoiceId;
  final String? createdAt;

  InventoryTransactionModel({
    this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    required this.invoiceId,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'type': type.name.toUpperCase(), // SALE / PURCHASE
      'quantity': quantity,
      'invoice_id': invoiceId,
      'created_at': createdAt,
    };
  }

  factory InventoryTransactionModel.fromMap(Map<String, dynamic> map) {
    return InventoryTransactionModel(
      id: map['id'],
      productId: map['product_id'],
      type: InventoryTransactionType.values.byName(
        map['type'].toString().toLowerCase(), // SALE → sale
      ),
      quantity: (map['quantity'] as num).toDouble(),
      invoiceId: map['invoice_id'],
      createdAt: map['created_at'],
    );
  }

  InventoryTransactionModel copyWith({
    int? id,
    int? productId,
    InventoryTransactionType? type,
    double? quantity,
    int? invoiceId,
    String? createdAt,
  }) {
    return InventoryTransactionModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      invoiceId: invoiceId ?? this.invoiceId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

enum InventoryTransactionType { sale, purchase }