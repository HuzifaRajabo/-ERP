import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:erp/repositories/product_repository.dart';

import 'helpers/test_db.dart';

void main() {
  late Database db;
  late ProductRepository repo;

  setUp(() async {
    enableSqfliteFfi();
    db = await createTestDatabase();
    repo = ProductRepository();
  });

  tearDown(() async {
    await closeTestDatabase(db);
  });

  Future<int> insertProduct({
    required String name,
    int isActive = 1,
  }) async {
    return db.insert('products', {
      'name': name,
      'description': 'وصف تجريبي',
      'cost_price': 100,
      'sale_price': 150,
      'is_active': isActive,
    });
  }

  Future<int> insertInventoryTransaction({
    required int productId,
    required String type,
    required double quantity,
    int? invoiceId,
  }) async {
    return db.insert('inventory_transactions', {
      'product_id': productId,
      'type': type,
      'quantity': quantity,
      'invoice_id': invoiceId,
    });
  }

  group('deleteOrDeactivateProduct', () {
    test('deletes a brand-new product (no stock, no history)', () async {
      final id = await insertProduct(name: 'منتج جديد');

      final result = await repo.deleteOrDeactivateProduct(id);

      expect(result, ProductDeleteResult.deleted);
      final exists = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(exists, isEmpty);
    });

    test('blocks deletion when the product still has stock', () async {
      final id = await insertProduct(name: 'منتج بمخزون');
      await insertInventoryTransaction(
        productId: id,
        type: 'PURCHASE',
        quantity: 10,
      );

      final result = await repo.deleteOrDeactivateProduct(id);

      expect(result, ProductDeleteResult.hasStock);
      final rows = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [id],
      );
      // لم يُحذف ولم يُوقف — ما زال موجوداً وفعالاً
      expect(rows, isNotEmpty);
      expect(rows.first['is_active'], 1);
    });

    test('deactivates a product with zero stock but historical movement',
        () async {
      final id = await insertProduct(name: 'منتج تاريخي');
      // شراء ثم بيع كامل → مخزون = 0 لكن له تاريخ
      await insertInventoryTransaction(
        productId: id,
        type: 'PURCHASE',
        quantity: 5,
      );
      await insertInventoryTransaction(
        productId: id,
        type: 'SALE',
        quantity: 5,
      );

      final result = await repo.deleteOrDeactivateProduct(id);

      expect(result, ProductDeleteResult.deactivated);
      final rows = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(rows.first['is_active'], 0);
    });

    test('returns notFound when the product does not exist', () async {
      final result = await repo.deleteOrDeactivateProduct(99999);
      expect(result, ProductDeleteResult.notFound);
    });

    test('active products are returned and inactive are excluded',
        () async {
      await insertProduct(name: 'نشط');
      await insertProduct(name: 'موقوف', isActive: 0);

      final page = await repo.getAllProducts(pageSize: 100);
      final names = page.products.map((p) => p.name).toList();

      expect(names, contains('نشط'));
      expect(names, isNot(contains('موقوف')));
    });

    test('getAllProducts can include inactive when requested', () async {
      await insertProduct(name: 'نشط');
      await insertProduct(name: 'موقوف', isActive: 0);

      final page = await repo.getAllProducts(
        pageSize: 100,
        includeInactive: true,
      );
      final names = page.products.map((p) => p.name).toList();

      expect(names, contains('نشط'));
      expect(names, contains('موقوف'));
    });
  });

  group('setProductActive', () {
    test('reactivates a deactivated product', () async {
      final id = await insertProduct(name: 'موقوف', isActive: 0);
      expect(
        (await db.query('products', where: 'id = ?', whereArgs: [id]))
            .first['is_active'],
        0,
      );

      await repo.setProductActive(id, true);

      final rows = await db.query('products', where: 'id = ?', whereArgs: [id]);
      expect(rows.first['is_active'], 1);
    });

    test('deactivates an active product', () async {
      final id = await insertProduct(name: 'نشط', isActive: 1);

      await repo.setProductActive(id, false);

      final rows = await db.query('products', where: 'id = ?', whereArgs: [id]);
      expect(rows.first['is_active'], 0);
    });
  });
}
