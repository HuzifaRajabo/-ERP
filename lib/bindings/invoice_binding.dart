import 'package:get/get.dart';
import '../repositories/invoice_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/party_repository.dart';
import '../controllers/invoice_controller.dart';

class InvoiceBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InvoiceRepository>(() => InvoiceRepository());

    // نتأكد أن ProductRepository و PartyRepository متاحين أيضاً
    // (قد يكونا مُسجَّلين مسبقاً من بايندنغز أخرى، lazyPut آمن في الحالتين)
    if (!Get.isRegistered<ProductRepository>()) {
      Get.lazyPut<ProductRepository>(() => ProductRepository());
    }
    if (!Get.isRegistered<PartyRepository>()) {
      Get.lazyPut<PartyRepository>(() => PartyRepository());
    }

    Get.lazyPut<InvoiceController>(
          () => InvoiceController(
        Get.find<InvoiceRepository>(),
        Get.find<ProductRepository>(),
        Get.find<PartyRepository>(),
      ),
    );
  }
}