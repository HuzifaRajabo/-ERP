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
      version: 3,
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
    await db.execute('''
    CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      sku TEXT UNIQUE NOT NULL,
      cost_price INTEGER NOT NULL,
      sale_price INTEGER NOT NULL,
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

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
    notes TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (party_id) REFERENCES parties(id)
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
      FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES products(id)
    )
  ''');

    // ← CHECK محذوف لأن SQLite لا يدعم تعديله لاحقاً
    // القيم المقبولة: SALE, PURCHASE, SALE_RETURN, PURCHASE_RETURN
    // يتم التحكم فيها من الكود
    await db.execute('''
    CREATE TABLE inventory_transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL,
      type TEXT NOT NULL,
      quantity REAL NOT NULL,
      invoice_id INTEGER NOT NULL,
      return_id INTEGER,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (product_id) REFERENCES products(id),
      FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
      FOREIGN KEY (return_id) REFERENCES returns(id) ON DELETE CASCADE
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
      product_name_snapshot TEXT NOT NULL,
      quantity REAL NOT NULL,
      unit_price INTEGER NOT NULL,
      line_total INTEGER NOT NULL,
      FOREIGN KEY (return_id) REFERENCES returns(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES products(id)
    )
  ''');

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
      await db.execute('ALTER TABLE payments ADD COLUMN return_id INTEGER');
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
