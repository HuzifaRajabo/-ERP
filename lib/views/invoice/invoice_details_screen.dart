import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/utils/money_utils.dart';
import '../../controllers/invoice_controller.dart';
import '../../controllers/feature_controller.dart';
import '../../models/business_config.dart';
import '../../models/invoice_model.dart';
import '../../models/invoice_item_model.dart';
import '../../models/invoice_draft.dart';
import '../../controllers/payment_controller.dart';
import '../../controllers/return_controller.dart';
import '../../controllers/company_profile_controller.dart';
import '../../models/payment_model.dart';
import '../../models/return_model.dart';
import '../debts/payment_bottom_sheet.dart';
import '../../core/services/app_event_bus.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../shared/shared_components.dart';

class InvoiceDetailsScreen extends StatefulWidget {
  const InvoiceDetailsScreen({super.key});

  @override
  State<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends State<InvoiceDetailsScreen> {
  final controller = Get.find<InvoiceController>();
  late final int invoiceId;
  late InvoiceModel invoice;
  late Future<InvoiceWithItems?> _invoiceFuture;
  Worker? _invoiceWorker;

  @override
  void initState() {
    super.initState();
    invoice = Get.arguments as InvoiceModel;
    _invoiceFuture = _loadInvoice();

    _invoiceWorker = AppEventBus.instance.listenToInvoices(() async {
      final updated = await controller.getInvoiceById(invoice.id!);
      if (updated != null && mounted) {
        setState(() => invoice = updated);
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
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
        final typeColor = isSale ? context.semantic.success : context.semantic.warning;
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
                onPressed: () => _exportPdf(
                  invoice,
                  items,
                  warehouseName: data.warehouseName,
                  batchesByProductId: data.batchesByProductId,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: colors.error,
                ),
                onPressed: () => _confirmDelete(context, invoice),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _CompanyIdentityBlock(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          invoice.invoiceNumber,
                          style: textTheme.titleLarge,
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppStatusBadge(
                              label: isSale ? 'فاتورة بيع' : 'فاتورة شراء',
                              color: typeColor,
                              icon: isSale
                                  ? Icons.point_of_sale_outlined
                                  : Icons.shopping_cart_outlined,
                            ),
                            if (featureEnabled(AppFeature.debts)) ...[
                              const SizedBox(width: 6),
                              AppStatusBadge(
                                label: invoice.paymentStatus.label,
                                color: statusColor,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    if (featureEnabled(AppFeature.warehouses) &&
                        data.warehouseName != null) ...[
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
                            style: textTheme.bodySmall,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              data.warehouseName!,
                              style: textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
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
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            invoice.createdAt!,
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              _SectionCard(
                icon: Icons.people_outline,
                title: isSale ? 'العميل' : 'المورد',
                color: colors.primary,
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

              _ItemsCardsSection(data: data),
              const SizedBox(height: 12),

              if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                _SectionCard(
                  icon: Icons.notes_outlined,
                  title: 'الملاحظات',
                  color: colors.secondary,
                  children: [
                    Text(
                      invoice.notes!,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

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
                      backgroundColor: context.semantic.success,
                      foregroundColor: context.semantic.onSuccess,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              _ReturnsSection(invoiceId: invoice.id!),
              const SizedBox(height: 12),

              _ReturnButton(invoice: invoice),
              const SizedBox(height: 12),

              const SizedBox(height: 20),

              _InvoiceTotalSection(invoice: invoice),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportPdf(
    InvoiceModel invoice,
    List<InvoiceItemModel> items, {
    String? warehouseName,
    Map<int, List<BatchAllocationSnapshot>> batchesByProductId = const {},
  }) async {
    try {
      await controller.exportInvoicePdf(
        invoice: invoice,
        items: items,
        warehouseName: warehouseName,
        batchesByProductId: batchesByProductId,
      );
    } catch (e) {
      final colors = Theme.of(context).colorScheme;
      final semantic = Theme.of(context).extension<AppSemanticColors>() ?? AppSemanticColors.light;
      Get.snackbar(
        'خطأ',
        'فشل تصدير الفاتورة: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: semantic.error,
        colorText: colors.onError,
      );
    }
  }

  void _confirmDelete(BuildContext context, InvoiceModel invoice) {
    final semantic = Theme.of(context).extension<AppSemanticColors>() ?? AppSemanticColors.light;
    final colors = Theme.of(context).colorScheme;
    Get.dialog(
      AlertDialog(
        title: const Text('حذف الفاتورة'),
        content: Text(
          'سيتم حذف ${invoice.invoiceNumber} نهائياً. '
          'لا يمكن حذف فاتورة أصبحت مرتبطة بحركات مخزون أو دفعات أو مرتجعات. '
          'هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              Get.back();
              final result =
                  await controller.deleteInvoice(invoice.id!);
              if (result == InvoiceDeleteResult.allowed) {
                Get.back();
              } else {
                Get.snackbar(
                  'تعذّر الحذف',
                  result.reason ?? 'حدث خطأ غير متوقع',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: semantic.error,
                  colorText: colors.onError,
                  margin: const EdgeInsets.all(12),
                  duration: const Duration(seconds: 4),
                );
              }
            },
            child: Text('حذف', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
  }
}

// ─── بطاقات أسطر الفاتورة ───

class _ItemsCardsSection extends StatelessWidget {
  final InvoiceWithItems data;

  const _ItemsCardsSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final items = data.items;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.list_alt, color: colors.onSurfaceVariant, size: 18),
                const SizedBox(width: 8),
                Text(
                  'المنتجات (${items.length})',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
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

  Color _batchStatusColor(BuildContext context, BatchAllocationSnapshot allocation) {
    final expiry = allocation.expiryDate;
    if (expiry == null) return Theme.of(context).colorScheme.onSurfaceVariant;
    final date = DateTime.tryParse(expiry);
    if (date == null) return Theme.of(context).colorScheme.onSurfaceVariant;
    final days = date
        .difference(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ),
        )
        .inDays;
    if (days < 0) return context.semantic.error;
    if (days <= 30) return context.semantic.warning;
    return context.semantic.success;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: colors.primary,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.productNameSnapshot,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            '${_fmtQty(item.quantity)} '
            '${item.unitNameSnapshot ?? 'الوحدة الأساسية'}'
            ' × ${MoneyUtils.formatMoney(item.unitPrice)}',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 6),

          Row(
            children: [
              Text(
                'الإجمالي:',
                style: textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                MoneyUtils.formatMoney(item.lineTotal),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          if (item.conversionFactorSnapshot != 1) ...[
            const SizedBox(height: 4),
            Text(
              'يعادل ${_fmtQty(item.baseQuantity)} وحدة أساسية',
              style: textTheme.labelSmall,
            ),
          ],

          if (featureEnabled(AppFeature.batches) && allocations.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.semantic.successContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.semantic.success.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    allocations.length == 1 ? 'الدفعة:' : 'الدفعات المخصصة:',
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.semantic.success,
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
                              color: _batchStatusColor(context, allocation),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${allocation.batchNumber} — '
                              '${_fmtQty(allocation.quantity)}'
                              '${featureEnabled(AppFeature.expiry) && allocation.expiryDate != null ? ' — انتهاء ${_fmtDate(allocation.expiryDate)}' : ''}',
                              style: textTheme.labelSmall?.copyWith(
                                color: context.semantic.onSuccessContainer,
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
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
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
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
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
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
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
      final result = await Get.find<PaymentController>().getPaymentsByInvoice(
        widget.invoiceId,
      );
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
    final colors = Theme.of(context).colorScheme;

    return Obx(() {
      if (_payments.isEmpty) {
        return AppEmptyState(
          icon: Icons.payments_outlined,
          title: 'لا توجد دفعات مسجلة',
        );
      }

      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.history, color: colors.onSurfaceVariant, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'سجل الدفعات (${_payments.length})',
                    style: Theme.of(context).textTheme.titleSmall,
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
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (payment.returnId != null
                      ? context.semantic.error
                      : context.semantic.success)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Icon(
              payment.returnId != null ? Icons.reply : Icons.payments_outlined,
              color: payment.returnId != null
                  ? context.semantic.error
                  : context.semantic.success,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  MoneyUtils.formatMoney(payment.amount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: payment.returnId != null
                        ? context.semantic.error
                        : context.semantic.success,
                  ),
                ),
                if (payment.notes != null)
                  Text(
                    payment.notes!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                if (payment.returnId != null)
                  AppStatusBadge(
                    label: 'دفعة راجعة',
                    color: context.semantic.error,
                  ),
                if (payment.createdAt != null)
                  Text(
                    payment.createdAt!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: colors.error, size: 20),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
            child: Text('حذف', style: TextStyle(color: colors.error)),
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
      final result = await Get.find<ReturnController>().getReturnsByInvoice(
        widget.invoiceId,
      );
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
    final colors = Theme.of(context).colorScheme;

    return Obx(() {
      if (_returns.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(Icons.undo_rounded, color: colors.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'لا توجد مرتجعات',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        );
      }

      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outlineVariant),
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
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => Get.toNamed('/return-details', arguments: ret.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.outlineVariant)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
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
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (ret.createdAt != null)
                    Text(
                      ret.createdAt!,
                      style: textTheme.labelSmall,
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
                Icon(Icons.chevron_left, color: colors.onSurfaceVariant, size: 18),
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
          side: BorderSide(color: Colors.purple.withValues(alpha: 0.4)),
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
  final _returnsTotal = 0.obs;
  Worker? _inventoryWorker;
  Worker? _invoiceWorker;

  @override
  void initState() {
    super.initState();
    _load();

    _inventoryWorker = AppEventBus.instance.listenToInventory(() {
      if (mounted) _load();
    });
    _invoiceWorker = AppEventBus.instance.listenToInvoices(() {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    try {
      final total = await Get.find<ReturnController>()
          .getReturnsTotalForInvoice(widget.invoice.id!);
      if (mounted) _returnsTotal.value = total;
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
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isSale = widget.invoice.type == InvoiceType.sale;

    return Obx(() {
      final grossTotal = widget.invoice.originalTotalAmount;
      final discount = widget.invoice.discountAmount;
      final returnsTotal = _returnsTotal.value;
      final netTotal = grossTotal - discount - returnsTotal;
      final paid = widget.invoice.paidAmount;
      final balance = netTotal - paid;

      return AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'إجمالي الفاتورة الأصلي',
                    value: MoneyUtils.formatMoney(grossTotal),
                    valueStyle: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (discount > 0) ...[
                    const SizedBox(height: 10),
                    _SummaryRow(
                      label: 'الحسم',
                      value: '- ${MoneyUtils.formatMoney(discount)}',
                      valueStyle: TextStyle(
                        color: colors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                  if (returnsTotal > 0) ...[
                    const SizedBox(height: 10),
                    _SummaryRow(
                      label: 'إجمالي المرتجعات',
                      value: '- ${MoneyUtils.formatMoney(returnsTotal)}',
                      labelStyle: TextStyle(
                        color: colors.secondary,
                      ),
                      valueStyle: TextStyle(
                        color: colors.secondary,
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
                      color: isSale ? context.semantic.success : context.semantic.warning,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SummaryRow(
                    label: 'المدفوع',
                    value: MoneyUtils.formatMoney(paid),
                    valueStyle: TextStyle(
                      color: context.semantic.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            if (featureEnabled(AppFeature.debts))
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getBalanceBackgroundColor(context, balance),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                border: Border(top: BorderSide(color: colors.outlineVariant)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getBalanceLabel(balance, isSale),
                        style: TextStyle(
                          color: _getBalanceTextColor(context, balance),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        MoneyUtils.formatMoney(balance.abs()),
                        style: TextStyle(
                          color: _getBalanceTextColor(context, balance),
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
                      color: _getProgressBarColor(context, balance),
                      backgroundColor: colors.outlineVariant,
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

  Color _getBalanceTextColor(BuildContext context, int balance) {
    if (balance > 0) return Theme.of(context).colorScheme.error;
    if (balance < 0) return Theme.of(context).colorScheme.primary;
    return context.semantic.success;
  }

  Color _getBalanceBackgroundColor(BuildContext context, int balance) {
    final color = _getBalanceTextColor(context, balance);
    return color.withValues(alpha: 0.08);
  }

  Color _getProgressBarColor(BuildContext context, int balance) {
    if (balance > 0) return context.semantic.warning;
    return _getBalanceTextColor(context, balance);
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
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: labelStyle?.color ?? textTheme.bodySmall?.color,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: labelStyle ?? textTheme.bodySmall,
            ),
          ],
        ),
        Text(value, style: valueStyle ?? const TextStyle(fontSize: 14)),
      ],
    );
  }
}

class _CompanyIdentityBlock extends StatelessWidget {
  const _CompanyIdentityBlock();

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<CompanyProfileController>()) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    return Obx(() {
      final lines = Get.find<CompanyProfileController>().headerLines;
      if (lines.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < lines.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0 : 2),
                child: Text(
                  lines[i],
                  softWrap: true,
                  style: i == 0
                      ? const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        )
                      : TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                ),
              ),
            const SizedBox(height: 10),
            Divider(height: 1, color: colors.outlineVariant),
          ],
        ),
      );
    });
  }
}
