import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/feature_controller.dart';
import '../../core/config/activity_profiles.dart';
import '../../core/theme/app_dimensions.dart';
import '../../models/business_config.dart';
import '../shared/app_ui.dart';
import '../shared/shared_components.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<FeatureController>();
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: Obx(() {
        final settings = controller.settings.value;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _SectionCard(
              title: 'المنشأة',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.apartment_outlined),
                title: const Text('معلومات المنشأة'),
                subtitle: const Text('الاسم والعنوان ورقم الهاتف'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Get.toNamed('/company-profile'),
              ),
            ),
            _SectionCard(
              title: 'نشاط المنشأة',
              child: Column(
                children: [
                  for (final activity in BusinessActivity.values)
                    RadioListTile<BusinessActivity>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(activity.label),
                      value: activity,
                      groupValue: settings.activity,
                      onChanged: (value) {
                        if (value == null) return;
                        _changeActivity(context, controller, value);
                      },
                    ),
                ],
              ),
            ),
            _SectionCard(
              title: 'المبيعات',
              child: Column(
                children: [
                  _FeatureSwitch(
                    controller: controller,
                    feature: AppFeature.wholesale,
                    settings: settings,
                  ),
                  _FeatureSwitch(
                    controller: controller,
                    feature: AppFeature.retail,
                    settings: settings,
                  ),
                ],
              ),
            ),
            _SectionCard(
              title: 'المخزون',
              child: Column(
                children: [
                  _FeatureSwitch(
                    controller: controller,
                    feature: AppFeature.productUnits,
                    settings: settings,
                  ),
                  _FeatureSwitch(
                    controller: controller,
                    feature: AppFeature.warehouses,
                    settings: settings,
                  ),
                  if (settings.isEnabled(AppFeature.warehouses))
                    _FeatureSwitch(
                      controller: controller,
                      feature: AppFeature.multipleWarehouses,
                      settings: settings,
                    ),
                  if (ActivityProfiles.isApplicable(
                    AppFeature.vehicles,
                    settings.activity,
                  ))
                    _FeatureSwitch(
                      controller: controller,
                      feature: AppFeature.vehicles,
                      settings: settings,
                    ),
                  _FeatureSwitch(
                    controller: controller,
                    feature: AppFeature.batches,
                    settings: settings,
                  ),
                  _FeatureSwitch(
                    controller: controller,
                    feature: AppFeature.expiry,
                    settings: settings,
                  ),
                ],
              ),
            ),
            _SectionCard(
              title: 'العبوات',
              child: _FeatureSwitch(
                controller: controller,
                feature: AppFeature.returnablePackaging,
                settings: settings,
              ),
            ),
            _SectionCard(
              title: 'الديون',
              child: _FeatureSwitch(
                controller: controller,
                feature: AppFeature.debts,
                settings: settings,
              ),
            ),
            _SectionCard(
              title: 'المصروفات',
              child: _FeatureSwitch(
                controller: controller,
                feature: AppFeature.expenses,
                settings: settings,
              ),
            ),
            _SectionCard(
              title: 'الهدر',
              child: _FeatureSwitch(
                controller: controller,
                feature: AppFeature.waste,
                settings: settings,
              ),
            ),
            _NotificationSettingsCard(controller: controller, settings: settings),
          ],
        );
      }),
    );
  }

  Future<void> _changeActivity(
    BuildContext context,
    FeatureController controller,
    BusinessActivity activity,
  ) async {
    if (activity == controller.activity) return;
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'تغيير نشاط المنشأة',
      message:
          'سيتم تحميل الإعدادات الافتراضية لنشاط «${activity.label}». '
          'لن تُحذف البيانات التاريخية، وقد تتغير الواجهة والميزات الظاهرة.',
      confirmLabel: 'متابعة',
    );
    if (confirmed != true) return;
    await controller.applyActivity(activity);
    AppUi.showSuccess('تم تحديث نشاط المنشأة');
  }
}

class _FeatureSwitch extends StatelessWidget {
  const _FeatureSwitch({
    required this.controller,
    required this.feature,
    required this.settings,
  });

  final FeatureController controller;
  final AppFeature feature;
  final BusinessSettings settings;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(feature.label),
      value: settings.isEnabled(feature),
      onChanged: (enabled) => _toggle(context, enabled),
    );
  }

  Future<void> _toggle(BuildContext context, bool enabled) async {
    if (!enabled && feature == AppFeature.debts) {
      final unpaid = await controller.countUnpaidInvoices();
      if (unpaid > 0) {
        if (!context.mounted) return;
        final confirmed = await AppConfirmDialog.show(
          context,
          title: 'تعطيل إدارة الديون',
          message:
              'يوجد $unpaid فاتورة ذات رصيد متبقي. تعطيل الديون يخفي الشاشات '
              'ولا يحذف البيانات. هل تريد المتابعة؟',
          confirmLabel: 'تعطيل',
          isDestructive: true,
        );
        if (confirmed != true) return;
      }
    }
    final error = await controller.setFeature(feature, enabled);
    if (error != null) {
      AppUi.showError(error);
    }
  }
}

