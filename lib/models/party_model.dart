class PartyModel {
  final int? id;
  final PartyType type;
  final String name;
  final String? phone;
  final String? address;
  final String? createdAt;

  PartyModel({
    this.id,
    required this.type,
    required this.name,
    this.phone,
    this.address,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name.toUpperCase(),         // ← تصحيح
      'name': name,
      'phone': phone,
      'address': address,
      'created_at': createdAt,
    };
  }

  factory PartyModel.fromMap(Map<String, dynamic> map) {
    return PartyModel(
      id: map['id'],
      type: PartyType.values.byName(map['type'].toString().toLowerCase()), // ← تصحيح
      name: map['name'],
      phone: map['phone'],
      address: map['address'],
      createdAt: map['created_at'],
    );
  }
}

enum PartyType { customer, supplier, both }