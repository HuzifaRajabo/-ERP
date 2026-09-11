import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/database/inventory_stock_sql.dart';
import '../core/utils/packaging_quantity_format.dart';
import '../core/utils/unit_conversion.dart';
import '../models/returnable_packaging_model.dart';

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
        'مطلوب ${PackagingQuantityFormat.formatQuantity(first.needed)}، '
        'متاح ${PackagingQuantityFormat.formatQuantity(first.available)}، '
        'النقص ${PackagingQuantityFormat.formatQuantity(first.shortage)}';
  }

  @override
  String toString() => message;
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

class ReturnablePackagingRepository {
  ReturnablePackagingRepository({Future<Database> Function()? dbProvider})
      : _dbProvider =
            dbProvider ?? (() async => DatabaseHelper.instance.database);

  final Future<Database> Function() _dbProvider;

  Future<Database> get _db async => _dbProvider();

  static const double epsilon = 0.0001;

  static String emptyStockSignedSql({String typeColumn = 'movement_type'}) =>
      '''
        CASE $typeColumn
          WHEN 'OPENING_EMPTY' THEN quantity
          WHEN 'PURCHASED_EMPTY' THEN quantity
          WHEN 'RETURNED' THEN quantity
          WHEN 'UNFILLED' THEN quantity
          WHEN 'FILLED' THEN -quantity
          ELSE 0
        END
      ''';

  // ====================================================================
  // أنواع العبوات ووحداتها
  // ====================================================================

  Future<int> createType({
    required String name,
    String? description,
    int value = 0,
    bool isActive = true,
    String baseUnitName = 'زجاجة',
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw PackagingException('اسم نوع العبوة مطلوب');
    }
    if (value < 0) {
      throw PackagingException('قيمة العبوة لا يمكن أن تكون سالبة');
    }
    final db = await _db;
    return db.transaction<int>((txn) async {
      final typeId = await txn.insert('returnable_packaging_types', {
        'name': trimmed,
        'description': _nullableText(description),
        'value': value,
        'is_active': isActive ? 1 : 0,
      });
      await txn.insert('returnable_packaging_units', {
        'type_id': typeId,
        'unit_name': baseUnitName.trim().isEmpty ? 'زجاجة' : baseUnitName.trim(),
        'conversion_factor': 1,
        'is_base_unit': 1,
        'is_active': 1,
      });
      return typeId;
    });
  }

