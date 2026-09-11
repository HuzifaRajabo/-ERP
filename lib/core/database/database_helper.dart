import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  /// رقم مخطط SQLite. زيادته تشغّل [_onUpgrade] على القواعد القديمة
  /// دون حذف بيانات المستخدم عند تثبيت APK فوق نسخة سابقة.
  static const int databaseVersion = 15;

  static Database? _database;

  /// للاختبارات فقط: يستبدل قاعدة البيانات الحالية بقاعدة بيانات مُجهّزة
  /// (مثل in-memory عبر sqflite_common_ffi) أو يُعيد تعيينها إلى null.
  @visibleForTesting
  static void overrideDatabaseForTesting(Database? db) {
    _database = db;
  }

  /// للاختبارات: تشغيل مسار الترقية كما يحدث على الهاتف.
  @visibleForTesting
  static Future<void> upgradeDatabaseForTesting(
    Database db,
    int oldVersion,
    int newVersion,
  ) {
    return instance._onUpgrade(db, oldVersion, newVersion);
  }

  /// للاختبارات: إصلاح المخطط الناقص دون تغيير رقم الإصدار.
  @visibleForTesting
  static Future<void> ensureCurrentSchemaForTesting(Database db) {
    return instance._ensureCurrentSchema(db);
  }

  @visibleForTesting
  static Future<void> createDatabaseForTesting(Database db, int version) {
    return instance._onCreate(db, version);
  }

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();

    final path = join(dbPath, 'erp_mvp.db');

    final database = await openDatabase(
      path,
      version: databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: (db, oldVersion, newVersion) async {
        // لا نحذف بيانات المستخدم إذا ثُبِّتت نسخة أقدم فوق أحدث.
        debugPrint(
          'Database downgrade ignored: $oldVersion -> $newVersion',
        );
      },
      onOpen: (db) async {
        await _ensureCurrentSchema(db);
        await _fillMissingExpenseCreatedAt(db);
      },
    );

    return database;
  }

  Future<void> _fillMissingExpenseCreatedAt(Database db) async {
    if (!await _tableExists(db, 'expenses')) return;
    final cols = await _columnNames(db, 'expenses');
    if (!cols.contains('created_at')) return;
    await db.rawUpdate(
      "UPDATE expenses SET created_at = datetime('now') WHERE created_at IS NULL",
    );
  }

  Future<bool> _tableExists(DatabaseExecutor db, String table) async {
    final rows = await db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?",
      [table],
    );
    return rows.isNotEmpty;
  }

  Future<Set<String>> _columnNames(DatabaseExecutor db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.map((r) => r['name'] as String).toSet();
  }

  Future<void> _addColumnIfMissing(
    DatabaseExecutor db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    if (!await _tableExists(db, table)) return;
    final cols = await _columnNames(db, table);
    if (cols.contains(column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  /// يكمّل أي جداول/أعمدة ناقصة في قاعدة قديمة حتى تطابق المخطط الحالي،
  /// بدون حذف البيانات. يُستدعى من onUpgrade وonOpen ليغطي التثبيت فوق نسخة سابقة.
  Future<void> _ensureCurrentSchema(Database db) async {
    await _ensureMissingTables(db);
    await _ensureMissingColumns(db);
    await _rebuildProductUnitsIfLegacy(db);
    await _rebuildInventoryTransactionsIfLegacy(db);
    // إعادة البناء قد تعيد إنشاء الجدول بدون أعمدة أحدث؛ نضيفها مجدداً.
    await _ensureMissingColumns(db);
    await _ensurePresetCategories(db);
    await _ensureDefaultWarehouse(db);
    await _ensureProductBaseUnits(db);
    await _ensureIndexes(db);
    await _cleanupExpiredReturnLedgerEntries(db);
    await _ensureBusinessSettingsDefaults(db);
    await _ensureCompanyProfileRow(db);
  }

  /// تعويض المرتجع المنتهي يُسجَّل على المستند نفسه ويؤثر في الربح فقط،
  /// وليس ذمة ولا حركة في دفتر الفواتير/الدفعات.
  Future<void> _cleanupExpiredReturnLedgerEntries(Database db) async {
    if (!await _tableExists(db, 'financial_transactions')) return;
    await db.delete(
      'financial_transactions',
      where: "type = 'ADJUSTMENT' AND notes LIKE ?",
      whereArgs: ['تعويض مرتجع منتهي الصلاحية%'],
    );
  }

  Future<void> _ensureMissingTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        is_preset INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS warehouses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        type TEXT CHECK(type IN ('MAIN','VAN','BRANCH')) NOT NULL DEFAULT 'MAIN',
        address TEXT,
        is_default INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_units (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        unit_name TEXT NOT NULL,
        conversion_factor REAL NOT NULL DEFAULT 1,
        cost_price INTEGER,
        default_sale_price INTEGER NOT NULL DEFAULT 0,
        can_buy INTEGER NOT NULL DEFAULT 1,
        can_sell INTEGER NOT NULL DEFAULT 1,
        is_default_sell_unit INTEGER NOT NULL DEFAULT 0,
        is_base_unit INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        batch_number TEXT,
        production_date TEXT,
        expiry_date TEXT,
        cost_price INTEGER,
        notes TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS returns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_number TEXT UNIQUE NOT NULL,
        original_invoice_id INTEGER NOT NULL,
        type TEXT CHECK(type IN ('SALE_RETURN','PURCHASE_RETURN')) NOT NULL,
        party_id INTEGER NOT NULL,
        party_name_snapshot TEXT NOT NULL,
        party_address_snapshot TEXT NOT NULL,
        total_amount INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (original_invoice_id) REFERENCES invoices(id),
        FOREIGN KEY (party_id) REFERENCES parties(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS return_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        batch_id INTEGER,
        product_name_snapshot TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_id INTEGER,
        unit_name_snapshot TEXT,
        conversion_factor_snapshot REAL NOT NULL DEFAULT 1,
        base_quantity REAL NOT NULL DEFAULT 0,
        unit_price INTEGER NOT NULL,
        line_total INTEGER NOT NULL,
        FOREIGN KEY (return_id) REFERENCES returns(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id),
        FOREIGN KEY (batch_id) REFERENCES batches(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        party_id INTEGER NOT NULL,
        invoice_id INTEGER,
        return_id INTEGER,
        amount INTEGER NOT NULL,
        type TEXT CHECK(type IN ('INBOUND','OUTBOUND')) NOT NULL,
        notes TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (party_id) REFERENCES parties(id),
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE SET NULL,
        FOREIGN KEY (return_id) REFERENCES returns(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL,
        description TEXT NOT NULL,
        category TEXT CHECK(category IN (
          'TRANSPORT','FUEL','SALARIES','RENT',
          'ELECTRICITY','INTERNET','MAINTENANCE','OTHER'
        )) NOT NULL,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS financial_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER,
        payment_id INTEGER,
        return_id INTEGER,
        party_id INTEGER NOT NULL,
        type TEXT CHECK(type IN (
          'SALE','PURCHASE','PAYMENT_IN','PAYMENT_OUT',
          'SALE_RETURN','PURCHASE_RETURN','REFUND','ADJUSTMENT'
        )) NOT NULL,
        direction TEXT CHECK(direction IN ('IN','OUT')) NOT NULL,
        amount INTEGER NOT NULL,
        notes TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
        FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE CASCADE,
        FOREIGN KEY (return_id) REFERENCES returns(id) ON DELETE CASCADE,
        FOREIGN KEY (party_id) REFERENCES parties(id)
      )
    ''');
    await _ensureWasteAndExpiredReturnTables(db);
    await _ensureReturnablePackagingTables(db);
    await _ensureNotificationTables(db);
    await _ensureCompanyProfileTable(db);
  }

  Future<void> _ensureCompanyProfileTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS company_profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL DEFAULT '',
        trade_name TEXT,
        address TEXT,
        service_area TEXT,
        phone TEXT,
        description TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT
      )
    ''');
  }

  /// سجل واحد فقط. إن لم يوجد يُدرج صف فارغ ليكون الحفظ دائماً UPDATE.
  Future<void> _ensureCompanyProfileRow(Database db) async {
    if (!await _tableExists(db, 'company_profile')) {
      await _ensureCompanyProfileTable(db);
    }
    final existing = await db.query('company_profile', limit: 1);
    if (existing.isNotEmpty) return;
    await db.insert('company_profile', {'name': ''});
  }

  Future<void> _ensureNotificationTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY NOT NULL,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        priority TEXT NOT NULL DEFAULT 'MEDIUM'
          CHECK(priority IN ('LOW','MEDIUM','HIGH','CRITICAL')),
        status TEXT NOT NULL DEFAULT 'ACTIVE'
          CHECK(status IN ('ACTIVE','RESOLVED')),
        is_read INTEGER NOT NULL DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now')),
        read_at TEXT,
        resolved_at TEXT,
        entity_type TEXT,
        entity_id INTEGER,
        product_id INTEGER,
        batch_id INTEGER,
        warehouse_id INTEGER,
        metadata TEXT
      )
    ''');
    await db.execute('''
      INSERT OR IGNORE INTO app_settings (key, value)
      VALUES ('expiry_warning_days', '30')
    ''');
    await db.execute('''
      INSERT OR IGNORE INTO app_settings (key, value)
      VALUES ('expiry_alerts_enabled', '1')
    ''');
  }

  Future<void> _ensureBusinessSettingsDefaults(Database db) async {
    if (!await _tableExists(db, 'app_settings')) return;
    const seeds = <(String, String)>[
      ('business_activity', 'food_distributor'),
      ('feature.product_units', '1'),
      ('feature.warehouses', '1'),
      ('feature.multiple_warehouses', '1'),
      ('feature.vehicles', '1'),
      ('feature.batches', '1'),
      ('feature.expiry', '1'),
      ('feature.returnable_packaging', '1'),
      ('feature.wholesale', '1'),
      ('feature.retail', '0'),
      ('feature.debts', '1'),
      ('feature.expenses', '1'),
      ('feature.waste', '1'),
      ('notify.low_stock', '1'),
      ('notify.out_of_stock', '1'),
      ('notify.debt_due', '1'),
      ('notify.debt_overdue', '1'),
      ('notify.debt_due_days', '7'),
      ('notify.debt_overdue_days', '30'),
      ('notify.packaging_unsettled', '1'),
      ('notify.packaging_overdue', '1'),
      ('notify.packaging_overdue_days', '30'),
    ];
    for (final seed in seeds) {
      await db.execute(
        'INSERT OR IGNORE INTO app_settings (key, value) VALUES (?, ?)',
        [seed.$1, seed.$2],
      );
    }
  }

  Future<void> _ensureWasteAndExpiredReturnTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS waste_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        waste_number TEXT UNIQUE NOT NULL,
        warehouse_id INTEGER NOT NULL,
        total_cost INTEGER NOT NULL DEFAULT 0,
        reason TEXT NOT NULL,
        notes TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (warehouse_id) REFERENCES warehouses(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS waste_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        waste_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        batch_id INTEGER NOT NULL,
        unit_id INTEGER,
        product_name_snapshot TEXT NOT NULL,
        unit_name_snapshot TEXT,
        batch_number_snapshot TEXT,
        expiry_date_snapshot TEXT,
        quantity REAL NOT NULL,
        conversion_factor_snapshot REAL NOT NULL DEFAULT 1,
        base_quantity REAL NOT NULL,
        unit_cost INTEGER NOT NULL,
        line_cost INTEGER NOT NULL,
        FOREIGN KEY (waste_id) REFERENCES waste_records(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id),
        FOREIGN KEY (batch_id) REFERENCES batches(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expired_returns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_number TEXT UNIQUE NOT NULL,
        party_id INTEGER NOT NULL,
        party_name_snapshot TEXT NOT NULL,
        warehouse_id INTEGER NOT NULL,
        inventory_cost INTEGER NOT NULL DEFAULT 0,
        compensation_amount INTEGER NOT NULL DEFAULT 0,
        paid_amount INTEGER NOT NULL DEFAULT 0,
        reason TEXT,
        notes TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (party_id) REFERENCES parties(id),
        FOREIGN KEY (warehouse_id) REFERENCES warehouses(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expired_return_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        expired_return_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        batch_id INTEGER NOT NULL,
        unit_id INTEGER,
        product_name_snapshot TEXT NOT NULL,
        unit_name_snapshot TEXT,
        batch_number_snapshot TEXT,
        expiry_date_snapshot TEXT,
        quantity REAL NOT NULL,
        conversion_factor_snapshot REAL NOT NULL DEFAULT 1,
        base_quantity REAL NOT NULL,
        unit_cost INTEGER NOT NULL,
        line_cost INTEGER NOT NULL,
        FOREIGN KEY (expired_return_id) REFERENCES expired_returns(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id),
        FOREIGN KEY (batch_id) REFERENCES batches(id)
      )
    ''');
  }

  Future<void> _ensureReturnablePackagingTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS returnable_packaging_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        value INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS returnable_packaging_units (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type_id INTEGER NOT NULL,
        unit_name TEXT NOT NULL,
        conversion_factor REAL NOT NULL DEFAULT 1,
        is_base_unit INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (type_id) REFERENCES returnable_packaging_types(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS returnable_packaging_product_mappings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL UNIQUE,
        type_id INTEGER NOT NULL,
        units_per_product_base REAL NOT NULL DEFAULT 1,
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
        FOREIGN KEY (type_id) REFERENCES returnable_packaging_types(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS returnable_packaging_settlements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        settlement_number TEXT UNIQUE NOT NULL,
        party_id INTEGER NOT NULL,
        type_id INTEGER NOT NULL,
        warehouse_id INTEGER NOT NULL,
        notes TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (party_id) REFERENCES parties(id),
        FOREIGN KEY (type_id) REFERENCES returnable_packaging_types(id),
        FOREIGN KEY (warehouse_id) REFERENCES warehouses(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS returnable_packaging_charges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        party_id INTEGER NOT NULL,
        type_id INTEGER NOT NULL,
        transaction_id INTEGER,
        settlement_id INTEGER,
        amount INTEGER NOT NULL,
        paid_amount INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (party_id) REFERENCES parties(id),
        FOREIGN KEY (type_id) REFERENCES returnable_packaging_types(id),
        FOREIGN KEY (settlement_id) REFERENCES returnable_packaging_settlements(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS returnable_packaging_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type_id INTEGER NOT NULL,
        party_id INTEGER,
        warehouse_id INTEGER,
        movement_type TEXT NOT NULL,
        quantity REAL NOT NULL,
        invoice_id INTEGER,
        return_id INTEGER,
        settlement_id INTEGER,
        charge_id INTEGER,
        notes TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (type_id) REFERENCES returnable_packaging_types(id),
        FOREIGN KEY (party_id) REFERENCES parties(id),
        FOREIGN KEY (warehouse_id) REFERENCES warehouses(id),
        FOREIGN KEY (invoice_id) REFERENCES invoices(id),
        FOREIGN KEY (return_id) REFERENCES returns(id),
        FOREIGN KEY (settlement_id) REFERENCES returnable_packaging_settlements(id),
        FOREIGN KEY (charge_id) REFERENCES returnable_packaging_charges(id)
      )
    ''');
  }

  Future<void> _ensureMissingColumns(Database db) async {
    var addedOriginalTotal = false;
    if (await _tableExists(db, 'invoices')) {
      final before = await _columnNames(db, 'invoices');
      addedOriginalTotal = !before.contains('original_total_amount');
    }

    for (final col in [
      (
        table: 'products',
        column: 'description',
        definition: 'TEXT',
      ),
      (
        table: 'products',
        column: 'category_id',
        definition: 'INTEGER',
      ),
      (
        table: 'products',
        column: 'is_active',
        definition: 'INTEGER NOT NULL DEFAULT 1',
      ),
      (
        table: 'products',
        column: 'barcode',
        definition: 'TEXT',
      ),
      (
        table: 'products',
        column: 'min_stock',
        definition: 'REAL',
      ),
      (
        table: 'invoices',
        column: 'sales_channel',
        definition: 'TEXT',
      ),
      (
        table: 'invoices',
        column: 'paid_amount',
        definition: 'INTEGER NOT NULL DEFAULT 0',
      ),
      (
        table: 'invoices',
        column: 'payment_status',
        definition: "TEXT NOT NULL DEFAULT 'UNPAID'",
      ),
      (
        table: 'invoices',
        column: 'original_total_amount',
        definition: 'INTEGER NOT NULL DEFAULT 0',
      ),
      (
        table: 'invoices',
        column: 'warehouse_id',
        definition: 'INTEGER',
      ),
      (
        table: 'invoices',
        column: 'notes',
        definition: 'TEXT',
      ),
      (
        table: 'invoice_items',
        column: 'returned_quantity',
        definition: 'REAL NOT NULL DEFAULT 0',
      ),
      (
        table: 'invoice_items',
        column: 'unit_id',
        definition: 'INTEGER',
      ),
      (
        table: 'invoice_items',
        column: 'unit_name_snapshot',
        definition: 'TEXT',
      ),
      (
        table: 'invoice_items',
        column: 'conversion_factor_snapshot',
        definition: 'REAL NOT NULL DEFAULT 1',
      ),
      (
        table: 'inventory_transactions',
        column: 'return_id',
        definition: 'INTEGER',
      ),
      (
        table: 'inventory_transactions',
        column: 'warehouse_id',
        definition: 'INTEGER',
      ),
      (
        table: 'inventory_transactions',
        column: 'batch_id',
        definition: 'INTEGER',
      ),
      (
        table: 'inventory_transactions',
        column: 'unit_id',
        definition: 'INTEGER',
      ),
      (
        table: 'inventory_transactions',
        column: 'transfer_id',
        definition: 'INTEGER',
      ),
      (
        table: 'inventory_transactions',
        column: 'notes',
        definition: 'TEXT',
      ),
      (
        table: 'payments',
        column: 'return_id',
        definition: 'INTEGER',
      ),
      (
        table: 'payments',
        column: 'packaging_charge_id',
        definition: 'INTEGER',
      ),
      (
        table: 'return_items',
        column: 'batch_id',
        definition: 'INTEGER',
      ),
      (
        table: 'return_items',
        column: 'unit_id',
        definition: 'INTEGER',
      ),
      (
        table: 'return_items',
        column: 'unit_name_snapshot',
        definition: 'TEXT',
      ),
      (
        table: 'return_items',
        column: 'conversion_factor_snapshot',
        definition: 'REAL NOT NULL DEFAULT 1',
      ),
      (
        table: 'return_items',
        column: 'base_quantity',
        definition: 'REAL NOT NULL DEFAULT 0',
      ),
      (
        table: 'expenses',
        column: 'created_at',
        definition: 'TEXT',
      ),
      (
        table: 'batches',
        column: 'production_date',
        definition: 'TEXT',
      ),
      (
        table: 'invoices',
        column: 'discount_amount',
        definition: 'INTEGER NOT NULL DEFAULT 0',
      ),
      (
        table: 'inventory_transactions',
        column: 'waste_id',
        definition: 'INTEGER',
      ),
      (
        table: 'inventory_transactions',
        column: 'expired_return_id',
        definition: 'INTEGER',
      ),
    ]) {
      await _addColumnIfMissing(
        db,
        table: col.table,
        column: col.column,
        definition: col.definition,
      );
    }

    if (addedOriginalTotal) {
      await db.rawUpdate(
        'UPDATE invoices SET original_total_amount = total_amount',
      );
    }
  }

  Future<void> _rebuildProductUnitsIfLegacy(Database db) async {
    if (!await _tableExists(db, 'product_units')) return;
    final colNames = await _columnNames(db, 'product_units');
    final isLegacy = colNames.contains('sale_price') &&
        !colNames.contains('default_sale_price');
    if (!isLegacy) return;

    await db.execute(
      'ALTER TABLE product_units RENAME TO product_units_old',
    );
    await db.execute('''
      CREATE TABLE product_units (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        unit_name TEXT NOT NULL,
        conversion_factor REAL NOT NULL DEFAULT 1,
        cost_price INTEGER,
        default_sale_price INTEGER NOT NULL DEFAULT 0,
        can_buy INTEGER NOT NULL DEFAULT 1,
        can_sell INTEGER NOT NULL DEFAULT 1,
        is_default_sell_unit INTEGER NOT NULL DEFAULT 0,
        is_base_unit INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
      )
    ''');

    final defaultSaleExpr = colNames.contains('sale_price')
        ? 'COALESCE(sale_price, 0)'
        : '0';
    final canBuyExpr =
        colNames.contains('can_buy') ? 'COALESCE(can_buy,1)' : '1';
    final canSellExpr =
        colNames.contains('can_sell') ? 'COALESCE(can_sell,1)' : '1';
    final isDefaultExpr = colNames.contains('is_default_sell_unit')
        ? 'COALESCE(is_default_sell_unit,0)'
        : '0';
    final isBaseExpr = colNames.contains('is_base_unit')
        ? 'COALESCE(is_base_unit,0)'
        : '0';
    final isActiveExpr =
        colNames.contains('is_active') ? 'COALESCE(is_active,1)' : '1';
    final createdAtExpr = colNames.contains('created_at')
        ? "COALESCE(created_at, datetime('now'))"
        : "datetime('now')";
    final updatedAtExpr =
        colNames.contains('updated_at') ? 'updated_at' : 'NULL';

    await db.execute('''
      INSERT INTO product_units (
        id, product_id, unit_name, conversion_factor,
        cost_price, default_sale_price, can_buy, can_sell,
        is_default_sell_unit, is_base_unit, is_active, created_at, updated_at
      )
      SELECT
        id, product_id, unit_name, COALESCE(conversion_factor,1),
        cost_price, $defaultSaleExpr, $canBuyExpr, $canSellExpr,
        $isDefaultExpr, $isBaseExpr, $isActiveExpr, $createdAtExpr, $updatedAtExpr
      FROM product_units_old
    ''');
    await db.execute('DROP TABLE product_units_old');
  }

  Future<void> _rebuildInventoryTransactionsIfLegacy(Database db) async {
    if (!await _tableExists(db, 'inventory_transactions')) return;

    final colNames = await _columnNames(db, 'inventory_transactions');
    final tableSqlRows = await db.rawQuery(
      "SELECT sql FROM sqlite_master WHERE type='table' AND name='inventory_transactions'",
    );
    final tableSql = (tableSqlRows.isEmpty
            ? ''
            : (tableSqlRows.first['sql'] as String? ?? ''))
        .toUpperCase();

    final invoiceInfo = await db.rawQuery(
      'PRAGMA table_info(inventory_transactions)',
    );
    final invoiceIdNotNull = invoiceInfo.any(
      (c) => c['name'] == 'invoice_id' && (c['notnull'] as int? ?? 0) == 1,
    );

    final needsRebuild = !colNames.contains('transfer_id') ||
        invoiceIdNotNull ||
        tableSql.contains('CHECK(TYPE IN');
    if (!needsRebuild) return;

    await db.execute(
      'ALTER TABLE inventory_transactions RENAME TO inventory_transactions_old',
    );
    await db.execute('''
      CREATE TABLE inventory_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        invoice_id INTEGER,
        return_id INTEGER,
        warehouse_id INTEGER,
        batch_id INTEGER,
        unit_id INTEGER,
        transfer_id INTEGER,
        waste_id INTEGER,
        expired_return_id INTEGER,
        notes TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (product_id) REFERENCES products(id),
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
        FOREIGN KEY (return_id) REFERENCES returns(id) ON DELETE CASCADE,
        FOREIGN KEY (warehouse_id) REFERENCES warehouses(id),
        FOREIGN KEY (batch_id) REFERENCES batches(id),
        FOREIGN KEY (unit_id) REFERENCES product_units(id)
      )
    ''');

    String colOrNull(String name) => colNames.contains(name) ? name : 'NULL';

    await db.execute('''
      INSERT INTO inventory_transactions (
        id, product_id, type, quantity, invoice_id, return_id,
        warehouse_id, batch_id, unit_id, transfer_id, waste_id,
        expired_return_id, notes, created_at
      )
      SELECT
        id, product_id, type, quantity, invoice_id, ${colOrNull('return_id')},
        ${colOrNull('warehouse_id')}, ${colOrNull('batch_id')},
        ${colOrNull('unit_id')}, ${colOrNull('transfer_id')},
        ${colOrNull('waste_id')}, ${colOrNull('expired_return_id')},
        ${colOrNull('notes')}, created_at
      FROM inventory_transactions_old
    ''');
    await db.execute('DROP TABLE inventory_transactions_old');
  }

  Future<void> _ensurePresetCategories(Database db) async {
    if (!await _tableExists(db, 'product_categories')) return;
    const presetCategories = [
      'شيبس',
      'سناكات',
      'مشروبات غازية',
      'عصائر',
      'مياه',
      'حلويات وشوكولاتة',
      'بسكويت وكيك',
      'مكسرات',
    ];
    for (final name in presetCategories) {
      await db.rawInsert(
        'INSERT OR IGNORE INTO product_categories(name, is_preset, is_active) VALUES(?,1,1)',
        [name],
      );
    }
  }

  Future<void> _ensureDefaultWarehouse(Database db) async {
    if (!await _tableExists(db, 'warehouses')) return;

    final existing = await db.query(
      'warehouses',
      where: 'is_default = 1',
      limit: 1,
    );
    int defaultWarehouseId;
    if (existing.isNotEmpty) {
      defaultWarehouseId = existing.first['id'] as int;
    } else {
      defaultWarehouseId = await db.insert('warehouses', {
        'name': 'المستودع الرئيسي',
        'type': 'MAIN',
        'is_default': 1,
        'is_active': 1,
      });
    }

    if (await _tableExists(db, 'invoices')) {
      final cols = await _columnNames(db, 'invoices');
      if (cols.contains('warehouse_id')) {
        await db.rawUpdate(
          'UPDATE invoices SET warehouse_id = ? WHERE warehouse_id IS NULL',
          [defaultWarehouseId],
        );
      }
    }
    if (await _tableExists(db, 'inventory_transactions')) {
      final cols = await _columnNames(db, 'inventory_transactions');
      if (cols.contains('warehouse_id')) {
        await db.rawUpdate(
          'UPDATE inventory_transactions SET warehouse_id = ? WHERE warehouse_id IS NULL',
          [defaultWarehouseId],
        );
      }
    }
  }

  Future<void> _ensureProductBaseUnits(Database db) async {
    if (!await _tableExists(db, 'product_units')) return;
    if (!await _tableExists(db, 'products')) return;
    final cols = await _columnNames(db, 'product_units');
    if (!cols.contains('default_sale_price')) return;

    await db.rawUpdate(
      'UPDATE product_units SET is_default_sell_unit = 1 WHERE is_base_unit = 1 AND is_default_sell_unit = 0',
    );

    final orphanProducts = await db.rawQuery('''
      SELECT p.id, p.cost_price, p.sale_price
      FROM products p
      WHERE NOT EXISTS (
        SELECT 1 FROM product_units pu WHERE pu.product_id = p.id
      )
    ''');

    for (final row in orphanProducts) {
      await db.insert('product_units', {
        'product_id': row['id'],
        'unit_name': 'قطعة',
        'conversion_factor': 1.0,
        'cost_price': row['cost_price'],
        'default_sale_price': row['sale_price'] ?? 0,
        'can_buy': 1,
        'can_sell': 1,
        'is_default_sell_unit': 1,
        'is_base_unit': 1,
        'is_active': 1,
      });
    }
  }

  Future<void> _ensureIndexes(Database db) async {
    const indexes = [
      'CREATE INDEX IF NOT EXISTS idx_invoice_party ON invoices(party_id)',
      'CREATE INDEX IF NOT EXISTS idx_invoice_date ON invoices(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_invoice_status ON invoices(payment_status)',
      'CREATE INDEX IF NOT EXISTS idx_item_inv ON invoice_items(invoice_id)',
      'CREATE INDEX IF NOT EXISTS idx_item_product ON invoice_items(product_id)',
      'CREATE INDEX IF NOT EXISTS idx_inv_prod ON inventory_transactions(product_id)',
      'CREATE INDEX IF NOT EXISTS idx_inv_type ON inventory_transactions(type)',
      'CREATE INDEX IF NOT EXISTS idx_returns_invoice ON returns(original_invoice_id)',
      'CREATE INDEX IF NOT EXISTS idx_returns_party ON returns(party_id)',
      'CREATE INDEX IF NOT EXISTS idx_payments_party ON payments(party_id)',
      'CREATE INDEX IF NOT EXISTS idx_payments_invoice ON payments(invoice_id)',
      'CREATE INDEX IF NOT EXISTS idx_payments_date ON payments(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category)',
      'CREATE INDEX IF NOT EXISTS idx_financial_transactions_invoice ON financial_transactions(invoice_id)',
      'CREATE INDEX IF NOT EXISTS idx_financial_transactions_payment ON financial_transactions(payment_id)',
      'CREATE INDEX IF NOT EXISTS idx_financial_transactions_return ON financial_transactions(return_id)',
      'CREATE INDEX IF NOT EXISTS idx_financial_transactions_party ON financial_transactions(party_id)',
      'CREATE INDEX IF NOT EXISTS idx_financial_transactions_date ON financial_transactions(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id)',
      'CREATE INDEX IF NOT EXISTS idx_product_units_product ON product_units(product_id)',
      'CREATE INDEX IF NOT EXISTS idx_product_units_default_sell ON product_units(product_id, is_default_sell_unit)',
      'CREATE INDEX IF NOT EXISTS idx_batches_product ON batches(product_id)',
      'CREATE INDEX IF NOT EXISTS idx_batches_expiry ON batches(expiry_date)',
      'CREATE INDEX IF NOT EXISTS idx_inv_warehouse ON inventory_transactions(warehouse_id)',
      'CREATE INDEX IF NOT EXISTS idx_inv_batch ON inventory_transactions(batch_id)',
      'CREATE INDEX IF NOT EXISTS idx_inv_transfer ON inventory_transactions(transfer_id)',
      'CREATE INDEX IF NOT EXISTS idx_invoices_warehouse ON invoices(warehouse_id)',
      'CREATE INDEX IF NOT EXISTS idx_waste_warehouse ON waste_records(warehouse_id)',
      'CREATE INDEX IF NOT EXISTS idx_waste_date ON waste_records(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_waste_items_waste ON waste_items(waste_id)',
      'CREATE INDEX IF NOT EXISTS idx_expired_returns_party ON expired_returns(party_id)',
      'CREATE INDEX IF NOT EXISTS idx_expired_returns_date ON expired_returns(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_expired_return_items ON expired_return_items(expired_return_id)',
      'CREATE INDEX IF NOT EXISTS idx_inv_waste ON inventory_transactions(waste_id)',
      'CREATE INDEX IF NOT EXISTS idx_inv_expired_return ON inventory_transactions(expired_return_id)',
      'CREATE INDEX IF NOT EXISTS idx_pkg_units_type ON returnable_packaging_units(type_id)',
      'CREATE INDEX IF NOT EXISTS idx_pkg_map_product ON returnable_packaging_product_mappings(product_id)',
      'CREATE INDEX IF NOT EXISTS idx_pkg_map_type ON returnable_packaging_product_mappings(type_id)',
      'CREATE INDEX IF NOT EXISTS idx_pkg_txn_type ON returnable_packaging_transactions(type_id)',
      'CREATE INDEX IF NOT EXISTS idx_pkg_txn_party ON returnable_packaging_transactions(party_id)',
      'CREATE INDEX IF NOT EXISTS idx_pkg_txn_wh ON returnable_packaging_transactions(warehouse_id)',
      'CREATE INDEX IF NOT EXISTS idx_pkg_txn_move ON returnable_packaging_transactions(movement_type)',
      'CREATE INDEX IF NOT EXISTS idx_pkg_txn_invoice ON returnable_packaging_transactions(invoice_id)',
      'CREATE INDEX IF NOT EXISTS idx_pkg_txn_date ON returnable_packaging_transactions(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_pkg_settle_party ON returnable_packaging_settlements(party_id)',
      'CREATE INDEX IF NOT EXISTS idx_pkg_charges_party ON returnable_packaging_charges(party_id)',
      'CREATE INDEX IF NOT EXISTS idx_inv_batch_warehouse ON inventory_transactions(batch_id, warehouse_id)',
      'CREATE INDEX IF NOT EXISTS idx_notifications_status ON notifications(status)',
      'CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(is_read)',
      'CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_notifications_batch ON notifications(batch_id)',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_active_key ON notifications(type, batch_id, warehouse_id) WHERE status = \'ACTIVE\' AND batch_id IS NOT NULL AND warehouse_id IS NOT NULL',
    ];
    for (final sql in indexes) {
      try {
        await db.execute(sql);
      } catch (_) {
        // الجدول أو العمود قد لا يكون موجوداً في مسار ترقية جزئي
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // ==============================
    // أصناف المنتجات — يجب أن تُنشأ قبل products لأنها مرجع FK
    // ==============================
    await db.execute('''
    CREATE TABLE product_categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT UNIQUE NOT NULL,
      is_preset INTEGER NOT NULL DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

    // إدراج الأصناف الجاهزة
    const presetCategories = [
      'شيبس', 'سناكات', 'مشروبات غازية', 'عصائر', 'مياه',
      'حلويات وشوكولاتة', 'بسكويت وكيك', 'مكسرات',
    ];
    for (final name in presetCategories) {
      await db.insert('product_categories', {
        'name': name,
        'is_preset': 1,
        'is_active': 1,
      });
    }

    await db.execute('''
    CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT,
      cost_price INTEGER NOT NULL,
      sale_price INTEGER NOT NULL,
      category_id INTEGER,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (category_id) REFERENCES product_categories(id) ON DELETE SET NULL
    )
  ''');

    // ==============================
    // المستودعات (مستودع رئيسي / سيارة توزيع / فرع)
    // ==============================
    await db.execute('''
    CREATE TABLE warehouses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT UNIQUE NOT NULL,
      type TEXT CHECK(type IN ('MAIN','VAN','BRANCH')) NOT NULL DEFAULT 'MAIN',
      address TEXT,
      is_default INTEGER NOT NULL DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

    // ==============================
    // وحدات المنتج (قطعة / باكيت / كرتون...)
    // الوحدة الأساسية دائماً conversion_factor = 1
    // ==============================
    await db.execute('''
    CREATE TABLE product_units (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL,
      unit_name TEXT NOT NULL,
      conversion_factor REAL NOT NULL DEFAULT 1,
      cost_price INTEGER,
      default_sale_price INTEGER NOT NULL DEFAULT 0,
      can_buy INTEGER NOT NULL DEFAULT 1,
      can_sell INTEGER NOT NULL DEFAULT 1,
      is_default_sell_unit INTEGER NOT NULL DEFAULT 0,
      is_base_unit INTEGER NOT NULL DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT,
      FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
    )
  ''');

    // ==============================
    // دفعات المنتج (لتتبع تاريخ الصلاحية وتكلفة كل دفعة شراء)
    // الكمية المتاحة لكل دفعة تُحسب من inventory_transactions
    // (نفس نمط حساب المخزون الحالي)، وليست عمود مخزّن، لتفادي
    // تعارض التحديثات المتزامنة.
    // ==============================
    await db.execute('''
    CREATE TABLE batches (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL,
      batch_number TEXT,
      production_date TEXT,
      expiry_date TEXT,
      cost_price INTEGER,
      notes TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
    )
  ''' );

    await db.execute('''
    CREATE TABLE parties (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT CHECK(type IN ('CUSTOMER','SUPPLIER','BOTH')) NOT NULL,
      name TEXT NOT NULL,
      phone TEXT,
      address TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

    await db.execute('''
    CREATE TABLE invoices (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_number TEXT UNIQUE NOT NULL,
    type TEXT CHECK(type IN ('SALE','PURCHASE')) NOT NULL,
    party_id INTEGER NOT NULL,
    party_name_snapshot TEXT NOT NULL,
    party_address_snapshot TEXT NOT NULL,
    total_amount INTEGER NOT NULL DEFAULT 0,
    original_total_amount INTEGER NOT NULL DEFAULT 0, -- إجمالي البنود قبل الحسم
    discount_amount INTEGER NOT NULL DEFAULT 0,
    paid_amount INTEGER NOT NULL DEFAULT 0,
    payment_status TEXT CHECK(payment_status IN ('UNPAID','PARTIAL','PAID'))
      NOT NULL DEFAULT 'UNPAID',
    warehouse_id INTEGER,
    notes TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (party_id) REFERENCES parties(id),
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(id)
    )
  ''');

    await db.execute('''
    CREATE TABLE invoice_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      product_name_snapshot TEXT NOT NULL,
      quantity REAL NOT NULL,
      returned_quantity REAL NOT NULL DEFAULT 0,
      unit_price INTEGER NOT NULL,
      line_total INTEGER NOT NULL,
      unit_id INTEGER,
      unit_name_snapshot TEXT,
      conversion_factor_snapshot REAL NOT NULL DEFAULT 1,
      FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES products(id),
      FOREIGN KEY (unit_id) REFERENCES product_units(id)
    )
  ''');

    // ← CHECK محذوف لأن SQLite لا يدعم تعديله لاحقاً
    // القيم المقبولة: SALE, PURCHASE, SALE_RETURN, PURCHASE_RETURN,
    //                 TRANSFER_OUT, TRANSFER_IN, WASTE, EXPIRED_RETURN
    // يتم التحكم فيها من الكود
    await db.execute('''
    CREATE TABLE inventory_transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL,
      type TEXT NOT NULL,
      quantity REAL NOT NULL, -- ← دائماً بالوحدة الأساسية (القطعة)
      invoice_id INTEGER,
      return_id INTEGER,
      warehouse_id INTEGER,
      batch_id INTEGER,
      unit_id INTEGER,
      transfer_id INTEGER,
      waste_id INTEGER,
      expired_return_id INTEGER,
      notes TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (product_id) REFERENCES products(id),
      FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
      FOREIGN KEY (return_id) REFERENCES returns(id) ON DELETE CASCADE,
      FOREIGN KEY (warehouse_id) REFERENCES warehouses(id),
      FOREIGN KEY (batch_id) REFERENCES batches(id),
      FOREIGN KEY (unit_id) REFERENCES product_units(id)
    )
  ''');

    await db.execute('''
    CREATE TABLE returns (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      return_number TEXT UNIQUE NOT NULL,
      original_invoice_id INTEGER NOT NULL,
      type TEXT CHECK(type IN ('SALE_RETURN','PURCHASE_RETURN')) NOT NULL,
      party_id INTEGER NOT NULL,
      party_name_snapshot TEXT NOT NULL,
      party_address_snapshot TEXT NOT NULL,
      total_amount INTEGER NOT NULL DEFAULT 0,
      notes TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (original_invoice_id) REFERENCES invoices(id),
      FOREIGN KEY (party_id) REFERENCES parties(id)
    )
  ''');

    await db.execute('''
    CREATE TABLE return_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      return_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      batch_id INTEGER,
      product_name_snapshot TEXT NOT NULL,
      quantity REAL NOT NULL,
      unit_id INTEGER,
      unit_name_snapshot TEXT,
      conversion_factor_snapshot REAL NOT NULL DEFAULT 1,
      base_quantity REAL NOT NULL DEFAULT 0,
      unit_price INTEGER NOT NULL,
      line_total INTEGER NOT NULL,
      FOREIGN KEY (return_id) REFERENCES returns(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES products(id),
      FOREIGN KEY (batch_id) REFERENCES batches(id)
    )
  ''' );

    await db.execute('''
    CREATE TABLE payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      party_id INTEGER NOT NULL,
      invoice_id INTEGER,
      return_id INTEGER,
      amount INTEGER NOT NULL,
      type TEXT CHECK(type IN ('INBOUND','OUTBOUND')) NOT NULL,
      notes TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (party_id) REFERENCES parties(id),
      FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE SET NULL,
      FOREIGN KEY (return_id) REFERENCES returns(id) ON DELETE SET NULL
    )
  ''');

    await db.execute('''
    CREATE TABLE expenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      amount INTEGER NOT NULL,
      description TEXT NOT NULL,
      category TEXT CHECK(category IN (
        'TRANSPORT','FUEL','SALARIES','RENT',
        'ELECTRICITY','INTERNET','MAINTENANCE','OTHER'
      )) NOT NULL,
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

    await db.execute('''
    CREATE TABLE waste_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      waste_number TEXT UNIQUE NOT NULL,
      warehouse_id INTEGER NOT NULL,
      total_cost INTEGER NOT NULL DEFAULT 0,
      reason TEXT NOT NULL,
      notes TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (warehouse_id) REFERENCES warehouses(id)
    )
  ''');

    await db.execute('''
    CREATE TABLE waste_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      waste_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      batch_id INTEGER NOT NULL,
      unit_id INTEGER,
      product_name_snapshot TEXT NOT NULL,
      unit_name_snapshot TEXT,
      batch_number_snapshot TEXT,
      expiry_date_snapshot TEXT,
      quantity REAL NOT NULL,
      conversion_factor_snapshot REAL NOT NULL DEFAULT 1,
      base_quantity REAL NOT NULL,
      unit_cost INTEGER NOT NULL,
      line_cost INTEGER NOT NULL,
      FOREIGN KEY (waste_id) REFERENCES waste_records(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES products(id),
      FOREIGN KEY (batch_id) REFERENCES batches(id)
    )
  ''');

    await db.execute('''
    CREATE TABLE expired_returns (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      return_number TEXT UNIQUE NOT NULL,
      party_id INTEGER NOT NULL,
      party_name_snapshot TEXT NOT NULL,
      warehouse_id INTEGER NOT NULL,
      inventory_cost INTEGER NOT NULL DEFAULT 0,
      compensation_amount INTEGER NOT NULL DEFAULT 0,
      paid_amount INTEGER NOT NULL DEFAULT 0,
      reason TEXT,
      notes TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (party_id) REFERENCES parties(id),
      FOREIGN KEY (warehouse_id) REFERENCES warehouses(id)
    )
  ''');

    await db.execute('''
    CREATE TABLE expired_return_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      expired_return_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      batch_id INTEGER NOT NULL,
      unit_id INTEGER,
      product_name_snapshot TEXT NOT NULL,
      unit_name_snapshot TEXT,
      batch_number_snapshot TEXT,
      expiry_date_snapshot TEXT,
      quantity REAL NOT NULL,
      conversion_factor_snapshot REAL NOT NULL DEFAULT 1,
      base_quantity REAL NOT NULL,
      unit_cost INTEGER NOT NULL,
      line_cost INTEGER NOT NULL,
      FOREIGN KEY (expired_return_id) REFERENCES expired_returns(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES products(id),
      FOREIGN KEY (batch_id) REFERENCES batches(id)
    )
  ''');

    await db.execute('''
    CREATE TABLE financial_transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_id INTEGER,
      payment_id INTEGER,
      return_id INTEGER,
      party_id INTEGER NOT NULL,
      type TEXT CHECK(type IN (
        'SALE','PURCHASE','PAYMENT_IN','PAYMENT_OUT',
        'SALE_RETURN','PURCHASE_RETURN','REFUND','ADJUSTMENT'
      )) NOT NULL,
      direction TEXT CHECK(direction IN ('IN','OUT')) NOT NULL,
      amount INTEGER NOT NULL,
      notes TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
      FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE CASCADE,
      FOREIGN KEY (return_id) REFERENCES returns(id) ON DELETE CASCADE,
      FOREIGN KEY (party_id) REFERENCES parties(id)
    )
  ''');

    // ==============================
    // Indexes
    // ==============================

    await db.execute('CREATE INDEX idx_invoice_party ON invoices(party_id)');
    await db.execute('CREATE INDEX idx_invoice_date ON invoices(created_at)');
    await db.execute(
      'CREATE INDEX idx_invoice_status ON invoices(payment_status)',
    );
    await db.execute('CREATE INDEX idx_item_inv ON invoice_items(invoice_id)');
    await db.execute(
      'CREATE INDEX idx_item_product ON invoice_items(product_id)',
    );
    await db.execute(
      'CREATE INDEX idx_inv_prod ON inventory_transactions(product_id)',
    );
    await db.execute(
      'CREATE INDEX idx_inv_type ON inventory_transactions(type)',
    );
    await db.execute(
      'CREATE INDEX idx_returns_invoice ON returns(original_invoice_id)',
    );
    await db.execute('CREATE INDEX idx_returns_party ON returns(party_id)');
    await db.execute('CREATE INDEX idx_payments_party ON payments(party_id)');
    await db.execute(
      'CREATE INDEX idx_payments_invoice ON payments(invoice_id)',
    );
    await db.execute('CREATE INDEX idx_payments_date ON payments(created_at)');
    await db.execute('CREATE INDEX idx_expenses_date ON expenses(created_at)');
    await db.execute(
      'CREATE INDEX idx_expenses_category ON expenses(category)',
    );
    await db.execute(
      'CREATE INDEX idx_financial_transactions_invoice ON financial_transactions(invoice_id)',
    );
    await db.execute(
      'CREATE INDEX idx_financial_transactions_payment ON financial_transactions(payment_id)',
    );
    await db.execute(
      'CREATE INDEX idx_financial_transactions_return ON financial_transactions(return_id)',
    );
    await db.execute(
      'CREATE INDEX idx_financial_transactions_party ON financial_transactions(party_id)',
    );
    await db.execute(
      'CREATE INDEX idx_financial_transactions_date ON financial_transactions(created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_products_category ON products(category_id)',
    );
    await db.execute(
      'CREATE INDEX idx_product_units_product ON product_units(product_id)',
    );
    await db.execute(
      'CREATE INDEX idx_batches_product ON batches(product_id)',
    );
    await db.execute(
      'CREATE INDEX idx_batches_expiry ON batches(expiry_date)',
    );
    await db.execute(
      'CREATE INDEX idx_inv_warehouse ON inventory_transactions(warehouse_id)',
    );
    await db.execute(
      'CREATE INDEX idx_inv_batch ON inventory_transactions(batch_id)',
    );
    await db.execute(
      'CREATE INDEX idx_inv_transfer ON inventory_transactions(transfer_id)',
    );
    await db.execute(
      'CREATE INDEX idx_invoices_warehouse ON invoices(warehouse_id)',
    );

    // مستودع افتراضي عند أول تثبيت
    await db.insert('warehouses', {
      'name': 'المستودع الرئيسي',
      'type': 'MAIN',
      'is_default': 1,
      'is_active': 1,
    });

    await _ensureCompanyProfileTable(db);
    await _ensureCompanyProfileRow(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('Upgrading database from $oldVersion to $newVersion');

    // الإصلاح الهيكلي (جداول/أعمدة/قيود) يجب أن يتم بدون db.transaction():
    // onUpgrade يعمل أصلاً داخل معاملة sqflite، والمعاملة المتداخلة كانت
    // تُسقط فتح القاعدة عند تثبيت APK فوق نسخة أقدم.
    await _ensureCurrentSchema(db);

    if (oldVersion < 2) {
      await db.execute('''
      CREATE TABLE IF NOT EXISTS financial_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER,
        payment_id INTEGER,
        return_id INTEGER,
        party_id INTEGER NOT NULL,
        type TEXT CHECK(type IN (
          'SALE','PURCHASE','PAYMENT_IN','PAYMENT_OUT',
          'SALE_RETURN','PURCHASE_RETURN','REFUND','ADJUSTMENT'
        )) NOT NULL,
        direction TEXT CHECK(direction IN ('IN','OUT')) NOT NULL,
        amount INTEGER NOT NULL,
        notes TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
        FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE CASCADE,
        FOREIGN KEY (return_id) REFERENCES returns(id) ON DELETE CASCADE,
        FOREIGN KEY (party_id) REFERENCES parties(id)
      )
    ''');

      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_financial_transactions_invoice ON financial_transactions(invoice_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_financial_transactions_payment ON financial_transactions(payment_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_financial_transactions_return ON financial_transactions(return_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_financial_transactions_party ON financial_transactions(party_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_financial_transactions_date ON financial_transactions(created_at)',
      );
    }

    if (oldVersion < 3) {
      for (final stmt in [
        'ALTER TABLE invoice_items ADD COLUMN returned_quantity REAL NOT NULL DEFAULT 0',
        'ALTER TABLE inventory_transactions ADD COLUMN return_id INTEGER',
      ]) {
        try {
          await db.execute(stmt);
        } catch (_) {}
      }
    }

    if (oldVersion < 4) {
      // ملاحظة: كانت هذه الكتلة معطّلة سابقاً لأن رقم الإصدار كان متوقفاً
      // عند 3. تم إبقاؤها بأمان (try/catch) تحسباً لأي قاعدة بيانات
      // وصلت فعلياً للإصدار 3 دون هذا العمود.
      try {
        await db.execute('ALTER TABLE payments ADD COLUMN return_id INTEGER');
      } catch (_) {
        // العمود موجود مسبقاً، لا شيء يُفعل
      }
    }

    if (oldVersion < 5) {
      // ==============================
      // دعم: وحدات متعددة + تواريخ صلاحية + تعدد مستودعات
      // ==============================

      await db.execute('''
        CREATE TABLE IF NOT EXISTS warehouses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE NOT NULL,
          type TEXT CHECK(type IN ('MAIN','VAN','BRANCH')) NOT NULL DEFAULT 'MAIN',
          address TEXT,
          is_default INTEGER NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT DEFAULT (datetime('now'))
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS product_categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE NOT NULL,
          is_preset INTEGER NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT DEFAULT (datetime('now'))
        )
      ''');

      // إدراج الأصناف الجاهزة (INSERT OR IGNORE تتجاهل المكررات بأمان)
      const presetCategories = [
        'شيبس', 'سناكات', 'مشروبات غازية', 'عصائر', 'مياه',
        'حلويات وشوكولاتة', 'بسكويت وكيك', 'مكسرات',
        'مربيات وزيوت', 'منتجات ألبان', 'أخرى',
      ];
      for (final name in presetCategories) {
        await db.rawInsert(
          'INSERT OR IGNORE INTO product_categories(name, is_preset, is_active) VALUES(?,1,1)',
          [name],
        );
      }

      await db.execute('''
        CREATE TABLE IF NOT EXISTS product_units (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          unit_name TEXT NOT NULL,
          conversion_factor REAL NOT NULL DEFAULT 1,
          sale_price INTEGER NOT NULL,
          cost_price INTEGER,
          is_base_unit INTEGER NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT DEFAULT (datetime('now')),
          FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS batches (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          batch_number TEXT,
          production_date TEXT,
          expiry_date TEXT,
          cost_price INTEGER,
          notes TEXT,
          created_at TEXT DEFAULT (datetime('now')),
          FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
        )
      ''' );

      // إضافة الأعمدة الجديدة (كل واحد بمحاولة منفصلة لتفادي فشل الكل
      // إذا كان أحدها مضافاً مسبقاً من تشغيل جزئي سابق)
      for (final stmt in [
        'ALTER TABLE products ADD COLUMN category_id INTEGER',
        'ALTER TABLE invoices ADD COLUMN warehouse_id INTEGER',
        'ALTER TABLE inventory_transactions ADD COLUMN warehouse_id INTEGER',
        'ALTER TABLE inventory_transactions ADD COLUMN batch_id INTEGER',
        'ALTER TABLE inventory_transactions ADD COLUMN unit_id INTEGER',
        'ALTER TABLE invoice_items ADD COLUMN unit_id INTEGER',
        'ALTER TABLE invoice_items ADD COLUMN unit_name_snapshot TEXT',
        'ALTER TABLE invoice_items ADD COLUMN conversion_factor_snapshot REAL NOT NULL DEFAULT 1',
        'ALTER TABLE batches ADD COLUMN production_date TEXT',
        'ALTER TABLE return_items ADD COLUMN batch_id INTEGER',
      ]) {
        try {
          await db.execute(stmt);
        } catch (_) {
          // العمود موجود مسبقاً
        }
      }

      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_product_units_product ON product_units(product_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_batches_product ON batches(product_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_batches_expiry ON batches(expiry_date)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_inv_warehouse ON inventory_transactions(warehouse_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_inv_batch ON inventory_transactions(batch_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_invoices_warehouse ON invoices(warehouse_id)',
      );

      // إنشاء مستودع افتراضي وربط كل البيانات القديمة به،
      // حتى لا تُفقد بيانات المخزون والفواتير السابقة من الحسابات
      int defaultWarehouseId;
      final existing = await db.query(
        'warehouses',
        where: 'is_default = 1',
        limit: 1,
      );
      if (existing.isNotEmpty) {
        defaultWarehouseId = existing.first['id'] as int;
      } else {
        defaultWarehouseId = await db.insert('warehouses', {
          'name': 'المستودع الرئيسي',
          'type': 'MAIN',
          'is_default': 1,
          'is_active': 1,
        });
      }

      await db.rawUpdate(
        'UPDATE invoices SET warehouse_id = ? WHERE warehouse_id IS NULL',
        [defaultWarehouseId],
      );
      await db.rawUpdate(
        'UPDATE inventory_transactions SET warehouse_id = ? WHERE warehouse_id IS NULL',
        [defaultWarehouseId],
      );
    }

    if (oldVersion < 6) {
      // إعادة بناء product_units تتم في _rebuildProductUnitsIfLegacy
    }

    if (oldVersion < 7) {
      // إعادة بناء inventory_transactions تتم في _rebuildInventoryTransactionsIfLegacy
    }

    if (oldVersion < 8) {
      // ==============================
      // v8: إصلاح منطق المرتجعات مع تعدد الوحدات
      //   - إضافة أعمدة معلومات الوحدة لجدول return_items
      //     (unit_id, unit_name_snapshot, conversion_factor_snapshot, base_quantity)
      //   - تحويل returned_quantity في invoice_items (التي كانت تُخزَّن
      //     بوحدة العرض) إلى الوحدة الأساسية:
      //       returned_quantity = returned_quantity × conversion_factor_snapshot
      //     حتى تصبح المقارنة والكمية المتبقية دائماً بالوحدة الأساسية.
      // ==============================
      for (final stmt in [
        'ALTER TABLE return_items ADD COLUMN unit_id INTEGER',
        'ALTER TABLE return_items ADD COLUMN unit_name_snapshot TEXT',
        'ALTER TABLE return_items ADD COLUMN conversion_factor_snapshot REAL NOT NULL DEFAULT 1',
        'ALTER TABLE return_items ADD COLUMN base_quantity REAL NOT NULL DEFAULT 0',
      ]) {
        try {
          await db.execute(stmt);
        } catch (_) {
          // العمود موجود مسبقاً
        }
      }

      // backfill: تحويل القيم القديمة المخزنة بوحدة العرض إلى الوحدة الأساسية
      await db.rawUpdate(
        '''
        UPDATE invoice_items
        SET returned_quantity = returned_quantity * conversion_factor_snapshot
        WHERE conversion_factor_snapshot <> 1
          AND returned_quantity > 0
        ''',
      );
    }

    if (oldVersion < 9) {
      // ==============================
      // v9: الحذف اللين للمنتجات (soft delete)
      //   - إضافة عمود is_active لجدول products للتحكم بظهور المنتج
      //     في المستودع وقوائم اختيار الفواتير دون فقدان أي سجل تاريخي.
      //   - المسار آمن: ALTER في try/catch بحيث لا ينكسر إذا كان العمود
      //     موجوداً مسبقاً (قواعد بيانات مطورة بشكل غير قياسي).
      // ==============================
      try {
        await db.execute(
          'ALTER TABLE products ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
        );
      } catch (_) {
        // العمود موجود مسبقاً — لا شيء يُفعل
      }
    }

    if (oldVersion < 11) {
      // v11: حسم الفاتورة + إتلاف المخزون + مرتجع منتهي الصلاحية
      // الجداول والأعمدة تُضاف عبر _ensureCurrentSchema في بداية onUpgrade.
    }

    if (oldVersion < 13) {
      // v13: إشعارات محلية + إعدادات بسيطة (صلاحية الدفعات)
      // الجداول والفهارس تُضاف عبر _ensureCurrentSchema.
    }

    if (oldVersion < 14) {
      // v14: نشاط المنشأة + إعداد الميزات + أعمدة اختيارية
      // المفاتيح والأعمدة تُضاف عبر _ensureCurrentSchema.
    }

    if (oldVersion < 15) {
      // v15: معلومات المنشأة (سجل واحد في company_profile)
      // الجدول والصف الافتراضي يُضافان عبر _ensureCurrentSchema.
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
