class InvoiceModel {
  final int? id;
  final String invoiceNumber;
  final InvoiceType type;
  final int partyId;
  final String partyNameSnapshot;
  final String partyAddressSnapshot;
  final int totalAmount; // الصافي بعد الحسم، ثم يتغير عند المرتجع
  final int originalTotalAmount; // إجمالي البنود قبل الحسم — لا يتغير
  final int discountAmount; // حسم بقيمة مالية على مستوى الفاتورة
  final int paidAmount;
  final PaymentStatus paymentStatus;
  final int? warehouseId;
  final String? notes;
  final String? salesChannel;
  final String? createdAt;

  InvoiceModel({
    this.id,
    required this.invoiceNumber,
    required this.type,
    required this.partyId,
    required this.partyNameSnapshot,
    required this.partyAddressSnapshot,
    required this.totalAmount,
    required this.originalTotalAmount,
    this.discountAmount = 0,
    this.paidAmount = 0,
    this.paymentStatus = PaymentStatus.unpaid,
    this.warehouseId,
    this.notes,
    this.salesChannel,
    this.createdAt,
  });

  int get remaining {
    final remainingAmount = totalAmount - paidAmount;
    return remainingAmount < 0 ? 0 : remainingAmount;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'invoice_number': invoiceNumber,
    'type': type.name.toUpperCase(),
    'party_id': partyId,
    'party_name_snapshot': partyNameSnapshot,
    'party_address_snapshot': partyAddressSnapshot,
    'total_amount': totalAmount,
    'original_total_amount': originalTotalAmount,
    'discount_amount': discountAmount,
    'paid_amount': paidAmount,
    'payment_status': paymentStatus.name.toUpperCase(),
    'warehouse_id': warehouseId,
    'notes': notes,
    'sales_channel': salesChannel,
    'created_at': createdAt,
  };

  factory InvoiceModel.fromMap(Map<String, dynamic> map) => InvoiceModel(
    id: map['id'],
    invoiceNumber: map['invoice_number'],
    type: InvoiceType.values.byName(map['type'].toString().toLowerCase()),
    partyId: map['party_id'],
    partyNameSnapshot: map['party_name_snapshot'],
    partyAddressSnapshot: map['party_address_snapshot'],
    totalAmount: map['total_amount'] ?? 0,
    originalTotalAmount:
        map['original_total_amount'] ?? map['total_amount'] ?? 0,
    discountAmount: map['discount_amount'] ?? 0,
    paidAmount: map['paid_amount'] ?? 0,
    paymentStatus: PaymentStatus.values.byName(
      (map['payment_status'] ?? 'UNPAID').toString().toLowerCase(),
    ),
    warehouseId: map['warehouse_id'],
    notes: map['notes'],
    salesChannel: map['sales_channel'] as String?,
    createdAt: map['created_at'],
  );
}

enum InvoiceType { sale, purchase }

enum PaymentStatus {
  unpaid,
  partial,
  paid;

  String get label => switch (this) {
    PaymentStatus.unpaid => 'غير مدفوع',
    PaymentStatus.partial => 'مدفوع جزئياً',
    PaymentStatus.paid => 'مدفوع',
  };

  // لون الحالة للواجهة
  // (نستخدم int لأن Color من Flutter غير متاح في الموديل)
  String get colorHex => switch (this) {
    PaymentStatus.unpaid => 'F44336', // أحمر
    PaymentStatus.partial => 'FF9800', // برتقالي
    PaymentStatus.paid => '4CAF50', // أخضر
  };
}

/// نتيجة محاولة حذف فاتورة.
///
/// - [allowed]  : حُذفت الفاتورة بنجاح (مع تنظيف الدفعات والحركات المالية).
/// - [blocked]  : مُنع الحذف، والسبب في [reason] (نص واضح بالعربية).
class InvoiceDeleteResult {
  final bool success;
  final String? reason;

  const InvoiceDeleteResult._(this.success, this.reason);

  static const InvoiceDeleteResult allowed =
      InvoiceDeleteResult._(true, null);

  const InvoiceDeleteResult.blocked({this.reason})
      : success = false;

  bool get isBlocked => !success;

  @override
  String toString() =>
      success ? 'allowed' : 'blocked($reason)';
}
