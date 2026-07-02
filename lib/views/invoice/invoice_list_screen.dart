import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/invoice_controller.dart';
import '../../models/invoice_model.dart';

class InvoiceListScreen extends GetView<InvoiceController> {
  const InvoiceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفواتير'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.refreshInvoices,
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterChips(controller: controller),
          const Expanded(child: _InvoiceList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await controller.startNewInvoice();
          Get.toNamed('/invoice-form');
        },
        icon: const Icon(Icons.add),
        label: const Text('فاتورة جديدة'),
      ),
    );
  }
}

// ==============================
// Filter Chips
// ==============================

class _FilterChips extends StatelessWidget {
  final InvoiceController controller;

  const _FilterChips({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _Chip(
            label: 'الكل',
            selected: controller.selectedType.value == null,
            color: Colors.blueGrey,
            onTap: () => controller.filterByType(null),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'مبيعات',
            selected: controller.selectedType.value == InvoiceType.sale,
            color: Colors.green,
            onTap: () => controller.filterByType(InvoiceType.sale),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'مشتريات',
            selected:
            controller.selectedType.value == InvoiceType.purchase,
            color: Colors.orange,
            onTap: () => controller.filterByType(InvoiceType.purchase),
          ),
        ],
      ),
    ));
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ==============================
// Invoice List
// ==============================

class _InvoiceList extends GetView<InvoiceController> {
  const _InvoiceList();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.hasError) {
        return _ErrorView(
          message: controller.errorMessage.value ?? 'خطأ غير معروف',
          onRetry: controller.refreshInvoices,
        );
      }

      if (controller.isEmpty) {
        return const _EmptyView();
      }

      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >=
              notification.metrics.maxScrollExtent - 200) {
            controller.loadMore();
          }
          return false;
        },
        child: RefreshIndicator(
          onRefresh: controller.refreshInvoices,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
            itemCount: controller.invoices.length +
                (controller.hasMore.value ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == controller.invoices.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
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

// ==============================
// Invoice Card
// ==============================

class _InvoiceCard extends GetView<InvoiceController> {
  final InvoiceModel invoice;

  const _InvoiceCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final isSale = invoice.type == InvoiceType.sale;
    final color = isSale ? Colors.green : Colors.orange;
    final typeLabel = isSale ? 'بيع' : 'شراء';
    final typeIcon =
    isSale ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Get.toNamed('/invoice-details', arguments: invoice.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // أيقونة النوع
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon, color: color),
              ),
              const SizedBox(width: 12),

              // المعلومات الرئيسية
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          invoice.invoiceNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      invoice.partyNameSnapshot,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    if (invoice.createdAt != null)
                      Text(
                        invoice.createdAt!,
                        style:
                        TextStyle(color: Colors.grey[400], fontSize: 11),
                      ),
                  ],
                ),
              ),

              // المبلغ الإجمالي
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${invoice.totalAmount}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 20),
                    onPressed: () => _confirmDelete(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
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
    Get.dialog(AlertDialog(
      title: const Text('حذف الفاتورة'),
      content: Text(
        'سيتم حذف الفاتورة ${invoice.invoiceNumber} '
            'وإعادة حركات المخزون المرتبطة بها.\nهل تريد المتابعة؟',
      ),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('إلغاء')),
        TextButton(
          onPressed: () {
            Get.back();
            controller.deleteInvoice(invoice.id!);
          },
          child: const Text('حذف', style: TextStyle(color: Colors.red)),
        ),
      ],
    ));
  }
}

// ==============================
// Empty & Error
// ==============================

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('لا توجد فواتير',
              style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        ],
      ),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}