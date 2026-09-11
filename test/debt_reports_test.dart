import 'package:erp/core/database/database_helper.dart';
import 'package:erp/models/company_profile_model.dart';
import 'package:erp/models/debt_report_model.dart';
import 'package:erp/models/invoice_model.dart';
import 'package:erp/repositories/invoice_repository.dart';
import 'package:erp/repositories/payment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late PaymentRepository payments;
  late InvoiceRepository invoices;
  late int partyId;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DatabaseHelper.databaseVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: DatabaseHelper.createDatabaseForTesting,
        onOpen: DatabaseHelper.ensureCurrentSchemaForTesting,
      ),
    );
    DatabaseHelper.overrideDatabaseForTesting(db);
    payments = PaymentRepository();
    invoices = InvoiceRepository();

    partyId = await db.insert('parties', {
      'type': 'BOTH',
      'name': 'طرف مشترك',
      'phone': '0999',
      'address': 'دمشق',
    });

    await db.insert('invoices', {
      'invoice_number': 'SALE-1',
      'type': 'SALE',
      'party_id': partyId,
      'party_name_snapshot': 'طرف مشترك',
      'party_address_snapshot': 'دمشق',
      'total_amount': 10000,
      'original_total_amount': 10000,
      'paid_amount': 0,
      'payment_status': 'UNPAID',
    });
    await db.insert('invoices', {
      'invoice_number': 'PURCHASE-1',
      'type': 'PURCHASE',
      'party_id': partyId,
      'party_name_snapshot': 'طرف مشترك',
      'party_address_snapshot': 'دمشق',
      'total_amount': 5000,
      'original_total_amount': 5000,
      'paid_amount': 0,
      'payment_status': 'UNPAID',
    });
    await db.insert('invoices', {
      'invoice_number': 'SALE-PAID',
      'type': 'SALE',
      'party_id': partyId,
      'party_name_snapshot': 'طرف مشترك',
      'party_address_snapshot': 'دمشق',
      'total_amount': 2000,
      'original_total_amount': 2000,
      'paid_amount': 2000,
      'payment_status': 'PAID',
    });

    final typeId = await db.insert('returnable_packaging_types', {
      'name': 'زجاجة',
      'value': 0,
      'is_active': 1,
    });
    await db.insert('returnable_packaging_charges', {
      'party_id': partyId,
      'type_id': typeId,
      'amount': 1500,
      'paid_amount': 0,
    });
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.overrideDatabaseForTesting(null);
  });

  test('ديون الزبائن تشمل البيع والعبوات دون المشتريات', () async {
    final statements = await payments.getDebtStatements(
      invoiceType: InvoiceType.sale,
      includePackaging: true,
    );
    expect(statements, hasLength(1));
    final statement = statements.first;
    expect(statement.owedToUs, isTrue);
    expect(
      statement.lines.map((line) => line.documentNumber),
      containsAll(['SALE-1', 'تعويض عبوات']),
    );
    expect(
      statement.lines.map((line) => line.documentNumber),
      isNot(contains('PURCHASE-1')),
    );
    expect(
      statement.lines.map((line) => line.documentNumber),
      isNot(contains('SALE-PAID')),
    );
    expect(statement.totalRemaining, 11500);

    final report = DebtTabReport.fromStatements(
      owedToUs: true,
      parties: statements,
    );
    expect(report.grandRemaining, 11500);
    expect(report.title, 'تقرير ديون الزبائن');
    expect(report.directionLabel, 'مستحق لنا');
  });

  test('ديون الموردين تشمل الشراء فقط بدون عبوات', () async {
    final statements = await payments.getDebtStatements(
      invoiceType: InvoiceType.purchase,
      includePackaging: true,
    );
    expect(statements, hasLength(1));
    final statement = statements.first;
    expect(statement.owedToUs, isFalse);
    expect(statement.lines, hasLength(1));
    expect(statement.lines.first.documentNumber, 'PURCHASE-1');
    expect(statement.lines.first.sourceTypeLabel, 'فاتورة شراء');
    expect(statement.totalRemaining, 5000);
    expect(
      statement.lines.any((line) => line.kind == DebtSourceKind.packagingCharge),
      isFalse,
    );
  });

  test('كشف طرف both لا يخلط البيع مع الشراء', () async {
    final customer = await payments.getDebtStatements(
      invoiceType: InvoiceType.sale,
      partyId: partyId,
      includePackaging: false,
    );
    expect(customer.single.lines, hasLength(1));
    expect(customer.single.lines.single.documentNumber, 'SALE-1');

    final supplier = await payments.getDebtStatements(
      invoiceType: InvoiceType.purchase,
      partyId: partyId,
      includePackaging: true,
    );
    expect(supplier.single.lines.single.documentNumber, 'PURCHASE-1');
  });

  test('getInvoicesByParty يفلتر النوع وغير المسدد', () async {
    final sales = await invoices.getInvoicesByParty(
      partyId: partyId,
      type: InvoiceType.sale,
      unpaidOnly: true,
    );
    expect(sales.invoices.map((invoice) => invoice.invoiceNumber), ['SALE-1']);

    final purchases = await invoices.getInvoicesByParty(
      partyId: partyId,
      type: InvoiceType.purchase,
      unpaidOnly: true,
    );
    expect(
      purchases.invoices.map((invoice) => invoice.invoiceNumber),
      ['PURCHASE-1'],
    );
  });

  test('غياب Company Profile لا يترك أسطر ترويسة تكسر التقرير', () {
    expect(const CompanyProfileModel().headerLines, isEmpty);
    expect(CompanyProfileModel.empty().headerLines, isEmpty);
  });
}
