class InvoiceModel {
  final int? id;
  final String invoiceNumber;
  final InvoiceType type;
  final int partyId;
  final String partyNameSnapshot;
  final String partyAddressSnapshot;
  final int totalAmount; // يتغير عند المرتجع (للعرض)
  final int originalTotalAmount; // ← لا يتغير أبداً (للتقارير)
  final int paidAmount;
  final PaymentStatus paymentStatus;
  final String? notes;
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
    this.paidAmount = 0,
    this.paymentStatus = PaymentStatus.unpaid,
    this.notes,
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
    'paid_amount': paidAmount,
    'payment_status': paymentStatus.name.toUpperCase(),
    'notes': notes,
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
    paidAmount: map['paid_amount'] ?? 0,
    paymentStatus: PaymentStatus.values.byName(
      (map['payment_status'] ?? 'UNPAID').toString().toLowerCase(),
    ),
    notes: map['notes'],
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
