import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/services/app_event_bus.dart';
import '../core/utils/money_utils.dart';
import '../core/utils/packaging_quantity_format.dart';
import '../models/party_model.dart';
import '../models/returnable_packaging_model.dart';
import '../models/warehouse_model.dart';
import '../repositories/party_repository.dart';
import '../repositories/returnable_packaging_repository.dart';
import '../repositories/warehouse_repository.dart';

class PackagingController extends GetxController {
  PackagingController({
    required this.repo,
    required this.partyRepo,
    required this.warehouseRepo,
  });

  final ReturnablePackagingRepository repo;
  final PartyRepository partyRepo;
  final WarehouseRepository warehouseRepo;

  final types = <PackagingType>[].obs;
  final emptyStock = <WarehouseEmptyStock>[].obs;
  final transactions = <PackagingTransaction>[].obs;
  final parties = <PartyModel>[].obs;
  final warehouses = <WarehouseModel>[].obs;
  final report = Rxn<PackagingReportSummary>();
  final ownership = Rxn<PackagingOwnershipSummary>();
  final unitsByType = <int, List<PackagingUnit>>{}.obs;
  final mappingByProductId = <int, PackagingProductMapping>{}.obs;

  final isLoading = false.obs;
  final errorMessage = RxnString();

  final filterPartyId = RxnInt();
  final filterTypeId = RxnInt();
  final filterWarehouseId = RxnInt();
  final filterMovement = Rxn<PackagingMovementType>();
  DateTime? filterFrom;
  DateTime? filterTo;
  final hasDateFilter = false.obs;

  @override
  void onInit() {
    super.onInit();
    AppEventBus.instance.listenToPackaging(loadAll);
    AppEventBus.instance.listenToInvoices(loadAll);
    AppEventBus.instance.listenToProducts(loadAll);
    AppEventBus.instance.listenToInventory(loadAll);
    loadAll();
  }

  Future<void> loadAll() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      await Future.wait([
        loadTypes(),
        loadEmptyStock(),
        loadTransactions(),
        loadLookups(),
        loadReport(),
        loadOwnership(),
        loadMappings(),
      ]);
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadTypes() async {
    final result = await repo.getTypes();
    types.assignAll(result);
    final map = <int, List<PackagingUnit>>{};
    for (final type in result) {
      if (type.id == null) continue;
      map[type.id!] = await repo.getUnits(type.id!);
    }
    unitsByType.assignAll(map);
  }

  Future<void> loadEmptyStock() async {
    emptyStock.assignAll(await repo.getEmptyStock());
  }

  Future<List<PackagingWarehouseStock>> warehouseStockForType(int typeId) {
    return repo.getWarehouseStock(
      typeId: typeId,
      includeZeroWarehouses: true,
    );
  }

  Future<void> loadTransactions() async {
    transactions.assignAll(
      await repo.getTransactions(
        partyId: filterPartyId.value,
        typeId: filterTypeId.value,
        warehouseId: filterWarehouseId.value,
        movementType: filterMovement.value,
        from: filterFrom,
        to: filterTo,
      ),
    );
  }

  Future<void> loadLookups() async {
    final page = await partyRepo.getParties(pageSize: 500);
    parties.assignAll(
      page.parties
          .where(
            (party) =>
                party.type == PartyType.customer || party.type == PartyType.both,
          )
          .toList(),
    );
    warehouses.assignAll(await warehouseRepo.getAllWarehouses());
  }

  Future<void> loadReport() async {
    report.value = await repo.getReportSummary(
      from: filterFrom,
      to: filterTo,
    );
  }

  Future<void> loadOwnership() async {
    ownership.value = await repo.getOwnershipSummary();
  }

  Future<void> loadMappings() async {
    mappingByProductId.assignAll(await repo.getAllProductMappings());
  }

  void setMovementFilter(PackagingMovementType? value) {
    filterMovement.value = value;
    loadTransactions();
  }

  void setPartyFilter(int? value) {
    filterPartyId.value = value;
    loadTransactions();
  }

  void setTypeFilter(int? value) {
    filterTypeId.value = value;
    loadTransactions();
  }

  void setWarehouseFilter(int? value) {
    filterWarehouseId.value = value;
    loadTransactions();
  }

  Future<void> setDateFilter(DateTime? from, DateTime? to) async {
    filterFrom = from;
    filterTo = to;
    hasDateFilter.value = from != null || to != null;
    await Future.wait([loadTransactions(), loadReport()]);
  }

  String formatQty(double quantity, int? typeId) {
    final units = typeId == null ? <PackagingUnit>[] : (unitsByType[typeId] ?? []);
    return PackagingQuantityFormat.format(quantity, units: units);
  }

