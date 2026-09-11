import '../models/invoice_model.dart';

enum DebtSourceKind { invoice, packagingCharge }

class DebtSourceLine {
  final DebtSourceKind kind;
  final String documentNumber;
  final String sourceTypeLabel;
  final String? date;
  final int totalAmount;
  final int paidAmount;

  const DebtSourceLine({
    required this.kind,
    required this.documentNumber,
    required this.sourceTypeLabel,
    this.date,
    required this.totalAmount,
    required this.paidAmount,
  });

  int get remaining {
    final value = totalAmount - paidAmount;
    return value < 0 ? 0 : value;
  }
}

class PartyDebtStatement {
  final int partyId;
  final String partyName;
  final String? partyPhone;
  final bool owedToUs;
  final List<DebtSourceLine> lines;

  const PartyDebtStatement({
    required this.partyId,
    required this.partyName,
    this.partyPhone,
    required this.owedToUs,
    required this.lines,
  });

  int get invoiceCount =>
      lines.where((line) => line.kind == DebtSourceKind.invoice).length;

  int get totalAmount => lines.fold(0, (sum, line) => sum + line.totalAmount);

  int get totalPaid => lines.fold(0, (sum, line) => sum + line.paidAmount);

  int get totalRemaining => lines.fold(0, (sum, line) => sum + line.remaining);
}

class DebtTabReport {
  final bool owedToUs;
  final List<PartyDebtStatement> parties;

  const DebtTabReport({
    required this.owedToUs,
    required this.parties,
  });

  factory DebtTabReport.fromStatements({
    required bool owedToUs,
    required List<PartyDebtStatement> parties,
  }) {
    final sorted = [...parties]
      ..sort((a, b) => b.totalRemaining.compareTo(a.totalRemaining));
    return DebtTabReport(owedToUs: owedToUs, parties: sorted);
  }

  int get grandRemaining =>
      parties.fold(0, (sum, party) => sum + party.totalRemaining);

  String get title =>
      owedToUs ? 'تقرير ديون الزبائن' : 'تقرير ديون الموردين';

  String get directionLabel => owedToUs ? 'مستحق لنا' : 'مستحق لهم';

  String get emptyMessage =>
      owedToUs ? 'لا توجد ديون على الزبائن' : 'لا توجد ديون للموردين';
}

InvoiceType debtInvoiceType({required bool owedToUs}) =>
    owedToUs ? InvoiceType.sale : InvoiceType.purchase;

class PartyDebtSummary {
  final int partyId;
  final String partyName;
  final String? partyPhone;
  final int invoiceCount;
  final int invoiceRemaining;
  final int packagingCompensationRemaining;

  PartyDebtSummary({
    required this.partyId,
    required this.partyName,
    this.partyPhone,
    required this.invoiceCount,
    required this.invoiceRemaining,
    this.packagingCompensationRemaining = 0,
  });

  int get totalRemaining => invoiceRemaining + packagingCompensationRemaining;
}
