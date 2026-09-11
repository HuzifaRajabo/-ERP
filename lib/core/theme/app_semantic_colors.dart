import 'package:flutter/material.dart';

import 'app_colors.dart';

/// ألوان ERP الدلالية (Semantic) — قابلة للتكيف بين الوضع الفاتح والداكن.
///
/// تُستخدم عبر `Theme.of(context).extension<AppSemanticColors>()`
/// أو الاختصار `context.semantic`.
///
/// القواعد الموحدة لتوظيف الألوان:
/// - [success] / [profit] = إيجابي / مكسب / مدفوع / متوفر / زيادة
/// - [error]   / [loss]   = سلبي / خسارة / غير مدفوع / نفد / نقص
/// - [warning] = تحذير / منخفض / متأخر
/// - [info]    = معلومات / مستحق لنا
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.profit,
    required this.loss,
    required this.stockIn,
    required this.stockLow,
    required this.stockOut,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;

  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  final Color profit;
  final Color loss;
  final Color stockIn;
  final Color stockLow;
  final Color stockOut;

  static const light = AppSemanticColors(
    success: AppColors.success,
    onSuccess: Colors.white,
    successContainer: Color(0xFFDCFCE7),
    onSuccessContainer: Color(0xFF14532D),
    warning: AppColors.warning,
    onWarning: Colors.white,
    warningContainer: Color(0xFFFEF3C7),
    onWarningContainer: Color(0xFF78350F),
    error: AppColors.error,
    onError: Colors.white,
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF7F1D1D),
    info: AppColors.info,
    onInfo: Colors.white,
    infoContainer: Color(0xFFE0F2FE),
    onInfoContainer: Color(0xFF0C4A6E),
    profit: AppColors.success,
    loss: AppColors.error,
    stockIn: AppColors.success,
    stockLow: AppColors.warning,
    stockOut: AppColors.error,
  );

  static const dark = AppSemanticColors(
    success: AppColorsDark.success,
    onSuccess: Color(0xFF052E16),
    successContainer: Color(0xFF14532D),
    onSuccessContainer: Color(0xFFBBF7D0),
    warning: AppColorsDark.warning,
    onWarning: Color(0xFF451A03),
    warningContainer: Color(0xFF78350F),
    onWarningContainer: Color(0xFFFDE68A),
    error: AppColorsDark.error,
    onError: Color(0xFF420E0E),
    errorContainer: Color(0xFF5F1A1A),
    onErrorContainer: Color(0xFFFECACA),
    info: AppColorsDark.info,
    onInfo: Color(0xFF082F49),
    infoContainer: Color(0xFF0C4A6E),
    onInfoContainer: Color(0xFFBAE6FD),
    profit: AppColorsDark.success,
    loss: AppColorsDark.error,
    stockIn: AppColorsDark.success,
    stockLow: AppColorsDark.warning,
    stockOut: AppColorsDark.error,
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? error,
    Color? onError,
    Color? errorContainer,
    Color? onErrorContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? profit,
    Color? loss,
    Color? stockIn,
    Color? stockLow,
    Color? stockOut,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      errorContainer: errorContainer ?? this.errorContainer,
      onErrorContainer: onErrorContainer ?? this.onErrorContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      profit: profit ?? this.profit,
      loss: loss ?? this.loss,
      stockIn: stockIn ?? this.stockIn,
      stockLow: stockLow ?? this.stockLow,
      stockOut: stockOut ?? this.stockOut,
    );
  }

  @override
  AppSemanticColors lerp(
    covariant AppSemanticColors? other,
    double t,
  ) {
    if (other == null) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer:
          Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer:
          Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      error: Color.lerp(error, other.error, t)!,
      onError: Color.lerp(onError, other.onError, t)!,
      errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
      onErrorContainer:
          Color.lerp(onErrorContainer, other.onErrorContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer:
          Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      profit: Color.lerp(profit, other.profit, t)!,
      loss: Color.lerp(loss, other.loss, t)!,
      stockIn: Color.lerp(stockIn, other.stockIn, t)!,
      stockLow: Color.lerp(stockLow, other.stockLow, t)!,
      stockOut: Color.lerp(stockOut, other.stockOut, t)!,
    );
  }
}

/// اختصار للوصول إلى ألوان الـ ERP الدلالية من أي Widget.
extension AppSemanticColorsX on BuildContext {
  AppSemanticColors get semantic =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light;
}