  Future<void> exportReportPdf() async {
    final summary = report.value ?? await repo.getReportSummary();
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Bold.ttf'),
    );
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (context) => [
          pw.Header(level: 0, text: 'تقرير العبوات القابلة للإرجاع'),
          pw.SizedBox(height: 12),
          pw.Bullet(text: 'مسلّم خلال الفترة: ${PackagingQuantityFormat.formatQuantity(summary.issued)}'),
          pw.Bullet(text: 'مستلم سليم: ${PackagingQuantityFormat.formatQuantity(summary.returned)}'),
          pw.Bullet(text: 'مكسر: ${PackagingQuantityFormat.formatQuantity(summary.broken)}'),
          pw.Bullet(text: 'مفقود: ${PackagingQuantityFormat.formatQuantity(summary.lost)}'),
          pw.Bullet(text: 'عكس مرتجع بيع: ${PackagingQuantityFormat.formatQuantity(summary.reversed)}'),
          pw.Bullet(text: 'غير مسوّى حالياً: ${PackagingQuantityFormat.formatQuantity(summary.unsettled)}'),
          pw.Bullet(text: 'مخزون فارغ: ${PackagingQuantityFormat.formatQuantity(summary.emptyStock)}'),
          pw.Bullet(text: 'ممتلئ في المخزون: ${PackagingQuantityFormat.formatQuantity(summary.fullInStock)}'),
          pw.Bullet(text: 'إجمالي قيمة العبوات: ${MoneyUtils.formatMoney(summary.totalValue)}'),
          pw.Bullet(text: 'مطالبات الكسر والفقد المستحقة: ${MoneyUtils.formatMoney(summary.chargeDue)}'),
        ],
      ),
    );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'تقرير_العبوات.pdf',
    );
  }

  Future<List<PackagingType>> getTypes({bool activeOnly = false}) {
    return repo.getTypes(activeOnly: activeOnly);
  }

  Future<List<PackagingUnit>> getUnits(int typeId, {bool activeOnly = true}) {
    return repo.getUnits(typeId, activeOnly: activeOnly);
  }

  Future<List<PackagingProductMapping>> getMappingsForType(int typeId) {
    return repo.getMappingsForType(typeId);
  }

  Future<PackagingProductMapping?> getProductMapping(int productId) {
    return repo.getProductMapping(productId);
  }

  Future<int> createType({
    required String name,
    String? description,
    int value = 0,
    bool isActive = true,
  }) async {
    final id = await repo.createType(
      name: name,
      description: description,
      value: value,
      isActive: isActive,
    );
    AppEventBus.instance.notifyPackagingChanged();
    return id;
  }

  Future<void> updateType({
    required int id,
    required String name,
    String? description,
    required int value,
    required bool isActive,
  }) async {
    await repo.updateType(
      id: id,
      name: name,
      description: description,
      value: value,
      isActive: isActive,
    );
    AppEventBus.instance.notifyPackagingChanged();
  }

  Future<int> addUnit({
    required int typeId,
    required String unitName,
    required double conversionFactor,
  }) async {
    final id = await repo.addUnit(
      typeId: typeId,
      unitName: unitName,
      conversionFactor: conversionFactor,
    );
    AppEventBus.instance.notifyPackagingChanged();
    return id;
  }

  Future<void> deleteUnit(int id) async {
    await repo.deleteUnit(id);
    AppEventBus.instance.notifyPackagingChanged();
  }

  Future<List<PartyModel>> loadCustomerParties({int pageSize = 500}) async {
    final page = await partyRepo.getParties(pageSize: pageSize);
    return page.parties
        .where(
          (party) =>
              party.type == PartyType.customer || party.type == PartyType.both,
        )
        .toList();
  }

  Future<List<WarehouseModel>> getAllWarehouses() {
    return warehouseRepo.getAllWarehouses();
  }

  Future<double> unsettled({required int partyId, required int typeId}) {
    return repo.unsettled(partyId: partyId, typeId: typeId);
  }

  Future<int> settle({
    required int partyId,
    required int typeId,
    required int warehouseId,
    required double returnedBase,
    required double brokenBase,
    required double lostBase,
    int compensationPaidNow = 0,
    String? notes,
  }) async {
    final id = await repo.settle(
      partyId: partyId,
      typeId: typeId,
      warehouseId: warehouseId,
      returnedBase: returnedBase,
      brokenBase: brokenBase,
      lostBase: lostBase,
      compensationPaidNow: compensationPaidNow,
      notes: notes,
    );
    AppEventBus.instance.notifyPackagingChanged();
    AppEventBus.instance.notifyInvoiceChanged();
    return id;
  }

  Future<List<PartyPackagingBalance>> getPartyBalances(int partyId) {
    return repo.getPartyBalances(partyId);
  }

  Future<List<PackagingCharge>> getCharges({
    int? partyId,
    bool unpaidOnly = false,
  }) {
    return repo.getCharges(partyId: partyId, unpaidOnly: unpaidOnly);
  }

  Future<int> payCharge({
    required int chargeId,
    required int amount,
    String? notes,
  }) async {
    final id = await repo.payCharge(
      chargeId: chargeId,
      amount: amount,
      notes: notes,
    );
    AppEventBus.instance.notifyPackagingChanged();
    AppEventBus.instance.notifyInvoiceChanged();
    return id;
  }

  Future<void> saveOrClearProductMapping({
    required int productId,
    int? typeId,
    double unitsPerProductBase = 1,
  }) async {
    if (typeId == null) {
      await repo.clearProductMapping(productId);
    } else {
      await repo.setProductMapping(
        productId: productId,
        typeId: typeId,
        unitsPerProductBase: unitsPerProductBase,
      );
    }
    AppEventBus.instance.notifyPackagingChanged();
  }

  Future<int> recordOpeningEmpty({
    required int typeId,
    required int warehouseId,
    required double quantity,
    String? notes,
  }) async {
    final id = await repo.recordOpeningEmpty(
      typeId: typeId,
      warehouseId: warehouseId,
      quantity: quantity,
      notes: notes,
    );
    AppEventBus.instance.notifyPackagingChanged();
    return id;
  }

  Future<int> recordOpeningIssued({
    required int typeId,
    required int partyId,
    required double quantity,
    String? notes,
  }) async {
    final id = await repo.recordOpeningIssued(
      typeId: typeId,
      partyId: partyId,
      quantity: quantity,
      notes: notes,
    );
    AppEventBus.instance.notifyPackagingChanged();
    AppEventBus.instance.notifyInvoiceChanged();
    return id;
  }

  Future<List<PackagingWarehouseStock>> getWarehouseStock({
    required int warehouseId,
  }) {
    return repo.getWarehouseStock(warehouseId: warehouseId);
  }
}
