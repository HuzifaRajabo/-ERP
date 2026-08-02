// payment_model.dart
enum PaymentType { inbound, outbound }

class PaymentModel {
  final int? id;
  final int partyId;
  final int? invoiceId; // null = دفعة عامة وُزِّعت على فواتير
  final int? returnId;
  final int amount;
  final PaymentType type;
  final String? notes;
  final String? createdAt;

  PaymentModel({
    this.id,
    required this.partyId,
    this.invoiceId,
    this.returnId,
    required this.amount,
    required this.type,
    this.notes,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'party_id': partyId,
    'invoice_id': invoiceId,
    'return_id': returnId,
    'amount': amount,
    'type': type.name.toUpperCase(),
    'notes': notes,
    'created_at': createdAt,
  };

  factory PaymentModel.fromMap(Map<String, dynamic> map) => PaymentModel(
    id: map['id'],
    partyId: map['party_id'],
    invoiceId: map['invoice_id'],
    returnId: map['return_id'],
    amount: map['amount'],
    type: PaymentType.values.byName(map['type'].toString().toLowerCase()),
    notes: map['notes'],
    createdAt: map['created_at'],
  );
}

// ==============================
// كائنات مساعدة
// ==============================

/// فاتورة مع معلومات الدفع — لعرض التوزيع للمستخدم
class InvoicePaymentInfo {
  final int invoiceId;
  final String invoiceNumber;
  final int totalAmount;
  final int paidAmount;
  final int remaining; // totalAmount - paidAmount
  int suggestedPayment; // المقترح دفعه (قابل للتعديل يدوياً)

  InvoicePaymentInfo({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.totalAmount,
    required this.paidAmount,
    required this.remaining,
    required this.suggestedPayment,
  });
}

/// نتيجة التوزيع النهائية قبل الحفظ
class PaymentDistribution {
  final int partyId;
  final int totalAmount;
  final PaymentType type;
  final String? notes;
  final List<PaymentDistributionItem> items;

  PaymentDistribution({
    required this.partyId,
    required this.totalAmount,
    required this.type,
    this.notes,
    required this.items,
  });

  int get distributedTotal => items.fold(0, (sum, i) => sum + i.amount);
}

class PaymentDistributionItem {
  final int invoiceId;
  final String invoiceNumber;
  int amount; // قابل للتعديل

  PaymentDistributionItem({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.amount,
  });
}
