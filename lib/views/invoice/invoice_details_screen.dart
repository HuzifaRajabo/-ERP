import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/utils/money_utils.dart';
import '../../controllers/invoice_controller.dart';
import '../../models/invoice_model.dart';
import '../../models/invoice_item_model.dart';
import '../../models/invoice_draft.dart';
import '../../controllers/payment_controller.dart';
import '../../models/payment_model.dart';
import '../../models/return_model.dart';
import '../../repositories/return_repository.dart';
import '../../repositories/payment_repository.dart';
import '../debts/payment_bottom_sheet.dart';
import '../../core/services/app_event_bus.dart';
import '../../core/services/invoice_pdf_service.dart';

class InvoiceDetailsScreen extends StatefulWidget {
  const InvoiceDetailsScreen({super.key});

  @override
  State<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends State<InvoiceDetailsScreen> {
  final controller = Get.find<InvoiceController>();
  final _returnRepo  = ReturnRepository();
  final _paymentRepo = PaymentRepository();
  late final int invoiceId;
  late InvoiceModel invoice;
  late Future<InvoiceWithItems?> _invoiceFuture;
  Worker? _invoiceWorker;

  @override
  void initState() {
    super.initState();
    invoice = Get.arguments as InvoiceModel; // ← فقط هذا السطر
    _invoiceFuture = _loadInvoice();

    _invoiceWorker = AppEventBus.instance.listenToInvoices(() async {
      final updated = await controller.repo.getInvoiceById(invoice.id!);
      if (updated != null && mounted) {
        setState(() => invoice = updated);
        // إعادة تحميل الفاتورة كاملة
        setState(() => _invoiceFuture = _loadInvoice());
      }
    });
  }

  Future<InvoiceWithItems?> _loadInvoice() {
    return controller.getInvoiceWithItems(invoice.id!);
  }

  @override
  void dispose() {
    _invoiceWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InvoiceWithItems?>(
      future: _invoiceFuture,
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
        final statusColor = Color(
          int.parse('FF${invoice.paymentStatus.colorHex}', radix: 16),
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(invoice.invoiceNumber),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'تصدير PDF',
                onPressed: () => _exportPdf(invoice, items), // ← items من snapshot
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDelete(context, invoice),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ─── رأس الفاتورة ───
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
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: typeColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isSale ? 'فاتورة بيع' : 'فاتورة شراء',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                invoice.paymentStatus.label,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (data.warehouseName != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.warehouse_outlined,
                            size: 14,
                            color: Color(0xFF059669),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'المستودع:',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              data.warehouseName!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (invoice.createdAt != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            invoice.createdAt!,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ─── معلومات الطرف ───
              _SectionCard(
                icon: Icons.people_outline,
                title: isSale ? 'العميل' : 'المورد',
                color: Colors.blue,
                children: [
                  _DetailRow(label: 'الاسم', value: invoice.partyNameSnapshot),
                  if (invoice.partyAddressSnapshot.isNotEmpty)
                    _DetailRow(
                      label: 'العنوان',
                      value: invoice.partyAddressSnapshot,
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // ─── بطاقات أسطر الفاتورة ───
              _ItemsCardsSection(data: data),
              const SizedBox(height: 12),

              // ─── الملاحظات ───
              if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                _SectionCard(
                  icon: Icons.notes_outlined,
                  title: 'الملاحظات',
                  color: Colors.purple,
                  children: [
                    Text(
                      invoice.notes!,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // ─── سجل الدفعات ───
              _PaymentHistorySection(invoiceId: invoice.id!),
              const SizedBox(height: 12),

              if (invoice.paymentStatus != PaymentStatus.paid) ...[
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () => PaymentBottomSheet.show(invoice),
                    icon: const Icon(Icons.add),
                    label: const Text('تسجيل دفعة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ─── قسم المرتجعات ───
              _ReturnsSection(invoiceId: invoice.id!),
              const SizedBox(height: 12),

              _ReturnButton(invoice: invoice),
              const SizedBox(height: 12),

              // ─── قسم الحسابات والإجمالي الصافي ───
              _InvoiceTotalSection(invoice: invoice),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportPdf(
    InvoiceModel invoice,
    List<InvoiceItemModel> items,
  ) async {
    try {
      final payments = await _paymentRepo.getPaymentsByInvoice(invoice.id!);
      final returns  = await _returnRepo.getReturnsByInvoice(invoice.id!);

      await InvoicePdfService.exportInvoice(
        invoice:  invoice,
        items:    items,
        payments: payments,
        returns:  returns,
      );
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل تصدير الفاتورة: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _confirmDelete(BuildContext context, InvoiceModel invoice) {
    Get.dialog(
      AlertDialog(
        title: const Text('حذف الفاتورة'),
        content: Text(
          'سيتم حذف ${invoice.invoiceNumber} وإعادة تأثيرها على المخزون. هل تريد المتابعة؟',
        ),
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
      ),
    );
  }
}

// ─── بطاقات أسطر الفاتورة ───

/// بطاقات الأسطر بدل الجدول القديم — تعرض الوحدة والسعر والدفعات
/// المخصصة وتواريخ الصلاحية، مع توافق كامل مع الفواتير القديمة
/// (وحدة/دفعات غير متوفرة → تُخفى أو تُعرض كـ "الوحدة الأساسية").
class _ItemsCardsSection extends StatelessWidget {
  final InvoiceWithItems data;

  const _ItemsCardsSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final items = data.items;

    return Container(
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
                Icon(
                  Icons.list_alt,
                  color: Colors.grey[600],
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'المنتجات (${items.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...items.map(
            (item) => _ItemDetailCard(
              item: item,
              allocations: data.allocationsFor(item),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemDetailCard extends StatelessWidget {
  final InvoiceItemModel item;
  final List<BatchAllocationSnapshot> allocations;

  const _ItemDetailCard({required this.item, required this.allocations});

  String _fmtQty(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    final s = value.toStringAsFixed(2);
    return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Color _batchStatusColor(BatchAllocationSnapshot allocation) {
    final expiry = allocation.expiryDate;
    if (expiry == null) return Colors.grey;
    final date = DateTime.tryParse(expiry);
    if (date == null) return Colors.grey;
    final days = date.difference(
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    ).inDays;
    if (days < 0) return Colors.red;
    if (days <= 30) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // اسم المنتج
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: Color(0xFF2563EB),
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.productNameSnapshot,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // الكمية × السعر
          Text(
            '${_fmtQty(item.quantity)} '
            '${item.unitNameSnapshot ?? 'الوحدة الأساسية'}'
            ' × ${MoneyUtils.formatMoney(item.unitPrice)}',
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
          const SizedBox(height: 6),

          // الإجمالي
          Row(
            children: [
              Text(
                'الإجمالي:',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const Spacer(),
              Text(
                MoneyUtils.formatMoney(item.lineTotal),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),

          // المكافئ بالوحدة الأساسية (معلومة ثانوية)
          if (item.conversionFactorSnapshot != 1) ...[
            const SizedBox(height: 4),
            Text(
              'يعادل ${_fmtQty(item.baseQuantity)} وحدة أساسية',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],

          // الدفعات المخصصة
          if (allocations.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    allocations.length == 1
                        ? 'الدفعة:'
                        : 'الدفعات المخصصة:',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF065F46),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...allocations.map(
                    (allocation) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _batchStatusColor(allocation),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${allocation.batchNumber} — '
                              '${_fmtQty(allocation.quantity)}'
                              '${allocation.expiryDate != null ? ' — انتهاء ${_fmtDate(allocation.expiryDate)}' : ''}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 14,
                ),
              ),
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
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── سجل الدفعات ───

class _PaymentHistorySection extends StatefulWidget {
  final int invoiceId;
  const _PaymentHistorySection({required this.invoiceId});

  @override
  State<_PaymentHistorySection> createState() => _PaymentHistorySectionState();
}

class _PaymentHistorySectionState extends State<_PaymentHistorySection> {
  final _repo = PaymentRepository();
  final _payments = <PaymentModel>[].obs;
  Worker? _worker;

  @override
  void initState() {
    super.initState();
    _load();
    _worker = AppEventBus.instance.listenToInvoices(() {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    try {
      final result = await _repo.getPaymentsByInvoice(widget.invoiceId);
      if (mounted) _payments.assignAll(result);
    } catch (e) {
      debugPrint('Error loading payments: $e');
    }
  }

  @override
  void dispose() {
    _worker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (_payments.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.payments_outlined, color: Colors.grey[400]),
              const SizedBox(width: 8),
              Text(
                'لا توجد دفعات مسجلة',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        );
      }

      return Container(
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
                  Icon(Icons.history, color: Colors.grey[600], size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'سجل الدفعات (${_payments.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ..._payments.map(
              (payment) => _PaymentRow(
                payment: payment,
                invoiceId: widget.invoiceId,
                onDeleted: _load,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _PaymentRow extends GetView<PaymentController> {
  final PaymentModel payment;
  final int invoiceId;
  final VoidCallback onDeleted;

  const _PaymentRow({
    required this.payment,
    required this.invoiceId,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (payment.returnId != null ? Colors.red : Colors.green)
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              payment.returnId != null ? Icons.reply : Icons.payments_outlined,
              color: payment.returnId != null ? Colors.red : Colors.green,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  MoneyUtils.formatMoney(payment.amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: payment.returnId != null ? Colors.red : Colors.green,
                  ),
                ),
                if (payment.notes != null)
                  Text(
                    payment.notes!,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                if (payment.returnId != null)
                  Text(
                    'دفعة راجعة',
                    style: TextStyle(color: Colors.red[600], fontSize: 12),
                  ),
                if (payment.createdAt != null)
                  Text(
                    payment.createdAt!,
                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('حذف الدفعة'),
        content: Text(
          'سيتم حذف الدفعة بمبلغ ${MoneyUtils.formatMoney(payment.amount)} وإعادة المتبقي للفاتورة. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              Get.back();
              await controller.deletePayment(payment.id!, invoiceId);
              onDeleted();
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─── سجل المرتجعات ───

class _ReturnsSection extends StatefulWidget {
  final int invoiceId;
  const _ReturnsSection({required this.invoiceId});

  @override
  State<_ReturnsSection> createState() => _ReturnsSectionState();
}

class _ReturnsSectionState extends State<_ReturnsSection> {
  final _repo = ReturnRepository();
  final _returns = <ReturnModel>[].obs;
  Worker? _worker;

  @override
  void initState() {
    super.initState();
    _load();
    _worker = AppEventBus.instance.listenToInventory(() {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    try {
      final result = await _repo.getReturnsByInvoice(widget.invoiceId);
      if (mounted) _returns.assignAll(result);
    } catch (e) {
      debugPrint('Error loading returns: $e');
    }
  }

  @override
  void dispose() {
    _worker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (_returns.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.undo_rounded, color: Colors.grey[400]),
              const SizedBox(width: 8),
              Text(
                'لا توجد مرتجعات',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        );
      }

      return Container(
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
                  Icon(Icons.undo_rounded, color: Colors.purple[400], size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'سجل المرتجعات (${_returns.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ..._returns.map((ret) => _ReturnRow(ret: ret)),
          ],
        ),
      );
    });
  }
}

class _ReturnRow extends StatelessWidget {
  final ReturnModel ret;
  const _ReturnRow({required this.ret});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Get.toNamed('/return-details', arguments: ret.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.undo_rounded,
                color: Colors.purple,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ret.returnNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (ret.createdAt != null)
                    Text(
                      ret.createdAt!,
                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                Text(
                  '- ${MoneyUtils.formatMoney(ret.totalAmount)}',
                  style: const TextStyle(
                    color: Colors.purple,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_left, color: Colors.grey[400], size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReturnButton extends StatelessWidget {
  final InvoiceModel invoice;
  const _ReturnButton({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final isSale = invoice.type == InvoiceType.sale;
    final returnType = isSale
        ? ReturnType.saleReturn
        : ReturnType.purchaseReturn;

    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton.icon(
        onPressed: () => Get.toNamed(
          '/return-form',
          arguments: {'invoice': invoice, 'returnType': returnType},
        ),
        icon: const Icon(Icons.undo_rounded, color: Colors.purple),
        label: Text(
          isSale ? 'تسجيل مرتجع مبيعات' : 'تسجيل مرتجع مشتريات',
          style: const TextStyle(color: Colors.purple),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.purple.withOpacity(0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ─── قسم الحسابات النهائي ───

class _InvoiceTotalSection extends StatefulWidget {
  final InvoiceModel invoice;
  const _InvoiceTotalSection({required this.invoice});

  @override
  State<_InvoiceTotalSection> createState() => _InvoiceTotalSectionState();
}

class _InvoiceTotalSectionState extends State<_InvoiceTotalSection> {
  final _repo = ReturnRepository();
  final _returnsTotal = 0.obs;
  Worker? _inventoryWorker;
  Worker? _invoiceWorker;

  @override
  void initState() {
    super.initState();
    _load();

    // الاستماع للمخزون (مرتجعات جديدة) والفواتير (تعديل دفعات أو حالات)
    _inventoryWorker = AppEventBus.instance.listenToInventory(() {
      if (mounted) _load();
    });
    _invoiceWorker = AppEventBus.instance.listenToInvoices(() {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    try {
      final returns = await _repo.getReturnsByInvoice(widget.invoice.id!);
      if (mounted) {
        _returnsTotal.value = returns.fold(0, (sum, r) => sum + r.totalAmount);
      }
    } catch (e) {
      debugPrint('Error loading returns total: $e');
    }
  }

  @override
  void dispose() {
    _inventoryWorker?.dispose();
    _invoiceWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSale = widget.invoice.type == InvoiceType.sale;

    return Obx(() {
      final grossTotal = widget.invoice.originalTotalAmount;
      final returnsTotal = _returnsTotal.value;
      final netTotal = grossTotal - returnsTotal;
      final paid = widget.invoice.paidAmount;
      final balance = netTotal - paid;

      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          color: Colors.white,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'إجمالي الفاتورة الأصلي',
                    value: MoneyUtils.formatMoney(grossTotal),
                    valueStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (returnsTotal > 0) ...[
                    const SizedBox(height: 10),
                    _SummaryRow(
                      label: 'إجمالي المرتجعات',
                      value: '- ${MoneyUtils.formatMoney(returnsTotal)}',
                      labelStyle: const TextStyle(color: Colors.purple),
                      valueStyle: const TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      icon: Icons.undo_rounded,
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),
                  _SummaryRow(
                    label: 'صافي الفاتورة',
                    value: MoneyUtils.formatMoney(netTotal),
                    valueStyle: TextStyle(
                      color: isSale ? Colors.green[700] : Colors.orange[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SummaryRow(
                    label: 'المدفوع',
                    value: MoneyUtils.formatMoney(paid),
                    valueStyle: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getBalanceBackgroundColor(balance),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getBalanceLabel(balance, isSale),
                        style: TextStyle(
                          color: _getBalanceTextColor(balance),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        MoneyUtils.formatMoney(balance.abs()),
                        style: TextStyle(
                          color: _getBalanceTextColor(balance),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: netTotal > 0
                          ? (paid / netTotal).clamp(0.0, 1.0)
                          : 1.0,
                      minHeight: 6,
                      color: _getProgressBarColor(balance),
                      backgroundColor: Colors.grey.shade300,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  String _getBalanceLabel(int balance, bool isSale) {
    if (balance > 0) return 'المتبقي';
    if (balance < 0) return isSale ? 'المستحق للعميل' : 'المستحق لنا من المورد';
    return 'مسواة بالكامل';
  }

  Color _getBalanceTextColor(int balance) {
    if (balance > 0) return Colors.red.shade700;
    if (balance < 0) return Colors.blue.shade800;
    return Colors.green.shade700;
  }

  Color _getBalanceBackgroundColor(int balance) {
    if (balance > 0) return Colors.red.shade50;
    if (balance < 0) return Colors.blue.shade50;
    return Colors.green.shade50;
  }

  Color _getProgressBarColor(int balance) {
    if (balance > 0) return Colors.orange;
    if (balance < 0) return Colors.blue;
    return Colors.green;
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final IconData? icon;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: labelStyle?.color ?? Colors.grey[700],
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style:
                  labelStyle ??
                  TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
          ],
        ),
        Text(value, style: valueStyle ?? const TextStyle(fontSize: 14)),
      ],
    );
  }
}
