import 'dart:math';

class CebTariff120 {
  // Minimum monthly charge (Tariff 120)
  static const double minimumMonthlyCharge = 184.0;

  /// Slabs for Domestic Tariffs 120/140 (energy charge, Rs/kWh)
  /// Source: CEB "Customer Information" / tariffs PDF (effective dates may change).
  /// Blocks are cumulative monthly kWh.
  static const List<_Slab> _slabs = [
    _Slab(uptoKwh: 25, rate: 3.16),
    _Slab(uptoKwh: 50, rate: 4.38),
    _Slab(uptoKwh: 75, rate: 4.74),
    _Slab(uptoKwh: 100, rate: 5.45),
    _Slab(uptoKwh: 200, rate: 6.15),
    _Slab(uptoKwh: 250, rate: 7.02),
    _Slab(uptoKwh: 300, rate: 7.90),
    _Slab(uptoKwh: 500, rate: 10.46),
    _Slab(uptoKwh: 1000, rate: 10.68),
    _Slab(uptoKwh: 1500, rate: 10.91),
    _Slab(uptoKwh: 2000, rate: 11.13),
    _Slab(uptoKwh: double.infinity, rate: 11.36),
  ];

  /// Energy charge for a month-to-date kWh, with Tariff 120 minimum applied.
  static double monthlyChargeForKwh(double monthKwh) {
    final kwh = max(0.0, monthKwh);
    double cost = _slabCost(kwh);

    // Apply minimum monthly charge (Tariff 120)
    if (cost < minimumMonthlyCharge) cost = minimumMonthlyCharge;

    return cost;
  }

  /// Incremental cost (Rs) of adding `deltaKwh` at the current point in the month.
  /// This is the best way to estimate "Rs today" and "peak window cost".
  static double incrementalCost({
    required double monthKwhBefore,
    required double deltaKwh,
  }) {
    final before = max(0.0, monthKwhBefore);
    final after = max(0.0, monthKwhBefore + max(0.0, deltaKwh));

    final costBefore = monthlyChargeForKwh(before);
    final costAfter = monthlyChargeForKwh(after);

    return max(0.0, costAfter - costBefore);
  }

  static double _slabCost(double kwh) {
    double remaining = kwh;
    double prevLimit = 0.0;
    double total = 0.0;

    for (final s in _slabs) {
      final bandSize = s.uptoKwh - prevLimit; // how many kWh in this slab band
      final usedInBand = min(remaining, bandSize);

      if (usedInBand > 0) {
        total += usedInBand * s.rate;
        remaining -= usedInBand;
      }

      prevLimit = s.uptoKwh;
      if (remaining <= 0) break;
    }
    return total;
  }
}

class _Slab {
  final double uptoKwh;
  final double rate;
  const _Slab({required this.uptoKwh, required this.rate});
}
