import 'package:get/get.dart';

import '../core/config/activity_profiles.dart';
import '../core/config/feature_rules.dart';
import '../core/services/app_event_bus.dart';
import '../models/business_config.dart';
import '../repositories/business_settings_repository.dart';

bool featureEnabled(AppFeature feature) {
  if (!Get.isRegistered<FeatureController>()) return true;
  return Get.find<FeatureController>().isEnabled(feature);
}

class FeatureController extends GetxController {
  FeatureController(this.repo);

  final BusinessSettingsRepository repo;

  final Rx<BusinessSettings> settings = ActivityProfiles.settingsFor(
    BusinessActivity.foodDistributor,
  ).obs;

  final RxBool loading = false.obs;
  final RxnString error = RxnString();

  bool isEnabled(AppFeature feature) => settings.value.isEnabled(feature);

  SalesMode get salesMode => settings.value.salesMode;

  BusinessActivity get activity => settings.value.activity;

  NotificationConfig get notifications => settings.value.notifications;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = true;
    try {
      settings.value = await repo.load();
      error.value = null;
    } catch (e) {
      error.value = 'تعذر تحميل إعدادات المنشأة';
    } finally {
      loading.value = false;
    }
  }

  Future<String?> setFeature(AppFeature feature, bool enabled) async {
    final result = FeatureRules.apply(
      activity: settings.value.activity,
      current: settings.value.features,
      feature: feature,
      enabled: enabled,
    );
    if (!result.ok || result.features == null) {
      return result.error ?? 'تعذر حفظ الإعداد';
    }
    final next = settings.value.copyWith(features: result.features);
    await repo.save(next);
    settings.value = next;
    AppEventBus.instance.notifyInventoryChanged();
    return null;
  }

  Future<void> applyActivity(BusinessActivity activity) async {
    final next = ActivityProfiles.settingsFor(activity);
    await repo.save(next);
    settings.value = next;
    AppEventBus.instance.notifyInventoryChanged();
  }

  Future<void> setNotifications(NotificationConfig config) async {
    final next = settings.value.copyWith(notifications: config);
    await repo.save(next);
    settings.value = next;
    AppEventBus.instance.notifyInventoryChanged();
  }
}