class _NotificationSettingsCard extends StatelessWidget {
  const _NotificationSettingsCard({
    required this.controller,
    required this.settings,
  });

  final FeatureController controller;
  final BusinessSettings settings;

  @override
  Widget build(BuildContext context) {
    final n = settings.notifications;
    return _SectionCard(
      title: 'الإشعارات',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(NotificationPref.lowStock.label),
            value: n.lowStock,
            onChanged: (v) =>
                controller.setNotifications(n.copyWith(lowStock: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(NotificationPref.outOfStock.label),
            value: n.outOfStock,
            onChanged: (v) =>
                controller.setNotifications(n.copyWith(outOfStock: v)),
          ),
          if (settings.isEnabled(AppFeature.expiry)) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(NotificationPref.expiry.label),
              value: n.expiry,
              onChanged: (v) =>
                  controller.setNotifications(n.copyWith(expiry: v)),
            ),
            if (n.expiry)
              _AlertPeriodEditor(
                key: const ValueKey('expiry-period'),
                title: 'التنبيه قبل انتهاء الصلاحية بـ',
                hint: 'يُرسل الإشعار عندما تقترب الصلاحية من هذه المدة',
                value: n.expiryWarning,
                onChanged: (period) => controller.setNotifications(
                  n.copyWith(expiryWarning: period),
                ),
              ),
          ],
          if (settings.isEnabled(AppFeature.debts)) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(NotificationPref.debtDue.label),
              value: n.debtDue,
              onChanged: (v) =>
                  controller.setNotifications(n.copyWith(debtDue: v)),
            ),
            if (n.debtDue)
              _AlertPeriodEditor(
                key: const ValueKey('debt-due-period'),
                title: 'أرسل تنبيهاً إذا تجاوز عمر الفاتورة غير المسددة',
                hint: 'يُحسب من تاريخ الفاتورة',
                value: n.debtDuePeriod,
                onChanged: (period) => controller.setNotifications(
                  n.copyWith(debtDuePeriod: period),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(NotificationPref.debtOverdue.label),
              value: n.debtOverdue,
              onChanged: (v) =>
                  controller.setNotifications(n.copyWith(debtOverdue: v)),
            ),
            if (n.debtOverdue)
              _AlertPeriodEditor(
                key: const ValueKey('debt-overdue-period'),
                title: 'أرسل تنبيهاً إذا تجاوز الدين هذه المدة',
                hint: 'يُحسب من تاريخ الفاتورة غير المسددة',
                value: n.debtOverduePeriod,
                onChanged: (period) => controller.setNotifications(
                  n.copyWith(debtOverduePeriod: period),
                ),
              ),
          ],
          if (settings.isEnabled(AppFeature.returnablePackaging)) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(NotificationPref.packagingUnsettled.label),
              value: n.packagingUnsettled,
              onChanged: (v) => controller.setNotifications(
                n.copyWith(packagingUnsettled: v),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(NotificationPref.packagingOverdue.label),
              value: n.packagingOverdue,
              onChanged: (v) => controller.setNotifications(
                n.copyWith(packagingOverdue: v),
              ),
            ),
            if (n.packagingOverdue)
              _AlertPeriodEditor(
                key: const ValueKey('packaging-overdue-period'),
                title: 'أرسل تنبيهاً إذا تجاوزت العبوات غير المسوّاة هذه المدة',
                hint: 'يُحسب من أقدم تسليم غير مسوّى',
                value: n.packagingOverduePeriod,
                onChanged: (period) => controller.setNotifications(
                  n.copyWith(packagingOverduePeriod: period),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AlertPeriodEditor extends StatefulWidget {
  const _AlertPeriodEditor({
    super.key,
    required this.title,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String hint;
  final AlertPeriod value;
  final ValueChanged<AlertPeriod> onChanged;

  @override
  State<_AlertPeriodEditor> createState() => _AlertPeriodEditorState();
}

class _AlertPeriodEditorState extends State<_AlertPeriodEditor> {
  late final TextEditingController _amountCtrl;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: '${widget.value.amount}');
  }

  @override
  void didUpdateWidget(covariant _AlertPeriodEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value.amount != widget.value.amount &&
        _amountCtrl.text != '${widget.value.amount}') {
      _amountCtrl.text = '${widget.value.amount}';
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _commitAmount(String raw) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null || parsed < 1) return;
    widget.onChanged(widget.value.copyWith(amount: parsed));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              SizedBox(
                width: 88,
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                  ),
                  onChanged: _commitAmount,
                  onSubmitted: _commitAmount,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final unit in AlertPeriodUnit.values)
                      ChoiceChip(
                        label: Text(unit.label),
                        selected: widget.value.unit == unit,
                        onSelected: (_) => widget.onChanged(
                          widget.value.copyWith(unit: unit),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.hint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}
