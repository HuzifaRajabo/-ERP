import 'package:sqflite/sqflite.dart';

import '../core/config/activity_profiles.dart';
import '../models/business_config.dart';
import 'app_settings_repository.dart';

class BusinessSettingsRepository {
  BusinessSettingsRepository({
    AppSettingsRepository? settings,
    Future<Database> Function()? dbProvider,
  }) : _settings = settings ??
            AppSettingsRepository(dbProvider: dbProvider);

  final AppSettingsRepository _settings;

  static const activityKey = 'business_activity';
  static const featurePrefix = 'feature.';
  static const debtDueDaysKey = 'notify.debt_due_days';
  static const debtOverdueDaysKey = 'notify.debt_overdue_days';
  static const packagingOverdueDaysKey = 'notify.packaging_overdue_days';
  static const expiryWarningUnitKey = 'notify.expiry_warning_unit';
  static const debtDueUnitKey = 'notify.debt_due_unit';
  static const debtOverdueUnitKey = 'notify.debt_overdue_unit';
  static const packagingOverdueUnitKey = 'notify.packaging_overdue_unit';

  static String featureKey(AppFeature feature) => '$featurePrefix${feature.key}';

  Future<BusinessSettings> load() async {
    final activity = BusinessActivity.fromKey(
      await _settings.getValue(activityKey),
    );
    final features = <AppFeature, bool>{};
    for (final feature in AppFeature.values) {
      final raw = await _settings.getValue(featureKey(feature));
      if (raw == null) {
        features[feature] =
            ActivityProfiles.defaultsFor(activity)[feature] ?? false;
      } else {
        features[feature] = raw != '0';
      }
    }

    final defaults = ActivityProfiles.settingsFor(activity).notifications;
    Future<bool> flag(NotificationPref pref, bool fallback) async {
      final raw = await _settings.getValue(pref.key);
      if (raw == null) return fallback;
      return raw != '0';
    }

    Future<int> days(String key, int fallback) async {
      final raw = await _settings.getValue(key);
      return int.tryParse(raw ?? '') ?? fallback;
    }

    Future<AlertPeriod> period({
      required int daysValue,
      required String unitKey,
    }) async {
      final unitRaw = await _settings.getValue(unitKey);
      if (unitRaw == null || unitRaw.isEmpty) {
        return AlertPeriod.inferFromDays(daysValue);
      }
      return AlertPeriod.fromStored(days: daysValue, unitKey: unitRaw);
    }

    final expiryDays = await _settings.getExpiryWarningDays();
    final debtDueDays = await days(debtDueDaysKey, defaults.debtDueDays);
    final debtOverdueDays =
        await days(debtOverdueDaysKey, defaults.debtOverdueDays);
    final packagingOverdueDays = await days(
      packagingOverdueDaysKey,
      defaults.packagingOverdueDays,
    );

    final notifications = NotificationConfig(
      lowStock: await flag(NotificationPref.lowStock, defaults.lowStock),
      outOfStock: await flag(NotificationPref.outOfStock, defaults.outOfStock),
      expiry: await flag(NotificationPref.expiry, defaults.expiry),
      expiryWarning: await period(
        daysValue: expiryDays,
        unitKey: expiryWarningUnitKey,
      ),
      debtDue: await flag(NotificationPref.debtDue, defaults.debtDue),
      debtOverdue: await flag(NotificationPref.debtOverdue, defaults.debtOverdue),
      debtDuePeriod: await period(
        daysValue: debtDueDays,
        unitKey: debtDueUnitKey,
      ),
      debtOverduePeriod: await period(
        daysValue: debtOverdueDays,
        unitKey: debtOverdueUnitKey,
      ),
      packagingUnsettled: await flag(
        NotificationPref.packagingUnsettled,
        defaults.packagingUnsettled,
      ),
      packagingOverdue: await flag(
        NotificationPref.packagingOverdue,
        defaults.packagingOverdue,
      ),
      packagingOverduePeriod: await period(
        daysValue: packagingOverdueDays,
        unitKey: packagingOverdueUnitKey,
      ),
    );

    return BusinessSettings(
      activity: activity,
      features: features,
      notifications: notifications,
    );
  }

  Future<void> save(BusinessSettings settings) async {
    await _settings.setValue(activityKey, settings.activity.key);
    for (final feature in AppFeature.values) {
      final enabled = settings.features[feature] ?? false;
      await _settings.setValue(featureKey(feature), enabled ? '1' : '0');
    }
    final n = settings.notifications;
    await _settings.setValue(
      NotificationPref.lowStock.key,
      n.lowStock ? '1' : '0',
    );
    await _settings.setValue(
      NotificationPref.outOfStock.key,
      n.outOfStock ? '1' : '0',
    );
    await _settings.setExpiryAlertsEnabled(n.expiry);
    await _settings.setExpiryWarningDays(n.expiryWarningDays);
    await _settings.setValue(expiryWarningUnitKey, n.expiryWarning.unit.key);
    await _settings.setValue(
      NotificationPref.debtDue.key,
      n.debtDue ? '1' : '0',
    );
    await _settings.setValue(
      NotificationPref.debtOverdue.key,
      n.debtOverdue ? '1' : '0',
    );
    await _settings.setValue(debtDueDaysKey, '${n.debtDueDays}');
    await _settings.setValue(debtDueUnitKey, n.debtDuePeriod.unit.key);
    await _settings.setValue(debtOverdueDaysKey, '${n.debtOverdueDays}');
    await _settings.setValue(debtOverdueUnitKey, n.debtOverduePeriod.unit.key);
    await _settings.setValue(
      NotificationPref.packagingUnsettled.key,
      n.packagingUnsettled ? '1' : '0',
    );
    await _settings.setValue(
      NotificationPref.packagingOverdue.key,
      n.packagingOverdue ? '1' : '0',
    );
    await _settings.setValue(
      packagingOverdueDaysKey,
      '${n.packagingOverdueDays}',
    );
    await _settings.setValue(
      packagingOverdueUnitKey,
      n.packagingOverduePeriod.unit.key,
    );
  }
}
