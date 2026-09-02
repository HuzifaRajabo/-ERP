class ProductModel {
  final int? id;
  final String name;
  final String description;
  final int costPrice;
  final int salePrice;
  final int? categoryId;
  final String? categoryName; // ← مجلوب بـ JOIN من product_categories (للعرض فقط)
  final bool isActive; // ← soft delete: 1 = فعال، 0 = موقوف
  final String? createdAt;

  ProductModel({
    this.id,
    required this.name,
    required this.description,
    required this.costPrice,
    required this.salePrice,
    this.categoryId,
    this.categoryName,
    this.isActive = true,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'cost_price': costPrice,
      'sale_price': salePrice,
      'category_id': categoryId,
      'is_active': isActive ? 1 : 0,
      // categoryName لا يُكتب في قاعدة البيانات (مجرد عرض)
      'created_at': createdAt,
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      costPrice: map['cost_price'],
      salePrice: map['sale_price'],
      categoryId: map['category_id'],
      categoryName: map['category_name'], // ← يأتي من JOIN في الريبو
      isActive: (map['is_active'] ?? 1) == 1 ||
          (map['is_active'] is bool && map['is_active'] == true),
      createdAt: map['created_at'],
    );
  }

  ProductModel copyWith({
    int? id,
    String? name,
    String? description,
    int? costPrice,
    int? salePrice,
    int? categoryId,
    String? categoryName,
    bool? isActive,
    String? createdAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      costPrice: costPrice ?? this.costPrice,
      salePrice: salePrice ?? this.salePrice,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}