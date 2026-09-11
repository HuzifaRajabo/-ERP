class CompanyProfileModel {
  final int? id;
  final String name;
  final String tradeName;
  final String address;
  final String serviceArea;
  final String phone;
  final String description;
  final String? createdAt;
  final String? updatedAt;

  const CompanyProfileModel({
    this.id,
    this.name = '',
    this.tradeName = '',
    this.address = '',
    this.serviceArea = '',
    this.phone = '',
    this.description = '',
    this.createdAt,
    this.updatedAt,
  });

  factory CompanyProfileModel.empty() => const CompanyProfileModel();

  factory CompanyProfileModel.fromMap(Map<String, dynamic> map) {
    return CompanyProfileModel(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      tradeName: (map['trade_name'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
      serviceArea: (map['service_area'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'trade_name': tradeName,
      'address': address,
      'service_area': serviceArea,
      'phone': phone,
      'description': description,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  /// أسطر ترويسة المستندات: الاسم، الاسم التجاري، العنوان، الهاتف.
  /// الحقول الفارغة تُحذف. serviceArea و description لا يُعرضان هنا.
  List<String> get headerLines {
    final lines = <String>[];
    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) lines.add(trimmedName);
    final trimmedTrade = tradeName.trim();
    if (trimmedTrade.isNotEmpty) lines.add(trimmedTrade);
    final trimmedAddress = address.trim();
    if (trimmedAddress.isNotEmpty) lines.add(trimmedAddress);
    final trimmedPhone = phone.trim();
    if (trimmedPhone.isNotEmpty) lines.add(trimmedPhone);
    return lines;
  }

  bool get hasIdentity => name.trim().isNotEmpty;

  CompanyProfileModel copyWith({
    int? id,
    String? name,
    String? tradeName,
    String? address,
    String? serviceArea,
    String? phone,
    String? description,
    String? createdAt,
    String? updatedAt,
  }) {
    return CompanyProfileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      tradeName: tradeName ?? this.tradeName,
      address: address ?? this.address,
      serviceArea: serviceArea ?? this.serviceArea,
      phone: phone ?? this.phone,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
