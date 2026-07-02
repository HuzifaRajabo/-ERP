import 'package:get/get.dart';
import '../repositories/product_repository.dart';
import '../controllers/product_controller.dart';

class ProductBinding extends Bindings {
  @override
  void dependencies() {

    Get.lazyPut<ProductRepository>(
          () => ProductRepository(),
    );

    Get.lazyPut<ProductController>(
          () => ProductController(
        Get.find<ProductRepository>(),
      ),
    );
  }
}