import '../../models/product_unit_model.dart';

/// خطأ في التحقق من وحدات المنتج
class ProductUnitValidationException implements Exception {
  final String message;
  const ProductUnitValidationException(this.message);

  @override
  String toString() => message;
}

/// يحقق من صحة مجموعة وحدات المنتج قبل الحفظ.
/// يُستدعى من ProductController.saveProduct() وأيضاً من أي مسار حفظ آخر.
class ProductUnitValidator {
  /// يرمي [ProductUnitValidationException] إذا وُجدت أي مخالفة.
  static void validate(String productName, List<ProductUnitModel> units) {
    if (productName.trim().isEmpty) {
      throw const ProductUnitValidationException('اسم المنتج مطلوب');
    }

    if (units.isEmpty) {
      throw const ProductUnitValidationException(
        'يجب إضافة وحدة أساسية واحدة على الأقل',
      );
    }

    // ── تحقق من الوحدة الأساسية ──
    final baseUnits = units.where((u) => u.isBaseUnit).toList();
    if (baseUnits.isEmpty) {
      throw const ProductUnitValidationException(
        'يجب تحديد وحدة أساسية واحدة للمنتج',
      );
    }
    if (baseUnits.length > 1) {
      throw const ProductUnitValidationException(
        'لا يمكن وجود أكثر من وحدة أساسية واحدة لنفس المنتج',
      );
    }

    final base = baseUnits.first;
    if (base.conversionFactor != 1.0) {
      throw const ProductUnitValidationException(
        'معامل التحويل للوحدة الأساسية يجب أن يكون 1',
      );
    }

    // ── تحقق من معاملات التحويل ──
    for (final u in units) {
      if (u.conversionFactor <= 0) {
        throw ProductUnitValidationException(
          'معامل التحويل للوحدة "${u.unitName}" يجب أن يكون أكبر من صفر',
        );
      }
    }

    // ── تحقق من تكرار اسم الوحدة ──
    final names = units.map((u) => u.unitName.trim().toLowerCase()).toList();
    final uniqueNames = names.toSet();
    if (names.length != uniqueNames.length) {
      throw const ProductUnitValidationException(
        'لا يمكن تكرار اسم الوحدة لنفس المنتج',
      );
    }

    // ── تحقق من وحدة البيع الافتراضية ──
    final defaultSellUnits = units.where((u) => u.isDefaultSellUnit).toList();
    if (defaultSellUnits.length > 1) {
      throw const ProductUnitValidationException(
        'لا يمكن وجود أكثر من وحدة بيع افتراضية واحدة',
      );
    }
    if (defaultSellUnits.isNotEmpty && !defaultSellUnits.first.canSell) {
      throw const ProductUnitValidationException(
        'وحدة البيع الافتراضية يجب أن تكون مسموحاً بالبيع بها',
      );
    }

    // ── تحقق من أسعار البيع ──
    for (final u in units) {
      if (u.defaultSalePrice < 0) {
        throw ProductUnitValidationException(
          'سعر بيع الوحدة "${u.unitName}" لا يمكن أن يكون سالباً',
        );
      }
    }
  }
}
