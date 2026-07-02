import 'package:get/get.dart';
import '../repositories/party_repository.dart';
import '../models/party_model.dart';

enum PartyLoadState { idle, loading, loadingMore, error }

class PartyController extends GetxController {
  final PartyRepository repo;

  PartyController(this.repo);

  // ==============================
  // State
  // ==============================

  final RxList<PartyModel> parties = <PartyModel>[].obs;
  final Rx<PartyLoadState> state = PartyLoadState.idle.obs;
  final RxBool hasMore = true.obs;
  final RxnString errorMessage = RxnString();
  final RxString searchKeyword = ''.obs;
  final Rxn<PartyType> selectedType = Rxn<PartyType>();

  int? _cursor;

  // ==============================
  // Getters
  // ==============================

  bool get isLoading => state.value == PartyLoadState.loading;
  bool get isLoadingMore => state.value == PartyLoadState.loadingMore;
  bool get hasError => state.value == PartyLoadState.error;
  bool get isEmpty => parties.isEmpty && state.value == PartyLoadState.idle;

  // ==============================
  // Lifecycle
  // ==============================

  @override
  void onInit() {
    super.onInit();

    // تشغيل البحث تلقائياً عند تغيير الكلمة مع debounce
    debounce(
      searchKeyword,
          (_) => loadInitial(),
      time: const Duration(milliseconds: 500),
    );

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
        keyword: searchKeyword.value,
        type: selectedType.value,
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
  // Search
  // ==============================

  void search(String keyword) {
    searchKeyword.value = keyword.trim();
    // debounce في onInit تتولى الباقي تلقائياً
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
      refreshParties();
    } catch (e) {
      state.value = PartyLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  Future<void> updateParty(PartyModel party) async {
    try {
      await repo.updateParty(party);
      final index = parties.indexWhere((p) => p.id == party.id);
      if (index != -1) {
        parties[index] = party;
        parties.refresh();
      }
    } catch (e) {
      state.value = PartyLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  Future<void> deleteParty(int id) async {
    try {
      await repo.deleteParty(id);
      parties.removeWhere((p) => p.id == id);
    } catch (e) {
      state.value = PartyLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  Future<PartyModel?> getPartyById(int id) {
    return repo.getPartyById(id);
  }

  Future<PartyModel?> getPartyByPhone(String phone) {
    return repo.getPartyByPhone(phone);
  }

  // ==============================
  // Helpers
  // ==============================

  Future<void> refreshParties() async {
    await loadInitial();
  }

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