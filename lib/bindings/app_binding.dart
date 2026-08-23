// lib/bindings/app_binding.dart

import 'package:get/get.dart';
import '../repositories/product_repository.dart';
import '../repositories/party_repository.dart';
import '../repositories/invoice_repository.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/payment_repository.dart';
import '../repositories/expense_repository.dart';
import '../repositories/report_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/batch_repository.dart';
import '../repositories/product_unit_repository.dart';
import '../repositories/warehouse_repository.dart';
import '../controllers/product_controller.dart';
import '../controllers/party_controller.dart';
import '../controllers/invoice_controller.dart';
import '../controllers/inventory_controller.dart';
import '../controllers/payment_controller.dart';
import '../controllers/expense_controller.dart';
import '../controllers/report_controller.dart';
import '../repositories/return_repository.dart';
import '../controllers/return_controller.dart';
import '../controllers/category_controller.dart';
import '../controllers/batch_controller.dart';
import '../controllers/product_unit_controller.dart';
import '../controllers/warehouse_controller.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    // ==============================
    // Repositories — تُسجَّل أولاً
    // ==============================
    Get.put<ProductRepository>(
      ProductRepository(),
      permanent: true, // ← لا تُحذف أبداً
    );
    Get.put<PartyRepository>(PartyRepository(), permanent: true);
    Get.put<InvoiceRepository>(InvoiceRepository(), permanent: true);
    Get.put<InventoryRepository>(InventoryRepository(), permanent: true);
    Get.put<PaymentRepository>(PaymentRepository(), permanent: true);
    Get.put<CategoryRepository>(CategoryRepository(), permanent: true);
    Get.put<BatchRepository>(BatchRepository(), permanent: true);
    Get.put<ProductUnitRepository>(ProductUnitRepository(), permanent: true);
    Get.put<WarehouseRepository>(WarehouseRepository(), permanent: true);

    // ==============================
    // Controllers — تعتمد على الـ Repositories
    // ==============================
    Get.put<ProductController>(
      ProductController(Get.find<ProductRepository>(), Get.find<CategoryRepository>()),
      permanent: true,
    );
    Get.put<PartyController>(
      PartyController(Get.find<PartyRepository>()),
      permanent: true,
    );
    Get.put<InvoiceController>(
      InvoiceController(
        Get.find<InvoiceRepository>(),
        Get.find<ProductRepository>(),
        Get.find<PartyRepository>(),
      ),
      permanent: true,
    );
    Get.put<InventoryController>(
      InventoryController(Get.find<InventoryRepository>()),
      permanent: true,
    );
    Get.put<PaymentController>(
      PaymentController(
        Get.find<PaymentRepository>(),
        Get.find<InvoiceRepository>(),
      ),
      permanent: true,
    );
    Get.put<ExpenseRepository>(ExpenseRepository(), permanent: true);
    Get.put<ExpenseController>(
      ExpenseController(Get.find<ExpenseRepository>()),
      permanent: true,
    );
    Get.put<ReportRepository>(ReportRepository(), permanent: true);
    Get.put<ReportController>(
      ReportController(Get.find<ReportRepository>()),
      permanent: true,
    );
    Get.put<ReturnRepository>(ReturnRepository(), permanent: true);

    Get.put<ReturnController>(
      ReturnController(Get.find<ReturnRepository>()),
      permanent: true,
    );

    Get.put<CategoryController>(
      CategoryController(Get.find<CategoryRepository>()),
      permanent: true,
    );
    Get.put<BatchController>(
      BatchController(Get.find<BatchRepository>()),
      permanent: true,
    );
    Get.put<ProductUnitController>(
      ProductUnitController(Get.find<ProductUnitRepository>()),
      permanent: true,
    );
    Get.put<WarehouseController>(
      WarehouseController(Get.find<WarehouseRepository>()),
      permanent: true,
    );
  }
}
