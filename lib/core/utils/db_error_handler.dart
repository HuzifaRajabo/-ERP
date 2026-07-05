// lib/core/utils/db_error_handler.dart

class DbErrorHandler {
  /// يترجم أخطاء SQLite لرسائل عربية واضحة
  static String handle(Object e, {required String entityName}) {
    final msg = e.toString().toLowerCase();

    if (msg.contains('foreign key constraint failed') ||
        msg.contains('constraint failed')) {
      return 'لا يمكن حذف $entityName لأنه مرتبط بفواتير أو حركات مخزون موجودة';
    }

    if (msg.contains('unique constraint') || msg.contains('unique')) {
      return 'هذه البيانات موجودة مسبقاً، تحقق من القيم المكررة';
    }

    if (msg.contains('not null constraint')) {
      return 'بعض الحقول المطلوبة فارغة';
    }

    return 'حدث خطأ غير متوقع، حاول مجدداً';
  }
}