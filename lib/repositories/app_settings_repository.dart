import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';

class AppSettingsRepository {
  AppSettingsRepository({Future<Database> Function()? dbProvider})
      : _dbProvider =
            dbProvider ?? (() async => DatabaseHelper.instance.database);

  final Future<Database> Function() _dbProvider;

  static const expiryWarningDaysKey = 'expiry_warning_days';
  static const expiryAlertsEnabledKey = 'expiry_alerts_enabled';
  static const defaultWarningDays = 30;
  static const minPeriodDays = 1;
  static const maxPeriodDays = 730;
  static const allowedWarningDays = [7, 14, 30, 60];

  Future<Database> get _db async => _dbProvider();

  Future<String?> getValue(String key) async {
    final db = await _db;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setValue(String key, String value) async {
    final db = await _db;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getExpiryWarningDays() async {
    final raw = await getValue(expiryWarningDaysKey);
    final parsed = int.tryParse(raw ?? '');
    if (parsed != null &&
        parsed >= minPeriodDays &&
        parsed <= maxPeriodDays) {
      return parsed;
    }
    return defaultWarningDays;
  }

  Future<void> setExpiryWarningDays(int days) async {
    final value = days.clamp(minPeriodDays, maxPeriodDays);
    await setValue(expiryWarningDaysKey, '$value');
  }

  Future<bool> isExpiryAlertsEnabled() async {
    final raw = await getValue(expiryAlertsEnabledKey);
    return raw != '0';
  }

  Future<void> setExpiryAlertsEnabled(bool enabled) async {
    await setValue(expiryAlertsEnabledKey, enabled ? '1' : '0');
  }
}
