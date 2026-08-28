// lib/views/report/report_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/utils/money_utils.dart';
import '../../controllers/report_controller.dart';
import '../../models/report_model.dart';

class ReportScreen extends GetView<ReportController> {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('التقارير المالية'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: controller.exportOverviewPdf,
            ),
          ],
          bottom: const TabBar(
            isScrollable: false,
            tabs: [
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'الملخص'),
              Tab(icon: Icon(Icons.receipt_long_outlined), text: 'المبيعات'),
              Tab(icon: Icon(Icons.trending_up_outlined), text: 'الأرباح'),
            ],
          ),
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.errorMessage.value != null) {
            return _ErrorView(
              message: controller.errorMessage.value!,
              onRetry: controller.loadAll,
            );
          }
          final ov = controller.overview.value;
          if (ov == null) {
            return const Center(child: Text('لا توجد بيانات'));
          }

          return Column(
            children: [
              _DateRangeBar(controller: controller),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Obx(
                  () => Text(
                    controller.rangeLabel,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  children: [
                    _SummaryTab(ov: ov),
                    _SalesPurchasesTab(ov: ov),
                    _ProfitLossTab(ov: ov),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ==============================
// شريط الفترة
// ==============================
class _DateRangeBar extends StatelessWidget {
  final ReportController controller;
  const _DateRangeBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final labels = {
      ReportDateRange.today: 'اليوم',
      ReportDateRange.thisWeek: 'الأسبوع',
      ReportDateRange.thisMonth: 'الشهر',
      ReportDateRange.thisYear: 'السنة',
      ReportDateRange.custom: 'مخصصة',
    };
    return Obx(
      () => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: ReportDateRange.values.map((r) {
            final sel = controller.selectedRange.value == r;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: () => r == ReportDateRange.custom
                    ? _pickRange(context)
                    : controller.setRange(r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: sel ? Colors.blue : Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Text(
                    labels[r]!,
                    style: TextStyle(
                      color: sel ? Colors.white : Colors.blue,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final res = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 30)),
        end: now,
      ),
    );
    if (res != null) {
      controller.setCustomRange(res.start, res.end);
    }
  }
}

// ==============================
// Tab 1: الملخص
// ==============================
class _SummaryTab extends StatelessWidget {
  final ReportOverview ov;
  const _SummaryTab({required this.ov});

  @override
  Widget build(BuildContext context) {
    final isProfit = ov.netProfit >= 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // بطاقات KPI
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              _KpiCard(
                label: 'صافي الربح',
                value: ov.netProfit,
                icon: Icons.trending_up,
                color: isProfit ? Colors.green : Colors.red,
                prefix: isProfit ? '+' : '',
              ),
              _KpiCard(
                label: 'النقدية المقبوضة',
                value: ov.salePaid,
                icon: Icons.payments_outlined,
                color: Colors.blue,
              ),
              _KpiCard(
                label: 'الذمم المدينة',
                value: ov.debtsOwedToUs,
                icon: Icons.inbox_outlined,
                color: Colors.orange,
                subtitle: 'مستحق لنا',
              ),
              _KpiCard(
                label: 'الذمم الدائنة',
                value: ov.debtsOwedByUs,
                icon: Icons.outbox_outlined,
                color: Colors.red,
                subtitle: 'مستحق علينا',
              ),
            ],
          ),
          const SizedBox(height: 20),

          const _SectionTitle('ملخص النشاط'),
          const SizedBox(height: 10),
          _InfoTable(
            rows: [
              _InfoRow('صافي المبيعات', ov.saleNetTotal, Colors.green),
              _InfoRow('صافي المشتريات', ov.purchaseNetTotal, Colors.orange),
              _InfoRow(
                'تكلفة البضاعة المباعة',
                ov.cogsTotal,
                Colors.deepOrange,
              ),
              _InfoRow(
                'مجمل الربح',
                ov.grossProfit,
                ov.grossProfit >= 0 ? Colors.green : Colors.red,
                bold: true,
              ),
              _InfoRow('المصاريف', ov.expenseTotal, Colors.red),
              _InfoRow('قيمة المخزون', ov.inventoryValue, Colors.teal),
              _InfoRow(
                'صافي الربح',
                ov.netProfit,
                isProfit ? Colors.green[800]! : Colors.red[800]!,
                bold: true,
              ),
            ],
          ),
          if (ov.warehouseSummaries.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _SectionTitle('أداء المستودعات'),
            const SizedBox(height: 10),
            ...ov.warehouseSummaries.map(
              (warehouse) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _WarehouseSummaryCard(summary: warehouse),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WarehouseSummaryCard extends StatelessWidget {
  final WarehouseReportSummary summary;

  const _WarehouseSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.warehouseName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          _InfoTable(
            rows: [
              _InfoRow('إجمالي المبيعات', summary.sales, Colors.green),
              _InfoRow('مرتجعات المبيعات', summary.salesReturns, Colors.purple),
              _InfoRow('صافي المبيعات', summary.netSales, Colors.green),
              _InfoRow('تكلفة البضاعة', summary.cogs, Colors.deepOrange),
              _InfoRow('مجمل الربح', summary.grossProfit, Colors.blue),
              _InfoRow('قيمة المخزون', summary.inventoryValue, Colors.teal),
            ],
          ),
        ],
      ),
    );
  }
}

// ==============================
// Tab 2: المبيعات والمشتريات
// ==============================
class _SalesPurchasesTab extends StatelessWidget {
  final ReportOverview ov;
  const _SalesPurchasesTab({required this.ov});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader('المبيعات', Icons.arrow_upward_rounded, Colors.green),
          const SizedBox(height: 10),
          _InfoTable(
            rows: [
              _InfoRow(
                'عدد الفواتير',
                ov.saleInvoiceCount,
                Colors.grey,
                isCount: true,
              ),
              _InfoRow('إجمالي الفواتير', ov.saleTotal, null),
              _InfoRow(
                'المرتجعات',
                ov.saleReturnTotal,
                Colors.purple,
                prefix: '-',
              ),
              _InfoRow(
                'صافي المبيعات',
                ov.saleNetTotal,
                Colors.green,
                bold: true,
              ),
              _InfoRow('المقبوض من العملاء', ov.salePaid, Colors.blue),
              _InfoRow('الذمم على العملاء', ov.debtsOwedToUs, Colors.orange),
            ],
          ),
          const SizedBox(height: 20),

          _SectionHeader(
            'المشتريات',
            Icons.arrow_downward_rounded,
            Colors.orange,
          ),
          const SizedBox(height: 10),
          _InfoTable(
            rows: [
              _InfoRow(
                'عدد الفواتير',
                ov.purchaseInvoiceCount,
                Colors.grey,
                isCount: true,
              ),
              _InfoRow('إجمالي المشتريات', ov.purchaseTotal, null),
              _InfoRow(
                'المرتجعات',
                ov.purchaseReturnTotal,
                Colors.teal,
                prefix: '-',
              ),
              _InfoRow(
                'صافي المشتريات',
                ov.purchaseNetTotal,
                Colors.orange,
                bold: true,
              ),
              _InfoRow('المدفوع للموردين', ov.purchasePaid, Colors.blue),
              _InfoRow('الذمم للموردين', ov.debtsOwedByUs, Colors.red),
            ],
          ),
        ],
      ),
    );
  }
}

