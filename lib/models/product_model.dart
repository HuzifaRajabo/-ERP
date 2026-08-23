class ProductModel {
  final int? id;
  final String name;
  final String description;
  final int costPrice;
  final int salePrice;
  final int? categoryId;
  final String? categoryName; // ← مجلوب بـ JOIN من product_categories (للعرض فقط)
  final String? createdAt;

  ProductModel({
    this.id,
    required this.name,
    required this.description,
    required this.costPrice,
    required this.salePrice,
    this.categoryId,
    this.categoryName,
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
      createdAt: map['created_at'],
    );
  }
}