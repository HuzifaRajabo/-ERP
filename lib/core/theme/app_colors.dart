import 'package:flutter/material.dart';

/// ألوان الثيم العامة (Light Mode).
///
/// هذه القيم تُستخدم كجذور (seeds) لبناء الـ ColorScheme في [AppTheme.light].
/// لا يجب استخدامها مباشرة داخل الشاشات، بل عبر
/// `Theme.of(context).colorScheme` أو `context.semantic`.
abstract final class AppColors {
  // ===== Brand =====
  static const primary = Color(0xFF2563EB);
  static const primaryDark = Color(0xFF1D4ED8);
  static const secondary = Color(0xFF475569);
  static const tertiary = Color(0xFF0369A1);

  // ===== Surfaces (light) =====
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF1F5F9);

  // ===== Text (light) =====
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textMuted = Color(0xFF64748B);

  // ===== Borders (light) =====
  static const border = Color(0xFFE2E8F0);
  static const divider = Color(0xFFE2E8F0);

  // ===== Semantic (light) =====
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const error = Color(0xFFDC2626);
  static const info = Color(0xFF0284C7);

  // ===== Aliases (light) =====
  static const profit = success;
  static const loss = error;
  static const receivable = info;
  static const payable = warning;
}

/// ألوان الوضع الداكن.
///
/// أسطح داكنة مريحة (ليست أسود نقي)، مع نصوص فاتحة وتباين جيد.
abstract final class AppColorsDark {
  // ===== Brand =====
  static const primary = Color(0xFF93B4FF);
  static const primaryDark = Color(0xFF1D4ED8);
  static const secondary = Color(0xFFB0BEC9);
  static const tertiary = Color(0xFF7CC4E8);

  // ===== Surfaces (dark) =====
  static const background = Color(0xFF0B1220);
  static const surface = Color(0xFF111A2E);
  static const surfaceMuted = Color(0xFF16213A);

  // ===== Text (dark) =====
  static const textPrimary = Color(0xFFE6EDF6);
  static const textSecondary = Color(0xFF9FB0C6);
  static const textMuted = Color(0xFF7C8DA6);

  // ===== Borders (dark) =====
  static const border = Color(0xFF24334B);
  static const divider = Color(0xFF1E2C42);

  // ===== Semantic (dark) =====
  static const success = Color(0xFF4ADE80);
  static const warning = Color(0xFFFBBF24);
  static const error = Color(0xFFF87171);
  static const info = Color(0xFF38BDF8);
}