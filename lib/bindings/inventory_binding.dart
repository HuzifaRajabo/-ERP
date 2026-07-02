import 'package:get/get.dart';
import '../repositories/inventory_repository.dart';
import '../controllers/inventory_controller.dart';

class InventoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InventoryRepository>(() => InventoryRepository());
    Get.lazyPut<InventoryController>(
          () => InventoryController(Get.find<InventoryRepository>()),
    );
  }
}