import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/services/company_profile_service.dart';
import '../models/company_profile_model.dart';

class CompanyProfileController extends GetxController {
  CompanyProfileController(this._service);

  final CompanyProfileService _service;

  final formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final tradeNameCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final serviceAreaCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();

  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxnString errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    nameCtrl.dispose();
    tradeNameCtrl.dispose();
    addressCtrl.dispose();
    serviceAreaCtrl.dispose();
    phoneCtrl.dispose();
    descriptionCtrl.dispose();
    super.onClose();
  }

  String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال اسم المنشأة';
    }
    return null;
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final profile = await _service.load();
      _fillFields(profile);
    } catch (_) {
      errorMessage.value = 'تعذر تحميل معلومات المنشأة';
    } finally {
      isLoading.value = false;
    }
  }

  void _fillFields(CompanyProfileModel profile) {
    nameCtrl.text = profile.name;
    tradeNameCtrl.text = profile.tradeName;
    addressCtrl.text = profile.address;
    serviceAreaCtrl.text = profile.serviceArea;
    phoneCtrl.text = profile.phone;
    descriptionCtrl.text = profile.description;
  }

  Future<bool> save() async {
    errorMessage.value = null;
    final formState = formKey.currentState;
    if (formState != null && !formState.validate()) {
      return false;
    }
    final nameError = validateName(nameCtrl.text);
    if (nameError != null) {
      errorMessage.value = nameError;
      return false;
    }

    isSaving.value = true;
    try {
      final current = _service.profile.value;
      await _service.save(
        current.copyWith(
          name: nameCtrl.text.trim(),
          tradeName: tradeNameCtrl.text.trim(),
          address: addressCtrl.text.trim(),
          serviceArea: serviceAreaCtrl.text.trim(),
          phone: phoneCtrl.text.trim(),
          description: descriptionCtrl.text.trim(),
        ),
      );
      _fillFields(_service.profile.value);
      return true;
    } catch (_) {
      errorMessage.value = 'تعذر حفظ معلومات المنشأة';
      return false;
    } finally {
      isSaving.value = false;
    }
  }
}
