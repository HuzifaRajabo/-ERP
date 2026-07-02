class ProductPackagingModel {

  final int? id;
  final int productId;
  final Level level;
  final int unitsPerParent;
  final int priceFactor;

  ProductPackagingModel({
    this.id,
    required this.productId,
    required this.level,
    required this.unitsPerParent,
    required this.priceFactor,
});

  Map<String, dynamic> toMap(){
    return{
      'id': id,
      'product_id': productId,
      'level': level.name.toUpperCase(),
      'units_per_parent': unitsPerParent,
      'price_factor': priceFactor,
    };
  }

  factory ProductPackagingModel.forMap(Map<String, dynamic> map){
    return ProductPackagingModel(
      id: map['id'],
      productId: map['product_id'],
      level: Level.values.byName(map['level'].toString().toLowerCase()),
      unitsPerParent: map['units_per_parent'],
      priceFactor: map['price_factor'],
    );

    }

}

enum Level {piece, pack, bundle}