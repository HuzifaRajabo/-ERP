// lib/core/utils/unit_conversion.dart
//
// تحويل موحّد بين وحدات البيع/الشراء (Display Unit) والوحدة الأساسية (Base Unit).
// القاعدة الأساسية: المخزون والحسابات الكمية تُخزَّن دائماً بالوحدة الأساسية.
//   baseQuantity = quantity × conversionFactor
//
// المصدر الوحيد لمعامل التحويل يجب أن يكون تعريف الوحدة في product_units
// أو لقطة conversion_factor_snapshot في سطر الفاتورة، وليس اسم الوحدة.

class UnitConversion {
  UnitConversion._();

  /// يحوّل كمية بوحدة معيّنة إلى المكافئ بالوحدة الأساسية.
  static double toBaseQuantity(double quantity, double conversionFactor) =>
      quantity * conversionFactor;

  /// السعر بالسنتم لكل وحدة أساسية واحدة، آخذاً سعر الوحدة الكاملة (per unit)
  /// ومعامل تحويلها.
  ///
  /// مثال: سعر الطرد 120 سنتم و 1 طرد = 12 كرتونة
  ///   → سعر الكرتونة الواحدة = 120 / 12 = 10 سنتم
  static double pricePerBaseUnit(int pricePerSoldUnit, double conversionFactor) {
    if (conversionFactor <= 0) return pricePerSoldUnit.toDouble();
    return pricePerSoldUnit / conversionFactor;
  }

  /// قيمة مالية بند ما: الكمية بالوحدة الأساسية × سعر الوحدة الأساسية.
  /// نحافظ على دقة الكسر قبل التقريب (لا نستخدم toInt() على كمية عشرية).
  static int lineTotal(int pricePerBaseUnit, double baseQuantity) =>
      (baseQuantity * pricePerBaseUnit).round();

  /// قيمة مالية محسوبة مباشرة من كمية الوحدة المختارة وسعرها ومعاملها —
  /// تُستخدم لتجنّب أي فرق دقيق عند تغيّر وحدة الإرجاع.
  static int lineTotalFromSold(
    double quantity,
    int pricePerSoldUnit,
    double conversionFactor,
  ) =>
      (toBaseQuantity(quantity, conversionFactor) *
              pricePerUnit(pricePerSoldUnit, conversionFactor))
          .round();

  /// سعر الوحدة الأساسية (أقرب عدد صحيح سنتم) — للعرض فقط،
  /// لكن الحساب الفعلي يستخدم الدالة double غير المقرّبة.
  static int pricePerUnit(int pricePerSoldUnit, double conversionFactor) =>
      pricePerBaseUnit(pricePerSoldUnit, conversionFactor).round();
}
