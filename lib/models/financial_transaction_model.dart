enum FinancialTransactionType {
  sale,
  purchase,
  paymentIn,
  paymentOut,
  saleReturn,
  purchaseReturn,
  refund,
  adjustment,
}

enum FinancialTransactionDirection { inbound, outbound }

class FinancialTransactionModel {
  final int? id;
  final int? invoiceId;
  final int? paymentId;
  final int? returnId;
  final int partyId;
  final FinancialTransactionType type;
  final FinancialTransactionDirection direction;
  final int amount;
  final String? notes;
  final String? createdAt;

  FinancialTransactionModel({
    this.id,
    this.invoiceId,
    this.paymentId,
    this.returnId,
    required this.partyId,
    required this.type,
    required this.direction,
    required this.amount,
    this.notes,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'payment_id': paymentId,
      'return_id': returnId,
      'party_id': partyId,
      'type': type.dbValue,
      'direction': direction.dbValue,
      'amount': amount,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory FinancialTransactionModel.fromMap(Map<String, dynamic> map) {
    return FinancialTransactionModel(
      id: map['id'],
      invoiceId: map['invoice_id'],
      paymentId: map['payment_id'],
      returnId: map['return_id'],
      partyId: map['party_id'],
      type: financialTransactionTypeFromDb(map['type'] as String),
      direction: financialTransactionDirectionFromDb(
        map['direction'] as String,
      ),
      amount: map['amount'],
      notes: map['notes'],
      createdAt: map['created_at'],
    );
  }
}

extension FinancialTransactionTypeExtension on FinancialTransactionType {
  String get dbValue => switch (this) {
    FinancialTransactionType.sale => 'SALE',
    FinancialTransactionType.purchase => 'PURCHASE',
    FinancialTransactionType.paymentIn => 'PAYMENT_IN',
    FinancialTransactionType.paymentOut => 'PAYMENT_OUT',
    FinancialTransactionType.saleReturn => 'SALE_RETURN',
    FinancialTransactionType.purchaseReturn => 'PURCHASE_RETURN',
    FinancialTransactionType.refund => 'REFUND',
    FinancialTransactionType.adjustment => 'ADJUSTMENT',
  };
}

extension FinancialTransactionDirectionExtension
    on FinancialTransactionDirection {
  String get dbValue => switch (this) {
    FinancialTransactionDirection.inbound => 'IN',
    FinancialTransactionDirection.outbound => 'OUT',
  };
}

FinancialTransactionType financialTransactionTypeFromDb(String value) =>
    switch (value.toUpperCase()) {
      'SALE' => FinancialTransactionType.sale,
      'PURCHASE' => FinancialTransactionType.purchase,
      'PAYMENT_IN' => FinancialTransactionType.paymentIn,
      'PAYMENT_OUT' => FinancialTransactionType.paymentOut,
      'SALE_RETURN' => FinancialTransactionType.saleReturn,
      'PURCHASE_RETURN' => FinancialTransactionType.purchaseReturn,
      'REFUND' => FinancialTransactionType.refund,
      'ADJUSTMENT' => FinancialTransactionType.adjustment,
      _ => throw Exception('Unknown transaction type: $value'),
    };

FinancialTransactionDirection financialTransactionDirectionFromDb(
  String value,
) => switch (value.toUpperCase()) {
  'IN' => FinancialTransactionDirection.inbound,
  'OUT' => FinancialTransactionDirection.outbound,
  _ => throw Exception('Unknown transaction direction: $value'),
};
