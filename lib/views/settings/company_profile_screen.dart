import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/company_profile_controller.dart';
import '../../core/theme/app_dimensions.dart';
import '../shared/app_ui.dart';

class CompanyProfileScreen extends StatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  late final CompanyProfileController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<CompanyProfileController>();
    controller.load();
  }

  Future<void> _save() async {
    final ok = await controller.save();
    if (!mounted) return;
    if (ok) {
      AppUi.showSuccess('تم حفظ معلومات المنشأة بنجاح');
    } else if (controller.errorMessage.value != null) {
      AppUi.showError(controller.errorMessage.value!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('معلومات المنشأة'),
        centerTitle: true,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: controller.nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: AppUi.inputDecoration(
                    label: 'اسم المنشأة *',
                    icon: Icons.apartment_outlined,
                  ),
                  validator: controller.validateName,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: controller.tradeNameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: AppUi.inputDecoration(
                    label: 'الاسم التجاري',
                    icon: Icons.storefront_outlined,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: controller.addressCtrl,
                  maxLines: 2,
                  textInputAction: TextInputAction.next,
                  decoration: AppUi.inputDecoration(
                    label: 'العنوان',
                    icon: Icons.location_on_outlined,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: controller.serviceAreaCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: AppUi.inputDecoration(
                    label: 'مجال العمل / نطاق التغطية',
                    icon: Icons.map_outlined,
                    hint: 'مثال: دمشق وريفها',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: controller.phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: AppUi.inputDecoration(
                    label: 'رقم الهاتف',
                    icon: Icons.phone_outlined,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: controller.descriptionCtrl,
                  maxLines: 4,
                  decoration: AppUi.inputDecoration(
                    label: 'الوصف',
                    icon: Icons.notes_outlined,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Obx(
                  () => FilledButton.icon(
                    onPressed: controller.isSaving.value ? null : _save,
                    icon: controller.isSaving.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('حفظ'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
