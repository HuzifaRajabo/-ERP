import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/invoice_controller.dart';
import '../../core/utils/money_utils.dart';
import '../../models/invoice_model.dart';
import '../../core/theme/app_colors.dart';
import '../../repositories/invoice_repository.dart';
import '../shared/shared_components.dart';

class InvoiceListScreen extends GetView<InvoiceController> {
  const InvoiceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الفواتير',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 2),
            Text('إدارة المبيعات والمشتريات', style: TextStyle(fontSize: 11)),
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
                      child: CircularProgressIndicator(strokeWidth: 2),
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
          const Expanded(child: _InvoiceList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await controller.startNewInvoice();
          Get.toNamed('/invoice-form');
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'فاتورة جديدة',
          style: TextStyle(fontWeight: FontWeight.w800),
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
              value: Obx(() => Text(controller.invoices.length.toString())),
              icon: Icons.receipt_long_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _HeaderStat(
              title: 'مبيعات',
              value: Obx(
                () => Text(
                  controller.invoices
                      .where((e) => e.type == InvoiceType.sale)
                      .length
                      .toString(),
                ),
              ),
              icon: Icons.trending_up_rounded,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _HeaderStat(
              title: 'مشتريات',
              value: Obx(
                () => Text(
                  controller.invoices
                      .where((e) => e.type == InvoiceType.purchase)
                      .length
                      .toString(),
                ),
              ),
              icon: Icons.shopping_cart_rounded,
              color: AppColors.warning,
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
        border: Border.all(color: color.withOpacity(0.12)),
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
            child: Icon(icon, size: 18, color: color),
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
          const _InvoiceSearchField(),
          const SizedBox(height: 12),
          Obx(
            () => Row(
              children: [
                Expanded(
                  child: _FilterButton(
                    label: 'الكل',
                    icon: Icons.apps_rounded,
                    selected: controller.selectedType.value == null,
                    color: const Color(0xFF2563EB),
                    onTap: () => controller.filterByType(null),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FilterButton(
                    label: 'المبيعات',
                    icon: Icons.trending_up_rounded,
                    selected: controller.selectedType.value == InvoiceType.sale,
                    color: const Color(0xFF16A34A),
                    onTap: () => controller.filterByType(InvoiceType.sale),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FilterButton(
                    label: 'المشتريات',
                    icon: Icons.shopping_cart_rounded,
                    selected:
                        controller.selectedType.value == InvoiceType.purchase,
                    color: const Color(0xFFF59E0B),
                    onTap: () => controller.filterByType(InvoiceType.purchase),
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

/// حقل البحث الفعلي — مربوط بـ InvoiceController.setSearchQuery عبر
/// debounce بسيط (350ms) لتفادي تنفيذ استعلام قاعدة بيانات مع كل
/// ضغطة مفتاح. المسار الكامل: Widget → Controller → Repository → Database.
class _InvoiceSearchField extends StatefulWidget {
  const _InvoiceSearchField();

  @override
  State<_InvoiceSearchField> createState() => _InvoiceSearchFieldState();
}

class _InvoiceSearchFieldState extends State<_InvoiceSearchField> {
  final _textController = TextEditingController();
  Timer? _debounce;

  final InvoiceController controller = Get.find<InvoiceController>();

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      controller.setSearchQuery(value);
    });
  }

  void _onClear() {
    _debounce?.cancel();
    _textController.clear();
    controller.setSearchQuery('');
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AppSearchField(
        hint: 'بحث برقم الفاتورة أو اسم الطرف...',
        controller: _textController,
        onChanged: _onChanged,
        onClear: controller.searchQuery.value.isEmpty ? null : _onClear,
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
      color: selected ? color : color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : color,
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
      if (controller.isLoading && controller.invoices.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.hasError && controller.invoices.isEmpty) {
        return _ErrorView(
          message:
              controller.errorMessage.value ?? 'حدث خطأ أثناء تحميل الفواتير',
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
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
            itemCount:
                controller.invoices.length + (controller.hasMore.value ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == controller.invoices.length) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              return _InvoiceCard(invoice: controller.invoices[index]);
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

  const _InvoiceCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final isSale = invoice.type == InvoiceType.sale;

    final color = isSale ? const Color(0xFF16A34A) : const Color(0xFFF59E0B);

    final background = isSale
        ? const Color(0xFFF0FDF4)
        : const Color(0xFFFFFBEB);

    final typeLabel = isSale ? 'مبيعات' : 'مشتريات';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Get.toNamed('/invoice-details', arguments: invoice);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
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
                      borderRadius: BorderRadius.circular(13),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                invoice.invoiceNumber,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            _TypeBadge(text: typeLabel, color: color),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline_rounded,
                              size: 14,
                              color: Color(0xFF9CA3AF),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                invoice.partyNameSnapshot,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
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

              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _AmountItem(
                        title: 'الإجمالي',
                        value: invoice.totalAmount,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    _VerticalDivider(),
                    Expanded(
                      child: _AmountItem(
                        title: 'المدفوع',
                        value: invoice.paidAmount,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                    _VerticalDivider(),
                    Expanded(
                      child: _AmountItem(
                        title: 'المتبقي',
                        value: invoice.remaining,
                        color: invoice.remaining > 0
                            ? Theme.of(context).colorScheme.error
                            : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  _PaymentStatusBadge(status: invoice.paymentStatus),
                  const Spacer(),
                  if (invoice.createdAt != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          invoice.createdAt!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF9CA3AF),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('حذف الفاتورة'),
          ],
        ),
        content: Text(
          'سيتم حذف الفاتورة ${invoice.invoiceNumber} نهائياً.\n'
          'لا يمكن حذف فاتورة أصبحت مرتبطة بحركات مخزون أو دفعات أو مرتجعات.\n\n'
          'هل أنت متأكد من المتابعة؟',
          style: const TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () async {
              Get.back();

              if (invoice.id != null) {
                final result =
                    await controller.deleteInvoice(invoice.id!);

                if (result == InvoiceDeleteResult.allowed) {
                  Get.snackbar(
                    'حذف الفاتورة',
                    'تم حذف الفاتورة',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: const Color(0xFF22C55E),
                    colorText: Colors.white,
                    margin: const EdgeInsets.all(12),
                  );
                } else {
                  Get.snackbar(
                    'تعذّر الحذف',
                    result.reason ?? 'حدث خطأ غير متوقع',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                    margin: const EdgeInsets.all(12),
                    duration: const Duration(seconds: 4),
                  );
                }
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
    return Container(width: 1, height: 28, color: const Color(0xFFE5E7EB));
  }
}

// ============================================================
// BADGES
// ============================================================

class _TypeBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _TypeBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return AppStatusBadge(label: text, color: color);
  }
}

class _PaymentStatusBadge extends StatelessWidget {
  final PaymentStatus status;

  const _PaymentStatusBadge({required this.status});

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

    return AppStatusBadge(label: data.$1, color: data.$2, icon: data.$3);
  }
}

// ============================================================
// EMPTY
// ============================================================

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'لا توجد فواتير',
      message: 'لم يتم تسجيل أي فواتير ضمن الفلتر الحالي',
    );
  }
}

// ============================================================
// ERROR
// ============================================================

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AppErrorState(
      title: 'تعذر تحميل الفواتير',
      message: message,
      onRetry: onRetry,
    );
  }
}