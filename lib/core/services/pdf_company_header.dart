import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// ترويسة هوية المنشأة المشتركة لفواتير PDF والتقارير والمستندات الرسمية.
class PdfCompanyHeader {
  PdfCompanyHeader._();

  static pw.Widget build({
    required List<String> lines,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    if (lines.isEmpty) return pw.SizedBox();

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines.length; i++)
            pw.Text(
              lines[i],
              style: pw.TextStyle(
                font: i == 0 ? bold : regular,
                fontSize: i == 0 ? 14 : 10,
                color: i == 0 ? PdfColors.grey900 : PdfColors.grey700,
                lineSpacing: 1.2,
              ),
            ),
        ],
      ),
    );
  }
}