// ==============================
// Tab 3: الأرباح والخسائر
// ==============================
class _ProfitLossTab extends GetView<ReportController> {
  final ReportOverview ov;
  const _ProfitLossTab({required this.ov});

  @override
  Widget build(BuildContext context) {
    final grossIsProfit = ov.grossProfit >= 0;
    final netIsProfit = ov.netProfit >= 0;
    final margin = ov.saleNetTotal > 0
        ? (ov.netProfit / ov.saleNetTotal * 100)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // قائمة الدخل
          const _SectionTitle('قائمة الدخل'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _PLRow(
                  'صافي المبيعات',
                  ov.saleNetTotal,
                  Colors.green,
                  bold: true,
                ),
                _Divider(),
                _PLRow(
                  '(-) تكلفة البضاعة المباعة',
                  ov.cogsTotal,
                  Colors.deepOrange,
                  prefix: '-',
                ),
                _Divider(thick: true),
                _PLRow(
                  '= مجمل الربح',
                  ov.grossProfit,
                  grossIsProfit ? Colors.green[700]! : Colors.red,
                  bold: true,
                  highlight: true,
                ),
                _Divider(),
                _PLRow(
                  '(-) المصاريف التشغيلية',
                  ov.expenseTotal,
                  Colors.red,
                  prefix: '-',
                ),
                _Divider(thick: true),
                _PLRow(
                  '= صافي الربح',
                  ov.netProfit,
                  netIsProfit ? Colors.green[800]! : Colors.red[800]!,
                  bold: true,
                  highlight: true,
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // مؤشرات
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'هامش الربح',
                  value: '${margin.toStringAsFixed(1)}%',
                  icon: Icons.percent,
                  color: netIsProfit ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: 'عدد فواتير البيع',
                  value: '${ov.saleInvoiceCount}',
                  icon: Icons.receipt_outlined,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // جدول تفاصيل الأرباح
          const _SectionTitle('تفاصيل الأرباح لكل فاتورة'),
          const SizedBox(height: 10),
          Obx(() {
            if (controller.isLoadingDetails.value) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.profitDetails.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  'لا توجد فواتير بيع',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  // رأس الجدول
                  Container(
                    color: Colors.grey[50],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'الفاتورة',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'صافي البيع',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'التكلفة',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'الربح',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // الصفوف
                  ...controller.profitDetails.map((d) {
                    final isP = d.profit >= 0;
                    return InkWell(
                      onTap: () => Get.toNamed(
                        '/invoice-details',
                        arguments: d.invoiceId,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade100),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d.invoiceNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    d.partyName,
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                MoneyUtils.formatMoney(d.saleAmount),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                MoneyUtils.formatMoney(d.costAmount),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    isP
                                        ? '+${MoneyUtils.formatMoney(d.profit)}'
                                        : MoneyUtils.formatMoney(d.profit),
                                    style: TextStyle(
                                      color: isP ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${d.margin.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      color: isP
                                          ? Colors.green[300]
                                          : Colors.red[300],
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ==============================
// Widgets المساعدة
// ==============================

class _InfoRow {
  final String label;
  final int value;
  final Color? color;
  final String prefix;
  final bool bold;
  final bool isCount;

  const _InfoRow(
    this.label,
    this.value,
    this.color, {
    this.prefix = '',
    this.bold = false,
    this.isCount = false,
  });
}

class _InfoTable extends StatelessWidget {
  final List<_InfoRow> rows;
  const _InfoTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: rows.asMap().entries.map((e) {
          final r = e.value;
          final isLast = e.key == rows.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  r.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: r.bold ? FontWeight.bold : FontWeight.normal,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  r.isCount
                      ? '${r.value}'
                      : '${r.prefix}${MoneyUtils.formatMoney(r.value)}',
                  style: TextStyle(
                    color: r.color ?? Colors.black87,
                    fontWeight: r.bold ? FontWeight.bold : FontWeight.w500,
                    fontSize: r.bold ? 15 : 13,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final String prefix;
  final String? subtitle;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.prefix = '',
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            prefix.isNotEmpty && value >= 0
                ? '$prefix${MoneyUtils.formatMoney(value)}'
                : MoneyUtils.formatMoney(value),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 19,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: TextStyle(color: color.withOpacity(0.6), fontSize: 10),
            ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ],
      ),
    );
  }
}

class _PLRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final String prefix;
  final bool bold;
  final bool highlight;
  final bool isLast;

  const _PLRow(
    this.label,
    this.value,
    this.color, {
    this.prefix = '',
    this.bold = false,
    this.highlight = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: highlight ? color.withOpacity(0.05) : Colors.transparent,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(12))
            : BorderRadius.zero,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: bold ? Colors.black87 : Colors.grey[700],
            ),
          ),
          Text(
            '$prefix${MoneyUtils.formatMoney(value)}',
            style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: bold ? 16 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool thick;
  const _Divider({this.thick = false});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: thick ? 2 : 1,
      color: thick ? Colors.grey.shade300 : Colors.grey.shade100,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader(this.title, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
