// lib/models/return_model.dart

import '../core/utils/unit_conversion.dart';

enum ReturnType {
  saleReturn,
  purchaseReturn;

  String get label => switch (this) {
    ReturnType.saleReturn     => 'مرتجع مبيعات',
    ReturnType.purchaseReturn => 'مرتجع مشتريات',
  };

  String get inventoryType => switch (this) {
    ReturnType.saleReturn     => 'SALE_RETURN',
    ReturnType.purchaseReturn => 'PURCHASE_RETURN',
  };

  // ← للحفظ في قاعدة البيانات يطابق الـ CHECK constraint
  String get dbValue => switch (this) {
    ReturnType.saleReturn     => 'SALE_RETURN',
    ReturnType.purchaseReturn => 'PURCHASE_RETURN',
  };

  // ← للقراءة من قاعدة البيانات
  static ReturnType fromDb(String value) => switch (value.toUpperCase()) {
    'SALE_RETURN'     => ReturnType.saleReturn,
    'PURCHASE_RETURN' => ReturnType.purchaseReturn,
    _ => throw Exception('Unknown return type: $value'),
  };
}

class ReturnModel {
  final int? id;
  final String returnNumber;       // RTN-0001
  final int originalInvoiceId;
  final ReturnType type;
  final int partyId;
  final String partyNameSnapshot;
  final String partyAddressSnapshot;
  final int totalAmount;
  final String? notes;
  final String? createdAt;

  ReturnModel({
    this.id,
    required this.returnNumber,
    required this.originalInvoiceId,
    required this.type,
    required this.partyId,
    required this.partyNameSnapshot,
    required this.partyAddressSnapshot,
    required this.totalAmount,
    this.notes,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'return_number': returnNumber,
    'original_invoice_id': originalInvoiceId,
    'type': type.dbValue,          // ← SALE_RETURN / PURCHASE_RETURN
    'party_id': partyId,
    'party_name_snapshot': partyNameSnapshot,
    'party_address_snapshot': partyAddressSnapshot,
    'total_amount': totalAmount,
    'notes': notes,
    'created_at': createdAt,
  };

  factory ReturnModel.fromMap(Map<String, dynamic> map) => ReturnModel(
    id: map['id'],
    returnNumber: map['return_number'],
    originalInvoiceId: map['original_invoice_id'],
    type: ReturnType.fromDb(map['type']),  // ← يقرأ SALE_RETURN
    partyId: map['party_id'],
    partyNameSnapshot: map['party_name_snapshot'],
    partyAddressSnapshot: map['party_address_snapshot'],
    totalAmount: map['total_amount'],
    notes: map['notes'],
    createdAt: map['created_at'],
  );
}

/// بند مرتجع — يخزّن معلومات الوحدة ومعامل التحويل والكمية الأساسية أيضاً.
/// - [quantity] الكمية كما أدخلها المستخدم بوحدة الإرجاع (Display Quantity)
/// - [unitId]/[unitName] وحدة الإرجاع التي اختارها المستخدم
/// - [conversionFactor] معامل تحويل وحدة الإرجاع إلى الوحدة الأساسية
/// - [baseQuantity] الكمية المكافئة بالوحدة الأساسية (= quantity × conversionFactor)
/// - [unitPrice] سعر الوحدة الأساسية الواحدة بالسنتم (يُشتق من سعر بند الفاتورة)
/// - [lineTotal] القيمة المالية = baseQuantity × unitPrice
class ReturnItemModel {
  final int? id;
  final int returnId;
  final int productId;
  final int? batchId;
  final String productNameSnapshot;
  final double quantity;
  final int? unitId;
  final String? unitName;
  final double conversionFactor;
  final double baseQuantity;
  final int unitPrice;
  final int lineTotal;

  ReturnItemModel({
    this.id,
    required this.returnId,
    required this.productId,
    this.batchId,
    required this.productNameSnapshot,
    required this.quantity,
    this.unitId,
    this.unitName,
    this.conversionFactor = 1,
    this.baseQuantity = 0,
    required this.unitPrice,
    required this.lineTotal,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'return_id': returnId,
    'product_id': productId,
    'batch_id': batchId,
    'product_name_snapshot': productNameSnapshot,
    'quantity': quantity,
    'unit_id': unitId,
    'unit_name_snapshot': unitName,
    'conversion_factor_snapshot': conversionFactor,
    'base_quantity': baseQuantity,
    'unit_price': unitPrice,
    'line_total': lineTotal,
  };

  factory ReturnItemModel.fromMap(Map<String, dynamic> map) => ReturnItemModel(
    id: map['id'],
    returnId: map['return_id'],
    productId: map['product_id'],
    batchId: map['batch_id'],
    productNameSnapshot: map['product_name_snapshot'],
    quantity: (map['quantity'] as num).toDouble(),
    unitId: map['unit_id'] as int?,
    unitName: map['unit_name_snapshot'] as String?,
    conversionFactor:
        (map['conversion_factor_snapshot'] as num?)?.toDouble() ?? 1,
    baseQuantity: (map['base_quantity'] as num?)?.toDouble() ??
        ((map['quantity'] as num).toDouble() *
            ((map['conversion_factor_snapshot'] as num?)?.toDouble() ?? 1)),
    unitPrice: map['unit_price'],
    lineTotal: map['line_total'],
  );
}

// ==============================
// كائنات مساعدة
// ==============================

/// سطر فاتورة مع معلومات الكمية المتاحة للإرجاع بوحدة أساسية موحّدة.
///
/// مرجع البيانات:
/// - الكمية الأصلية بوحدة الفاتورة: [originalQuantity]
/// - معامل وحدة الفاتورة: [invoiceConversionFactor]
/// - الكمية الأصلية بالوحدة الأساسية: [originalBaseQuantity]
/// - ما أُرجع مسبقاً بالوحدة الأساسية: [returnedBaseQuantity]
/// - المتبقي بالوحدة الأساسية: [remainingBaseQuantity]
class ReturnableItem {
  final int invoiceItemId;
  final int productId;
  final int? batchId;
  final String productName;

