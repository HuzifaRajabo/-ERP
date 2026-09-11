import 'package:get/get.dart';

import '../../models/company_profile_model.dart';
import '../../repositories/company_profile_repository.dart';

/// مصدر مركزي لمعلومات المنشأة. الفواتير وPDF تقرأ من هنا وليس من SQLite مباشرة.
class CompanyProfileService extends GetxService {
  CompanyProfileService(this._repo);

  final CompanyProfileRepository _repo;

  final Rx<CompanyProfileModel> profile = CompanyProfileModel.empty().obs;

  bool _loaded = false;

  static CompanyProfileService resolve({
    CompanyProfileRepository? repo,
  }) {
    if (Get.isRegistered<CompanyProfileService>()) {
      return Get.find<CompanyProfileService>();
    }
    return CompanyProfileService(repo ?? CompanyProfileRepository());
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<CompanyProfileModel> load() async {
    final current = await _repo.getCompanyProfile();
    profile.value = current;
    _loaded = true;
    return current;
  }

  Future<CompanyProfileModel> current() async {
    if (!_loaded) await load();
    return profile.value;
  }

  Future<CompanyProfileModel> save(CompanyProfileModel next) async {
    final saved = await _repo.saveCompanyProfile(next);
    profile.value = saved;
    _loaded = true;
    return saved;
  }

  Future<List<String>> headerIdentity() async {
    final currentProfile = await current();
    return currentProfile.headerLines;
  }

  /// نقطة دخول المستندات: لا تعتمد على Controller الواجهة ولا تُسقط PDF عند الخطأ.
  static Future<List<String>> headerLinesForDocument() async {
    try {
      return await resolve().headerIdentity();
    } catch (_) {
      return const [];
    }
  }
}
