class InvoiceItemModel {
  final int? id;
  final int invoiceId;
  final int productId;
  final String productNameSnapshot;
  final double quantity;
  final int unitPrice;
  final int lineTotal;

  InvoiceItemModel({
    this.id,
    required this.invoiceId,
    required this.productId,
    required this.productNameSnapshot,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'product_id': productId,
      'product_name_snapshot': productNameSnapshot,
      'quantity': quantity,
      'unit_price': unitPrice,
      'line_total': lineTotal,
    };
  }

  factory InvoiceItemModel.fromMap(Map<String, dynamic> map) {
    return InvoiceItemModel(
      id: map['id'],
      invoiceId: map['invoice_id'],
      productId: map['product_id'],
      productNameSnapshot: map['product_name_snapshot'],
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: map['unit_price'],
      lineTotal: map['line_total'],
    );
  }
}