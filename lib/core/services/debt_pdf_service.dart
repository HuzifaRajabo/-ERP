import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/debt_report_model.dart';
import '../utils/app_dates.dart';
import '../utils/money_utils.dart';
import 'company_profile_service.dart';
import 'pdf_company_header.dart';

class DebtPdfService {
  DebtPdfService._();

  static Future<void> exportTabReport(DebtTabReport report) async {
    final bytes = await _buildPdf(
      title: report.title,
      directionLabel: report.directionLabel,
      emptyMessage: report.emptyMessage,
      grandRemaining: report.grandRemaining,
      parties: report.parties,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: report.owedToUs
          ? 'تقرير_ديون_الزبائن.pdf'
          : 'تقرير_ديون_الموردين.pdf',
    );
  }

  static Future<void> exportPartyStatement(PartyDebtStatement statement) async {
    final bytes = await _buildPdf(
      title: 'كشف حساب — ${statement.partyName}',
      directionLabel: statement.owedToUs ? 'مستحق لنا' : 'مستحق لهم',
      emptyMessage: 'لا توجد مستحقات لهذا الطرف',
      grandRemaining: statement.totalRemaining,
      parties: [statement],
      isPartyStatement: true,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'كشف_حساب_${statement.partyName}.pdf',
    );
  }

  static Future<Uint8List> _buildPdf({
    required String title,
    required String directionLabel,
    required String emptyMessage,
    required int grandRemaining,
    required List<PartyDebtStatement> parties,
    bool isPartyStatement = false,
  }) async {
    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final boldFontData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    final regular = pw.Font.ttf(fontData);
    final bold = pw.Font.ttf(boldFontData);
    final identityLines =
        await CompanyProfileService.headerLinesForDocument();
    final exportedAt = AppDates.formatDisplay(
      DateTime.now().toIso8601String(),
    );

    final hasLines = parties.any((party) => party.lines.isNotEmpty);
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        margin: const pw.EdgeInsets.fromLTRB(34, 34, 34, 38),
        build: (context) {
          final children = <pw.Widget>[
            PdfCompanyHeader.build(
              lines: identityLines,
              regular: regular,
              bold: bold,
            ),
            if (identityLines.isNotEmpty) pw.SizedBox(height: 8),
            pw.Text(
              title,
              style: pw.TextStyle(font: bold, fontSize: 18),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'الجهة: $directionLabel',
              style: pw.TextStyle(
                font: regular,
                fontSize: 11,
                color: PdfColors.grey700,
              ),
            ),
            pw.Text(
              'تاريخ التصدير: $exportedAt',
              style: pw.TextStyle(
                font: regular,
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
            pw.SizedBox(height: 12),
          ];

          if (!hasLines) {
            children.add(pw.Text(emptyMessage));
            return children;
          }

          for (final party in parties) {
            children.add(_partyBlock(party, regular, bold, isPartyStatement));
            children.add(pw.SizedBox(height: 12));
          }

          if (!isPartyStatement) {
            children.add(
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      directionLabel,
                      style: pw.TextStyle(font: bold, fontSize: 12),
                    ),
                    pw.Text(
                      MoneyUtils.formatMoney(grandRemaining),
                      style: pw.TextStyle(font: bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          return children;
        },
      ),
    );
    return doc.save();
  }

  static pw.Widget _partyBlock(
    PartyDebtStatement party,
    pw.Font regular,
    pw.Font bold,
    bool isPartyStatement,
  ) {
    final phone = party.partyPhone?.trim();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (!isPartyStatement) ...[
          pw.Text(party.partyName, style: pw.TextStyle(font: bold, fontSize: 13)),
          if (phone != null && phone.isNotEmpty)
            pw.Text(
              phone,
              style: pw.TextStyle(
                font: regular,
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          pw.Text(
            party.invoiceCount > 0
                ? '${party.invoiceCount} فاتورة غير مسددة'
                : 'بدون فواتير غير مسددة',
            style: pw.TextStyle(
              font: regular,
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 6),
        ] else ...[
          if (phone != null && phone.isNotEmpty)
            pw.Text(
              phone,
              style: pw.TextStyle(
                font: regular,
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _summaryChip('الإجمالي', party.totalAmount, regular, bold),
              _summaryChip('المدفوع', party.totalPaid, regular, bold),
              _summaryChip('المتبقي', party.totalRemaining, regular, bold),
            ],
          ),
          pw.SizedBox(height: 8),
        ],
        if (party.lines.isEmpty)
          pw.Text(
            'لا توجد مستحقات',
            style: pw.TextStyle(font: regular, fontSize: 10),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: const [
              'الرقم',
              'النوع',
              'التاريخ',
              'الإجمالي',
              'المدفوع',
              'المتبقي',
            ],
            data: [
              for (final line in party.lines)
                [
                  line.documentNumber,
                  line.sourceTypeLabel,
                  _displayDate(line.date),
                  MoneyUtils.formatMoney(line.totalAmount),
                  MoneyUtils.formatMoney(line.paidAmount),
                  MoneyUtils.formatMoney(line.remaining),
                ],
            ],
            headerStyle: pw.TextStyle(font: bold, fontSize: 9),
            cellStyle: pw.TextStyle(font: regular, fontSize: 8),
            cellAlignment: pw.Alignment.centerRight,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          ),
        if (!isPartyStatement) ...[
          pw.SizedBox(height: 4),
          pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              'المتبقي: ${MoneyUtils.formatMoney(party.totalRemaining)}',
              style: pw.TextStyle(font: bold, fontSize: 11),
            ),
          ),
        ],
      ],
    );
  }

  static pw.Widget _summaryChip(
    String label,
    int amount,
    pw.Font regular,
    pw.Font bold,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: regular,
            fontSize: 9,
            color: PdfColors.grey600,
          ),
        ),
        pw.Text(
          MoneyUtils.formatMoney(amount),
          style: pw.TextStyle(font: bold, fontSize: 11),
        ),
      ],
    );
  }

  static String _displayDate(String? value) {
    if (value == null || value.trim().isEmpty) return '-';
    final formatted = AppDates.formatDisplay(value);
    return formatted.isEmpty ? '-' : formatted;
  }
}
