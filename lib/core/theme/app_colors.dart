import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF2563EB);
  static const primaryDark = Color(0xFF1D4ED8);
  static const secondary = Color(0xFF475569);

  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF1F5F9);

  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textMuted = Color(0xFF64748B);

  static const border = Color(0xFFE2E8F0);
  static const divider = Color(0xFFE2E8F0);

  static const success = Color(0xFF15803D);
  static const warning = Color(0xFFB45309);
  static const error = Color(0xFFB91C1C);
  static const info = Color(0xFF0369A1);

  static const profit = success;
  static const loss = error;
  static const receivable = info;
  static const payable = warning;
}
