import '../../models/business_config.dart';
import 'activity_profiles.dart';

class FeatureToggleResult {
  const FeatureToggleResult._({
    required this.ok,
    this.error,
    this.features,
  });

  final bool ok;
  final String? error;
  final Map<AppFeature, bool>? features;

  factory FeatureToggleResult.blocked(String error) =>
      FeatureToggleResult._(ok: false, error: error);

  factory FeatureToggleResult.applied(Map<AppFeature, bool> features) =>
      FeatureToggleResult._(ok: true, features: features);
}

abstract final class FeatureRules {
  static FeatureToggleResult apply({
    required BusinessActivity activity,
    required Map<AppFeature, bool> current,
    required AppFeature feature,
    required bool enabled,
  }) {
    if (!ActivityProfiles.isApplicable(feature, activity) && enabled) {
      return FeatureToggleResult.blocked(
        'هذه الميزة غير متاحة لنشاط المنشأة الحالي',
      );
    }

    final next = Map<AppFeature, bool>.from(current);

    if (enabled) {
      if (feature == AppFeature.multipleWarehouses ||
          feature == AppFeature.vehicles) {
        next[AppFeature.warehouses] = true;
      }
      if (feature == AppFeature.expiry) {
        next[AppFeature.batches] = true;
      }
      if (feature == AppFeature.returnablePackaging) {
        next[AppFeature.productUnits] = true;
      }
      next[feature] = true;
    } else {
      if (feature == AppFeature.warehouses) {
        if (current[AppFeature.vehicles] == true) {
          return FeatureToggleResult.blocked(
            'لا يمكن تعطيل المستودعات لأن المركبات مفعلة. عطّل المركبات أولاً.',
          );
        }
        if (current[AppFeature.multipleWarehouses] == true) {
          return FeatureToggleResult.blocked(
            'لا يمكن تعطيل المستودعات لأن تعدد المستودعات مفعّل. عطّل تعدد المستودعات أولاً.',
          );
        }
      }
      if (feature == AppFeature.batches && current[AppFeature.expiry] == true) {
        return FeatureToggleResult.blocked(
          'لا يمكن تعطيل الدفعات لأن الصلاحية مفعلة. عطّل الصلاحية أولاً.',
        );
      }
      if (feature == AppFeature.productUnits &&
          current[AppFeature.returnablePackaging] == true) {
        return FeatureToggleResult.blocked(
          'لا يمكن تعطيل الوحدات لأن العبوات القابلة للإرجاع مفعلة. عطّل العبوات أولاً.',
        );
      }
      if (feature == AppFeature.wholesale && current[AppFeature.retail] != true) {
        return FeatureToggleResult.blocked(
          'يجب الإبقاء على نوع بيع واحد على الأقل (جملة أو مفرق).',
        );
      }
      if (feature == AppFeature.retail && current[AppFeature.wholesale] != true) {
        return FeatureToggleResult.blocked(
          'يجب الإبقاء على نوع بيع واحد على الأقل (جملة أو مفرق).',
        );
      }
      next[feature] = false;
    }

    if (next[AppFeature.wholesale] != true && next[AppFeature.retail] != true) {
      return FeatureToggleResult.blocked(
        'يجب الإبقاء على نوع بيع واحد على الأقل (جملة أو مفرق).',
      );
    }

    return FeatureToggleResult.applied(next);
  }
}
