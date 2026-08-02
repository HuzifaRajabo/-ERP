import 'package:get/get.dart';
import '../core/utils/money_utils.dart';
import '../models/expense_model.dart';
import '../repositories/expense_repository.dart';
import '../core/utils/db_error_handler.dart';
import '../core/services/app_event_bus.dart';

enum ExpenseLoadState { idle, loading, loadingMore, error }

class ExpenseController extends GetxController {
  final ExpenseRepository repo;

  ExpenseController(this.repo);

  final RxList<ExpenseModel> expenses = <ExpenseModel>[].obs;
  final Rx<ExpenseLoadState> state = ExpenseLoadState.idle.obs;
  final RxBool hasMore = true.obs;
  final RxnString errorMessage = RxnString();
  final Rxn<ExpenseModel> editingExpense = Rxn<ExpenseModel>();
  final RxInt amount = 0.obs;
  final RxString description = ''.obs;
  final Rx<ExpenseCategory> category = ExpenseCategory.other.obs;
  final RxBool isSaving = false.obs;
  final RxnString formError = RxnString();

  int? _cursor;

  bool get isLoading => state.value == ExpenseLoadState.loading;
  bool get isLoadingMore => state.value == ExpenseLoadState.loadingMore;
  bool get hasError => state.value == ExpenseLoadState.error;
  bool get isEmpty => expenses.isEmpty && state.value == ExpenseLoadState.idle;

  @override
  void onInit() {
    super.onInit();
    loadInitial();
  }

  void _reset() {
    expenses.clear();
    _cursor = null;
    hasMore.value = true;
    errorMessage.value = null;
  }

  Future<void> loadInitial() async {
    _reset();
    state.value = ExpenseLoadState.loading;
    await _fetchPage();
  }

  Future<void> loadMore() async {
    if (!hasMore.value || state.value != ExpenseLoadState.idle) return;
    state.value = ExpenseLoadState.loadingMore;
    await _fetchPage();
  }

  Future<void> _fetchPage() async {
    try {
      final page = await repo.getAllExpenses(lastId: _cursor);
      expenses.addAll(page.expenses);
      _cursor = page.nextCursor;
      hasMore.value = page.hasNextPage;
      state.value = ExpenseLoadState.idle;
      errorMessage.value = null;
    } catch (e) {
      state.value = ExpenseLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  Future<void> refreshExpenses() async => loadInitial();

  void initNewExpense() {
    editingExpense.value = null;
    amount.value = 0;
    description.value = '';
    category.value = ExpenseCategory.other;
    formError.value = null;
  }

  void initExpenseForm(ExpenseModel expense) {
    editingExpense.value = expense;
    amount.value = expense.amount;
    description.value = expense.description;
    category.value = expense.category;
    formError.value = null;
  }

  void setAmount(String value) {
    final parsed = MoneyUtils.parseAmount(value) ?? 0;
    amount.value = parsed;
    formError.value = null;
  }

  void setDescription(String value) {
    description.value = value;
    formError.value = null;
  }

  void setCategory(ExpenseCategory selected) {
    category.value = selected;
    formError.value = null;
  }

  Future<bool> saveExpense() async {
    formError.value = null;

    if (amount.value <= 0) {
      formError.value = 'المبلغ يجب أن يكون أكبر من صفر';
      return false;
    }

    if (description.value.trim().isEmpty) {
      formError.value = 'الوصف مطلوب';
      return false;
    }

    isSaving.value = true;

    try {
      final expense = ExpenseModel(
        id: editingExpense.value?.id,
        amount: amount.value,
        description: description.value.trim(),
        category: category.value,
        createdAt: editingExpense.value?.createdAt,
      );

      if (editingExpense.value == null) {
        await repo.insertExpense(expense);
      } else {
        await repo.updateExpense(expense);
      }

      AppEventBus.instance.notifyExpenseChanged();
      await loadInitial();
      isSaving.value = false;
      return true;
    } catch (e) {
      formError.value = DbErrorHandler.handle(e, entityName: 'المصروف');
      isSaving.value = false;
      return false;
    }
  }

  Future<bool> deleteExpense(int id) async {
    try {
      await repo.deleteExpense(id);
      AppEventBus.instance.notifyExpenseChanged();
      await loadInitial();
      return true;
    } catch (e) {
      errorMessage.value = DbErrorHandler.handle(e, entityName: 'المصروف');
      return false;
    }
  }
}
