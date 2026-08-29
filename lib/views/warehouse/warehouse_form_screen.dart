import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/warehouse_controller.dart';
import '../../models/warehouse_model.dart';
import '../shared/app_ui.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';

class WarehouseFormScreen extends StatefulWidget {
  const WarehouseFormScreen({super.key});

  @override
  State<WarehouseFormScreen> createState() => _WarehouseFormScreenState();
}

class _WarehouseFormScreenState extends State<WarehouseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  WarehouseModel? _editing;
  WarehouseType _type = WarehouseType.main;
  bool _isDefault = false;

  bool get _isEdit => _editing != null;

  @override
  void initState() {
    super.initState();
    final arg = Get.arguments;
    if (arg is WarehouseModel) {
      _editing = arg;
      _nameCtrl.text = arg.name;
      _addressCtrl.text = arg.address ?? '';
      _type = arg.type;
      _isDefault = arg.isDefault;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = Get.find<WarehouseController>();
    final name = _nameCtrl.text.trim();
    final address = _addressCtrl.text.trim();

    if (_isEdit) {
      await controller.updateWarehouse(
        _editing!.copyWith(
          name: name,
          type: _type,
          address: address.isEmpty ? null : address,
          isDefault: _isDefault,
        ),
      );
    } else {
      await controller.addWarehouse(
        WarehouseModel(
          name: name,
          type: _type,
          address: address.isEmpty ? null : address,
          isDefault: _isDefault,
        ),
      );
    }

    if (controller.state.value == WarehouseLoadState.error) {
      AppUi.showError(controller.errorMessage.value ?? 'حدث خطأ أثناء الحفظ');
      return;
    }

    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'تعديل مستودع' : 'إضافة مستودع'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: AppUi.inputDecoration(
                  label: 'اسم المستودع',
                  icon: Icons.storefront_outlined,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'أدخل اسم المستودع'
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _addressCtrl,
                decoration: AppUi.inputDecoration(
                  label: 'العنوان (اختياري)',
                  icon: Icons.location_on_outlined,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'نوع المستودع',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              _typeSelector(),
              const SizedBox(height: AppSpacing.xl),
              SwitchListTile(
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
                title: const Text('مستودع افتراضي'),
                subtitle: const Text('يُستخدم تلقائياً في الفواتير الجديدة'),
                contentPadding: EdgeInsets.zero,
                activeTrackColor: AppColors.primary,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_isEdit ? 'حفظ التعديلات' : 'إضافة المستودع'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: WarehouseType.values.map((t) {
        final selected = _type == t;
        return ChoiceChip(
          label: Text(t.label),
          selected: selected,
          onSelected: (_) => setState(() => _type = t),
          selectedColor: AppColors.primary,
          side: BorderSide(
            color: selected
                ? AppColors.primary
                : Theme.of(context).colorScheme.outline,
          ),
          labelStyle: TextStyle(
            color: selected
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        );
      }).toList(),
    );
  }
}
