import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../models/company_profile_model.dart';

class CompanyProfileRepository {
  CompanyProfileRepository({Future<Database> Function()? dbProvider})
      : _dbProvider = dbProvider ?? (() => DatabaseHelper.instance.database);

  final Future<Database> Function() _dbProvider;

  Future<Database> get _db => _dbProvider();

  Future<CompanyProfileModel> getCompanyProfile() async {
    final db = await _db;
    final rows = await db.query('company_profile', orderBy: 'id ASC', limit: 1);
    if (rows.isNotEmpty) {
      return CompanyProfileModel.fromMap(rows.first);
    }
    await db.insert('company_profile', {'name': ''});
    final created = await db.query(
      'company_profile',
      orderBy: 'id ASC',
      limit: 1,
    );
    return CompanyProfileModel.fromMap(created.first);
  }

  /// يحفظ السجل الوحيد: UPDATE إن وُجد، وإلا INSERT مرة واحدة.
  Future<CompanyProfileModel> saveCompanyProfile(
    CompanyProfileModel profile,
  ) async {
    return updateCompanyProfile(profile);
  }

  Future<CompanyProfileModel> updateCompanyProfile(
    CompanyProfileModel profile,
  ) async {
    final db = await _db;
    final existing = await db.query(
      'company_profile',
      orderBy: 'id ASC',
      limit: 1,
    );
    final now = DateTime.now().toIso8601String();
    final data = <String, Object?>{
      'name': profile.name.trim(),
      'trade_name': profile.tradeName.trim(),
      'address': profile.address.trim(),
      'service_area': profile.serviceArea.trim(),
      'phone': profile.phone.trim(),
      'description': profile.description.trim(),
      'updated_at': now,
    };

    if (existing.isEmpty) {
      data['created_at'] = now;
      await db.insert('company_profile', data);
    } else {
      final id = existing.first['id'] as int;
      await db.update(
        'company_profile',
        data,
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    return getCompanyProfile();
  }
}
