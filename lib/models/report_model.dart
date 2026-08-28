// lib/models/report_model.dart

enum ReportDateRange { today, thisWeek, thisMonth, thisYear, custom }

class ReportMath {
  const ReportMath._();

  static int netSales(int grossSales, int salesReturns) =>
      grossSales - salesReturns;

  static int grossProfit(int netSales, int cogs) => netSales - cogs;

  static int netProfit(int grossProfit, int expenses) => grossProfit - expenses;

  static int inventoryValue(double quantity, double unitCost) =>
      (quantity * unitCost).round();
}

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
  final List<WarehouseReportSummary> warehouseSummaries;

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
    this.warehouseSummaries = const [],
  });

  int get revenue => saleNetTotal;
  int get cost => cogsTotal;
  int get profit => netProfit;
}

class WarehouseReportSummary {
  final int warehouseId;
  final String warehouseName;
  final int sales;
  final int salesReturns;
  final int cogs;
  final int grossProfit;
  final int inventoryValue;

  const WarehouseReportSummary({
    required this.warehouseId,
    required this.warehouseName,
    required this.sales,
    this.salesReturns = 0,
    required this.cogs,
    required this.grossProfit,
    required this.inventoryValue,
  });

  int get netSales => sales - salesReturns;
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
