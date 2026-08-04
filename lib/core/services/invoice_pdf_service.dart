// lib/core/services/invoice_pdf_service.dart
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/invoice_model.dart';
import '../../models/invoice_item_model.dart';
import '../../models/payment_model.dart';
import '../../models/return_model.dart';
import '../utils/money_utils.dart';

class InvoicePdfService {
  // ====================================================================
  // الدالة الرئيسية — تولّد PDF وتفتح نافذة المشاركة/الطباعة
  // ====================================================================

  static Future<void> exportInvoice({
    required InvoiceModel invoice,
    required List<InvoiceItemModel> items,
    required List<PaymentModel> payments,
    required List<ReturnModel> returns,
  }) async {
    final pdfBytes = await _buildPdf(
      invoice: invoice,
      items: items,
      payments: payments,
      returns: returns,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: '${invoice.invoiceNumber}.pdf',
    );
  }

  // ====================================================================
  // بناء الـ PDF
  // ====================================================================

  static Future<Uint8List> _buildPdf({
    required InvoiceModel invoice,
    required List<InvoiceItemModel> items,
    required List<PaymentModel> payments,
    required List<ReturnModel> returns,
  }) async {
    // ── تحميل الخط العربي ──
    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final boldFontData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    final ttf      = pw.Font.ttf(fontData);
    final ttfBold  = pw.Font.ttf(boldFontData);

    final isSale = invoice.type == InvoiceType.sale;

    // حساب إجمالي المرتجعات
    final totalReturns = returns.fold(0, (s, r) => s + r.totalAmount);
    final netTotal     = invoice.originalTotalAmount - totalReturns;
    final balance      = netTotal - invoice.paidAmount;

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [

          // ── رأس الفاتورة ──
          _buildHeader(invoice, isSale, ttfBold),
          pw.SizedBox(height: 16),

          // ── معلومات الطرف ──
          _buildPartyInfo(invoice, isSale, ttf, ttfBold),
          pw.SizedBox(height: 16),

          // ── جدول الأسطر ──
          _buildItemsTable(items, ttf, ttfBold),
          pw.SizedBox(height: 16),

          // ── الملاحظات ──
          if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
            _buildNotes(invoice.notes!, ttf, ttfBold),
            pw.SizedBox(height: 16),
          ],

          // ── الدفعات ──
          if (payments.isNotEmpty) ...[
            _buildPayments(payments, ttf, ttfBold),
            pw.SizedBox(height: 16),
          ],

          // ── المرتجعات ──
          if (returns.isNotEmpty) ...[
            _buildReturns(returns, ttf, ttfBold),
            pw.SizedBox(height: 16),
          ],

          // ── الإجمالي ──
          _buildTotals(
            invoice:      invoice,
            totalReturns: totalReturns,
            netTotal:     netTotal,
            balance:      balance,
            isSale:       isSale,
            ttf:          ttf,
            bold:      ttfBold,
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ====================================================================
  // رأس الفاتورة
  // ====================================================================

  static pw.Widget _buildHeader(
    InvoiceModel invoice,
    bool isSale,
    pw.Font bold,
  ) {
    final typeLabel = isSale ? 'فاتورة مبيعات' : 'فاتورة مشتريات';
    final color     = isSale ? PdfColors.green800 : PdfColors.orange800;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: isSale
            ? PdfColors.green50
            : PdfColors.orange50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(
          color: isSale ? PdfColors.green200 : PdfColors.orange200,
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                invoice.invoiceNumber,
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 20,
                  color: color,
                ),
              ),
              if (invoice.createdAt != null)
                pw.Text(
                  invoice.createdAt!,
                  style: pw.TextStyle(
                    color: PdfColors.grey600,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 14, vertical: 6),
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: pw.BorderRadius.circular(20),
            ),
            child: pw.Text(
              typeLabel,
              style: pw.TextStyle(
                font: bold,
                color: PdfColors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // معلومات الطرف
  // ====================================================================

  static pw.Widget _buildPartyInfo(
    InvoiceModel invoice,
    bool isSale,
    pw.Font ttf,
    pw.Font bold,
  ) {
    final title = isSale ? 'العميل' : 'المورد';

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  font: bold,
                  color: PdfColors.blue800,
                  fontSize: 12)),
          pw.SizedBox(height: 6),
          _pdfRow('الاسم', invoice.partyNameSnapshot, ttf, bold),
          if (invoice.partyAddressSnapshot.isNotEmpty)
            _pdfRow('العنوان', invoice.partyAddressSnapshot, ttf, bold),
        ],
      ),
    );
  }

  // ====================================================================
  // جدول الأسطر
  // ====================================================================

  static pw.Widget _buildItemsTable(
    List<InvoiceItemModel> items,
    pw.Font ttf,
    pw.Font bold,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
      },
      children: [
        // رأس الجدول
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _tableCell('المنتج',      bold, isHeader: true),
            _tableCell('الكمية',      bold, isHeader: true),
            _tableCell('سعر القطعة', bold, isHeader: true),
            _tableCell('الإجمالي',   bold, isHeader: true),
          ],
        ),
        // الأسطر
        ...items.map((item) => pw.TableRow(
          children: [
            _tableCell(item.productNameSnapshot, ttf),
            _tableCell(
              item.quantity % 1 == 0
                  ? item.quantity.toInt().toString()
                  : item.quantity.toStringAsFixed(2),
              ttf,
            ),
            _tableCell(MoneyUtils.formatMoney(item.unitPrice), ttf),
            _tableCell(
              MoneyUtils.formatMoney(item.lineTotal),
              ttf,
              isBold: true,
            ),
          ],
        )),
      ],
    );
  }

  // ====================================================================
  // الملاحظات
  // ====================================================================

  static pw.Widget _buildNotes(
      String notes, pw.Font ttf, pw.Font bold) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.purple50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.purple200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('ملاحظات',
              style: pw.TextStyle(
                  font: bold,
                  color: PdfColors.purple800,
                  fontSize: 11)),
          pw.SizedBox(height: 4),
          pw.Text(notes,
              style: pw.TextStyle(font: ttf, fontSize: 11)),
        ],
      ),
    );
  }

  // ====================================================================
  // سجل الدفعات
  // ====================================================================

  static pw.Widget _buildPayments(
    List<PaymentModel> payments,
    pw.Font ttf,
    pw.Font bold,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('سجل الدفعات',
            style: pw.TextStyle(
                font: bold, fontSize: 13, color: PdfColors.green800)),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _tableCell('المبلغ',     bold, isHeader: true),
                _tableCell('ملاحظات',    bold, isHeader: true),
                _tableCell('التاريخ',    bold, isHeader: true),
              ],
            ),
            ...payments.map((p) => pw.TableRow(
              children: [
                _tableCell(' ${MoneyUtils.formatMoney(p.amount)}', ttf,
                    color: PdfColors.green700),
                _tableCell(p.notes ?? '-', ttf),
                _tableCell(p.createdAt ?? '-', ttf),
              ],
            )),
          ],
        ),
      ],
    );
  }

  // ====================================================================
  // سجل المرتجعات
  // ====================================================================

  static pw.Widget _buildReturns(
    List<ReturnModel> returns,
    pw.Font ttf,
    pw.Font bold,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('سجل المرتجعات',
            style: pw.TextStyle(
                font: bold, fontSize: 13, color: PdfColors.purple800)),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _tableCell('رقم المرتجع', bold, isHeader: true),
                _tableCell('القيمة',       bold, isHeader: true),
                _tableCell('التاريخ',      bold, isHeader: true),
              ],
            ),
            ...returns.map((r) => pw.TableRow(
              children: [
                _tableCell(r.returnNumber, ttf),
                _tableCell('- ${MoneyUtils.formatMoney(r.totalAmount)}', ttf,
                    color: PdfColors.purple700),
                _tableCell(r.createdAt ?? '-', ttf),
              ],
            )),
          ],
        ),
      ],
    );
  }

  // ====================================================================
  // قسم الإجمالي والرصيد
  // ====================================================================

  static pw.Widget _buildTotals({
    required InvoiceModel invoice,
    required int totalReturns,
    required int netTotal,
    required int balance,
    required bool isSale,
    required pw.Font ttf,
    required pw.Font bold,
  }) {
    final balanceLabel = balance > 0
        ? 'المتبقي'
        : balance < 0
            ? (isSale ? 'المستحق للعميل' : 'المستحق لنا من المورد')
            : 'مسواة بالكامل';

    final balanceColor = balance > 0
        ? PdfColors.red700
        : balance < 0
            ? PdfColors.blue800
            : PdfColors.green700;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          // الإجمالي الأصلي
          _totalRow(
            'إجمالي الفاتورة الأصلي',
            ' ${MoneyUtils.formatMoney(invoice.originalTotalAmount)}',
            ttf, bold,
          ),
          if (totalReturns > 0)
            _totalRow(
              'إجمالي المرتجعات',
              '- ${MoneyUtils.formatMoney(totalReturns)}',
              ttf, bold,
              valueColor: PdfColors.purple700,
            ),
          pw.Divider(color: PdfColors.grey400, thickness: 1),
          _totalRow(
            'صافي الفاتورة',
            ' ${MoneyUtils.formatMoney(netTotal)}',
            ttf, bold,
            isBold: true,
            valueColor: isSale ? PdfColors.green700 : PdfColors.orange700,
          ),
          _totalRow(
            'المدفوع',
            ' ${MoneyUtils.formatMoney(invoice.paidAmount)}',
            ttf, bold,
            valueColor: PdfColors.green600,
          ),
          pw.Divider(color: PdfColors.grey400, thickness: 1.5),
          _totalRow(
            balanceLabel,
            ' ${MoneyUtils.formatMoney(balance.abs())}',
            ttf, bold,
            isBold: true,
            valueColor: balanceColor,
            bgColor: balance > 0
                ? PdfColors.red50
                : balance < 0
                    ? PdfColors.blue50
                    : PdfColors.green50,
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // Helpers
  // ====================================================================

  static pw.Widget _tableCell(
    String text,
    pw.Font font, {
    bool isHeader = false,
    bool isBold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.right,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader || isBold
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          color: color ?? (isHeader ? PdfColors.grey700 : PdfColors.black),
        ),
      ),
    );
  }

  static pw.Widget _pdfRow(
    String label,
    String value,
    pw.Font ttf,
    pw.Font bold,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 60,
            child: pw.Text(label,
                style: pw.TextStyle(
                    font: ttf,
                    color: PdfColors.grey600,
                    fontSize: 11)),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(
                    font: bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _totalRow(
    String label,
    String value,
    pw.Font ttf,
    pw.Font bold, {
    bool isBold = false,
    PdfColor? valueColor,
    PdfColor? bgColor,
  }) {
    return pw.Container(
      color: bgColor,
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                font: isBold ? bold : ttf,
                fontSize: isBold ? 13 : 11,
                color: PdfColors.grey700,
              )),
          pw.Text(value,
              style: pw.TextStyle(
                font: isBold ? bold : ttf,
                fontSize: isBold ? 15 : 11,
                color: valueColor ?? PdfColors.black,
              )),
        ],
      ),
    );
  }
}