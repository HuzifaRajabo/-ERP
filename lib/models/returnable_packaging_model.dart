enum PackagingMovementType {
  issued,
  returned,
  broken,
  lost,
  reversed,
  openingEmpty,
  openingIssued,
  purchasedEmpty,
  filled,
  unfilled;

  String get dbValue => switch (this) {
        PackagingMovementType.issued => 'ISSUED',
        PackagingMovementType.returned => 'RETURNED',
        PackagingMovementType.broken => 'BROKEN',
        PackagingMovementType.lost => 'LOST',
        PackagingMovementType.reversed => 'REVERSED',
        PackagingMovementType.openingEmpty => 'OPENING_EMPTY',
        PackagingMovementType.openingIssued => 'OPENING_ISSUED',
        PackagingMovementType.purchasedEmpty => 'PURCHASED_EMPTY',
        PackagingMovementType.filled => 'FILLED',
        PackagingMovementType.unfilled => 'UNFILLED',
      };

  String get label => switch (this) {
        PackagingMovementType.issued => 'تسليم',
        PackagingMovementType.returned => 'استلام سليم',
        PackagingMovementType.broken => 'مكسر',
        PackagingMovementType.lost => 'مفقود',
        PackagingMovementType.reversed => 'عكس مرتجع بيع',
        PackagingMovementType.openingEmpty => 'رصيد افتتاحي فارغ',
        PackagingMovementType.openingIssued => 'رصيد افتتاحي لدى العميل',
        PackagingMovementType.purchasedEmpty => 'شراء عبوات فارغة',
        PackagingMovementType.filled => 'تعبئة من شراء',
        PackagingMovementType.unfilled => 'عكس تعبئة مرتجع شراء',
      };

  static PackagingMovementType fromDb(String value) {
    return PackagingMovementType.values.firstWhere(
      (item) => item.dbValue == value.toUpperCase(),
      orElse: () => PackagingMovementType.issued,
    );
  }
}

class PackagingType {
  final int? id;
  final String name;
  final String? description;
  final int value;
  final bool isActive;
  final String? createdAt;

  PackagingType({
    this.id,
    required this.name,
    this.description,
    this.value = 0,
    this.isActive = true,
    this.createdAt,
  });

  factory PackagingType.fromMap(Map<String, dynamic> map) => PackagingType(
        id: map['id'] as int?,
        name: map['name'] as String,
        description: map['description'] as String?,
        value: map['value'] as int? ?? 0,
        isActive: (map['is_active'] as int? ?? 1) == 1,
        createdAt: map['created_at'] as String?,
      );
}

class PackagingUnit {
  final int? id;
  final int typeId;
  final String unitName;
  final double conversionFactor;
  final bool isBaseUnit;
  final bool isActive;
  final String? createdAt;

  PackagingUnit({
    this.id,
    required this.typeId,
    required this.unitName,
    required this.conversionFactor,
    this.isBaseUnit = false,
    this.isActive = true,
    this.createdAt,
  });

  factory PackagingUnit.fromMap(Map<String, dynamic> map) => PackagingUnit(
        id: map['id'] as int?,
        typeId: map['type_id'] as int,
        unitName: map['unit_name'] as String,
        conversionFactor: (map['conversion_factor'] as num?)?.toDouble() ?? 1,
        isBaseUnit: (map['is_base_unit'] as int? ?? 0) == 1,
        isActive: (map['is_active'] as int? ?? 1) == 1,
        createdAt: map['created_at'] as String?,
      );
}

class PackagingProductMapping {
  final int? id;
  final int productId;
  final int typeId;
  final double unitsPerProductBase;
  final String? productName;
  final String? typeName;

  PackagingProductMapping({
    this.id,
    required this.productId,
    required this.typeId,
    this.unitsPerProductBase = 1,
    this.productName,
    this.typeName,
  });

  factory PackagingProductMapping.fromMap(Map<String, dynamic> map) =>
      PackagingProductMapping(
        id: map['id'] as int?,
        productId: map['product_id'] as int,
        typeId: map['type_id'] as int,
        unitsPerProductBase:
            (map['units_per_product_base'] as num?)?.toDouble() ?? 1,
        productName: map['product_name'] as String?,
        typeName: map['type_name'] as String?,
      );
}

class PackagingTransaction {
  final int? id;
  final int typeId;
  final int? partyId;
  final int? warehouseId;
  final PackagingMovementType movementType;
  final double quantity;
  final int? invoiceId;
  final int? returnId;
  final int? settlementId;
  final int? chargeId;
  final String? notes;
  final String? createdAt;
  final String? typeName;
  final String? partyName;
  final String? warehouseName;
  final String? invoiceNumber;
  final String? settlementNumber;

