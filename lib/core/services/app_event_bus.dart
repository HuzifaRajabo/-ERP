// lib/core/services/app_event_bus.dart

import 'dart:ui';

import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_rx/src/rx_workers/rx_workers.dart';

/// يُستخدم لإخطار كل الـ Controllers بالتغييرات
/// مثلاً: عند إضافة منتج → ProductController و InventoryController يتحدثان تلقائياً
class AppEventBus {
  AppEventBus._();
  static final AppEventBus instance = AppEventBus._();

  // أنواع الأحداث
  final _productChanged = false.obs;
  final _partyChanged = false.obs;
  final _invoiceChanged = false.obs;
  final _inventoryChanged = false.obs;

  // إطلاق الأحداث
  void notifyProductChanged() => _productChanged.toggle();
  void notifyPartyChanged() => _partyChanged.toggle();
  void notifyInvoiceChanged() => _invoiceChanged.toggle();
  void notifyInventoryChanged() => _inventoryChanged.toggle();

  // الاستماع للأحداث
  Worker listenToProducts(VoidCallback callback) =>
      ever(_productChanged, (_) => callback());

  Worker listenToParties(VoidCallback callback) =>
      ever(_partyChanged, (_) => callback());

  Worker listenToInvoices(VoidCallback callback) =>
      ever(_invoiceChanged, (_) => callback());

  Worker listenToInventory(VoidCallback callback) =>
      ever(_inventoryChanged, (_) => callback());
}