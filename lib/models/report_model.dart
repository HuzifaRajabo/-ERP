// lib/models/report_model.dart

enum ReportDateRange { today, thisWeek, thisMonth, thisYear, custom }

class ReportOverview {
  final int saleInvoiceCount;
  final int saleTotal;
  final int salePaid;
  final int saleRemaining;
  final int saleReturnTotal;
  final int saleReturnCount;
  final int saleNetTotal;

  final int purchaseInvoiceCount;
  final int purchaseTotal;
  final int purchasePaid;
  final int purchaseRemaining;
  final int purchaseReturnTotal;
  final int purchaseReturnCount;
  final int purchaseNetTotal;

  final int expenseCount;
  final int expenseTotal;

  final int debtsOwedToUs;
  final int debtsOwedByUs;
  final int inventoryValue;

  // الأرباح المحاسبية
  final int cogsTotal; // تكلفة البضاعة المباعة
  final int grossProfit; // مجمل الربح = صافي مبيعات - تكلفة
  final int netProfit; // صافي الربح = مجمل الربح - مصاريف

  ReportOverview({
    required this.saleInvoiceCount,
    required this.saleTotal,
    required this.salePaid,
    required this.saleRemaining,
    required this.saleReturnTotal,
    required this.saleReturnCount,
    required this.saleNetTotal,
    required this.purchaseInvoiceCount,
    required this.purchaseTotal,
    required this.purchasePaid,
    required this.purchaseRemaining,
    required this.purchaseReturnTotal,
    required this.purchaseReturnCount,
    required this.purchaseNetTotal,
    required this.expenseCount,
    required this.expenseTotal,
    required this.debtsOwedToUs,
    required this.debtsOwedByUs,
    required this.inventoryValue,
    required this.cogsTotal,
    required this.grossProfit,
    required this.netProfit,
  });

  int get revenue => saleNetTotal;
  int get cost => cogsTotal;
  int get profit => netProfit;
}

/// تفاصيل ربح فاتورة بيع واحدة
class InvoiceProfitDetail {
  final int invoiceId;
  final String invoiceNumber;
  final String partyName;
  final String createdAt;
  final int saleAmount; // صافي البيع بعد المرتجعات
  final int costAmount; // تكلفة البضاعة
  final int profit; // الربح = بيع - تكلفة
  final double margin; // هامش الربح %

  InvoiceProfitDetail({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.partyName,
    required this.createdAt,
    required this.saleAmount,
    required this.costAmount,
    required this.profit,
    required this.margin,
  });
}
