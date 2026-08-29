import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';

/// أدوات واجهة مشتركة صغيرة لشاشات إدارة المستودعات.
class AppUi {
  AppUi._();

  static void showError(String message) {
    Get.snackbar(
      'خطأ',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Get.theme.colorScheme.error,
      colorText: Get.theme.colorScheme.onError,
      borderRadius: 12,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 3),
    );
  }

  static void showSuccess(String message) {
    Get.snackbar(
      'تم بنجاح',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.success,
      colorText: Colors.white,
      borderRadius: 12,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 3),
    );
  }

  static InputDecoration inputDecoration({
    required String label,
    IconData? icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon) : null,
    );
  }
}
