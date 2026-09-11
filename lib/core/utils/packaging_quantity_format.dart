import '../../models/returnable_packaging_model.dart';

class PackagingQuantityFormat {
  PackagingQuantityFormat._();

  static const double _epsilon = 0.0001;

  static String formatQuantity(double value) {
    if ((value - value.roundToDouble()).abs() < _epsilon) {
      return value.round().toString();
    }
    final asFixed = value.toStringAsFixed(2);
    if (asFixed.endsWith('00')) {
      return value.round().toString();
    }
    if (asFixed.endsWith('0')) {
      return value.toStringAsFixed(1);
    }
    return asFixed;
  }

  /// يعرض الكمية الأساسية (زجاجة) بوحدات النوع، مثل `50 → 2 صندوق + 2 زجاجة`.
  static String format(
    double baseQuantity, {
    required List<PackagingUnit> units,
    String fallbackBaseName = 'زجاجة',
  }) {
    final sign = baseQuantity < -_epsilon ? '-' : '';
    var remaining = baseQuantity.abs();
    if (remaining < _epsilon) {
      final baseName = _baseName(units, fallbackBaseName);
      return '0 $baseName';
    }

    final active = units.where((unit) => unit.isActive).toList()
      ..sort((a, b) => b.conversionFactor.compareTo(a.conversionFactor));

    final parts = <String>[];
    for (final unit in active) {
      if (unit.conversionFactor <= 0) continue;
      final count = (remaining / unit.conversionFactor).floor();
      if (count <= 0) continue;
      parts.add('$count ${unit.unitName}');
      remaining = _round(remaining - count * unit.conversionFactor);
      if (remaining < _epsilon) break;
    }

    if (remaining >= _epsilon) {
      parts.add('${formatQuantity(remaining)} ${_baseName(units, fallbackBaseName)}');
    }

    if (parts.isEmpty) {
      return '$sign${formatQuantity(baseQuantity.abs())} ${_baseName(units, fallbackBaseName)}';
    }
    return '$sign${parts.join(' + ')}';
  }

  static PackagingUnit? aggregateUnit(List<PackagingUnit> units) {
    PackagingUnit? best;
    for (final unit in units) {
      if (!unit.isActive || unit.isBaseUnit) continue;
      if (best == null || unit.conversionFactor > best.conversionFactor) {
        best = unit;
      }
    }
    return best;
  }

  static PackagingUnit? baseUnit(List<PackagingUnit> units) {
    for (final unit in units) {
      if (unit.isBaseUnit && unit.isActive) return unit;
    }
    for (final unit in units) {
      if (unit.conversionFactor == 1) return unit;
    }
    return null;
  }

  static String _baseName(List<PackagingUnit> units, String fallback) {
    return baseUnit(units)?.unitName ?? fallback;
  }

  static double _round(double value) => (value * 10000).round() / 10000;
}