  Future<void> updateType({
    required int id,
    required String name,
    String? description,
    required int value,
    required bool isActive,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw PackagingException('اسم نوع العبوة مطلوب');
    }
    if (value < 0) {
      throw PackagingException('قيمة العبوة لا يمكن أن تكون سالبة');
    }
    final db = await _db;
    final updated = await db.update(
      'returnable_packaging_types',
      {
        'name': trimmed,
        'description': _nullableText(description),
        'value': value,
        'is_active': isActive ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated == 0) {
      throw PackagingException('نوع العبوة غير موجود');
    }
  }

  Future<List<PackagingType>> getTypes({bool activeOnly = false}) async {
    final db = await _db;
    final rows = await db.query(
      'returnable_packaging_types',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(PackagingType.fromMap).toList();
  }

  Future<PackagingType?> getTypeById(int id) async {
    final db = await _db;
    final rows = await db.query(
      'returnable_packaging_types',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PackagingType.fromMap(rows.first);
  }

  Future<List<PackagingUnit>> getUnits(int typeId, {bool activeOnly = true}) async {
    final db = await _db;
    final rows = await db.query(
      'returnable_packaging_units',
      where: activeOnly ? 'type_id = ? AND is_active = 1' : 'type_id = ?',
      whereArgs: [typeId],
      orderBy: 'is_base_unit DESC, conversion_factor ASC',
    );
    return rows.map(PackagingUnit.fromMap).toList();
  }

  Future<int> addUnit({
    required int typeId,
    required String unitName,
    required double conversionFactor,
  }) async {
    if (unitName.trim().isEmpty) {
      throw PackagingException('اسم الوحدة مطلوب');
    }
    if (conversionFactor <= 1) {
      throw PackagingException('معامل التحويل يجب أن يكون أكبر من 1');
    }
    final db = await _db;
    return db.insert('returnable_packaging_units', {
      'type_id': typeId,
      'unit_name': unitName.trim(),
      'conversion_factor': conversionFactor,
      'is_base_unit': 0,
      'is_active': 1,
    });
  }

  Future<void> updateUnit({
    required int id,
    required String unitName,
    required double conversionFactor,
    required bool isActive,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'returnable_packaging_units',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw PackagingException('وحدة العبوة غير موجودة');
    }
    final isBase = (rows.first['is_base_unit'] as int? ?? 0) == 1;
    if (isBase && conversionFactor != 1) {
      throw PackagingException('الوحدة الأساسية معاملها 1 دائماً');
    }
    if (!isBase && conversionFactor <= 1) {
      throw PackagingException('معامل التحويل يجب أن يكون أكبر من 1');
    }
    await db.update(
      'returnable_packaging_units',
      {
        'unit_name': unitName.trim(),
        'conversion_factor': isBase ? 1 : conversionFactor,
        'is_active': isActive ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteUnit(int id) async {
    final db = await _db;
    final rows = await db.query(
      'returnable_packaging_units',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    if ((rows.first['is_base_unit'] as int? ?? 0) == 1) {
      throw PackagingException('لا يمكن حذف الوحدة الأساسية');
    }
    await db.delete(
      'returnable_packaging_units',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ====================================================================
  // ربط المنتجات
  // ====================================================================

  Future<void> setProductMapping({
    required int productId,
    required int typeId,
    double unitsPerProductBase = 1,
  }) async {
    if (unitsPerProductBase <= 0) {
      throw PackagingException('عدد العبوات لكل وحدة أساسية يجب أن يكون أكبر من صفر');
    }
    final db = await _db;
    await db.insert(
      'returnable_packaging_product_mappings',
      {
        'product_id': productId,
        'type_id': typeId,
        'units_per_product_base': unitsPerProductBase,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearProductMapping(int productId) async {
    final db = await _db;
    await db.delete(
      'returnable_packaging_product_mappings',
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  Future<PackagingProductMapping?> getProductMapping(int productId) async {
    final db = await _db;
    return _mappingForProduct(db, productId);
  }

  Future<Map<int, PackagingProductMapping>> getAllProductMappings() async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT m.*, p.name AS product_name, t.name AS type_name
      FROM returnable_packaging_product_mappings m
      INNER JOIN products p ON p.id = m.product_id
      INNER JOIN returnable_packaging_types t ON t.id = m.type_id
      ''',
    );
    return {
      for (final row in rows)
        row['product_id'] as int: PackagingProductMapping.fromMap(row),
    };
  }

  Future<List<PackagingProductMapping>> getMappingsForType(int typeId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT m.*, p.name AS product_name, t.name AS type_name
      FROM returnable_packaging_product_mappings m
      INNER JOIN products p ON p.id = m.product_id
      INNER JOIN returnable_packaging_types t ON t.id = m.type_id
      WHERE m.type_id = ?
      ORDER BY p.name COLLATE NOCASE
      ''',
      [typeId],
    );
    return rows.map(PackagingProductMapping.fromMap).toList();
  }

  // ====================================================================
  // أرصدة
  // ====================================================================

  Future<double> unsettled({
    required int partyId,
    required int typeId,
  }) async {
    final db = await _db;
    return unsettledInTxn(db, partyId: partyId, typeId: typeId);
  }

  static Future<double> unsettledInTxn(
    DatabaseExecutor txn, {
    required int partyId,
    required int typeId,
  }) async {
    final rows = await txn.rawQuery(
      '''
      SELECT COALESCE(SUM(
        CASE movement_type
          WHEN 'ISSUED' THEN quantity
          WHEN 'OPENING_ISSUED' THEN quantity
          WHEN 'RETURNED' THEN -quantity
          WHEN 'BROKEN' THEN -quantity
          WHEN 'LOST' THEN -quantity
          WHEN 'REVERSED' THEN -quantity
          ELSE 0
        END
      ), 0) AS qty
      FROM returnable_packaging_transactions
      WHERE party_id = ? AND type_id = ?
      ''',
      [partyId, typeId],
    );
    return (rows.first['qty'] as num?)?.toDouble() ?? 0;
  }

  Future<double> emptyStock({
    required int warehouseId,
    int? typeId,
  }) async {
    final db = await _db;
    return _emptyStockInTxn(db, warehouseId: warehouseId, typeId: typeId);
  }

  Future<int> chargeDue({int? partyId}) async {
    final db = await _db;
    final where = partyId == null
        ? '(amount - paid_amount) > 0'
        : 'party_id = ? AND (amount - paid_amount) > 0';
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount - paid_amount), 0) AS total
      FROM returnable_packaging_charges
      WHERE $where
      ''',
      partyId == null ? null : [partyId],
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<List<PackagingAlertRow>> getUnsettledAlertRows() async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT
        x.party_id AS party_id,
        p.name AS party_name,
        x.type_id AS type_id,
        t.name AS type_name,
        COALESCE(SUM(
          CASE
            WHEN x.movement_type IN ('ISSUED','OPENING_ISSUED') THEN x.quantity
            WHEN x.movement_type IN ('RETURNED','BROKEN','LOST','REVERSED') THEN -x.quantity
            ELSE 0
          END
        ), 0) AS unsettled,
        MIN(
          CASE
            WHEN x.movement_type IN ('ISSUED','OPENING_ISSUED') THEN x.created_at
            ELSE NULL
          END
        ) AS oldest_issued_at
      FROM returnable_packaging_transactions x
      INNER JOIN parties p ON p.id = x.party_id
      INNER JOIN returnable_packaging_types t ON t.id = x.type_id
      WHERE x.party_id IS NOT NULL
      GROUP BY x.party_id, p.name, x.type_id, t.name
      HAVING unsettled > $epsilon
      ORDER BY p.name COLLATE NOCASE, t.name COLLATE NOCASE
      ''',
    );
    return rows
        .map(
          (row) => PackagingAlertRow(
            partyId: row['party_id'] as int,
            partyName: row['party_name'] as String? ?? '',
            typeId: row['type_id'] as int,
            typeName: row['type_name'] as String? ?? '',
            unsettled: (row['unsettled'] as num?)?.toDouble() ?? 0,
            oldestIssuedAt: row['oldest_issued_at'] as String?,
          ),
        )
        .toList();
  }

  Future<List<PartyPackagingBalance>> getPartyBalances(int partyId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT
        t.id AS type_id,
        t.name AS type_name,
        t.value AS type_value,
        COALESCE(SUM(CASE WHEN x.movement_type IN ('ISSUED','OPENING_ISSUED') THEN x.quantity ELSE 0 END), 0) AS issued,
        COALESCE(SUM(CASE WHEN x.movement_type = 'RETURNED' THEN x.quantity ELSE 0 END), 0) AS returned,
        COALESCE(SUM(CASE WHEN x.movement_type = 'BROKEN' THEN x.quantity ELSE 0 END), 0) AS broken,
        COALESCE(SUM(CASE WHEN x.movement_type = 'LOST' THEN x.quantity ELSE 0 END), 0) AS lost,
        COALESCE(SUM(CASE WHEN x.movement_type = 'REVERSED' THEN x.quantity ELSE 0 END), 0) AS reversed
      FROM returnable_packaging_types t
      INNER JOIN returnable_packaging_transactions x
        ON x.type_id = t.id AND x.party_id = ?
      GROUP BY t.id, t.name, t.value
      ORDER BY t.name COLLATE NOCASE
      ''',
      [partyId],
    );
    final charges = await db.rawQuery(
      '''
      SELECT type_id, COALESCE(SUM(amount - paid_amount), 0) AS due
      FROM returnable_packaging_charges
      WHERE party_id = ? AND (amount - paid_amount) > 0
      GROUP BY type_id
      ''',
      [partyId],
    );
    final dueByType = <int, int>{
      for (final row in charges)
        row['type_id'] as int: (row['due'] as num).toInt(),
    };
    return rows.map((row) {
      final issued = (row['issued'] as num).toDouble();
      final returned = (row['returned'] as num).toDouble();
      final broken = (row['broken'] as num).toDouble();
      final lost = (row['lost'] as num).toDouble();
      final reversed = (row['reversed'] as num).toDouble();
      return PartyPackagingBalance(
        typeId: row['type_id'] as int,
        typeName: row['type_name'] as String,
        typeValue: row['type_value'] as int? ?? 0,
        issued: issued,
        returned: returned,
        broken: broken,
        lost: lost,
        reversed: reversed,
        unsettled: issued - returned - broken - lost - reversed,
        chargeDue: dueByType[row['type_id'] as int] ?? 0,
      );
    }).toList();
  }

  Future<List<WarehouseEmptyStock>> getEmptyStock({int? warehouseId}) async {
    final db = await _db;
    final where = warehouseId == null ? '' : 'AND x.warehouse_id = ?';
    final rows = await db.rawQuery(
      '''
      SELECT
        x.warehouse_id,
        w.name AS warehouse_name,
        x.type_id,
        t.name AS type_name,
        COALESCE(SUM(${emptyStockSignedSql(typeColumn: 'x.movement_type')}), 0) AS qty
      FROM returnable_packaging_transactions x
      INNER JOIN warehouses w ON w.id = x.warehouse_id
      INNER JOIN returnable_packaging_types t ON t.id = x.type_id
      WHERE x.warehouse_id IS NOT NULL $where
      GROUP BY x.warehouse_id, w.name, x.type_id, t.name
      HAVING qty > $epsilon
      ORDER BY w.name COLLATE NOCASE, t.name COLLATE NOCASE
      ''',
      warehouseId == null ? null : [warehouseId],
    );
    return rows
        .map(
          (row) => WarehouseEmptyStock(
            warehouseId: row['warehouse_id'] as int,
            warehouseName: row['warehouse_name'] as String,
            typeId: row['type_id'] as int,
            typeName: row['type_name'] as String,
            quantity: (row['qty'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<List<PackagingWarehouseStock>> getWarehouseStock({
    int? warehouseId,
    int? typeId,
    bool includeZeroWarehouses = false,
  }) async {
    final db = await _db;
    final emptyArgs = <Object?>[];
    var emptyWhere = 'x.warehouse_id IS NOT NULL';
    if (warehouseId != null) {
      emptyWhere += ' AND x.warehouse_id = ?';
      emptyArgs.add(warehouseId);
    }
    if (typeId != null) {
      emptyWhere += ' AND x.type_id = ?';
      emptyArgs.add(typeId);
    }
    final emptyRows = await db.rawQuery(
      '''
      SELECT
        x.warehouse_id,
        w.name AS warehouse_name,
        x.type_id,
        t.name AS type_name,
        COALESCE(SUM(${emptyStockSignedSql(typeColumn: 'x.movement_type')}), 0) AS empty_qty
      FROM returnable_packaging_transactions x
      INNER JOIN warehouses w ON w.id = x.warehouse_id
      INNER JOIN returnable_packaging_types t ON t.id = x.type_id
      WHERE $emptyWhere
      GROUP BY x.warehouse_id, w.name, x.type_id, t.name
      ''',
      emptyArgs,
    );

    final fullArgs = <Object?>[];
    var fullWhere = 'it.warehouse_id IS NOT NULL';
    if (warehouseId != null) {
      fullWhere += ' AND it.warehouse_id = ?';
      fullArgs.add(warehouseId);
    }
    if (typeId != null) {
      fullWhere += ' AND m.type_id = ?';
      fullArgs.add(typeId);
    }
    final fullRows = await db.rawQuery(
      '''
      SELECT
        m.type_id,
        t.name AS type_name,
        it.warehouse_id,
        w.name AS warehouse_name,
        COALESCE(SUM(
          (${InventoryStockSql.signedQuantityCase(typeColumn: 'it.type', quantityColumn: 'it.quantity')}) * m.units_per_product_base
        ), 0) AS full_qty
      FROM returnable_packaging_product_mappings m
      INNER JOIN returnable_packaging_types t ON t.id = m.type_id
      INNER JOIN inventory_transactions it ON it.product_id = m.product_id
      INNER JOIN warehouses w ON w.id = it.warehouse_id
      WHERE $fullWhere
      GROUP BY m.type_id, t.name, it.warehouse_id, w.name
      ''',
      fullArgs,
    );

    final map = <String, PackagingWarehouseStock>{};
    String keyOf(int warehouse, int type) => '$warehouse-$type';

    void upsert({
      required int warehouseId,
      required String warehouseName,
      required int typeId,
      required String typeName,
      double? empty,
      double? fullInStock,
    }) {
      final key = keyOf(warehouseId, typeId);
      final current = map[key];
      map[key] = PackagingWarehouseStock(
        warehouseId: warehouseId,
        warehouseName: warehouseName,
        typeId: typeId,
        typeName: typeName,
        empty: empty ?? current?.empty ?? 0,
        fullInStock: fullInStock ?? current?.fullInStock ?? 0,
      );
    }

    for (final row in emptyRows) {
      upsert(
        warehouseId: row['warehouse_id'] as int,
        warehouseName: row['warehouse_name'] as String,
        typeId: row['type_id'] as int,
        typeName: row['type_name'] as String,
        empty: (row['empty_qty'] as num?)?.toDouble() ?? 0,
      );
    }
    for (final row in fullRows) {
      upsert(
        warehouseId: row['warehouse_id'] as int,
        warehouseName: row['warehouse_name'] as String,
        typeId: row['type_id'] as int,
        typeName: row['type_name'] as String,
        fullInStock: (row['full_qty'] as num?)?.toDouble() ?? 0,
      );
    }

    if (includeZeroWarehouses) {
      final typeRows = typeId == null
          ? await db.query(
              'returnable_packaging_types',
              where: 'is_active = 1',
            )
          : await db.query(
              'returnable_packaging_types',
              where: 'id = ?',
              whereArgs: [typeId],
            );
      final warehouseRows = warehouseId == null
          ? await db.query(
              'warehouses',
              where: 'is_active = 1',
              orderBy: 'is_default DESC, name COLLATE NOCASE',
            )
          : await db.query(
              'warehouses',
              where: 'id = ?',
              whereArgs: [warehouseId],
            );
      for (final type in typeRows) {
        final resolvedTypeId = type['id'] as int;
        final typeName = type['name'] as String;
        for (final warehouse in warehouseRows) {
          final resolvedWarehouseId = warehouse['id'] as int;
          map.putIfAbsent(
            keyOf(resolvedWarehouseId, resolvedTypeId),
            () => PackagingWarehouseStock(
              warehouseId: resolvedWarehouseId,
              warehouseName: warehouse['name'] as String,
              typeId: resolvedTypeId,
              typeName: typeName,
            ),
          );
        }
      }
    } else {
      map.removeWhere(
        (_, row) =>
            row.empty.abs() <= epsilon && row.fullInStock.abs() <= epsilon,
      );
    }

    final result = map.values.toList()
      ..sort((a, b) {
        final byWarehouse = a.warehouseName.compareTo(b.warehouseName);
        if (byWarehouse != 0) return byWarehouse;
        return a.typeName.compareTo(b.typeName);
      });
    return result;
  }

  Future<List<PackagingCharge>> getCharges({
    int? partyId,
    bool unpaidOnly = false,
  }) async {
    final db = await _db;
    final conditions = <String>[];
    final args = <Object?>[];
    if (partyId != null) {
      conditions.add('c.party_id = ?');
      args.add(partyId);
    }
    if (unpaidOnly) {
      conditions.add('(c.amount - c.paid_amount) > 0');
    }
    final where =
        conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final rows = await db.rawQuery(
      '''
      SELECT c.*, p.name AS party_name, t.name AS type_name,
             s.settlement_number
      FROM returnable_packaging_charges c
      INNER JOIN parties p ON p.id = c.party_id
      INNER JOIN returnable_packaging_types t ON t.id = c.type_id
      LEFT JOIN returnable_packaging_settlements s ON s.id = c.settlement_id
      $where
      ORDER BY c.id DESC
      ''',
      args,
    );
    return rows.map(PackagingCharge.fromMap).toList();
  }

  Future<List<PackagingTransaction>> getTransactions({
    DateTime? from,
    DateTime? to,
    int? partyId,
    int? typeId,
    PackagingMovementType? movementType,
    int? warehouseId,
  }) async {
    final db = await _db;
    final conditions = <String>[];
    final args = <Object?>[];
    if (partyId != null) {
      conditions.add('x.party_id = ?');
      args.add(partyId);
    }
    if (typeId != null) {
      conditions.add('x.type_id = ?');
      args.add(typeId);
    }
    if (movementType != null) {
      conditions.add('x.movement_type = ?');
      args.add(movementType.dbValue);
    }
    if (warehouseId != null) {
      conditions.add('x.warehouse_id = ?');
      args.add(warehouseId);
    }
    if (from != null) {
      conditions.add("x.created_at >= ?");
      args.add(_sqliteDate(from));
    }
    if (to != null) {
      conditions.add("x.created_at <= ?");
      args.add(_sqliteDate(to));
    }
    final where =
        conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final rows = await db.rawQuery(
      '''
      SELECT
        x.*,
        t.name AS type_name,
        p.name AS party_name,
        w.name AS warehouse_name,
        i.invoice_number,
        s.settlement_number
      FROM returnable_packaging_transactions x
      INNER JOIN returnable_packaging_types t ON t.id = x.type_id
      LEFT JOIN parties p ON p.id = x.party_id
      LEFT JOIN warehouses w ON w.id = x.warehouse_id
      LEFT JOIN invoices i ON i.id = x.invoice_id
      LEFT JOIN returnable_packaging_settlements s ON s.id = x.settlement_id
      $where
      ORDER BY x.id DESC
      ''',
      args,
    );
    return rows.map(PackagingTransaction.fromMap).toList();
  }

  Future<PackagingReportSummary> getReportSummary({
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db;
    final periodConditions = <String>[];
    final args = <Object?>[];
    if (from != null) {
      periodConditions.add('created_at >= ?');
      args.add(_sqliteDate(from));
    }
    if (to != null) {
      periodConditions.add('created_at <= ?');
      args.add(_sqliteDate(to));
    }
    final periodWhere = periodConditions.isEmpty
        ? ''
        : 'WHERE ${periodConditions.join(' AND ')}';
    final period = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN movement_type = 'ISSUED' THEN quantity ELSE 0 END), 0) AS issued,
        COALESCE(SUM(CASE WHEN movement_type = 'RETURNED' THEN quantity ELSE 0 END), 0) AS returned,
        COALESCE(SUM(CASE WHEN movement_type = 'BROKEN' THEN quantity ELSE 0 END), 0) AS broken,
        COALESCE(SUM(CASE WHEN movement_type = 'LOST' THEN quantity ELSE 0 END), 0) AS lost,
        COALESCE(SUM(CASE WHEN movement_type = 'REVERSED' THEN quantity ELSE 0 END), 0) AS reversed
      FROM returnable_packaging_transactions
      $periodWhere
      ''',
      args,
    );
    final current = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(
          CASE movement_type
            WHEN 'ISSUED' THEN quantity
            WHEN 'OPENING_ISSUED' THEN quantity
            WHEN 'RETURNED' THEN -quantity
            WHEN 'BROKEN' THEN -quantity
            WHEN 'LOST' THEN -quantity
            WHEN 'REVERSED' THEN -quantity
            ELSE 0
          END
        ), 0) AS unsettled,
        COALESCE(SUM(${emptyStockSignedSql()}), 0) AS empty_stock
      FROM returnable_packaging_transactions
      ''',
    );
    final charges = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(amount), 0) AS total,
        COALESCE(SUM(amount - paid_amount), 0) AS due
      FROM returnable_packaging_charges
      ''',
    );
    final ownership = await getOwnershipSummary();
    return PackagingReportSummary(
      issued: (period.first['issued'] as num?)?.toDouble() ?? 0,
      returned: (period.first['returned'] as num?)?.toDouble() ?? 0,
      broken: (period.first['broken'] as num?)?.toDouble() ?? 0,
      lost: (period.first['lost'] as num?)?.toDouble() ?? 0,
      reversed: (period.first['reversed'] as num?)?.toDouble() ?? 0,
      unsettled: (current.first['unsettled'] as num?)?.toDouble() ?? 0,
      emptyStock: (current.first['empty_stock'] as num?)?.toDouble() ?? 0,
      fullInStock: ownership.fullInStock,
      chargeTotal: (charges.first['total'] as num?)?.toInt() ?? 0,
      chargeDue: (charges.first['due'] as num?)?.toInt() ?? 0,
      totalValue: ownership.totalValue,
    );
  }

  Future<PackagingOwnershipSummary> getOwnershipSummary() async {
    final db = await _db;
    final emptyRows = await db.rawQuery(
      '''
      SELECT
        t.id AS type_id,
        t.name AS type_name,
        t.value AS type_value,
        COALESCE(SUM(${emptyStockSignedSql(typeColumn: 'x.movement_type')}), 0) AS empty_qty
      FROM returnable_packaging_types t
      LEFT JOIN returnable_packaging_transactions x ON x.type_id = t.id
      GROUP BY t.id, t.name, t.value
      ''',
    );
    final unsettledRows = await db.rawQuery(
      '''
      SELECT
        type_id,
        COALESCE(SUM(
          CASE movement_type
            WHEN 'ISSUED' THEN quantity
            WHEN 'OPENING_ISSUED' THEN quantity
            WHEN 'RETURNED' THEN -quantity
            WHEN 'BROKEN' THEN -quantity
            WHEN 'LOST' THEN -quantity
            WHEN 'REVERSED' THEN -quantity
            ELSE 0
          END
        ), 0) AS qty
      FROM returnable_packaging_transactions
      GROUP BY type_id
      ''',
    );
    final fullRows = await db.rawQuery(
      '''
      SELECT
        m.type_id,
        COALESCE(SUM(
          (${InventoryStockSql.signedQuantityCase()}) * m.units_per_product_base
        ), 0) AS qty
      FROM returnable_packaging_product_mappings m
      LEFT JOIN inventory_transactions it ON it.product_id = m.product_id
      GROUP BY m.type_id
      ''',
    );
    final unsettledByType = <int, double>{
      for (final row in unsettledRows)
        row['type_id'] as int: (row['qty'] as num).toDouble(),
    };
    final fullByType = <int, double>{
      for (final row in fullRows)
        row['type_id'] as int: (row['qty'] as num).toDouble(),
    };
    final byWarehouse = await getWarehouseStock();
    final warehouseCountByType = <int, int>{};
    for (final row in byWarehouse) {
      warehouseCountByType[row.typeId] =
          (warehouseCountByType[row.typeId] ?? 0) + 1;
    }
    final byType = <PackagingTypeOwnership>[];
    for (final row in emptyRows) {
      final typeId = row['type_id'] as int;
      final empty = (row['empty_qty'] as num?)?.toDouble() ?? 0;
      final full = fullByType[typeId] ?? 0;
      final unsettled = unsettledByType[typeId] ?? 0;
      if (empty.abs() <= epsilon &&
          full.abs() <= epsilon &&
          unsettled.abs() <= epsilon) {
        continue;
      }
      byType.add(
        PackagingTypeOwnership(
          typeId: typeId,
          typeName: row['type_name'] as String,
          typeValue: row['type_value'] as int? ?? 0,
          empty: empty,
          fullInStock: full,
          unsettled: unsettled,
          warehouseCount: warehouseCountByType[typeId] ?? 0,
        ),
      );
    }
    return PackagingOwnershipSummary(
      byType: byType,
      byWarehouse: byWarehouse,
    );
  }

  Future<double> fullInStockForType(int typeId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(
        (${InventoryStockSql.signedQuantityCase()}) * m.units_per_product_base
      ), 0) AS qty
      FROM returnable_packaging_product_mappings m
      LEFT JOIN inventory_transactions it ON it.product_id = m.product_id
      WHERE m.type_id = ?
      ''',
      [typeId],
    );
    return (rows.first['qty'] as num?)?.toDouble() ?? 0;
  }

  // ====================================================================
  // حركات البيع والمرتجع والتسوية
  // ====================================================================

  Future<void> issueForSaleInTransaction(
    DatabaseExecutor txn, {
    required int invoiceId,
    required int partyId,
    int? warehouseId,
    required List<PackagingSaleItem> items,
  }) async {
    for (final item in items) {
      if (item.baseQuantity <= epsilon) continue;
      final mapping = await _mappingForProduct(txn, item.productId);
      if (mapping == null) continue;
      final quantity = UnitConversion.toBaseQuantity(
        item.baseQuantity,
        mapping.unitsPerProductBase,
      );
      if (quantity <= epsilon) continue;
      await txn.insert('returnable_packaging_transactions', {
        'type_id': mapping.typeId,
        'party_id': partyId,
        'warehouse_id': warehouseId,
        'movement_type': PackagingMovementType.issued.dbValue,
        'quantity': quantity,
        'invoice_id': invoiceId,
        'notes': 'تسليم مع فاتورة البيع',
      });
    }
  }

  Future<void> reverseForSaleReturnInTransaction(
    DatabaseExecutor txn, {
    required int returnId,
    required int invoiceId,
    required int partyId,
    required List<PackagingSaleItem> items,
  }) async {
    for (final item in items) {
      if (item.baseQuantity <= epsilon) continue;
      final mapping = await _mappingForProduct(txn, item.productId);
      if (mapping == null) continue;
      final requested = UnitConversion.toBaseQuantity(
        item.baseQuantity,
        mapping.unitsPerProductBase,
      );
      if (requested <= epsilon) continue;
      final remaining = await unsettledInTxn(
        txn,
        partyId: partyId,
        typeId: mapping.typeId,
      );
      final quantity = requested < remaining ? requested : remaining;
      if (quantity <= epsilon) continue;
      await txn.insert('returnable_packaging_transactions', {
        'type_id': mapping.typeId,
        'party_id': partyId,
        'movement_type': PackagingMovementType.reversed.dbValue,
        'quantity': quantity,
        'invoice_id': invoiceId,
        'return_id': returnId,
        'notes': 'عكس عبوات مرتجع بيع',
      });
      await _assertUnsettledNotNegative(
        txn,
        partyId: partyId,
        typeId: mapping.typeId,
      );
    }
  }

  Future<void> assertIssuedCanBeDeletedForInvoice(
    DatabaseExecutor txn, {
    required int invoiceId,
  }) async {
    final issued = await txn.rawQuery(
      '''
      SELECT type_id, party_id, COALESCE(SUM(quantity), 0) AS qty
      FROM returnable_packaging_transactions
      WHERE invoice_id = ? AND movement_type = 'ISSUED'
      GROUP BY type_id, party_id
      ''',
      [invoiceId],
    );
    for (final row in issued) {
      final typeId = row['type_id'] as int;
      final partyId = row['party_id'] as int;
      final qty = (row['qty'] as num).toDouble();
      final remaining = await unsettledInTxn(
        txn,
        partyId: partyId,
        typeId: typeId,
      );
      if (remaining - qty < -epsilon) {
        throw PackagingException(
          'تم تسوية عبوات مرتبطة بهذه الفاتورة ولا يمكن حذفها',
        );
      }
    }
  }

  Future<void> deleteIssuedForInvoiceInTransaction(
    DatabaseExecutor txn, {
    required int invoiceId,
  }) async {
    await txn.delete(
      'returnable_packaging_transactions',
      where: 'invoice_id = ? AND movement_type IN (?, ?, ?, ?)',
      whereArgs: [
        invoiceId,
        PackagingMovementType.issued.dbValue,
        PackagingMovementType.filled.dbValue,
        PackagingMovementType.purchasedEmpty.dbValue,
        PackagingMovementType.unfilled.dbValue,
      ],
    );
  }

  Future<int> recordOpeningEmpty({
    required int typeId,
    required int warehouseId,
    required double quantity,
    String? notes,
  }) async {
    final qty = _normalizeQty(quantity);
    if (qty <= epsilon) {
      throw PackagingException('كمية الرصيد الافتتاحي يجب أن تكون أكبر من صفر');
    }
    final db = await _db;
    return db.insert('returnable_packaging_transactions', {
      'type_id': typeId,
      'warehouse_id': warehouseId,
      'movement_type': PackagingMovementType.openingEmpty.dbValue,
      'quantity': qty,
      'notes': _nullableText(notes) ?? 'رصيد افتتاحي — فوارغ',
    });
  }

  Future<int> recordOpeningIssued({
    required int typeId,
    required int partyId,
    required double quantity,
    String? notes,
  }) async {
    final qty = _normalizeQty(quantity);
    if (qty <= epsilon) {
      throw PackagingException('كمية الرصيد الافتتاحي يجب أن تكون أكبر من صفر');
    }
    final db = await _db;
    return db.insert('returnable_packaging_transactions', {
      'type_id': typeId,
      'party_id': partyId,
      'movement_type': PackagingMovementType.openingIssued.dbValue,
      'quantity': qty,
      'notes': _nullableText(notes) ?? 'رصيد افتتاحي — لدى العميل',
    });
  }

  Future<void> fillForPurchaseInTransaction(
    DatabaseExecutor txn, {
    required int invoiceId,
    int? warehouseId,
    required List<PackagingSaleItem> items,
    Map<int, double> purchasedEmptyByTypeId = const {},
  }) async {
    final neededByType = <int, double>{};
    final nameByType = <int, String>{};
    for (final item in items) {
      if (item.baseQuantity <= epsilon) continue;
      final mapping = await _mappingForProduct(txn, item.productId);
      if (mapping == null) continue;
      final quantity = UnitConversion.toBaseQuantity(
        item.baseQuantity,
        mapping.unitsPerProductBase,
      );
      if (quantity <= epsilon) continue;
      neededByType[mapping.typeId] =
          (neededByType[mapping.typeId] ?? 0) + quantity;
      nameByType[mapping.typeId] = mapping.typeName ?? 'عبوة';
    }
    if (neededByType.isEmpty) return;
    if (warehouseId == null) {
      throw PackagingException('حدد المستودع لتعبئة العبوات الفارغة');
    }

    final shortages = <PackagingFillShortage>[];
    for (final entry in neededByType.entries) {
      final available = await emptyStockInTxn(
        txn,
        warehouseId: warehouseId,
        typeId: entry.key,
      );
      final extra = purchasedEmptyByTypeId[entry.key] ?? 0;
      if (entry.value - available - extra > epsilon) {
        shortages.add(
          PackagingFillShortage(
            typeId: entry.key,
            typeName: nameByType[entry.key] ?? 'عبوة',
            needed: entry.value,
            available: available,
            extraOffered: extra,
          ),
        );
      }
    }
    if (shortages.isNotEmpty) {
      throw PackagingShortageException(shortages);
    }

    for (final entry in purchasedEmptyByTypeId.entries) {
      if (!neededByType.containsKey(entry.key)) continue;
      final extra = _normalizeQty(entry.value);
      if (extra <= epsilon) continue;
      await txn.insert('returnable_packaging_transactions', {
        'type_id': entry.key,
        'warehouse_id': warehouseId,
        'movement_type': PackagingMovementType.purchasedEmpty.dbValue,
        'quantity': extra,
        'invoice_id': invoiceId,
        'notes': 'شراء عبوات فارغة مع فاتورة الشراء',
      });
    }

    for (final entry in neededByType.entries) {
      await txn.insert('returnable_packaging_transactions', {
        'type_id': entry.key,
        'warehouse_id': warehouseId,
        'movement_type': PackagingMovementType.filled.dbValue,
        'quantity': entry.value,
        'invoice_id': invoiceId,
        'notes': 'تعبئة عبوات فارغة من فاتورة الشراء',
      });
    }
  }

  Future<void> unfillForPurchaseReturnInTransaction(
    DatabaseExecutor txn, {
    required int returnId,
    required int invoiceId,
    int? warehouseId,
    required List<PackagingSaleItem> items,
  }) async {
    for (final item in items) {
      if (item.baseQuantity <= epsilon) continue;
      final mapping = await _mappingForProduct(txn, item.productId);
      if (mapping == null) continue;
      final requested = UnitConversion.toBaseQuantity(
        item.baseQuantity,
        mapping.unitsPerProductBase,
      );
      if (requested <= epsilon) continue;

      final filledRows = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(
          CASE movement_type
            WHEN 'FILLED' THEN quantity
            WHEN 'UNFILLED' THEN -quantity
            ELSE 0
          END
        ), 0) AS qty
        FROM returnable_packaging_transactions
        WHERE invoice_id = ? AND type_id = ?
        ''',
        [invoiceId, mapping.typeId],
      );
      final remainingFill =
          (filledRows.first['qty'] as num?)?.toDouble() ?? 0;
      final quantity =
          requested < remainingFill ? requested : remainingFill;
      if (quantity <= epsilon) continue;

      await txn.insert('returnable_packaging_transactions', {
        'type_id': mapping.typeId,
        'warehouse_id': warehouseId,
        'movement_type': PackagingMovementType.unfilled.dbValue,
        'quantity': quantity,
        'invoice_id': invoiceId,
        'return_id': returnId,
        'notes': 'عكس تعبئة عبوات مرتجع شراء',
      });
    }
  }

  Future<int> settle({
    required int partyId,
    required int typeId,
    required int warehouseId,
    required double returnedBase,
    required double brokenBase,
    required double lostBase,
    int compensationPaidNow = 0,
    String? notes,
  }) async {
    final returned = _normalizeQty(returnedBase);
    final broken = _normalizeQty(brokenBase);
    final lost = _normalizeQty(lostBase);
    if (returned < -epsilon || broken < -epsilon || lost < -epsilon) {
      throw PackagingException('كميات التسوية لا يمكن أن تكون سالبة');
    }
    final total = returned + broken + lost;
    if (total <= epsilon) {
      throw PackagingException('يجب إدخال كمية واحدة على الأقل للتسوية');
    }

    final db = await _db;
    return db.transaction<int>((txn) async {
      final remaining = await unsettledInTxn(
        txn,
        partyId: partyId,
        typeId: typeId,
      );
      if (total - remaining > epsilon) {
        throw PackagingException(
          'كمية التسوية تتجاوز الرصيد غير المسوّى لدى العميل',
        );
      }

      final typeRows = await txn.query(
        'returnable_packaging_types',
        where: 'id = ?',
        whereArgs: [typeId],
        limit: 1,
      );
      if (typeRows.isEmpty) {
        throw PackagingException('نوع العبوة غير موجود');
      }
      final typeValue = typeRows.first['value'] as int? ?? 0;
      final settlementNumber = await _nextSettlementNumber(txn);
      final settlementId = await txn.insert('returnable_packaging_settlements', {
        'settlement_number': settlementNumber,
        'party_id': partyId,
        'type_id': typeId,
        'warehouse_id': warehouseId,
        'notes': _nullableText(notes),
      });

      if (returned > epsilon) {
        await txn.insert('returnable_packaging_transactions', {
          'type_id': typeId,
          'party_id': partyId,
          'warehouse_id': warehouseId,
          'movement_type': PackagingMovementType.returned.dbValue,
          'quantity': returned,
          'settlement_id': settlementId,
          'notes': 'استلام عبوات سليمة',
        });
      }

      final lossTxnIds = <int>[];
      if (broken > epsilon) {
        lossTxnIds.add(
          await _insertLossMovement(
            txn,
            partyId: partyId,
            typeId: typeId,
            warehouseId: warehouseId,
            settlementId: settlementId,
            quantity: broken,
            movementType: PackagingMovementType.broken,
          ),
        );
      }

      if (lost > epsilon) {
        lossTxnIds.add(
          await _insertLossMovement(
            txn,
            partyId: partyId,
            typeId: typeId,
            warehouseId: warehouseId,
            settlementId: settlementId,
            quantity: lost,
            movementType: PackagingMovementType.lost,
          ),
        );
      }

      await _recordCompensationCharge(
        txn,
        partyId: partyId,
        typeId: typeId,
        settlementId: settlementId,
        transactionIds: lossTxnIds,
        quantity: broken + lost,
        typeValue: typeValue,
        paidNow: compensationPaidNow,
      );

      await _assertUnsettledNotNegative(
        txn,
        partyId: partyId,
        typeId: typeId,
      );
      return settlementId;
    });
  }

  Future<int> payCharge({
    required int chargeId,
    required int amount,
    String? notes,
  }) async {
    final db = await _db;
    return db.transaction<int>(
      (txn) => payChargeInTxn(
        txn,
        chargeId: chargeId,
        amount: amount,
        notes: notes,
      ),
    );
  }

  Future<int> payChargeInTxn(
    DatabaseExecutor txn, {
    required int chargeId,
    required int amount,
    String? notes,
  }) async {
    if (amount <= 0) {
      throw PackagingException('يجب أن يكون مبلغ الدفع أكبر من صفر');
    }
    final rows = await txn.query(
      'returnable_packaging_charges',
      where: 'id = ?',
      whereArgs: [chargeId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw PackagingException('مطالبة العبوات غير موجودة');
    }
    final charge = PackagingCharge.fromMap(rows.first);
    if (amount > charge.remaining) {
      throw PackagingException(
        'المبلغ يتجاوز المتبقي على مطالبة العبوات (${charge.remaining})',
      );
    }
    final paymentId = await txn.insert('payments', {
      'party_id': charge.partyId,
      'amount': amount,
      'type': 'INBOUND',
      'notes': notes ?? 'دفعة مطالبة عبوات',
      'packaging_charge_id': chargeId,
    });
    await txn.insert('financial_transactions', {
      'payment_id': paymentId,
      'party_id': charge.partyId,
      'type': 'PAYMENT_IN',
      'direction': 'IN',
      'amount': amount,
      'notes': notes ?? 'دفعة مطالبة عبوات',
    });
    await txn.update(
      'returnable_packaging_charges',
      {'paid_amount': charge.paidAmount + amount},
      where: 'id = ?',
      whereArgs: [chargeId],
    );
    return paymentId;
  }

  // ====================================================================
  // داخلي
  // ====================================================================

  Future<int> _insertLossMovement(
    Transaction txn, {
    required int partyId,
    required int typeId,
    required int warehouseId,
    required int settlementId,
    required double quantity,
    required PackagingMovementType movementType,
  }) {
    return txn.insert('returnable_packaging_transactions', {
      'type_id': typeId,
      'party_id': partyId,
      'warehouse_id': warehouseId,
      'movement_type': movementType.dbValue,
      'quantity': quantity,
      'settlement_id': settlementId,
      'notes': movementType == PackagingMovementType.broken
          ? 'عبوات مكسورة'
          : 'عبوات مفقودة',
    });
  }

  Future<void> _recordCompensationCharge(
    Transaction txn, {
    required int partyId,
    required int typeId,
    required int settlementId,
    required List<int> transactionIds,
    required double quantity,
    required int typeValue,
    required int paidNow,
  }) async {
    if (paidNow < 0) {
      throw PackagingException('مبلغ الدفع لا يمكن أن يكون سالباً');
    }
    final amount = typeValue > 0 && quantity > epsilon
        ? (quantity * typeValue).round()
        : 0;
    if (paidNow > 0 && amount <= 0) {
      throw PackagingException('لا يوجد مبلغ تعويض للدفع');
    }
    if (amount <= 0) return;
    if (paidNow > amount) {
      throw PackagingException('المبلغ المدفوع يتجاوز قيمة التعويض');
    }

    const notes = 'تعويض عن العبوات المفقودة';
    final chargeId = await txn.insert('returnable_packaging_charges', {
      'party_id': partyId,
      'type_id': typeId,
      'transaction_id': transactionIds.isEmpty ? null : transactionIds.first,
      'settlement_id': settlementId,
      'amount': amount,
      'paid_amount': 0,
      'notes': notes,
    });
    for (final id in transactionIds) {
      await txn.update(
        'returnable_packaging_transactions',
        {'charge_id': chargeId},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await txn.insert('financial_transactions', {
      'party_id': partyId,
      'type': 'ADJUSTMENT',
      'direction': 'IN',
      'amount': amount,
      'notes': notes,
    });
    if (paidNow > 0) {
      await payChargeInTxn(
        txn,
        chargeId: chargeId,
        amount: paidNow,
        notes: 'دفعة تعويض عبوات عند التسوية',
      );
    }
  }

  Future<void> _assertUnsettledNotNegative(
    DatabaseExecutor txn, {
    required int partyId,
    required int typeId,
  }) async {
    final remaining = await unsettledInTxn(
      txn,
      partyId: partyId,
      typeId: typeId,
    );
    if (remaining < -epsilon) {
      throw PackagingException('لا يمكن أن يصبح الرصيد غير المسوّى سالباً');
    }
  }

  Future<double> emptyStockInTxn(
    DatabaseExecutor txn, {
    required int warehouseId,
    int? typeId,
  }) async {
    final typeFilter = typeId == null ? '' : 'AND type_id = ?';
    final rows = await txn.rawQuery(
      '''
      SELECT COALESCE(SUM(${emptyStockSignedSql()}), 0) AS qty
      FROM returnable_packaging_transactions
      WHERE warehouse_id = ? $typeFilter
      ''',
      typeId == null ? [warehouseId] : [warehouseId, typeId],
    );
    return (rows.first['qty'] as num?)?.toDouble() ?? 0;
  }

  Future<double> _emptyStockInTxn(
    DatabaseExecutor txn, {
    required int warehouseId,
    int? typeId,
  }) =>
      emptyStockInTxn(txn, warehouseId: warehouseId, typeId: typeId);

  Future<PackagingProductMapping?> _mappingForProduct(
    DatabaseExecutor txn,
    int productId,
  ) async {
    final rows = await txn.rawQuery(
      '''
      SELECT m.*, p.name AS product_name, t.name AS type_name
      FROM returnable_packaging_product_mappings m
      INNER JOIN products p ON p.id = m.product_id
      INNER JOIN returnable_packaging_types t ON t.id = m.type_id
      WHERE m.product_id = ?
      LIMIT 1
      ''',
      [productId],
    );
    if (rows.isEmpty) return null;
    return PackagingProductMapping.fromMap(rows.first);
  }

  Future<String> _nextSettlementNumber(DatabaseExecutor txn) async {
    final rows = await txn.rawQuery(
      'SELECT settlement_number FROM returnable_packaging_settlements ORDER BY id DESC LIMIT 1',
    );
    if (rows.isEmpty) return 'PS-0001';
    final last = rows.first['settlement_number'] as String;
    final digits = int.tryParse(last.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return 'PS-${(digits + 1).toString().padLeft(4, '0')}';
  }

  String? _nullableText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  double _normalizeQty(double value) => (value * 10000).round() / 10000;

  String _sqliteDate(DateTime dateTime) {
    final value = dateTime.toUtc().toIso8601String().split('.').first;
    return value.replaceFirst('T', ' ');
  }
}
