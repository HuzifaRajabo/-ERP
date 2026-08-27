import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;

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
      version: 8,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    await _fillMissingExpenseCreatedAt(database);

    return database;
  }

  Future<void> _fillMissingExpenseCreatedAt(Database db) async {
    await db.rawUpdate(
      "UPDATE expenses SET created_at = datetime('now') WHERE created_at IS NULL",
    );
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
    original_total_amount INTEGER NOT NULL DEFAULT 0, -- ← لا يتغير أبداً
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
    //                 TRANSFER_OUT, TRANSFER_IN
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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
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
    }

    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE invoice_items ADD COLUMN returned_quantity REAL NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE inventory_transactions ADD COLUMN return_id INTEGER',
      );
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
      // ==============================
      // v6: وحدات توزيع كاملة
      //   - إعادة بناء product_units بطريقة آمنة لحذف العمود القديم sale_price
      //   - نقل sale_price -> default_sale_price
      //   - الحفاظ على جميع البيانات (id, product_id, ...)
      //   - إنشاء وحدة أساسية افتراضية للمنتجات التي لا تملك وحدات
      //   - كل شيء داخل transaction لضمان الاتمامية
      // ==============================

      await db.transaction((txn) async {
        // تحقق مما إذا كان جدول product_units موجوداً
        final tables = await txn.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='product_units'");
        if (tables.isEmpty) {
          // لم يجد الجدول، أنشئ الجدول الجديد مباشرة
          await txn.execute('''
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
        } else {
          // جدول قديم موجود - إعادة بنائه لتحويل وحذف sale_price بأمان
          final cols = await txn.rawQuery("PRAGMA table_info(product_units)");
          final colNames = cols.map((c) => c['name'] as String).toSet();

          // أعد تسمية الجدول القديم
          await txn.execute('ALTER TABLE product_units RENAME TO product_units_old');

          // أنشئ الجدول الجديد بالشكل النهائي
          await txn.execute('''
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

          // جهز التعبيرات لاختيار الحقول من الجدول القديم، مع التعامل مع وجود/عدم وجود الأعمدة
          final defaultSaleExpr = colNames.contains('sale_price')
              ? "COALESCE(default_sale_price, sale_price, 0)"
              : "COALESCE(default_sale_price, 0)";
          final canBuyExpr = colNames.contains('can_buy') ? 'COALESCE(can_buy,1)' : '1';
          final canSellExpr = colNames.contains('can_sell') ? 'COALESCE(can_sell,1)' : '1';
          final isDefaultExpr = colNames.contains('is_default_sell_unit') ? 'COALESCE(is_default_sell_unit,0)' : '0';
          final isBaseExpr = colNames.contains('is_base_unit') ? 'COALESCE(is_base_unit,0)' : '0';
          final isActiveExpr = colNames.contains('is_active') ? 'COALESCE(is_active,1)' : '1';
          final createdAtExpr = colNames.contains('created_at') ? 'COALESCE(created_at, datetime(\'now\'))' : "datetime('now')";
          final updatedAtExpr = colNames.contains('updated_at') ? 'updated_at' : 'NULL';

          // أنسخ كل السجلات من الجدول القديم مع تحويل sale_price -> default_sale_price
          final insertSql = '''
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
          ''';

          await txn.execute(insertSql);

          // احذف الجدول القديم بعد النقل
          await txn.execute('DROP TABLE product_units_old');
        }

        // تأكد من أن الوحدة الأساسية مُعلّمة كوحدة بيع افتراضية
        await txn.rawUpdate('UPDATE product_units SET is_default_sell_unit = 1 WHERE is_base_unit = 1 AND is_default_sell_unit = 0');

        // إنشاء وحدة أساسية لكل منتج لا يملك أي وحدات بعد
        final orphanProducts = await txn.rawQuery('''
          SELECT p.id, p.cost_price, p.sale_price
          FROM products p
          WHERE NOT EXISTS (
            SELECT 1 FROM product_units pu WHERE pu.product_id = p.id
          )
        ''');

        for (final row in orphanProducts) {
          await txn.insert('product_units', {
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
            'created_at': DateTime.now().toIso8601String(),
          });
        }

        // Index جديد لتسريع الاستعلامات عن وحدة البيع الافتراضية
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_product_units_default_sell '
          'ON product_units(product_id, is_default_sell_unit)'
        );
      });
    }

    if (oldVersion < 7) {
      // ==============================
      // v7: نقل المخزون بين المستودعات
      //   - إعادة بناء inventory_transactions لجعل invoice_id اختياري
      //     (تحويلات المخزون لا تملك فاتورة)
      //   - إضافة عمود transfer_id لربط حركتي التحويل معاً
      //   - إضافة عمود notes
      //   - كل شيء داخل transaction لضمان الاتمامية
      // ==============================
      await db.transaction((txn) async {
        final cols = await txn.rawQuery('PRAGMA table_info(inventory_transactions)');
        final colNames = cols.map((c) => c['name'] as String).toSet();

        final hasTransferId = colNames.contains('transfer_id');

        // أعد تسمية الجدول القديم
        await txn.execute('ALTER TABLE inventory_transactions RENAME TO inventory_transactions_old');

        // أنشئ الجدول الجديد بالشكل النهائي
        await txn.execute('''
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

        // انسخ البيانات من الجدول القديم
        final transferCol = hasTransferId ? 'transfer_id' : 'NULL';
        await txn.execute('''
          INSERT INTO inventory_transactions (
            id, product_id, type, quantity, invoice_id, return_id,
            warehouse_id, batch_id, unit_id, transfer_id, notes, created_at
          )
          SELECT
            id, product_id, type, quantity, invoice_id, return_id,
            warehouse_id, batch_id, unit_id, $transferCol, NULL, created_at
          FROM inventory_transactions_old
        ''');

        // احذف الجدول القديم بعد النقل
        await txn.execute('DROP TABLE inventory_transactions_old');

        // أعد إنشاء الفهارس
        await txn.execute('CREATE INDEX IF NOT EXISTS idx_inv_prod ON inventory_transactions(product_id)');
        await txn.execute('CREATE INDEX IF NOT EXISTS idx_inv_type ON inventory_transactions(type)');
        await txn.execute('CREATE INDEX IF NOT EXISTS idx_inv_warehouse ON inventory_transactions(warehouse_id)');
        await txn.execute('CREATE INDEX IF NOT EXISTS idx_inv_batch ON inventory_transactions(batch_id)');
        await txn.execute('CREATE INDEX IF NOT EXISTS idx_inv_transfer ON inventory_transactions(transfer_id)');
      });
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
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
