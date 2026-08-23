class WarehouseModel {
  final int? id;
  final String name;
  final WarehouseType type;
  final String? address;
  final bool isDefault;
  final bool isActive;
  final String? createdAt;

  WarehouseModel({
    this.id,
    required this.name,
    required this.type,
    this.address,
    this.isDefault = false,
    this.isActive = true,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.dbValue,
      'address': address,
      'is_default': isDefault ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory WarehouseModel.fromMap(Map<String, dynamic> map) {
    return WarehouseModel(
      id: map['id'],
      name: map['name'],
      type: WarehouseType.fromDb(map['type']),
      address: map['address'],
      isDefault: (map['is_default'] as int? ?? 0) == 1,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'],
    );
  }

  WarehouseModel copyWith({
    int? id,
    String? name,
    WarehouseType? type,
    String? address,
    bool? isDefault,
    bool? isActive,
    String? createdAt,
  }) {
    return WarehouseModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      address: address ?? this.address,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

enum WarehouseType {
  main,
  van,
  branch;

  String get label => switch (this) {
    WarehouseType.main => 'مستودع رئيسي',
    WarehouseType.van => 'سيارة توزيع',
    WarehouseType.branch => 'فرع',
  };

  String get dbValue => switch (this) {
    WarehouseType.main => 'MAIN',
    WarehouseType.van => 'VAN',
    WarehouseType.branch => 'BRANCH',
  };

  static WarehouseType fromDb(String value) => switch (value.toUpperCase()) {
    'MAIN' => WarehouseType.main,
    'VAN' => WarehouseType.van,
    'BRANCH' => WarehouseType.branch,
    _ => throw Exception('Unknown warehouse type: $value'),
  };
}
