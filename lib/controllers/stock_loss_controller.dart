import 'package:get/get.dart';

import '../core/services/app_event_bus.dart';
import '../core/utils/unit_conversion.dart';
import '../models/party_model.dart';
import '../models/product_model.dart';
import '../models/product_unit_model.dart';
import '../models/warehouse_model.dart';
import '../models/waste_model.dart';
import '../repositories/expired_return_repository.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/party_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/product_unit_repository.dart';
import '../repositories/warehouse_repository.dart';
import '../repositories/waste_repository.dart';

class StockLossController extends GetxController {
  StockLossController({
    required this.wasteRepo,
    required this.expiredRepo,
    required this.warehouseRepo,
    required this.inventoryRepo,
    required this.productRepo,
    required this.unitRepo,
    required this.partyRepo,
    required this.isExpiredReturn,
  });

  final WasteRepository wasteRepo;
  final ExpiredReturnRepository expiredRepo;
  final WarehouseRepository warehouseRepo;
  final InventoryRepository inventoryRepo;
  final ProductRepository productRepo;
  final ProductUnitRepository unitRepo;
  final PartyRepository partyRepo;
  final bool isExpiredReturn;

  final warehouses = <WarehouseModel>[].obs;
  final products = <ProductModel>[].obs;
  final suppliers = <PartyModel>[].obs;
  final units = <ProductUnitModel>[].obs;
  final batches = <WarehouseProductBatchStock>[].obs;
  final lines = <WasteItemDraft>[].obs;

  final selectedWarehouseId = RxnInt();
  final selectedProductId = RxnInt();
  final selectedBatchId = RxnInt();
  final selectedUnitId = RxnInt();
  final selectedPartyId = RxnInt();
  final quantity = RxnDouble();
  final compensationAmount = 0.obs;
  final reason = ''.obs;
  final notes = ''.obs;
  final errorMessage = RxnString();
  final isSaving = false.obs;
  final isLoading = false.obs;
  final warehouseLocked = false.obs;

  WarehouseProductBatchStock? get selectedBatch {
    final id = selectedBatchId.value;
    if (id == null) return null;
    for (final b in batches) {
      if (b.batchId == id) return b;
    }
    return null;
  }

  ProductUnitModel? get selectedUnit {
    final id = selectedUnitId.value;
    if (id == null) return null;
    for (final u in units) {
      if (u.id == id) return u;
    }
    return null;
  }

  double get conversionFactor => selectedUnit?.conversionFactor ?? 1;

  double get baseQuantity =>
      UnitConversion.toBaseQuantity(quantity.value ?? 0, conversionFactor);

  int get unitCost => selectedBatch?.costPrice ?? 0;

  int get lineCost => (baseQuantity * unitCost).round();

  int get totalCost => lines.fold(0, (sum, item) => sum + item.lineCost);

  @override
  void onInit() {
    super.onInit();
    loadLookups();
  }

