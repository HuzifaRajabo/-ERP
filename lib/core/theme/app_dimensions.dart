/// نظام المسافات الموحد.
///
/// القاعدة: استخدم هذه الثوابت بدل الأرقام العشوائية في الشاشات.
/// القيم المعتمدة: 4 / 8 / 12 / 16 / 20 / 24 / 32 / 40
abstract final class AppSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const huge = 40.0;
}

/// نظام الحواف الموحد.
///
/// - [small]  : الأشياء الصغيرة (تاغ / chip / أزرار صغيرة)
/// - [medium] : الحقول والأزرار
/// - [card]   : البطاقات
/// - [large]  : الحوارات والنوافذ السفلية
/// - [xlarge] : الأوراق والمكونات الأكبر
abstract final class AppRadius {
  static const small = 8.0;
  static const medium = 10.0;
  static const card = 12.0;
  static const large = 16.0;
  static const xlarge = 20.0;
}

/// أبعاد العناصر الأساسية.
abstract final class AppSizes {
  static const buttonHeight = 48.0;
  static const buttonHeightSmall = 40.0;
  static const inputHeight = 48.0;
  static const iconButton = 40.0;
  static const listTileCompact = 44.0;
  static const dividerThickness = 1.0;
}