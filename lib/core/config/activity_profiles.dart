import '../../models/business_config.dart';

abstract final class ActivityProfiles {
  static Map<AppFeature, bool> defaultsFor(BusinessActivity activity) {
    final enabled = <AppFeature>{AppFeature.productUnits};

    void on(AppFeature feature) => enabled.add(feature);

    switch (activity) {
      case BusinessActivity.foodDistributor:
        on(AppFeature.warehouses);
        on(AppFeature.multipleWarehouses);
        on(AppFeature.vehicles);
        on(AppFeature.batches);
        on(AppFeature.expiry);
        on(AppFeature.returnablePackaging);
        on(AppFeature.wholesale);
        on(AppFeature.debts);
        on(AppFeature.expenses);
        on(AppFeature.waste);
      case BusinessActivity.accessoriesDistributor:
        on(AppFeature.warehouses);
        on(AppFeature.multipleWarehouses);
        on(AppFeature.vehicles);
        on(AppFeature.wholesale);
        on(AppFeature.debts);
        on(AppFeature.expenses);
      case BusinessActivity.electronicAccessoriesDistributor:
        on(AppFeature.wholesale);
        on(AppFeature.debts);
        on(AppFeature.expenses);
      case BusinessActivity.phoneTelecomStore:
        on(AppFeature.retail);
        on(AppFeature.debts);
        on(AppFeature.expenses);
      case BusinessActivity.foodWholesaleRetail:
        on(AppFeature.batches);
        on(AppFeature.expiry);
        on(AppFeature.returnablePackaging);
        on(AppFeature.wholesale);
        on(AppFeature.retail);
        on(AppFeature.debts);
        on(AppFeature.expenses);
        on(AppFeature.waste);
      case BusinessActivity.nonFoodWholesaleRetail:
        on(AppFeature.wholesale);
        on(AppFeature.retail);
        on(AppFeature.debts);
        on(AppFeature.expenses);
      case BusinessActivity.distributionCompany:
        on(AppFeature.warehouses);
        on(AppFeature.multipleWarehouses);
        on(AppFeature.vehicles);
        on(AppFeature.wholesale);
        on(AppFeature.debts);
        on(AppFeature.expenses);
        on(AppFeature.waste);
    }

    return {
      for (final feature in AppFeature.values) feature: enabled.contains(feature),
    };
  }

  static bool isApplicable(AppFeature feature, BusinessActivity activity) {
    if (feature == AppFeature.vehicles &&
        activity == BusinessActivity.phoneTelecomStore) {
      return false;
    }
    return true;
  }

  static BusinessSettings settingsFor(BusinessActivity activity) {
    final features = defaultsFor(activity);
    return BusinessSettings(
      activity: activity,
      features: features,
      notifications: NotificationConfig(
        expiry: features[AppFeature.expiry] ?? false,
        packagingUnsettled:
            features[AppFeature.returnablePackaging] ?? false,
        packagingOverdue: features[AppFeature.returnablePackaging] ?? false,
        debtDue: features[AppFeature.debts] ?? false,
        debtOverdue: features[AppFeature.debts] ?? false,
      ),
    );
  }
}