  PackagingTransaction({
    this.id,
    required this.typeId,
    this.partyId,
    this.warehouseId,
    required this.movementType,
    required this.quantity,
    this.invoiceId,
    this.returnId,
    this.settlementId,
    this.chargeId,
    this.notes,
    this.createdAt,
    this.typeName,
    this.partyName,
    this.warehouseName,
    this.invoiceNumber,
    this.settlementNumber,
  });

  factory PackagingTransaction.fromMap(Map<String, dynamic> map) =>
      PackagingTransaction(
        id: map['id'] as int?,
        typeId: map['type_id'] as int,
        partyId: map['party_id'] as int?,
        warehouseId: map['warehouse_id'] as int?,
        movementType: PackagingMovementType.fromDb(
          map['movement_type'] as String? ?? 'ISSUED',
        ),
        quantity: (map['quantity'] as num).toDouble(),
        invoiceId: map['invoice_id'] as int?,
        returnId: map['return_id'] as int?,
        settlementId: map['settlement_id'] as int?,
        chargeId: map['charge_id'] as int?,
        notes: map['notes'] as String?,
        createdAt: map['created_at'] as String?,
        typeName: map['type_name'] as String?,
        partyName: map['party_name'] as String?,
        warehouseName: map['warehouse_name'] as String?,
        invoiceNumber: map['invoice_number'] as String?,
        settlementNumber: map['settlement_number'] as String?,
      );
}

class PackagingSettlement {
  final int? id;
  final String settlementNumber;
  final int partyId;
  final int typeId;
  final int warehouseId;
  final String? notes;
  final String? createdAt;
  final String? partyName;
  final String? typeName;
  final String? warehouseName;

  PackagingSettlement({
    this.id,
    required this.settlementNumber,
    required this.partyId,
    required this.typeId,
    required this.warehouseId,
    this.notes,
    this.createdAt,
    this.partyName,
    this.typeName,
    this.warehouseName,
  });

  factory PackagingSettlement.fromMap(Map<String, dynamic> map) =>
      PackagingSettlement(
        id: map['id'] as int?,
        settlementNumber: map['settlement_number'] as String,
        partyId: map['party_id'] as int,
        typeId: map['type_id'] as int,
        warehouseId: map['warehouse_id'] as int,
        notes: map['notes'] as String?,
        createdAt: map['created_at'] as String?,
        partyName: map['party_name'] as String?,
        typeName: map['type_name'] as String?,
        warehouseName: map['warehouse_name'] as String?,
      );
}

class PackagingCharge {
  final int? id;
  final int partyId;
  final int typeId;
  final int? transactionId;
  final int? settlementId;
  final int amount;
  final int paidAmount;
  final String? notes;
  final String? createdAt;
  final String? partyName;
  final String? typeName;
  final String? settlementNumber;

  PackagingCharge({
    this.id,
    required this.partyId,
    required this.typeId,
    this.transactionId,
    this.settlementId,
    required this.amount,
    this.paidAmount = 0,
    this.notes,
    this.createdAt,
    this.partyName,
    this.typeName,
    this.settlementNumber,
  });

  int get remaining => amount - paidAmount;

  String get displayNumber {
    final number = settlementNumber?.trim();
    if (number != null && number.isNotEmpty) {
      return 'تعويض عبوات • $number';
    }
    return 'تعويض عبوات';
  }

  factory PackagingCharge.fromMap(Map<String, dynamic> map) => PackagingCharge(
        id: map['id'] as int?,
        partyId: map['party_id'] as int,
        typeId: map['type_id'] as int,
        transactionId: map['transaction_id'] as int?,
        settlementId: map['settlement_id'] as int?,
        amount: map['amount'] as int? ?? 0,
        paidAmount: map['paid_amount'] as int? ?? 0,
        notes: map['notes'] as String?,
        createdAt: map['created_at'] as String?,
        partyName: map['party_name'] as String?,
        typeName: map['type_name'] as String?,
        settlementNumber: map['settlement_number'] as String?,
      );
}

class PartyPackagingBalance {
  final int typeId;
  final String typeName;
  final int typeValue;
  final double issued;
  final double returned;
  final double broken;
  final double lost;
  final double reversed;
  final double unsettled;
  final int chargeDue;

  PartyPackagingBalance({
    required this.typeId,
    required this.typeName,
    required this.typeValue,
    required this.issued,
    required this.returned,
    required this.broken,
    required this.lost,
    required this.reversed,
    required this.unsettled,
    required this.chargeDue,
  });
}

class WarehouseEmptyStock {
  final int warehouseId;
  final String warehouseName;
  final int typeId;
  final String typeName;
  final double quantity;

