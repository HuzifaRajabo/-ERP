import 'package:get/get.dart';

import '../core/services/app_event_bus.dart';
import '../core/services/expiry_notification_service.dart';
import '../core/services/notification_scan_coordinator.dart';
import '../models/notification_model.dart';
import '../models/invoice_model.dart';
import '../models/warehouse_model.dart';
import '../models/product_model.dart';
import '../repositories/app_settings_repository.dart';
import '../repositories/notification_repository.dart';
import 'invoice_controller.dart';
import 'warehouse_controller.dart';
import 'product_controller.dart';

class NotificationController extends GetxController {
  NotificationController({
    required this.repo,
    required this.settingsRepo,
    required this.expiryService,
    required this.coordinator,
  });

  final NotificationRepository repo;
  final AppSettingsRepository settingsRepo;
  final ExpiryNotificationService expiryService;
  final NotificationScanCoordinator coordinator;

  final RxList<NotificationModel> notifications = <NotificationModel>[].obs;
  final RxInt unreadCount = 0.obs;
  final RxBool loading = false.obs;
  final RxnString error = RxnString();
  final Rx<NotificationListFilter> filter = NotificationListFilter.all.obs;

  final RxInt expiryWarningDays = AppSettingsRepository.defaultWarningDays.obs;
  final RxBool expiryAlertsEnabled = true.obs;

  Worker? _inventoryWorker;

  @override
  void onInit() {
    super.onInit();
    _inventoryWorker = AppEventBus.instance.listenToInventory(() {
      scanAndRefresh();
    });
    scanAndRefresh(force: true);
    loadSettings();
  }

  @override
  void onClose() {
    _inventoryWorker?.dispose();
    super.onClose();
  }

  Future<void> loadSettings() async {
    try {
      expiryWarningDays.value = await settingsRepo.getExpiryWarningDays();
      expiryAlertsEnabled.value = await settingsRepo.isExpiryAlertsEnabled();
    } catch (_) {
      expiryWarningDays.value = AppSettingsRepository.defaultWarningDays;
      expiryAlertsEnabled.value = true;
    }
  }

  Future<void> setExpiryWarningDays(int days) async {
    await settingsRepo.setExpiryWarningDays(days);
    expiryWarningDays.value = await settingsRepo.getExpiryWarningDays();
    await scanAndRefresh(force: true);
  }

  Future<void> setExpiryAlertsEnabled(bool enabled) async {
    await settingsRepo.setExpiryAlertsEnabled(enabled);
    expiryAlertsEnabled.value = enabled;
    await scanAndRefresh(force: true);
  }

  Future<void> refreshNotifications({bool forceScan = false}) async {
    loading.value = true;
    error.value = null;
    try {
      await coordinator.scan(force: forceScan);
      await _loadList();
    } catch (e) {
      error.value = 'تعذر تحميل الإشعارات';
    } finally {
      loading.value = false;
    }
  }

  Future<void> scanAndRefresh({bool force = false}) async {
    try {
      await coordinator.scan(force: force);
      await _loadList();
      error.value = null;
    } catch (_) {
      if (notifications.isEmpty) {
        error.value = 'تعذر تحميل الإشعارات';
      }
    }
  }

  Future<void> changeFilter(NotificationListFilter value) async {
    filter.value = value;
    await _loadList();
  }

  Future<void> markAsRead(int id) async {
    await repo.markAsRead(id);
    await _loadList();
  }

  Future<void> markAllAsRead() async {
    await repo.markAllAsRead();
    await _loadList();
  }

  int get activeExpiryCount {
    return notifications
        .where(
          (item) =>
              item.isActive &&
              NotificationType.expiryDbValues.contains(item.type),
        )
        .length;
  }

  Future<void> _loadList() async {
    final items = await repo.getNotifications(filter: filter.value);
    notifications.assignAll(items);
    unreadCount.value = await repo.getUnreadCount();
  }

  Future<NotificationNavigationTarget> resolveNavigation(
    NotificationModel item,
  ) async {
    InvoiceModel? invoice;
    WarehouseModel? warehouse;
    ProductModel? product;
    if (item.entityType == 'invoice' &&
        item.entityId != null &&
        Get.isRegistered<InvoiceController>()) {
      invoice = await Get.find<InvoiceController>().getInvoiceById(
        item.entityId!,
      );
      if (invoice != null) {
        return NotificationNavigationTarget(invoice: invoice);
      }
    }
    if (item.warehouseId != null &&
        Get.isRegistered<WarehouseController>()) {
      warehouse = await Get.find<WarehouseController>().getWarehouseById(
        item.warehouseId!,
      );
      if (warehouse != null) {
        return NotificationNavigationTarget(
          warehouse: warehouse,
          focusProductId: item.productId,
        );
      }
    }
    if (item.productId != null && Get.isRegistered<ProductController>()) {
      product = await Get.find<ProductController>().getProductById(
        item.productId!,
      );
      if (product != null) {
        return NotificationNavigationTarget(product: product);
      }
    }
    return const NotificationNavigationTarget();
  }
}

class NotificationNavigationTarget {
  const NotificationNavigationTarget({
    this.invoice,
    this.warehouse,
    this.product,
    this.focusProductId,
  });

  final InvoiceModel? invoice;
  final WarehouseModel? warehouse;
  final ProductModel? product;
  final int? focusProductId;
}
