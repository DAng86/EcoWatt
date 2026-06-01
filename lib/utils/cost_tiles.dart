import 'dart:math';
import 'ceb_tariff_120.dart';

class CostTiles {
  /// "Rs today (approx)" as incremental cost for today's kWh.
  static double rsToday({
    required double monthKwhToDate,
    required double todayKwh,
  }) {
    final before = max(0.0, monthKwhToDate - max(0.0, todayKwh));
    return CebTariff120.incrementalCost(
      monthKwhBefore: before,
      deltaKwh: todayKwh,
    );
  }

  /// "Rs forecast end-of-month" using average daily kWh so far.
  static double rsForecastEom({
    required double monthKwhToDate,
    required int dayOfMonth, // 1..31
    required int daysInMonth, // 28..31
  }) {
    final d = max(1, dayOfMonth);
    final avgPerDay = max(0.0, monthKwhToDate) / d;
    final projectedKwh = avgPerDay * daysInMonth;

    return CebTariff120.monthlyChargeForKwh(projectedKwh);
  }

  /// "Peak window cost (18:00–21:00)" as incremental cost of that peak kWh.
  static double rsPeakWindow({
    required double monthKwhToDate,
    required double peakKwhToday,
  }) {
    // This approximates peak window Rs by treating those kWh as the last-added kWh.
    // Good enough for "awareness" even without TOU tariffs.
    final before = max(0.0, monthKwhToDate - max(0.0, peakKwhToday));
    return CebTariff120.incrementalCost(
      monthKwhBefore: before,
      deltaKwh: peakKwhToday,
    );
  }
}
