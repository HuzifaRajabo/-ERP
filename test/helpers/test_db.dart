import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:erp/core/database/database_helper.dart';

/// يشغّل sqflite مع FFI (يسمح بقواعد بيانات محلية حقيقية في الاختبارات).
void enableSqfliteFfi() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// يفتح قاعدة بيانات `in-memory` وينشئ فيها كل جداول النظام الأساسية
/// التي تحتاجها الاختبارات، ثم يمرّرها إلى [DatabaseHelper] حتى تعمل
/// الـ repositories عليها مباشرةً. يرجع مقبض الـ Database لتنظيفه لاحقاً.
Future<Database> createTestDatabase() async {
  final db = await databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 9,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
    ),
  );

  DatabaseHelper.overrideDatabaseForTesting(db);
  return db;
}

Future<void> closeTestDatabase(Database db) async {
  DatabaseHelper.overrideDatabaseForTesting(null);
  await db.close();
}

Future<void> _createSchema(Database db, int version) async {
  await db.execute('''
  CREATE TABLE product_categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    is_preset INTEGER NOT NULL DEFAULT 0,
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
  )
  ''');

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
    original_total_amount INTEGER NOT NULL DEFAULT 0,
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
}
