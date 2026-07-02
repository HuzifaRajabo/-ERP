class ProductModel {
  final int? id;
  final String name;
  final String sku;
  final int costPrice;
  final int salePrice;
  final String? createdAt;

  ProductModel({
    this.id,
    required this.name,
    required this.sku,
    required this.costPrice,
    required this.salePrice,
    this.createdAt,
});

  Map<String, dynamic> toMap(){
    return{
      'id':id,
      'name':name,
      'sku':sku,
      'cost_price':costPrice,
      'sale_price':salePrice,
      'created_at':createdAt,
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'],
      name: map['name'],
      sku: map['sku'],
      costPrice: map['cost_price'],
      salePrice: map['sale_price'],
      createdAt: map['created_at'],
    );
  }

}