  WarehouseEmptyStock({
    required this.warehouseId,
    required this.warehouseName,
    required this.typeId,
    required this.typeName,
    required this.quantity,
  });
}

class PackagingWarehouseStock {
  final int warehouseId;
  final String warehouseName;
  final int typeId;
  final String typeName;
  final double empty;
  final double fullInStock;

  PackagingWarehouseStock({
    required this.warehouseId,
    required this.warehouseName,
    required this.typeId,
    required this.typeName,
    this.empty = 0,
    this.fullInStock = 0,
  });

  double get totalInWarehouse => empty + fullInStock;
}

class PackagingReportSummary {
  final double issued;
  final double returned;
  final double broken;
  final double lost;
  final double reversed;
  final double unsettled;
  final double emptyStock;
  final double fullInStock;
  final int chargeDue;
  final int chargeTotal;
  final int totalValue;

  const PackagingReportSummary({
    this.issued = 0,
    this.returned = 0,
    this.broken = 0,
    this.lost = 0,
    this.reversed = 0,
    this.unsettled = 0,
    this.emptyStock = 0,
    this.fullInStock = 0,
    this.chargeDue = 0,
    this.chargeTotal = 0,
    this.totalValue = 0,
  });
}

class PackagingTypeOwnership {
  final int typeId;
  final String typeName;
  final int typeValue;
  final double empty;
  final double fullInStock;
  final double unsettled;
  final int totalValue;
  final int warehouseCount;

  PackagingTypeOwnership({
    required this.typeId,
    required this.typeName,
    required this.typeValue,
    required this.empty,
    required this.fullInStock,
    required this.unsettled,
    this.warehouseCount = 0,
  }) : totalValue =
            ((empty + fullInStock + unsettled) * typeValue).round();

  double get totalQty => empty + fullInStock + unsettled;
}

class PackagingOwnershipSummary {
  final List<PackagingTypeOwnership> byType;
  final List<PackagingWarehouseStock> byWarehouse;

  const PackagingOwnershipSummary({
    this.byType = const [],
    this.byWarehouse = const [],
  });

  double get empty =>
      byType.fold(0, (sum, item) => sum + item.empty);
  double get fullInStock =>
      byType.fold(0, (sum, item) => sum + item.fullInStock);
  double get unsettled =>
      byType.fold(0, (sum, item) => sum + item.unsettled);
  double get totalQty => empty + fullInStock + unsettled;
  int get totalValue =>
      byType.fold(0, (sum, item) => sum + item.totalValue);
}

class PackagingFillShortage {
  final int typeId;
  final String typeName;
  final double needed;
  final double available;
  final double extraOffered;

  PackagingFillShortage({
    required this.typeId,
    required this.typeName,
    required this.needed,
    required this.available,
    this.extraOffered = 0,
  });

  double get shortage {
    final value = needed - available - extraOffered;
    return value < 0 ? 0 : value;
  }
}

class PackagingSaleItem {
  final int productId;
  final double baseQuantity;

  const PackagingSaleItem({
    required this.productId,
    required this.baseQuantity,
  });
}

class PackagingException implements Exception {
  PackagingException(this.message);
  final String message;

  @override
  String toString() => message;
}

class PackagingShortageException implements Exception {
  PackagingShortageException(this.shortages);
  final List<PackagingFillShortage> shortages;

  String get message {
    if (shortages.isEmpty) {
      return 'كمية الشراء تتجاوز الفوارغ المتاحة في المستودع';
    }
    final first = shortages.first;
    return 'كمية الشراء تتجاوز الفوارغ المتاحة لنوع "${first.typeName}": '
        'مطلوب ${_formatQuantity(first.needed)}، '
        'متاح ${_formatQuantity(first.available)}، '
        'النقص ${_formatQuantity(first.shortage)}';
  }

  @override
  String toString() => message;

  static String _formatQuantity(double value) {
    const epsilon = 0.0001;
    if ((value - value.roundToDouble()).abs() < epsilon) {
      return value.round().toString();
    }
    final asFixed = value.toStringAsFixed(2);
    if (asFixed.endsWith('00')) {
      return value.round().toString();
    }
    if (asFixed.endsWith('0')) {
      return value.toStringAsFixed(1);
    }
    return asFixed;
  }
}

class PackagingAlertRow {
  const PackagingAlertRow({
    required this.partyId,
    required this.partyName,
    required this.typeId,
    required this.typeName,
    required this.unsettled,
    this.oldestIssuedAt,
  });

  final int partyId;
  final String partyName;
  final int typeId;
  final String typeName;
  final double unsettled;
  final String? oldestIssuedAt;
}
