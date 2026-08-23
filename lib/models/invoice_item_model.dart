class InvoiceItemModel {
  final int? id;
  final int invoiceId;
  final int productId;
  final String productNameSnapshot;
  final double quantity; // ← بالوحدة المختارة عند البيع (قطعة/باكيت/كرتون)
  final int unitPrice; // ← سعر تلك الوحدة
  final int lineTotal;
  final int? unitId;
  final String? unitNameSnapshot;
  final double conversionFactorSnapshot; // ← لتحويل quantity إلى وحدة أساسية

  InvoiceItemModel({
    this.id,
    required this.invoiceId,
    required this.productId,
    required this.productNameSnapshot,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.unitId,
    this.unitNameSnapshot,
    this.conversionFactorSnapshot = 1,
  });

  /// الكمية المكافئة بالوحدة الأساسية (القطعة)، تُستخدم عند تسجيل
  /// حركة المخزون في inventory_transactions.
  double get baseQuantity => quantity * conversionFactorSnapshot;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'product_id': productId,
      'product_name_snapshot': productNameSnapshot,
      'quantity': quantity,
      'unit_price': unitPrice,
      'line_total': lineTotal,
      'unit_id': unitId,
      'unit_name_snapshot': unitNameSnapshot,
      'conversion_factor_snapshot': conversionFactorSnapshot,
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
      unitId: map['unit_id'],
      unitNameSnapshot: map['unit_name_snapshot'],
      conversionFactorSnapshot:
          (map['conversion_factor_snapshot'] as num?)?.toDouble() ?? 1,
    );
  }
}