/// نموذج الفاتورة - يمثل صف واحد في جدول invoices
///
/// ملاحظة: invoiceNumber هو String وليس int لأن العمود في قاعدة
/// البيانات معرّف كـ TEXT (مثل "INV-0001")، رغم أنه يُولَّد تلقائياً
/// من رقم تسلسلي داخلي.
class InvoiceModel {
  final int? id;
  final String invoiceNumber; // مُصحَّح: كان int، والعمود TEXT
  final InvoiceType type;
  final int partyId;
  final String partyNameSnapshot; // نسخة من اسم الطرف وقت إنشاء الفاتورة
  final String partyAddressSnapshot; // نفس الفكرة للعنوان
  final int totalAmount;
  final String? notes; // مُصحَّح: كان required، والعمود يقبل NULL
  final String? createdAt;

  InvoiceModel({
    this.id,
    required this.invoiceNumber,
    required this.type,
    required this.partyId,
    required this.partyNameSnapshot,
    required this.partyAddressSnapshot,
    required this.totalAmount,
    this.notes,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'type': type.name.toUpperCase(), // SALE / PURCHASE
      'party_id': partyId,
      'party_name_snapshot': partyNameSnapshot,
      'party_address_snapshot': partyAddressSnapshot,
      'total_amount': totalAmount,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory InvoiceModel.fromMap(Map<String, dynamic> map) {
    return InvoiceModel(
      id: map['id'],
      invoiceNumber: map['invoice_number'],
      type: InvoiceType.values.byName(
        map['type'].toString().toLowerCase(),
      ),
      partyId: map['party_id'],
      partyNameSnapshot: map['party_name_snapshot'],
      partyAddressSnapshot: map['party_address_snapshot'],
      totalAmount: map['total_amount'],
      notes: map['notes'],
      createdAt: map['created_at'],
    );
  }
}

enum InvoiceType { sale, purchase }