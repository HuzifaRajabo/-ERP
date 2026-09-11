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
}
