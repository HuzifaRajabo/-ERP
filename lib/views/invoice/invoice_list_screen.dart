import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/invoice_controller.dart';
import '../../core/utils/money_utils.dart';
import '../../models/invoice_model.dart';

class InvoiceListScreen extends GetView<InvoiceController> {
  const InvoiceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الفواتير',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            SizedBox(height: 2),
            Text(
              'إدارة المبيعات والمشتريات',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        actions: [
          Obx(
                () => IconButton(
              tooltip: 'تحديث',
              onPressed: controller.isLoading
                  ? null
                  : controller.refreshInvoices,
              icon: controller.isLoading
                  ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Icon(Icons.refresh_rounded),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const _InvoiceHeader(),
          const _InvoiceFilters(),
          const Expanded(
            child: _InvoiceList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 5,
        onPressed: () async {
          await controller.startNewInvoice();
          Get.toNamed('/invoice-form');
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'فاتورة جديدة',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HEADER
// ============================================================

class _InvoiceHeader extends GetView<InvoiceController> {
  const _InvoiceHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: _HeaderStat(
              title: 'الفواتير',
              value: Obx(
                    () => Text(controller.invoices.length.toString()),
              ),
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _HeaderStat(
              title: 'مبيعات',
              value: Obx(
                    () => Text(controller.invoices
                    .where((e) => e.type == InvoiceType.sale)
                    .length
                    .toString()),
              ),
              icon: Icons.trending_up_rounded,
              color: const Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _HeaderStat(
              title: 'مشتريات',
              value: Obx(
                    () => Text(controller.invoices
                    .where((e) => e.type == InvoiceType.purchase)
                    .length
                    .toString()),
              ),
              icon: Icons.shopping_cart_rounded,
              color: const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String title;
  final Widget value;
  final IconData icon;
  final Color color;

  const _HeaderStat({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.055),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: color.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                DefaultTextStyle(
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w900,
                  ),
                  child: value,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FILTERS
// ============================================================

class _InvoiceFilters extends GetView<InvoiceController> {
  const _InvoiceFilters();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'بحث برقم الفاتورة أو اسم الطرف...',
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 21,
              ),
              filled: true,
              fillColor: const Color(0xFFF7F8FC),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Obx(
                () => Row(
              children: [
                Expanded(
                  child: _FilterButton(
                    label: 'الكل',
                    icon: Icons.apps_rounded,
                    selected:
                    controller.selectedType.value == null,
                    color: const Color(0xFF2563EB),
                    onTap: () => controller.filterByType(null),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FilterButton(
                    label: 'المبيعات',
                    icon: Icons.trending_up_rounded,
                    selected:
                    controller.selectedType.value ==
                        InvoiceType.sale,
                    color: const Color(0xFF16A34A),
                    onTap: () => controller.filterByType(
                      InvoiceType.sale,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FilterButton(
                    label: 'المشتريات',
                    icon: Icons.shopping_cart_rounded,
                    selected:
                    controller.selectedType.value ==
                        InvoiceType.purchase,
                    color: const Color(0xFFF59E0B),
                    onTap: () => controller.filterByType(
                      InvoiceType.purchase,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? color
          : color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 5,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : color,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? Colors.white
                      : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// LIST
// ============================================================

class _InvoiceList extends GetView<InvoiceController> {
  const _InvoiceList();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading &&
          controller.invoices.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      if (controller.hasError &&
          controller.invoices.isEmpty) {
        return _ErrorView(
          message:
          controller.errorMessage.value ??
              'حدث خطأ أثناء تحميل الفواتير',
          onRetry: controller.refreshInvoices,
        );
      }

      if (controller.isEmpty) {
        return const _EmptyView();
      }

      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >=
              notification.metrics.maxScrollExtent - 250) {
            controller.loadMore();
          }
          return false;
        },
        child: RefreshIndicator(
          onRefresh: controller.refreshInvoices,
          child: ListView.separated(
            physics:
            const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              16,
              14,
              16,
              100,
            ),
            itemCount: controller.invoices.length +
                (controller.hasMore.value ? 1 : 0),
            separatorBuilder: (_, __) =>
            const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index ==
                  controller.invoices.length) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              return _InvoiceCard(
                invoice:
                controller.invoices[index],
              );
            },
          ),
        ),
      );
    });
  }
}

// ============================================================
// INVOICE CARD
// ============================================================

class _InvoiceCard extends GetView<InvoiceController> {
  final InvoiceModel invoice;

  const _InvoiceCard({
    required this.invoice,
  });

  @override
  Widget build(BuildContext context) {
    final isSale =
        invoice.type == InvoiceType.sale;

    final color = isSale
        ? const Color(0xFF16A34A)
        : const Color(0xFFF59E0B);

    final background = isSale
        ? const Color(0xFFF0FDF4)
        : const Color(0xFFFFFBEB);

    final typeLabel =
    isSale ? 'مبيعات' : 'مشتريات';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Get.toNamed(
            '/invoice-details',
            arguments: invoice,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius:
                      BorderRadius.circular(13),
                    ),
                    child: Icon(
                      isSale
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                invoice.invoiceNumber,
                                maxLines: 1,
                                overflow:
                                TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                  FontWeight.w900,
                                  color:
                                  Color(0xFF111827),
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            _TypeBadge(
                              text: typeLabel,
                              color: color,
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline_rounded,
                              size: 14,
                              color:
                              Color(0xFF9CA3AF),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                invoice.partyNameSnapshot,
                                maxLines: 1,
                                overflow:
                                TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color:
                                  Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: Color(0xFF9CA3AF),
                    ),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _confirmDelete(context);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFFDC2626),
                            ),
                            SizedBox(width: 8),
                            Text('حذف الفاتورة'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 15),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius:
                  BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _AmountItem(
                        title: 'الإجمالي',
                        value: invoice.totalAmount,
                        color:
                        const Color(0xFF111827),
                      ),
                    ),
                    _VerticalDivider(),
                    Expanded(
                      child: _AmountItem(
                        title: 'المدفوع',
                        value: invoice.paidAmount,
                        color:
                        const Color(0xFF16A34A),
                      ),
                    ),
                    _VerticalDivider(),
                    Expanded(
                      child: _AmountItem(
                        title: 'المتبقي',
                        value: invoice.remaining,
                        color: invoice.remaining > 0
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  _PaymentStatusBadge(
                    status: invoice.paymentStatus,
                  ),
                  const Spacer(),
                  if (invoice.createdAt != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color:
                          Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          invoice.createdAt!,
                          style: const TextStyle(
                            fontSize: 10,
                            color:
                            Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFDC2626),
            ),
            SizedBox(width: 8),
            Text('حذف الفاتورة'),
          ],
        ),
        content: Text(
          'سيتم حذف الفاتورة ${invoice.invoiceNumber} '
              'وعكس حركات المخزون المرتبطة بها.\n\n'
              'هل أنت متأكد من المتابعة؟',
          style: const TextStyle(
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
              const Color(0xFFDC2626),
            ),
            onPressed: () {
              Get.back();

              if (invoice.id != null) {
                controller.deleteInvoice(
                  invoice.id!,
                );
              }
            },
            child: const Text('حذف الفاتورة'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// AMOUNT
// ============================================================

class _AmountItem extends StatelessWidget {
  final String title;
  final int value;
  final Color color;

  const _AmountItem({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF9CA3AF),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          MoneyUtils.formatMoney(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: const Color(0xFFE5E7EB),
    );
  }
}

// ============================================================
// BADGES
// ============================================================

class _TypeBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _TypeBadge({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PaymentStatusBadge extends StatelessWidget {
  final PaymentStatus status;

  const _PaymentStatusBadge({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final data = switch (status) {
      PaymentStatus.paid => (
      'مدفوعة',
      const Color(0xFF16A34A),
      Icons.check_circle_rounded,
      ),
      PaymentStatus.partial => (
      'مدفوعة جزئياً',
      const Color(0xFFF59E0B),
      Icons.timelapse_rounded,
      ),
      PaymentStatus.unpaid => (
      'غير مدفوعة',
      const Color(0xFFDC2626),
      Icons.pending_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: data.$2.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            data.$3,
            size: 13,
            color: data.$2,
          ),
          const SizedBox(width: 4),
          Text(
            data.$1,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: data.$2,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EMPTY
// ============================================================

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius:
                BorderRadius.circular(26),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 40,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'لا توجد فواتير',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'لم يتم تسجيل أي فواتير ضمن الفلتر الحالي',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ERROR
// ============================================================

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius:
                BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 38,
                color: Color(0xFFDC2626),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'تعذر تحميل الفواتير',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}