  Future<void> loadLookups() async {
    isLoading.value = true;
    try {
      warehouses.assignAll(await warehouseRepo.getAllWarehouses());
      final page = await productRepo.getAllProducts(pageSize: 1000);
      products.assignAll(page.products);
      if (isExpiredReturn) {
        final partyPage =
            await partyRepo.getParties(type: PartyType.supplier, pageSize: 500);
        suppliers.assignAll(partyPage.parties);
      }
      final lockedId = _readLockedWarehouseId();
      if (lockedId != null && warehouses.any((w) => w.id == lockedId)) {
        selectedWarehouseId.value = lockedId;
        warehouseLocked.value = true;
      } else {
        selectedWarehouseId.value ??= warehouses
            .where((w) => w.isDefault)
            .map((w) => w.id)
            .firstOrNull ??
            warehouses.firstOrNull?.id;
      }
    } catch (e) {
      errorMessage.value = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }

  int? _readLockedWarehouseId() {
    final args = Get.arguments;
    if (args is int) return args;
    if (args is Map && args['warehouseId'] is int) {
      return args['warehouseId'] as int;
    }
    return null;
  }

  Future<void> selectWarehouse(int? id) async {
    if (warehouseLocked.value) return;
    selectedWarehouseId.value = id;
    selectedProductId.value = null;
    await _resetProductDependents();
  }

  Future<void> selectProduct(int? id) async {
    selectedProductId.value = id;
    await _resetProductDependents();
    if (id == null || selectedWarehouseId.value == null) return;
    units.assignAll(await unitRepo.getUnitsForProduct(id));
    batches.assignAll(
      await inventoryRepo.getWarehouseProductBatches(
        warehouseId: selectedWarehouseId.value!,
        productId: id,
      ),
    );
    selectedUnitId.value =
        units.where((u) => u.isBaseUnit).map((u) => u.id).firstOrNull ??
            units.firstOrNull?.id;
    selectedBatchId.value = batches.firstOrNull?.batchId;
  }

  Future<void> _resetProductDependents() async {
    units.clear();
    batches.clear();
    selectedBatchId.value = null;
    selectedUnitId.value = null;
    quantity.value = null;
  }

  String? addLine() {
    final warehouseId = selectedWarehouseId.value;
    final product = products
        .where((p) => p.id == selectedProductId.value)
        .firstOrNull;
    final batch = selectedBatch;
    if (warehouseId == null) return 'اختر المستودع';
    if (product == null) return 'اختر المنتج';
    if (batch == null) return 'اختر الدفعة';
    final qty = quantity.value ?? 0;
    if (qty <= 0) return 'أدخل كمية أكبر من صفر';
    if (baseQuantity > batch.available + 0.0001) {
      return 'الكمية تتجاوز المتاح في الدفعة';
    }

    lines.add(
      WasteItemDraft(
        productId: product.id!,
        productName: product.name,
        batchId: batch.batchId,
        batchNumber: batch.batchNumber ?? 'بدون رقم',
        expiryDate: batch.expiryDate,
        unitId: selectedUnit?.id,
        unitName: selectedUnit?.unitName,
        conversionFactor: conversionFactor,
        quantity: qty,
        baseQuantity: baseQuantity,
        unitCost: unitCost,
      ),
    );
    quantity.value = null;
    return null;
  }

  void removeLine(int index) => lines.removeAt(index);

  Future<bool> save() async {
    errorMessage.value = null;
    if (lines.isEmpty) {
      errorMessage.value = 'أضف منتجاً واحداً على الأقل';
      return false;
    }
    if (reason.value.trim().isEmpty) {
      errorMessage.value = isExpiredReturn
          ? 'أدخل سبب الإرجاع'
          : 'أدخل سبب الإتلاف';
      return false;
    }
    if (isExpiredReturn && selectedPartyId.value == null) {
      errorMessage.value = 'اختر المورد';
      return false;
    }
    if (isExpiredReturn && compensationAmount.value < 0) {
      errorMessage.value = 'قيمة التعويض لا يمكن أن تكون سالبة';
      return false;
    }

    isSaving.value = true;
    try {
      if (isExpiredReturn) {
        final party = suppliers
            .where((p) => p.id == selectedPartyId.value)
            .first;
        await expiredRepo.createExpiredReturn(
          partyId: party.id!,
          partyName: party.name,
          warehouseId: selectedWarehouseId.value!,
          compensationAmount: compensationAmount.value,
          reason: reason.value,
          notes: notes.value,
          items: List.from(lines),
        );
      } else {
        await wasteRepo.createWaste(
          warehouseId: selectedWarehouseId.value!,
          reason: reason.value,
          notes: notes.value,
          items: List.from(lines),
        );
      }
      AppEventBus.instance.notifyInventoryChanged();
      return true;
    } catch (e) {
      errorMessage.value = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isSaving.value = false;
    }
  }
}
