/// إعداد نشاط المنشأة والميزات. المفاتيح الداخلية إنجليزية والعرض عربي.
enum BusinessActivity {
  foodDistributor('food_distributor'),
  accessoriesDistributor('accessories_distributor'),
  electronicAccessoriesDistributor('electronic_accessories_distributor'),
  phoneTelecomStore('phone_telecom_store'),
  foodWholesaleRetail('food_wholesale_retail'),
  nonFoodWholesaleRetail('non_food_wholesale_retail'),
  distributionCompany('distribution_company');

  const BusinessActivity(this.key);
  final String key;

  String get label => switch (this) {
        BusinessActivity.foodDistributor => 'موزع غذائيات',
        BusinessActivity.accessoriesDistributor => 'موزع اكسسوارات',
        BusinessActivity.electronicAccessoriesDistributor =>
          'موزع اكسسوارات إلكترونية',
        BusinessActivity.phoneTelecomStore => 'متجر هواتف واكسسوارات',
        BusinessActivity.foodWholesaleRetail => 'متجر بيع جملة ومفرق غذائي',
        BusinessActivity.nonFoodWholesaleRetail =>
          'متجر بيع جملة ومفرق غير غذائي',
        BusinessActivity.distributionCompany => 'شركة توزيع',
      };

  static BusinessActivity fromKey(String? raw) {
    for (final item in BusinessActivity.values) {
      if (item.key == raw) return item;
    }
    return BusinessActivity.foodDistributor;
  }
}

enum SalesMode {
  wholesale('wholesale'),
  retail('retail'),
  wholesaleAndRetail('wholesale_and_retail'),
  distribution('distribution');

  const SalesMode(this.key);
  final String key;

  String get label => switch (this) {
        SalesMode.wholesale => 'جملة',
        SalesMode.retail => 'مفرق',
        SalesMode.wholesaleAndRetail => 'جملة ومفرق',
        SalesMode.distribution => 'توزيع',
      };

  static SalesMode fromFeatures({
    required bool wholesale,
    required bool retail,
    required BusinessActivity activity,
  }) {
    if (wholesale && retail) return SalesMode.wholesaleAndRetail;
    if (retail) return SalesMode.retail;
    if (activity == BusinessActivity.foodDistributor ||
        activity == BusinessActivity.accessoriesDistributor ||
        activity == BusinessActivity.electronicAccessoriesDistributor ||
        activity == BusinessActivity.distributionCompany) {
      return SalesMode.distribution;
    }
    return SalesMode.wholesale;
  }
}

enum AppFeature {
  productUnits('product_units', 'الوحدات'),
  warehouses('warehouses', 'المستودعات'),
  multipleWarehouses('multiple_warehouses', 'تعدد المستودعات'),
  vehicles('vehicles', 'المركبات'),
  batches('batches', 'الدفعات'),
  expiry('expiry', 'الصلاحية'),
  returnablePackaging('returnable_packaging', 'العبوات القابلة للإرجاع'),
  wholesale('wholesale', 'البيع بالجملة'),
  retail('retail', 'البيع بالمفرق'),
  debts('debts', 'الديون'),
  expenses('expenses', 'المصروفات'),
  waste('waste', 'الهدر');

  const AppFeature(this.key, this.label);
  final String key;
  final String label;

  static AppFeature? fromKey(String raw) {
    for (final item in AppFeature.values) {
      if (item.key == raw) return item;
    }
    return null;
  }
}

enum NotificationPref {
  lowStock('notify.low_stock', 'انخفاض المخزون'),
  outOfStock('notify.out_of_stock', 'نفاد المخزون'),
  expiry('expiry_alerts_enabled', 'تنبيهات انتهاء الصلاحية'),
  debtDue('notify.debt_due', 'دين مستحق'),
  debtOverdue('notify.debt_overdue', 'دين متأخر'),
  packagingUnsettled('notify.packaging_unsettled', 'عبوات غير مسوّاة'),
  packagingOverdue('notify.packaging_overdue', 'عبوات متأخرة التسوية');

  const NotificationPref(this.key, this.label);
  final String key;
  final String label;
}

enum AlertPeriodUnit {
  week('week'),
  month('month');

  const AlertPeriodUnit(this.key);
  final String key;

  String get label => switch (this) {
        AlertPeriodUnit.week => 'أسبوع',
        AlertPeriodUnit.month => 'شهر',
      };

  int toDays(int amount) => switch (this) {
        AlertPeriodUnit.week => amount * 7,
        AlertPeriodUnit.month => amount * 30,
      };

  static AlertPeriodUnit fromKey(String? raw) {
    if (raw == AlertPeriodUnit.month.key) return AlertPeriodUnit.month;
    return AlertPeriodUnit.week;
  }
}

class AlertPeriod {
  const AlertPeriod({
    this.amount = 1,
    this.unit = AlertPeriodUnit.week,
  });

  final int amount;
  final AlertPeriodUnit unit;

  int get days => unit.toDays(amount.clamp(1, 99));

