import 'invoice_model.dart';
import 'invoice_item_model.dart';

class InvoiceDraft {
  final InvoiceType type;
  final int partyId;
  final String partyNameSnapshot;
  final String partyAddressSnapshot;
  final String? notes;
  final List<InvoiceItemDraft> items;
  final int initialPayment; // ← المبلغ المدفوع عند الإنشاء (0 = غير مدفوع)

  InvoiceDraft({
    required this.type,
    required this.partyId,
    required this.partyNameSnapshot,
    required this.partyAddressSnapshot,
    this.notes,
    required this.items,
    this.initialPayment = 0,
  });

  int get totalAmount => items.fold(0, (sum, item) => sum + item.lineTotal);

  int get remaining => totalAmount - initialPayment;

  PaymentStatus get paymentStatus {
    if (initialPayment <= 0) return PaymentStatus.unpaid;
    if (initialPayment >= totalAmount) return PaymentStatus.paid;
    return PaymentStatus.partial;
  }
}
/// سطر فاتورة قبل الحفظ (بدون id أو invoiceId لأنهما غير معروفين بعد)
class InvoiceItemDraft {
  final int productId;
  final String productNameSnapshot;
  final double quantity;
  final int unitPrice;

  InvoiceItemDraft({
    required this.productId,
    required this.productNameSnapshot,
    required this.quantity,
    required this.unitPrice,
  });

  int get lineTotal => (quantity * unitPrice).round();
}

/// نتيجة جلب فاتورة كاملة (للعرض في صفحة التفاصيل)
class InvoiceWithItems {
  final InvoiceModel invoice;
  final List<InvoiceItemModel> items;

  InvoiceWithItems({required this.invoice, required this.items});
}