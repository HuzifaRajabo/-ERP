import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/expired_return_model.dart';
import '../../models/waste_model.dart';
import '../utils/money_utils.dart';
import 'company_profile_service.dart';
import 'pdf_company_header.dart';

class StockDocumentPdfService {
  static Future<void> exportWaste(WasteWithItems data) async {
    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final boldFontData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    final ttf = pw.Font.ttf(fontData);
    final bold = pw.Font.ttf(boldFontData);
    final identityLines =
        await CompanyProfileService.headerLinesForDocument();
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: ttf, bold: bold),
        build: (context) => [
          PdfCompanyHeader.build(
            lines: identityLines,
            regular: ttf,
            bold: bold,
          ),
          if (identityLines.isNotEmpty) pw.SizedBox(height: 8),
          pw.Text('عملية إتلاف ${data.record.wasteNumber}',
              style: pw.TextStyle(font: bold, fontSize: 18)),
          pw.SizedBox(height: 8),
          pw.Text('المستودع: ${data.record.warehouseName ?? ''}'),
          pw.Text('السبب: ${data.record.reason}'),
          if (data.record.createdAt != null)
            pw.Text('التاريخ: ${data.record.createdAt}'),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['المنتج', 'الدفعة', 'الكمية', 'التكلفة'],
            data: [
              for (final item in data.items)
                [
                  item.productNameSnapshot,
                  item.batchNumberSnapshot ?? '-',
                  '${item.quantity} ${item.unitNameSnapshot ?? ''}',
                  MoneyUtils.formatMoney(item.lineCost),
                ],
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'إجمالي الإتلاف: ${MoneyUtils.formatMoney(data.record.totalCost)}',
            style: pw.TextStyle(font: bold, fontSize: 14),
          ),
        ],
      ),
    );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: '${data.record.wasteNumber}.pdf',
    );
  }

  static Future<void> exportExpiredReturn(ExpiredReturnWithItems data) async {
    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final boldFontData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    final ttf = pw.Font.ttf(fontData);
    final bold = pw.Font.ttf(boldFontData);
    final r = data.record;
    final identityLines =
        await CompanyProfileService.headerLinesForDocument();
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: ttf, bold: bold),
        build: (context) => [
          PdfCompanyHeader.build(
            lines: identityLines,
            regular: ttf,
            bold: bold,
          ),
          if (identityLines.isNotEmpty) pw.SizedBox(height: 8),
          pw.Text('مرتجع منتهي الصلاحية ${r.returnNumber}',
              style: pw.TextStyle(font: bold, fontSize: 18)),
          pw.SizedBox(height: 8),
          pw.Text('المورد: ${r.partyNameSnapshot}'),
          pw.Text('المستودع: ${r.warehouseName ?? ''}'),
          if (r.createdAt != null) pw.Text('التاريخ: ${r.createdAt}'),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['المنتج', 'الدفعة', 'الصلاحية', 'الكمية', 'التكلفة'],
            data: [
              for (final item in data.items)
                [
                  item.productNameSnapshot,
                  item.batchNumberSnapshot ?? '-',
                  item.expiryDateSnapshot ?? '-',
                  '${item.quantity} ${item.unitNameSnapshot ?? ''}',
                  MoneyUtils.formatMoney(item.lineCost),
                ],
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text('تكلفة المخزون: ${MoneyUtils.formatMoney(r.inventoryCost)}'),
          pw.Text('التعويض: ${MoneyUtils.formatMoney(r.compensationAmount)}'),
          pw.Text(
            'صافي الخسارة: ${MoneyUtils.formatMoney(r.netLoss)}',
            style: pw.TextStyle(font: bold, fontSize: 14),
          ),
        ],
      ),
    );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: '${r.returnNumber}.pdf',
    );
  }
}