  AlertPeriod copyWith({int? amount, AlertPeriodUnit? unit}) {
    return AlertPeriod(
      amount: (amount ?? this.amount).clamp(1, 99),
      unit: unit ?? this.unit,
    );
  }

  static AlertPeriod fromStored({required int days, String? unitKey}) {
    if (unitKey != null && unitKey.isNotEmpty) {
      final unit = AlertPeriodUnit.fromKey(unitKey);
      final divisor = unit == AlertPeriodUnit.month ? 30 : 7;
      final amount = (days / divisor).round().clamp(1, 99);
      return AlertPeriod(amount: amount, unit: unit);
    }
    return inferFromDays(days);
  }

  static AlertPeriod inferFromDays(int days) {
    final safe = days < 1 ? 1 : days;
    if (safe >= 30 && safe % 30 == 0) {
      return AlertPeriod(
        amount: (safe ~/ 30).clamp(1, 99),
        unit: AlertPeriodUnit.month,
      );
    }
    if (safe % 7 == 0) {
      return AlertPeriod(
        amount: (safe ~/ 7).clamp(1, 99),
        unit: AlertPeriodUnit.week,
      );
    }
    if (safe >= 25) {
      return AlertPeriod(
        amount: (safe / 30).round().clamp(1, 99),
        unit: AlertPeriodUnit.month,
      );
    }
    return AlertPeriod(
      amount: (safe / 7).round().clamp(1, 99),
      unit: AlertPeriodUnit.week,
    );
  }
}

class NotificationConfig {
  const NotificationConfig({
    this.lowStock = true,
    this.outOfStock = true,
    this.expiry = true,
    this.expiryWarning = const AlertPeriod(amount: 1, unit: AlertPeriodUnit.month),
    this.debtDue = true,
    this.debtOverdue = true,
    this.debtDuePeriod = const AlertPeriod(amount: 1, unit: AlertPeriodUnit.week),
    this.debtOverduePeriod =
        const AlertPeriod(amount: 1, unit: AlertPeriodUnit.month),
    this.packagingUnsettled = true,
    this.packagingOverdue = true,
    this.packagingOverduePeriod =
        const AlertPeriod(amount: 1, unit: AlertPeriodUnit.month),
  });

  final bool lowStock;
  final bool outOfStock;
  final bool expiry;
  final AlertPeriod expiryWarning;
  final bool debtDue;
  final bool debtOverdue;
  final AlertPeriod debtDuePeriod;
  final AlertPeriod debtOverduePeriod;
  final bool packagingUnsettled;
  final bool packagingOverdue;
  final AlertPeriod packagingOverduePeriod;

  int get expiryWarningDays => expiryWarning.days;
  int get debtDueDays => debtDuePeriod.days;
  int get debtOverdueDays => debtOverduePeriod.days;
  int get packagingOverdueDays => packagingOverduePeriod.days;

  NotificationConfig copyWith({
    bool? lowStock,
    bool? outOfStock,
    bool? expiry,
    AlertPeriod? expiryWarning,
    bool? debtDue,
    bool? debtOverdue,
    AlertPeriod? debtDuePeriod,
    AlertPeriod? debtOverduePeriod,
    bool? packagingUnsettled,
    bool? packagingOverdue,
    AlertPeriod? packagingOverduePeriod,
  }) {
    return NotificationConfig(
      lowStock: lowStock ?? this.lowStock,
      outOfStock: outOfStock ?? this.outOfStock,
      expiry: expiry ?? this.expiry,
      expiryWarning: expiryWarning ?? this.expiryWarning,
      debtDue: debtDue ?? this.debtDue,
      debtOverdue: debtOverdue ?? this.debtOverdue,
      debtDuePeriod: debtDuePeriod ?? this.debtDuePeriod,
      debtOverduePeriod: debtOverduePeriod ?? this.debtOverduePeriod,
      packagingUnsettled: packagingUnsettled ?? this.packagingUnsettled,
      packagingOverdue: packagingOverdue ?? this.packagingOverdue,
      packagingOverduePeriod:
          packagingOverduePeriod ?? this.packagingOverduePeriod,
    );
  }
}

class BusinessSettings {
  const BusinessSettings({
    required this.activity,
    required this.features,
    required this.notifications,
  });

  final BusinessActivity activity;
  final Map<AppFeature, bool> features;
  final NotificationConfig notifications;

  bool isEnabled(AppFeature feature) => features[feature] ?? false;

  SalesMode get salesMode => SalesMode.fromFeatures(
        wholesale: isEnabled(AppFeature.wholesale),
        retail: isEnabled(AppFeature.retail),
        activity: activity,
      );

  BusinessSettings copyWith({
    BusinessActivity? activity,
    Map<AppFeature, bool>? features,
    NotificationConfig? notifications,
  }) {
    return BusinessSettings(
      activity: activity ?? this.activity,
      features: features ?? Map<AppFeature, bool>.from(this.features),
      notifications: notifications ?? this.notifications,
    );
  }
}
