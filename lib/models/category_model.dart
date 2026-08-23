class CategoryModel {
  final int? id;
  final String name;
  final bool isPreset;   // true = صنف جاهز مدمج في التطبيق (لا يُحذف)
  final bool isActive;
  final String? createdAt;

  CategoryModel({
    this.id,
    required this.name,
    this.isPreset = false,
    this.isActive = true,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_preset': isPreset ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'],
      name: map['name'],
      isPreset: (map['is_preset'] as int? ?? 0) == 1,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'],
    );
  }

  CategoryModel copyWith({
    int? id,
    String? name,
    bool? isPreset,
    bool? isActive,
    String? createdAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isPreset: isPreset ?? this.isPreset,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// الأصناف الجاهزة المدمجة — تُدرج تلقائياً عند أول تثبيت/ترقية
  static const List<String> presetNames = [
    'شيبس',
    'سناكات',
    'مشروبات غازية',
    'عصائر',
    'مياه',
    'حلويات وشوكولاتة',
    'بسكويت وكيك',
    'مكسرات',
  ];
}
