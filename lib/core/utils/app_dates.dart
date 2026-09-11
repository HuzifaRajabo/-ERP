/// تواريخ على مستوى اليوم فقط، بنفس أسلوب المشروع (`YYYY-MM-DD`)
/// دون منطق منطقة زمنية إضافي.
abstract final class AppDates {
  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String toIsoDate(DateTime value) =>
      dateOnly(value).toIso8601String().split('T').first;

  static DateTime? tryParseDateOnly(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return null;
    return dateOnly(parsed);
  }

  static int? daysUntil(String? expiryIso, DateTime today) {
    final expiry = tryParseDateOnly(expiryIso);
    if (expiry == null) return null;
    return expiry.difference(dateOnly(today)).inDays;
  }

  static String formatDisplay(String? expiryIso) {
    final parsed = tryParseDateOnly(expiryIso);
    if (parsed == null) return expiryIso?.trim() ?? '';
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  static String formatQuantity(double value) {
    if ((value - value.roundToDouble()).abs() < 0.0001) {
      return value.round().toString();
    }
    final asFixed = value.toStringAsFixed(2);
    if (asFixed.endsWith('00')) return value.round().toString();
    if (asFixed.endsWith('0')) return value.toStringAsFixed(1);
    return asFixed;
  }
}
