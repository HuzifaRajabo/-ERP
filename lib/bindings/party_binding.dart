import 'package:get/get.dart';
import '../repositories/party_repository.dart';
import '../controllers/party_controller.dart';

class PartyBinding extends Bindings {

  @override
  void dependencies() {
    Get.lazyPut<PartyRepository>(
        () => PartyRepository(),
    );

    Get.lazyPut<PartyController>(
        () => PartyController(
          Get.find<PartyRepository>(),
        ),
    );

  }

}