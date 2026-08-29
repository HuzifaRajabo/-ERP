import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/party_controller.dart';
import '../../models/party_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';

class PartyFormScreen extends GetView<PartyController> {
  const PartyFormScreen({super.key});

  bool get isEditing => Get.arguments != null;
  PartyModel? get party => Get.arguments as PartyModel?;

  @override
  Widget build(BuildContext context) {
    final nameController = TextEditingController(text: party?.name);
    final phoneController = TextEditingController(text: party?.phone);
    final addressController = TextEditingController(text: party?.address);
    final selectedType = (party?.type ?? PartyType.customer).obs;
    final formKey = GlobalKey<FormState>();

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'تعديل طرف' : 'إضافة طرف')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==============================
              // Name
              // ==============================
              TextFormField(
                controller: nameController,
                validator: (v) => v!.trim().isEmpty ? 'مطلوب' : null,
                decoration: InputDecoration(
                  labelText: 'الاسم',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ==============================
              // Phone
              // ==============================
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'رقم الهاتف (اختياري)',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              //==============================
              //address
              //==============================
              TextFormField(
                controller: addressController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'العنوان (اختياري)',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ==============================
              // Type Selector
              // ==============================
              Text('نوع الطرف', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              Obx(
                () => Row(
                  children: [
                    _TypeOption(
                      label: 'عميل',
                      icon: Icons.person_outline,
                      color: AppColors.primary,
                      selected: selectedType.value == PartyType.customer,
                      onTap: () => selectedType.value = PartyType.customer,
                    ),
                    const SizedBox(width: 8),
                    _TypeOption(
                      label: 'مورد',
                      icon: Icons.local_shipping_outlined,
                      color: AppColors.warning,
                      selected: selectedType.value == PartyType.supplier,
                      onTap: () => selectedType.value = PartyType.supplier,
                    ),
                    const SizedBox(width: 8),
                    _TypeOption(
                      label: 'كلاهما',
                      icon: Icons.people_outline,
                      color: AppColors.secondary,
                      selected: selectedType.value == PartyType.both,
                      onTap: () => selectedType.value = PartyType.both,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // ==============================
              // Submit
              // ==============================
              Obx(
                () => SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: controller.isLoading
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;

                            final newParty = PartyModel(
                              id: party?.id,
                              name: nameController.text.trim(),
                              phone: phoneController.text.trim().isEmpty
                                  ? null
                                  : phoneController.text.trim(),
                              address: addressController.text.trim().isEmpty
                                  ? null
                                  : addressController.text.trim(),
                              type: selectedType.value,
                            );

                            if (isEditing) {
                              await controller.updateParty(newParty);
                            } else {
                              await controller.addParty(newParty);
                            }

                            if (!controller.hasError) Get.back();
                          },
                    icon: controller.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(isEditing ? Icons.save : Icons.add),
                    label: Text(isEditing ? 'حفظ التعديلات' : 'إضافة'),
                  ),
                ),
              ),

              Obx(
                () => controller.hasError
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          controller.errorMessage.value ?? '',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TypeOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? Colors.white : color),
            const SizedBox(width: AppSpacing.xs),
            Text(label),
          ],
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        labelStyle: TextStyle(
          color: selected ? Colors.white : color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