  final double originalQuantity;       // كمية الفاتورة بوحدة البيع/الشراء
  final double invoiceConversionFactor; // معامل وحدة الفاتورة
  final int? invoiceUnitId;
  final String? invoiceUnitName;

  final int unitPrice;                 // سعر وحدة الفاتورة (per display unit)
  final double returnedBaseQuantity;   // أُرجع مسبقاً بالوحدة الأساسية
  final String? baseUnitName;          // اسم الوحدة الأساسية للعرض

  /// الكمية المتاحة فعلياً من هذا المنتج في مستودع الفاتورة
  /// بالوحدة الأساسية (محسوبة من inventory_transactions).
  final double stockAvailable;

  // وحدة الإرجاع المختارة (افتراضياً = وحدة الفاتورة)
  int? selectedUnitId;
  String? selectedUnitName;
  double selectedUnitConversionFactor;
  double selectedQuantity;             // كمية مرتجعة بوحدة الإرجاع المختارة

  ReturnableItem({
    required this.invoiceItemId,
    required this.productId,
    this.batchId,
    required this.productName,
    required this.originalQuantity,
    required this.invoiceConversionFactor,
    this.invoiceUnitId,
    this.invoiceUnitName,
    required this.unitPrice,
    this.returnedBaseQuantity = 0,
    this.baseUnitName,
    this.stockAvailable = double.infinity,
    this.selectedUnitId,
    this.selectedUnitName,
    this.selectedUnitConversionFactor = 1,
    this.selectedQuantity = 0,
  });

  /// الكمية الأصلية بالوحدة الأساسية
  double get originalBaseQuantity =>
      UnitConversion.toBaseQuantity(originalQuantity, invoiceConversionFactor);

  /// المتبقي القابل للإرجاع بالوحدة الأساسية (مبنياً على الفاتورة فقط)
  double get remainingBaseQuantity => originalBaseQuantity - returnedBaseQuantity;

  /// الحد الفعلي القابل للإرجاع حسب نوع المرتجع:
  /// - مرتجع مبيعات: البضاعة تُعاد إلى المخزون، فلا يُقصّ إلا على باقي الفاتورة.
  /// - مرتجع مشتريات: تُسحب البضاعة من المخزون (وقد بيع بعضها بعد الشراء)،
  ///   فيجب ألا يتجاوز الكمية المتاحة فعلياً في مستودع الفاتورة.
  double remainingForType(ReturnType type) {
    if (type != ReturnType.purchaseReturn) return remainingBaseQuantity;
    return remainingBaseQuantity < stockAvailable
        ? remainingBaseQuantity
        : stockAvailable;
  }

  /// الكمية المرتجعة المختارة بالوحدة الأساسية
  double get selectedBaseQuantity =>
      UnitConversion.toBaseQuantity(selectedQuantity, selectedUnitConversionFactor);

  /// يحوّل كمية بالوحدة الأساسية إلى المكافئ بوحدة الإرجاع المختارة
  double remainingInUnit(double baseQuantity) =>
      selectedUnitConversionFactor <= 0
          ? baseQuantity
          : baseQuantity / selectedUnitConversionFactor;

  /// سعر الوحدة الأساسية الواحدة (double — غير مقرّب، للدقة)
  double get pricePerBase =>
      UnitConversion.pricePerBaseUnit(unitPrice, invoiceConversionFactor);

  /// قيمة بند المرتجع = الكمية الأساسية × سعر الوحدة الأساسية
  /// نُبقي الدقة قبل التقريب (لا toInt على كمية عشرية).
  int get lineTotal => (selectedBaseQuantity * pricePerBase).round();

  /// نسخة جديدة مع تحديث وحدة/كمية الإرجاع المختارة فقط.
  ReturnableItem copyWith({
    double? selectedQuantity,
    int? selectedUnitId,
    String? selectedUnitName,
    double? selectedUnitConversionFactor,
  }) {
    return ReturnableItem(
      invoiceItemId: invoiceItemId,
      productId: productId,
      batchId: batchId,
      productName: productName,
      originalQuantity: originalQuantity,
      invoiceConversionFactor: invoiceConversionFactor,
      invoiceUnitId: invoiceUnitId,
      invoiceUnitName: invoiceUnitName,
      unitPrice: unitPrice,
      returnedBaseQuantity: returnedBaseQuantity,
      baseUnitName: baseUnitName,
      stockAvailable: stockAvailable,
      selectedUnitId: selectedUnitId ?? this.selectedUnitId,
      selectedUnitName: selectedUnitName ?? this.selectedUnitName,
      selectedUnitConversionFactor:
          selectedUnitConversionFactor ?? this.selectedUnitConversionFactor,
      selectedQuantity: selectedQuantity ?? this.selectedQuantity,
    );
  }
}

/// مرتجع كامل مع أسطره
class ReturnWithItems {
  final ReturnModel returnModel;
  final List<ReturnItemModel> items;

  ReturnWithItems({required this.returnModel, required this.items});
}