import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/invoice_controller.dart';
import '../../models/invoice_model.dart';
import '../../models/invoice_item_model.dart';
import '../../models/Invoice_draft.dart';

class InvoiceDetailsScreen extends GetView<InvoiceController> {
  const InvoiceDetailsScreen({super.key});

  int get invoiceId => Get.arguments as int;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InvoiceWithItems?>(
      future: controller.getInvoiceWithItems(invoiceId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('الفاتورة غير موجودة')),
          );
        }

        final data = snapshot.data!;
        final invoice = data.invoice;
        final items = data.items;
        final isSale = invoice.type == InvoiceType.sale;
        final typeColor = isSale ? Colors.green : Colors.orange;

        return Scaffold(
          appBar: AppBar(
            title: Text(invoice.invoiceNumber),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDelete(context, invoice),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [

              // ==============================
              // رأس الفاتورة
              // ==============================

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: typeColor.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          invoice.invoiceNumber,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: typeColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isSale ? 'فاتورة بيع' : 'فاتورة شراء',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    if (invoice.createdAt != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(invoice.createdAt!,
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 13)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ==============================
              // معلومات الطرف
              // ==============================

              _SectionCard(
                icon: Icons.people_outline,
                title: isSale ? 'العميل' : 'المورد',
                color: Colors.blue,
                children: [
                  _DetailRow(
                      label: 'الاسم',
                      value: invoice.partyNameSnapshot),
                  if (invoice.partyAddressSnapshot.isNotEmpty)
                    _DetailRow(
                        label: 'العنوان',
                        value: invoice.partyAddressSnapshot),
                ],
              ),
              const SizedBox(height: 12),

              // ==============================
              // جدول أسطر الفاتورة
              // ==============================

              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.list_alt, color: Colors.grey[600], size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'أسطر الفاتورة (${items.length})',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // رأس الجدول
                    Container(
                      color: Colors.grey[50],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: const Row(
                        children: [
                          Expanded(
                              flex: 3,
                              child: Text('المنتج',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.grey))),
                          Expanded(
                              flex: 1,
                              child: Text('الكمية',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.grey))),
                          Expanded(
                              flex: 2,
                              child: Text('سعر القطعة',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.grey))),
                          Expanded(
                              flex: 2,
                              child: Text('الإجمالي',
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.grey))),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // الأسطر
                    ...items.map((item) => _ItemDetailRow(item: item)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ==============================
              // الملاحظات
              // ==============================

              if (invoice.notes != null && invoice.notes!.isNotEmpty)
                _SectionCard(
                  icon: Icons.notes_outlined,
                  title: 'الملاحظات',
                  color: Colors.purple,
                  children: [
                    Text(invoice.notes!,
                        style: TextStyle(color: Colors.grey[700])),
                  ],
                ),

              if (invoice.notes != null && invoice.notes!.isNotEmpty)
                const SizedBox(height: 12),

              // ==============================
              // المبلغ الإجمالي
              // ==============================

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: typeColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'المبلغ الإجمالي',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      '${invoice.totalAmount}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: typeColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, InvoiceModel invoice) {
    Get.dialog(AlertDialog(
      title: const Text('حذف الفاتورة'),
      content: Text(
          'سيتم حذف ${invoice.invoiceNumber} وإعادة تأثيرها على المخزون. هل تريد المتابعة؟'),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('إلغاء')),
        TextButton(
          onPressed: () async {
            Get.back();
            await controller.deleteInvoice(invoice.id!);
            if (!controller.hasError) Get.back();
          },
          child: const Text('حذف', style: TextStyle(color: Colors.red)),
        ),
      ],
    ));
  }
}

class _ItemDetailRow extends StatelessWidget {
  final InvoiceItemModel item;

  const _ItemDetailRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(item.productNameSnapshot,
                style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 1,
            child: Text(
              item.quantity % 1 == 0
                  ? item.quantity.toInt().toString()
                  : item.quantity.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('${item.unitPrice}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${item.lineTotal}',
              textAlign: TextAlign.end,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}