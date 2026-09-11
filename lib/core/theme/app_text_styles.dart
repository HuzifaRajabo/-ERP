import 'package:flutter/material.dart';

/// مقياس الخطوط الموحد لأنظمة ERP.
///
/// القاعدة:
/// - [TextTheme] يُبنى من ألوان الـ ColorScheme الحالية (works in light/dark).
/// - لا تُستخدم قيم fontSize داخل الشاشات؛ بل تُستخدم هذه المستويات.
abstract final class AppTextStyles {
  /// يبني [TextTheme] متوافقًا مع الوضع الحالي.
  ///
  /// [onSurface] لون النص الأساسي، [muted] لون الأنصبة الثانوية/الخافتة.
  static TextTheme textTheme({
    Color onSurface = Colors.black,
    Color muted = Colors.grey,
  }) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: onSurface,
        height: 1.2,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: onSurface,
        height: 1.2,
      ),
      headlineLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: onSurface,
        height: 1.25,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: onSurface,
        height: 1.3,
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: onSurface,
        height: 1.3,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: onSurface,
        height: 1.35,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onSurface,
        height: 1.4,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onSurface,
        height: 1.4,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: onSurface,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: onSurface,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: muted,
        height: 1.45,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onSurface,
        height: 1.3,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: onSurface,
        height: 1.3,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: muted,
        height: 1.3,
      ),
    );
  }

  /// أرقام KPI الكبيرة في لوحة التحكم والتقارير.
  static TextStyle kpi({Color color = Colors.black}) => TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.2,
      );

  /// المبالغ الرئيسية في الفواتير والتقارير.
  static TextStyle amount({Color color = Colors.black}) => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.3,
      );

  /// المبالغ الثانوية / أرقام الجداول.
  static TextStyle amountSmall({Color color = Colors.black}) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.3,
      );
}