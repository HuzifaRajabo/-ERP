import 'invoice_model.dart';
import 'invoice_item_model.dart';

class InvoiceDraft {
  final InvoiceType type;
  final int partyId;
  final String partyNameSnapshot;
  final String partyAddressSnapshot;
  final String? notes;
  final List<InvoiceItemDraft> items;
  final int initialPayment;
  final int? warehouseId; // ← المستودع/السيارة التي تصدر منها الفاتورة

  InvoiceDraft({
    required this.type,
    required this.partyId,
    required this.partyNameSnapshot,
    required this.partyAddressSnapshot,
    this.notes,
    required this.items,
    this.initialPayment = 0,
    this.warehouseId,
  });

  int get totalAmount => items.fold(0, (sum, item) => sum + item.lineTotal);

  int get remaining => totalAmount - initialPayment;

  PaymentStatus get paymentStatus {
    if (initialPayment <= 0) return PaymentStatus.unpaid;
    if (initialPayment >= totalAmount) return PaymentStatus.paid;
    return PaymentStatus.partial;
  }
}

/// سطر فاتورة قبل الحفظ — يحمل معلومات الوحدة والدفعة
class InvoiceItemDraft {
  final int productId;
  final String productNameSnapshot;
  final double quantity;           // بالوحدة المختارة (قطعة/باكيت/كرتون)
  final int unitPrice;             // سعر تلك الوحدة
  final int? unitId;               // null = الوحدة الأساسية
  final String? unitNameSnapshot;
  final double conversionFactorSnapshot; // كم قطعة في الوحدة
  final int? batchId;              // الدفعة المختارة (للتتبع والصلاحية)
  final List<BatchAllocationSnapshot> batchAllocations;

  InvoiceItemDraft({
    required this.productId,
    required this.productNameSnapshot,
    required this.quantity,
    required this.unitPrice,
    this.unitId,
    this.unitNameSnapshot,
    this.conversionFactorSnapshot = 1,
    this.batchId,
    this.batchAllocations = const [],
  });

  int get lineTotal => (quantity * unitPrice).round();

  /// الكمية بالوحدة الأساسية — هذا ما يُسجَّل في inventory_transactions
  double get baseQuantity => quantity * conversionFactorSnapshot;
}

class BatchAllocationSnapshot {
  final int batchId;
  final double quantity;
  final String batchNumber;
  final String? expiryDate;

  const BatchAllocationSnapshot({
    required this.batchId,
    required this.quantity,
    required this.batchNumber,
    this.expiryDate,
  });
}

/// نتيجة جلب فاتورة كاملة (للعرض في صفحة التفاصيل)
class InvoiceWithItems {
  final InvoiceModel invoice;
  final List<InvoiceItemModel> items;

  InvoiceWithItems({required this.invoice, required this.items});
}
