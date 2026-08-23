/// وحدة بيع/شراء لمنتج معين، مثل: قطعة، باكيت، كرتون.
///
/// كل منتج له وحدة أساسية واحدة (is_base_unit = true) بمعامل تحويل = 1،
/// وهي الوحدة التي يُحسب بها المخزون فعلياً (inventory_transactions.quantity
/// دائماً بالوحدة الأساسية). أي وحدة أخرى (باكيت، كرتون) تحمل معامل تحويل
/// يوضح كم قطعة أساسية بداخلها، ليتم تحويل الكمية عند البيع/الشراء.
class ProductUnitModel {
  final int? id;
  final int productId;
  final String unitName;
  final double conversionFactor;
  final int salePrice;
  final int? costPrice;
  final bool isBaseUnit;
  final bool isActive;
  final String? createdAt;

  ProductUnitModel({
    this.id,
    required this.productId,
    required this.unitName,
    required this.conversionFactor,
    required this.salePrice,
    this.costPrice,
    this.isBaseUnit = false,
    this.isActive = true,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'unit_name': unitName,
      'conversion_factor': conversionFactor,
      'sale_price': salePrice,
      'cost_price': costPrice,
      'is_base_unit': isBaseUnit ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory ProductUnitModel.fromMap(Map<String, dynamic> map) {
    return ProductUnitModel(
      id: map['id'],
      productId: map['product_id'],
      unitName: map['unit_name'],
      conversionFactor: (map['conversion_factor'] as num).toDouble(),
      salePrice: map['sale_price'],
      costPrice: map['cost_price'],
      isBaseUnit: (map['is_base_unit'] as int? ?? 0) == 1,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'],
    );
  }

  /// يحوّل كمية بهذه الوحدة إلى الكمية المكافئة بالوحدة الأساسية
  double toBaseQuantity(double quantityInThisUnit) =>
      quantityInThisUnit * conversionFactor;

  ProductUnitModel copyWith({
    int? id,
    int? productId,
    String? unitName,
    double? conversionFactor,
    int? salePrice,
    int? costPrice,
    bool? isBaseUnit,
    bool? isActive,
    String? createdAt,
  }) {
    return ProductUnitModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      unitName: unitName ?? this.unitName,
      conversionFactor: conversionFactor ?? this.conversionFactor,
      salePrice: salePrice ?? this.salePrice,
      costPrice: costPrice ?? this.costPrice,
      isBaseUnit: isBaseUnit ?? this.isBaseUnit,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
