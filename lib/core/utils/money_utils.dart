class MoneyUtils {
  MoneyUtils._();

  /// Parses user-entered money text into cents.
  ///
  /// Supported input formats:
  /// - 12.50
  /// - 12,50
  /// - 0.75
  /// - 125
  /// Returns null for invalid input.
  static int? parseAmount(String? input) {
    if (input == null) return null;
    final normalized = input.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;

    final regex = RegExp(r'^-?\d+(\.\d{0,2})?\$');
    if (!regex.hasMatch(normalized)) return null;

    final parts = normalized.split('.');
    final whole = int.tryParse(parts[0]);
    if (whole == null) return null;

    var cents = whole.abs() * 100;
    if (parts.length == 2) {
      final fraction = parts[1].padRight(2, '0');
      if (fraction.length > 2) return null;
      final fractionValue = int.tryParse(fraction);
      if (fractionValue == null) return null;
      cents += fractionValue;
    }

    return whole < 0 ? -cents : cents;
  }

  /// Formats cents to a display string with two decimals.
  /// Example: 1250 -> 12.50
  static String formatInput(int cents) {
    final isNegative = cents < 0;
    final absCents = cents.abs();
    final dollars = absCents ~/ 100;
    final remainder = absCents % 100;
    return '${isNegative ? '-' : ''}$dollars.${remainder.toString().padLeft(2, '0')}';
  }

  /// Formats cents with currency symbol.
  /// Example: 1250 -> 12.50 $
  static String formatMoney(int cents, {String symbol = r'$'}) {
    return '${formatInput(cents)} $symbol';
  }
}
