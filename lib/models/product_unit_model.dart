/// وحدة بيع/شراء لمنتج معين، مثل: قطعة، باكيت، كرتون، طرد، شوال.
///
/// القواعد الأساسية:
/// - لكل منتج وحدة أساسية واحدة (isBaseUnit=true) بـ conversionFactor=1
/// - الكمية في inventory_transactions دائماً بالوحدة الأساسية
/// - كل وحدة أخرى تُحوَّل: quantity × conversionFactor = baseQuantity
/// - canBuy / canSell مستقلان — الوحدة يمكن أن تكون للشراء فقط أو البيع فقط
/// - isDefaultSellUnit: وحدة بيع افتراضية واحدة فقط لكل منتج، ويجب أن canSell=true
class ProductUnitModel {
  final int? id;
  final int productId;

  final String unitName;

  /// عدد الوحدات الأساسية بداخل هذه الوحدة.
  /// مثال: كرتون=30، طرد=360، قطعة=1
  final double conversionFactor;

  /// سعر التكلفة لهذه الوحدة (null = غير محدد)
  final int? costPrice;

  /// سعر البيع الافتراضي لهذه الوحدة
  final int defaultSalePrice;

  /// هل يمكن استخدام هذه الوحدة في فواتير الشراء؟
  final bool canBuy;

  /// هل يمكن استخدام هذه الوحدة في فواتير البيع؟
  final bool canSell;

  /// وحدة البيع الافتراضية التي تُختار تلقائياً عند إنشاء فاتورة بيع
  final bool isDefaultSellUnit;

  /// الوحدة الأساسية (conversionFactor=1) — أساس حسابات المخزون
  final bool isBaseUnit;

  /// soft delete — الوحدات المستخدمة في تاريخ الفواتير لا تُحذف
  final bool isActive;

  final String? createdAt;
  final String? updatedAt;

  ProductUnitModel({
    this.id,
    required this.productId,
    required this.unitName,
    required this.conversionFactor,
    this.costPrice,
    required this.defaultSalePrice,
    this.canBuy = true,
    this.canSell = true,
    this.isDefaultSellUnit = false,
    this.isBaseUnit = false,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'unit_name': unitName,
      'conversion_factor': conversionFactor,
      'cost_price': costPrice,
      'default_sale_price': defaultSalePrice,
      'can_buy': canBuy ? 1 : 0,
      'can_sell': canSell ? 1 : 0,
      'is_default_sell_unit': isDefaultSellUnit ? 1 : 0,
      'is_base_unit': isBaseUnit ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory ProductUnitModel.fromMap(Map<String, dynamic> map) {
    return ProductUnitModel(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      unitName: map['unit_name'] as String,
      conversionFactor: (map['conversion_factor'] as num).toDouble(),
      costPrice: map['cost_price'] as int?,
      defaultSalePrice: (map['default_sale_price'] ?? map['sale_price'] ?? 0) as int,
      canBuy: (map['can_buy'] as int? ?? 1) == 1,
      canSell: (map['can_sell'] as int? ?? 1) == 1,
      isDefaultSellUnit: (map['is_default_sell_unit'] as int? ?? 0) == 1,
      isBaseUnit: (map['is_base_unit'] as int? ?? 0) == 1,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  /// يحوّل كمية بهذه الوحدة إلى الكمية المكافئة بالوحدة الأساسية
  double toBaseQuantity(double quantityInThisUnit) =>
      quantityInThisUnit * conversionFactor;

  // ── للتوافق مع الكود القديم الذي يستخدم salePrice ──
  int get salePrice => defaultSalePrice;

  ProductUnitModel copyWith({
    int? id,
    int? productId,
    String? unitName,
    double? conversionFactor,
    int? costPrice,
    int? defaultSalePrice,
    bool? canBuy,
    bool? canSell,
    bool? isDefaultSellUnit,
    bool? isBaseUnit,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return ProductUnitModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      unitName: unitName ?? this.unitName,
      conversionFactor: conversionFactor ?? this.conversionFactor,
      costPrice: costPrice ?? this.costPrice,
      defaultSalePrice: defaultSalePrice ?? this.defaultSalePrice,
      canBuy: canBuy ?? this.canBuy,
      canSell: canSell ?? this.canSell,
      isDefaultSellUnit: isDefaultSellUnit ?? this.isDefaultSellUnit,
      isBaseUnit: isBaseUnit ?? this.isBaseUnit,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'ProductUnitModel(id=$id, product=$productId, name=$unitName, '
      'factor=$conversionFactor, sell=$defaultSalePrice, '
      'base=$isBaseUnit, defaultSell=$isDefaultSellUnit)';
}
