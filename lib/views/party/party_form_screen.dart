import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/party_controller.dart';
import '../../models/party_model.dart';

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
      appBar: AppBar(
        title: Text(isEditing ? 'تعديل طرف' : 'إضافة طرف'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
              const SizedBox(height: 16),

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
              const SizedBox(height: 24),

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
              const SizedBox(height: 16),

              // ==============================
              // Type Selector
              // ==============================

              const Text(
                'نوع الطرف',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Obx(() => Row(
                    children: [
                      _TypeOption(
                        label: 'عميل',
                        icon: Icons.person_outline,
                        color: Colors.blue,
                        selected: selectedType.value == PartyType.customer,
                        onTap: () => selectedType.value = PartyType.customer,
                      ),
                      const SizedBox(width: 8),
                      _TypeOption(
                        label: 'مورد',
                        icon: Icons.local_shipping_outlined,
                        color: Colors.orange,
                        selected: selectedType.value == PartyType.supplier,
                        onTap: () => selectedType.value = PartyType.supplier,
                      ),
                      const SizedBox(width: 8),
                      _TypeOption(
                        label: 'كلاهما',
                        icon: Icons.people_outline,
                        color: Colors.purple,
                        selected: selectedType.value == PartyType.both,
                        onTap: () => selectedType.value = PartyType.both,
                      ),
                    ],
                  )),
              const SizedBox(height: 32),

              // ==============================
              // Submit
              // ==============================

              Obx(() => SizedBox(
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
                  )),

              Obx(() => controller.hasError
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        controller.errorMessage.value ?? '',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : const SizedBox.shrink()),
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
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? Colors.white : color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}