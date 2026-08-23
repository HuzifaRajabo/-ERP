import 'package:get/get.dart';

import '../models/category_model.dart';
import '../repositories/category_repository.dart';

enum CategoryLoadState { idle, loading, error }

class CategoryController extends GetxController {
  final CategoryRepository repo;

  CategoryController(this.repo);

  final RxList<CategoryModel> categories = <CategoryModel>[].obs;
  final Rx<CategoryLoadState> state = CategoryLoadState.idle.obs;
  final RxnString errorMessage = RxnString();

  Future<void> loadCategories({bool activeOnly = true}) async {
    try {
      state.value = CategoryLoadState.loading;
      final list = await repo.getAllCategories(activeOnly: activeOnly);
      categories.assignAll(list);
      state.value = CategoryLoadState.idle;
      errorMessage.value = null;
    } catch (e) {
      state.value = CategoryLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  Future<void> addCategory(CategoryModel category) async {
    try {
      await repo.insertCategory(category);
      await loadCategories();
    } catch (e) {
      state.value = CategoryLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  Future<void> updateCategory(CategoryModel category) async {
    try {
      await repo.updateCategory(category);
      await loadCategories();
    } catch (e) {
      state.value = CategoryLoadState.error;
      errorMessage.value = e.toString();
    }
  }

  Future<void> deleteOrDeactivateCategory(CategoryModel category) async {
    try {
      await repo.deleteOrDeactivateCategory(category);
      await loadCategories();
    } catch (e) {
      state.value = CategoryLoadState.error;
      errorMessage.value = e.toString();
    }
  }
}
