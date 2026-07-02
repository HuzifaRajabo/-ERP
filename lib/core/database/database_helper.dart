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

    final path = join(
      dbPath,
      'erp_mvp.db',
    );

    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(
      Database db,
      int version,
      ) async {
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
      
        notes TEXT,
      
        created_at TEXT DEFAULT (datetime('now')),
      
        FOREIGN KEY (party_id)
          REFERENCES parties(id)
        )
    ''');

    await db.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name_snapshot TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price INTEGER NOT NULL,
        line_total INTEGER NOT NULL,
        FOREIGN KEY (invoice_id)
          REFERENCES invoices(id)
          ON DELETE CASCADE,
        FOREIGN KEY (product_id)
          REFERENCES products(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE inventory_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,

        type TEXT CHECK(type IN ('SALE','PURCHASE')) NOT NULL,

        quantity REAL NOT NULL,

        invoice_id INTEGER NOT NULL,

        created_at TEXT DEFAULT (datetime('now')),

        FOREIGN KEY (product_id)
          REFERENCES products(id),

        FOREIGN KEY (invoice_id)
          REFERENCES invoices(id)
          ON DELETE CASCADE
      )
    ''');

        await db.execute('''
      CREATE INDEX idx_invoice_party
      ON invoices(party_id)
    ''');

        await db.execute('''
      CREATE INDEX idx_invoice_date
      ON invoices(created_at)
    ''');

        await db.execute('''
      CREATE INDEX idx_item_inv
      ON invoice_items(invoice_id)
    ''');

        await db.execute('''
      CREATE INDEX idx_item_product
      ON invoice_items(product_id)
    ''');

        await db.execute('''
      CREATE INDEX idx_inv_prod
      ON inventory_transactions(product_id)
    ''');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}