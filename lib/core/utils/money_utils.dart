class MoneyUtils {
  MoneyUtils._();

  static int? parseAmount(String? input) {
    if (input == null) return null;

    var normalized = input.trim();

    if (normalized.isEmpty) {
      return null;
    }

    const arabicDigits = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
    };

    for (final entry in arabicDigits.entries) {
      normalized = normalized.replaceAll(
        entry.key,
        entry.value,
      );
    }

    normalized = normalized
        .replaceAll('٫', '.')
        .replaceAll(',', '.')
        .replaceAll(' ', '');

    final regex = RegExp(
      r'^-?\d+(\.\d{1,2})?$',
    );

    if (!regex.hasMatch(normalized)) {
      return null;
    }

    final isNegative = normalized.startsWith('-');

    final unsigned = isNegative
        ? normalized.substring(1)
        : normalized;

    final parts = unsigned.split('.');

    final whole = int.tryParse(parts[0]);

    if (whole == null) {
      return null;
    }

    var cents = whole * 100;

    if (parts.length == 2) {
      final fraction = parts[1].padRight(2, '0');

      final fractionValue = int.tryParse(fraction);

      if (fractionValue == null) {
        return null;
      }

      cents += fractionValue;
    }

    return isNegative ? -cents : cents;
  }

  static String formatInput(int cents) {
    final isNegative = cents < 0;
    final absCents = cents.abs();

    final whole = absCents ~/ 100;
    final remainder = absCents % 100;

    return '${isNegative ? '-' : ''}'
        '$whole.'
        '${remainder.toString().padLeft(2, '0')}';
  }

  static String formatMoney(
      int cents, {
        String symbol = r'$',
      }) {
    return '${formatInput(cents)} $symbol';
  }
}