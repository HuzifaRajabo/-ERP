import 'package:erp/core/services/app_event_bus.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/report_model.dart';
import '../repositories/report_repository.dart';
import '../core/utils/money_utils.dart';

class ReportController extends GetxController {
  final ReportRepository repo;

  ReportController(this.repo);

  final Rxn<ReportOverview> overview = Rxn<ReportOverview>();
  final Rx<ReportDateRange> selectedRange = ReportDateRange.thisMonth.obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingDetails = false.obs;
  final RxList<InvoiceProfitDetail> profitDetails = <InvoiceProfitDetail>[].obs;
  final RxnString errorMessage = RxnString();

  DateTime? customFrom;
  DateTime? customTo;

  @override
  void onInit() {
    super.onInit();
    AppEventBus.instance.listenToInvoices(loadOverview);
    AppEventBus.instance.listenToInventory(loadOverview);
    AppEventBus.instance.listenToExpenses(loadOverview);
    loadOverview();
  }

  // بداية اليوم: 00:00:00.000
  DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 0, 0, 0, 0);

  // نهاية اليوم: 23:59:59.999 لضمان شمول آخر ثانية
  DateTime _endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  Future<void> loadOverview() async {
    isLoading.value = true;
    errorMessage.value = null;

    try {
      final range = _buildRange();
      overview.value = await repo.getOverview(
        from: range.item1,
        to: range.item2,
      );
      await _loadProfitDetails(from: range.item1, to: range.item2);
    } catch (e) {
      errorMessage.value = e.toString();
      overview.value = null;
      profitDetails.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadAll() async => loadOverview();

  Future<void> _loadProfitDetails({DateTime? from, DateTime? to}) async {
    isLoadingDetails.value = true;
    try {
      final details = await repo.getInvoiceProfitDetails(from: from, to: to);
      profitDetails.assignAll(details);
    } catch (e) {
      profitDetails.clear();
    } finally {
      isLoadingDetails.value = false;
    }
  }

  String get rangeLabel => _rangeLabel();

  Tuple2<DateTime?, DateTime?> _buildRange() {
    final now = DateTime.now();

    switch (selectedRange.value) {
      case ReportDateRange.today:
        // بداية اليوم بالوقت المحلي تحول إلى UTC
        final startOfToday = DateTime(now.year, now.month, now.day, 0, 0, 0).toUtc();
        // نهاية اليوم بالوقت المحلي تحول إلى UTC
        final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).toUtc();
        return Tuple2(startOfToday, endOfToday);

      case ReportDateRange.thisWeek:
        final startOfWeek = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return Tuple2(
          _startOfDay(startOfWeek).toUtc(),
          _endOfDay(endOfWeek).toUtc(),
        );

      case ReportDateRange.thisMonth:
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0);
        return Tuple2(
          _startOfDay(startOfMonth).toUtc(),
          _endOfDay(endOfMonth).toUtc(),
        );

      case ReportDateRange.thisYear:
        final startOfYear = DateTime(now.year, 1, 1);
        final endOfYear = DateTime(now.year, 12, 31);
        return Tuple2(
          _startOfDay(startOfYear).toUtc(),
          _endOfDay(endOfYear).toUtc(),
        );

      case ReportDateRange.custom:
        if (customFrom != null && customTo != null) {
          return Tuple2(
            _startOfDay(customFrom!).toUtc(),
            _endOfDay(customTo!).toUtc(),
          );
        }
        return const Tuple2(null, null);
    }
  }

  void setRange(ReportDateRange range) {
    selectedRange.value = range;

    if (range != ReportDateRange.custom) {
      customFrom = null;
      customTo = null;
      loadOverview();
    }
  }

  void setCustomRange(DateTime from, DateTime to) {
    selectedRange.value = ReportDateRange.custom;
    customFrom = from;
    customTo = to;
    loadOverview();
  }

  Future<void> exportOverviewPdf() async {
    final currentOverview = overview.value;
    if (currentOverview == null) return;

    final doc = pw.Document();

    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
    );

    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Bold.ttf'),
    );

    

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        // --- تعديل: تطبيق الخط العربي واتجاه النص ---
        // نقوم بتحديد اتجاه النص من اليمين لليسار (RTL) عالمياً للصفحة
        textDirection: pw.TextDirection.rtl,
        // نقوم بتعيين الخط العربي كخط أساسي لوثيقة الـ PDF
        theme: pw.ThemeData.withFont(
          base: regular,
          bold: bold,
        ),
        build: (context) {
          return [
            // الآن سيتم عرض العنوان بشكل صحيح تماماً
            pw.Header(level: 0, text: 'التقرير المالي الشامل'),
            pw.SizedBox(height: 10),
            pw.Text('الفترة: ${_rangeLabel()}'),
            pw.SizedBox(height: 16),
            _buildSection('المبيعات', [
              'عدد الفواتير: ${currentOverview.saleInvoiceCount}',
              'إجمالي المبيعات: ${MoneyUtils.formatMoney(currentOverview.saleTotal)}',
              'المدفوع: ${MoneyUtils.formatMoney(currentOverview.salePaid)}',
              'المتبقي: ${MoneyUtils.formatMoney(currentOverview.saleRemaining)}',
            ]),
            _buildSection('المشتريات', [
              'عدد الفواتير: ${currentOverview.purchaseInvoiceCount}',
              'إجمالي المشتريات: ${MoneyUtils.formatMoney(currentOverview.purchaseTotal)}',
              'المدفوع: ${MoneyUtils.formatMoney(currentOverview.purchasePaid)}',
              'المتبقي: ${MoneyUtils.formatMoney(currentOverview.purchaseRemaining)}',
            ]),
            _buildSection('المرتجعات', [
              'عدد مرتجعات المبيعات: ${currentOverview.saleReturnCount}',
              'قيمة مرتجعات المبيعات: ${MoneyUtils.formatMoney(currentOverview.saleReturnTotal)}',
              'عدد مرتجعات المشتريات: ${currentOverview.purchaseReturnCount}',
              'قيمة مرتجعات المشتريات: ${MoneyUtils.formatMoney(currentOverview.purchaseReturnTotal)}',
            ]),
            _buildSection('المصاريف', [
              'عدد العمليات: ${currentOverview.expenseCount}',
              'إجمالي المصاريف: ${MoneyUtils.formatMoney(currentOverview.expenseTotal)}',
            ]),
            _buildSection('الديون', [
              'الديون المستحقة لنا: ${MoneyUtils.formatMoney(currentOverview.debtsOwedToUs)}',
              'الديون المستحقة علينا: ${MoneyUtils.formatMoney(currentOverview.debtsOwedByUs)}',
            ]),
            _buildSection('الأرباح', [
              'الإيرادات الصافية: ${MoneyUtils.formatMoney(currentOverview.revenue)}',
              'التكاليف الصافية: ${MoneyUtils.formatMoney(currentOverview.cost)}',
              'صافي الربح: ${MoneyUtils.formatMoney(currentOverview.profit)}',
            ]),
          ];
        },
      ),
    );

    final bytes = await doc.save();
    // تغيير اسم الملف ليكون بالعربية أيضاً (اختياري)
    await Printing.sharePdf(bytes: bytes, filename: 'التقرير_المالي_الشامل.pdf');
  }

  String _rangeLabel() {
    final range = _buildRange();
    if (range.item1 == null || range.item2 == null) {
      return 'غير محددة';
    }
    return '${_formatDate(range.item1!)} - ${_formatDate(range.item2!)}';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  pw.Widget _buildSection(String title, List<String> lines) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        ...lines.map(
          (line) => pw.Text('• $line', style: const pw.TextStyle(fontSize: 12)),
        ),
        pw.SizedBox(height: 12),
      ],
    );
  }
}

class Tuple2<T1, T2> {
  final T1 item1;
  final T2 item2;

  const Tuple2(this.item1, this.item2);
}
