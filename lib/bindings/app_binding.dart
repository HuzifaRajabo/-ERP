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
import '../repositories/stock_transfer_repository.dart';
import '../controllers/product_controller.dart';
import '../controllers/party_controller.dart';
import '../controllers/invoice_controller.dart';
import '../controllers/inventory_controller.dart';
import '../controllers/payment_controller.dart';
import '../controllers/expense_controller.dart';
import '../controllers/report_controller.dart';
import '../repositories/return_repository.dart';
import '../repositories/waste_repository.dart';
import '../repositories/expired_return_repository.dart';
import '../repositories/returnable_packaging_repository.dart';
import '../controllers/packaging_controller.dart';
import '../controllers/return_controller.dart';
import '../controllers/category_controller.dart';
import '../controllers/batch_controller.dart';
import '../controllers/product_unit_controller.dart';
import '../controllers/warehouse_controller.dart';
import '../repositories/app_settings_repository.dart';
import '../repositories/business_settings_repository.dart';
import '../repositories/company_profile_repository.dart';
import '../repositories/notification_repository.dart';
import '../core/services/company_profile_service.dart';
import '../core/services/expiry_notification_service.dart';
import '../core/services/stock_notification_service.dart';
import '../core/services/debt_notification_service.dart';
import '../core/services/packaging_notification_service.dart';
import '../core/services/notification_scan_coordinator.dart';
import '../controllers/notification_controller.dart';
import '../controllers/feature_controller.dart';
import '../controllers/company_profile_controller.dart';

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
    Get.put<StockTransferRepository>(
      StockTransferRepository(
        Get.find<BatchRepository>(),
        Get.find<ProductUnitRepository>(),
      ),
      permanent: true,
    );

    // ==============================
    // Controllers — تعتمد على الـ Repositories
    // ==============================
    Get.put<ProductController>(
      ProductController(
        Get.find<ProductRepository>(),
        Get.find<ProductUnitRepository>(),
        Get.find<CategoryRepository>(),
      ),
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
        unitRepo: Get.find<ProductUnitRepository>(),
        categoryRepo: Get.find<CategoryRepository>(),
        batchRepo: Get.find<BatchRepository>(),
        warehouseRepo: Get.find<WarehouseRepository>(),
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
        Get.find<PartyRepository>(),
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
    Get.put<WasteRepository>(WasteRepository(), permanent: true);
    Get.put<ExpiredReturnRepository>(
      ExpiredReturnRepository(),
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
    Get.put<ReturnablePackagingRepository>(
      ReturnablePackagingRepository(),
      permanent: true,
    );
    Get.put<PackagingController>(
      PackagingController(
        repo: Get.find<ReturnablePackagingRepository>(),
        partyRepo: Get.find<PartyRepository>(),
        warehouseRepo: Get.find<WarehouseRepository>(),
      ),
      permanent: true,
    );
    Get.put<AppSettingsRepository>(AppSettingsRepository(), permanent: true);
    Get.put<BusinessSettingsRepository>(
      BusinessSettingsRepository(
        settings: Get.find<AppSettingsRepository>(),
      ),
      permanent: true,
    );
    Get.put<FeatureController>(
      FeatureController(
        Get.find<BusinessSettingsRepository>(),
        invoiceRepo: Get.find<InvoiceRepository>(),
      ),
      permanent: true,
    );
    Get.put<CompanyProfileRepository>(
      CompanyProfileRepository(),
      permanent: true,
    );
    Get.put<CompanyProfileService>(
      CompanyProfileService(Get.find<CompanyProfileRepository>()),
      permanent: true,
    );
    Get.put<CompanyProfileController>(
      CompanyProfileController(Get.find<CompanyProfileService>()),
      permanent: true,
    );
    Get.put<NotificationRepository>(NotificationRepository(), permanent: true);
    Get.put<ExpiryNotificationService>(
      ExpiryNotificationService(
        settingsRepo: Get.find<AppSettingsRepository>(),
        notificationRepo: Get.find<NotificationRepository>(),
        batchRepo: Get.find<BatchRepository>(),
      ),
      permanent: true,
    );
    Get.put<StockNotificationService>(
      StockNotificationService(
        inventoryRepo: Get.find<InventoryRepository>(),
        notificationRepo: Get.find<NotificationRepository>(),
      ),
      permanent: true,
    );
    Get.put<DebtNotificationService>(
      DebtNotificationService(
        invoiceRepo: Get.find<InvoiceRepository>(),
        notificationRepo: Get.find<NotificationRepository>(),
      ),
      permanent: true,
    );
    Get.put<PackagingNotificationService>(
      PackagingNotificationService(
        packagingRepo: Get.find<ReturnablePackagingRepository>(),
        notificationRepo: Get.find<NotificationRepository>(),
      ),
      permanent: true,
    );
    Get.put<NotificationScanCoordinator>(
      NotificationScanCoordinator(
        settingsRepo: Get.find<BusinessSettingsRepository>(),
        notificationRepo: Get.find<NotificationRepository>(),
        expiryService: Get.find<ExpiryNotificationService>(),
        stockService: Get.find<StockNotificationService>(),
        debtService: Get.find<DebtNotificationService>(),
        packagingService: Get.find<PackagingNotificationService>(),
      ),
      permanent: true,
    );
    Get.put<NotificationController>(
      NotificationController(
        repo: Get.find<NotificationRepository>(),
        settingsRepo: Get.find<AppSettingsRepository>(),
        expiryService: Get.find<ExpiryNotificationService>(),
        coordinator: Get.find<NotificationScanCoordinator>(),
      ),
      permanent: true,
    );
  }
}
