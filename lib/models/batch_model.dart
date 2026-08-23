class BatchModel {
  final int? id;
  final int productId;
  final String? batchNumber;
  final String? productionDate; // ISO date string 'YYYY-MM-DD'
  final String? expiryDate; // ISO date string 'YYYY-MM-DD'
  final int? costPrice;
  final String? notes;
  final String? createdAt;

  BatchModel({
    this.id,
    required this.productId,
    this.batchNumber,
    this.productionDate,
    this.expiryDate,
    this.costPrice,
    this.notes,
    this.createdAt,
  });

  /// أيام متبقية حتى انتهاء الصلاحية. سالب يعني منتهي الصلاحية بالفعل.
  /// null إذا لم يُحدَّد تاريخ صلاحية لهذا المنتج (مثل منتجات غير غذائية).
  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    final expiry = DateTime.tryParse(expiryDate!);
    if (expiry == null) return null;
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    return expiry.difference(todayDateOnly).inDays;
  }

  bool get isExpired {
    final days = daysUntilExpiry;
    return days != null && days < 0;
  }

  bool get isExpiringSoon {
    final days = daysUntilExpiry;
    return days != null && days <= 30 && days >= 0;
  }

  String get expiryStatus {
    final days = daysUntilExpiry;
    if (days == null) return 'غير محدد';
    if (days < 0) return 'منتهي';
    if (days <= 30) return 'قريب الانتهاء';
    return 'صالح';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'batch_number': batchNumber,
      'production_date': productionDate,
      'expiry_date': expiryDate,
      'cost_price': costPrice,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory BatchModel.fromMap(Map<String, dynamic> map) {
    return BatchModel(
      id: map['id'],
      productId: map['product_id'],
      batchNumber: map['batch_number'],
      productionDate: map['production_date'],
      expiryDate: map['expiry_date'],
      costPrice: map['cost_price'],
      notes: map['notes'],
      createdAt: map['created_at'],
    );
  }
}
