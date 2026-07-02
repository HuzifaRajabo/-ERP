import 'invoice_model.dart';
import 'invoice_item_model.dart';

class InvoiceDraft {
  final InvoiceType type;
  final int partyId;
  final String partyNameSnapshot;
  final String partyAddressSnapshot;
  final String? notes;
  final List<InvoiceItemDraft> items;

  InvoiceDraft({
    required this.type,
    required this.partyId,
    required this.partyNameSnapshot,
    required this.partyAddressSnapshot,
    this.notes,
    required this.items,
  });

  /// المبلغ الإجمالي يُحسب تلقائياً من مجموع أسطر الفاتورة
  /// لمنع أي تضارب بين القيمة المُدخلة يدوياً والقيمة الحقيقية
  int get totalAmount => items.fold(0, (sum, item) => sum + item.lineTotal);
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