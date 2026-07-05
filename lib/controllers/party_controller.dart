import 'package:get/get.dart';
import '../repositories/party_repository.dart';
import '../models/party_model.dart';
import '../core/services/app_event_bus.dart';
import '../core/utils/db_error_handler.dart';

enum PartyLoadState { idle, loading, loadingMore, error }

class PartyController extends GetxController {
  final PartyRepository repo;

  PartyController(this.repo);

  final RxList<PartyModel> parties = <PartyModel>[].obs;
  final Rx<PartyLoadState> state = PartyLoadState.idle.obs;
  final RxBool hasMore = true.obs;
  final RxnString errorMessage = RxnString();
  final RxString searchKeyword = ''.obs;
  final Rxn<PartyType> selectedType = Rxn<PartyType>(); // ← جديد

  int? _cursor;

  bool get isLoading => state.value == PartyLoadState.loading;
  bool get isLoadingMore => state.value == PartyLoadState.loadingMore;
  bool get hasError => state.value == PartyLoadState.error;
  bool get isEmpty => parties.isEmpty && state.value == PartyLoadState.idle;

  @override
  void onInit() {
    super.onInit();
    debounce(
      searchKeyword,
          (_) => loadInitial(),
      time: const Duration(milliseconds: 500),
    );
    AppEventBus.instance.listenToParties(loadInitial);
    loadInitial();
  }

  // ==============================
  // Load / Pagination
  // ==============================

  Future<void> loadInitial() async {
    _reset();
    state.value = PartyLoadState.loading;
    await _fetchPage();
  }

  Future<void> loadMore() async {
    if (!hasMore.value || state.value != PartyLoadState.idle) return;
    state.value = PartyLoadState.loadingMore;
    await _fetchPage();
  }

  Future<void> _fetchPage() async {
    try {
      final page = await repo.getParties(
        keyword: searchKeyword.value.isEmpty ? null : searchKeyword.value,
        type: selectedType.value, // ← فلتر النوع
        lastId: _cursor,
      );

      parties.addAll(page.parties);
      _cursor = page.nextCursor;
      hasMore.value = page.hasNextPage;
      state.value = PartyLoadState.idle;
      errorMessage.value = null;
    } catch (e) {
      state.value = PartyLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  // ==============================
  // Search & Filter
  // ==============================

  void search(String keyword) {
    searchKeyword.value = keyword.trim();
  }

  void clearSearch() {
    searchKeyword.value = '';
  }

  void filterByType(PartyType? type) {
    selectedType.value = type;
    loadInitial();
  }

  // ==============================
  // CRUD
  // ==============================

  Future<void> addParty(PartyModel party) async {
    try {
      await repo.insertParty(party);
      AppEventBus.instance.notifyPartyChanged();
    } catch (e) {
      state.value = PartyLoadState.error;
      errorMessage.value = DbErrorHandler.handle(e, entityName: 'الطرف');
    }
  }

  Future<void> updateParty(PartyModel party) async {
    try {
      await repo.updateParty(party);
      AppEventBus.instance.notifyPartyChanged();
    } catch (e) {
      state.value = PartyLoadState.error;
      errorMessage.value = DbErrorHandler.handle(e, entityName: 'الطرف');
    }
  }

  Future<void> deleteParty(int id) async {
    try {
      await repo.deleteParty(id);
      AppEventBus.instance.notifyPartyChanged();
    } catch (e) {
      state.value = PartyLoadState.error;
      errorMessage.value = DbErrorHandler.handle(e, entityName: 'الطرف');
    }
  }

  Future<PartyModel?> getPartyById(int id) => repo.getPartyById(id);
  Future<PartyModel?> getPartyByPhone(String phone) =>
      repo.getPartyByPhone(phone);

  // ==============================
  // Helpers
  // ==============================

  Future<void> refreshParties() async => loadInitial();

  void _reset() {
    parties.clear();
    _cursor = null;
    hasMore.value = true;
    errorMessage.value = null;
    state.value = PartyLoadState.idle;
  }

  void clearError() {
    state.value = PartyLoadState.idle;
    errorMessage.value = null;
  }
}