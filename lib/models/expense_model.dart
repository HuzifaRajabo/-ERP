// expense_model.dart
enum ExpenseCategory {
  transport,
  fuel,
  salaries,
  rent,
  electricity,
  internet,
  maintenance,
  other,
}

extension ExpenseCategoryLabel on ExpenseCategory {
  String get label => switch (this) {
    ExpenseCategory.transport => 'نقل',
    ExpenseCategory.fuel => 'وقود',
    ExpenseCategory.salaries => 'رواتب',
    ExpenseCategory.rent => 'إيجار',
    ExpenseCategory.electricity => 'كهرباء',
    ExpenseCategory.internet => 'إنترنت',
    ExpenseCategory.maintenance => 'صيانة',
    ExpenseCategory.other => 'أخرى',
  };
}

class ExpenseModel {
  final int? id;
  final int amount;
  final String description;
  final ExpenseCategory category;
  final String? createdAt;

  ExpenseModel({
    this.id,
    required this.amount,
    required this.description,
    required this.category,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'amount': amount,
      'description': description,
      'category': category.name.toUpperCase(),
    };

    if (createdAt != null) {
      map['created_at'] = createdAt;
    }

    return map;
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) => ExpenseModel(
    id: map['id'],
    amount: map['amount'],
    description: map['description'],
    category: ExpenseCategory.values.byName(
      map['category'].toString().toLowerCase(),
    ),
    createdAt: map['created_at'],
  );
}
