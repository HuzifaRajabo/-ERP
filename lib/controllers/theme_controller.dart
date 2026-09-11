import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../repositories/app_settings_repository.dart';

/// مسؤول عن ظاهرة (Theme Mode):
/// - قراءة الوضع المحفوظ عند تشغيل التطبيق
/// - تغيير الوضع preserving لحظيًا
/// - حفظ الاختيار عبر [AppSettingsRepository]
///
/// لا يتعامل مع قاعدة البيانات مباشرة — يُفوّض الحفظ للـ Repository.
class ThemeController extends GetxController {
  ThemeController(this._settingsRepository);

  final AppSettingsRepository _settingsRepository;

  final Rx<ThemeMode> _themeMode = ThemeMode.system.obs;

  ThemeMode get themeMode => _themeMode.value;

  /// يُستدعى قبل `runApp` لاستعادة الوضع المحفوظ
  /// وتجنّب وميض White→Dark.
  Future<void> load() async {
    final saved = await _settingsRepository.getThemeMode();
    _themeMode.value = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode.value == mode) return;
    _themeMode.value = mode;
    await _settingsRepository.setThemeMode(switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }
}

/// اختصار داخل Widgets: إذا كان الـ Controller مسجلًا استخدمه وإلا system.
extension ThemeModeX on ThemeMode {
  bool get isDark => this == ThemeMode.dark;
}