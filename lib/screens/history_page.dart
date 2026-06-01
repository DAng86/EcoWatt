import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/reading.dart';
import '../services/db_service.dart';

const String chGfSockets = 'GF_SOCKETS';
const String chGfLights = 'GF_LIGHTS';
const String chFfSockets = 'FF_SOCKETS';
const String chFfLights = 'FF_LIGHTS';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  DateTime selectedDay = DateTime.now();

  Future<List<MonthlyBill>> _loadMonthlyBills() async {
    final count = await DBService.instance.countMonthlyBills();

    if (count < 12) {
      await _generateMonthlyBillDemoData();
    }

    return DBService.instance.getLast12MonthlyBills();
  }

  Future<void> _generateMonthlyBillDemoData() async {
    final now = DateTime.now();
    final rand = Random();

    for (int i = 11; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);

      final seasonalFactor =
          (date.month == 12 || date.month == 1 || date.month == 2) ? 1.15 : 1.0;

      final energyKwh =
          (260 + rand.nextInt(130)) * seasonalFactor; // around 260–390 kWh

      final billRs = _estimateCebMonthlyBill(energyKwh);

      await DBService.instance.upsertMonthlyBill(
        month: date.month,
        year: date.year,
        energyKwh: energyKwh,
        estimatedRs: billRs,
      );
    }
  }

  Future<List<Reading>> _loadDayReadings() async {
    final start = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );

    final end = start.add(const Duration(days: 1));

    var readings = await DBService.instance.readingsBetween(start, end);

    readings = readings
        .where((r) =>
            r.channel == chGfLights ||
            r.channel == chGfSockets ||
            r.channel == chFfLights ||
            r.channel == chFfSockets)
        .toList()
      ..sort((a, b) => a.ts.compareTo(b.ts));

    bool dayIncomplete = true;

    if (readings.isNotEmpty) {
      final first = readings.first.ts;
      final last = readings.last.ts;
      final spanHours = last.difference(first).inHours;

      dayIncomplete = spanHours < 20;
    }

    if (readings.isEmpty || dayIncomplete) {
      await _generateFullDaySimulation(start);

      readings = await DBService.instance.readingsBetween(start, end);

      readings = readings
          .where((r) =>
              r.channel == chGfLights ||
              r.channel == chGfSockets ||
              r.channel == chFfLights ||
              r.channel == chFfSockets)
          .toList()
        ..sort((a, b) => a.ts.compareTo(b.ts));
    }

    return readings;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDay,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedDay = picked;
      });
    }
  }

  String _formatDay(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1320),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1320),
        elevation: 0,
        toolbarHeight: 60,
        title: const SizedBox(),
        actions: [
          Row(
            children: [
              Text(
                _formatDay(selectedDay),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_rounded,
                    color: Colors.white),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<Reading>>(
        future: _loadDayReadings(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final readings = snap.data!;

          final socketPoints = _bucketReadings(
            readings: readings,
            bucketMinutes: 15,
            channels: const [chGfSockets, chFfSockets],
          );

          final lightPoints = _bucketReadings(
            readings: readings,
            bucketMinutes: 15,
            channels: const [chGfLights, chFfLights],
          );

          final summary = _buildSummary(readings);

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              children: [
                const SizedBox(height: 12),
                FutureBuilder<List<MonthlyBill>>(
                  future: _loadMonthlyBills(),
                  builder: (context, billSnap) {
                    if (!billSnap.hasData) {
                      return const SizedBox(
                        height: 180,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    return _MonthlyBillTrendCard(
                      bills: billSnap.data!,
                    );
                  },
                ),
                const SizedBox(height: 12),
                _SectionChartCard(
                  title: 'Sockets Usage',
                  subtitle: 'GF Sockets vs FF Sockets',
                  points: socketPoints,
                  line1Label: 'GF Sockets',
                  line2Label: 'FF Sockets',
                  line1Color: const Color(0xFF42A5F5),
                  line2Color: const Color(0xFF26C6DA),
                ),
                const SizedBox(height: 12),
                _SectionChartCard(
                  title: 'Lights Usage',
                  subtitle: 'GF Lights vs FF Lights',
                  points: lightPoints,
                  line1Label: 'GF Lights',
                  line2Label: 'FF Lights',
                  line1Color: const Color(0xFFFFD54F),
                  line2Color: const Color(0xFFEC407A),
                ),
                const SizedBox(height: 12),
                _SummaryCard(summary: summary),
              ],
            ),
          );
        },
      ),
    );
  }
}

double _estimateCebMonthlyBill(double monthlyKWh) {
  final blocks = [
    [25.0, 3.16],
    [25.0, 4.38],
    [25.0, 4.74],
    [25.0, 5.45],
    [100.0, 6.15],
    [50.0, 7.02],
    [50.0, 7.90],
  ];

  double remaining = monthlyKWh;
  double energyCost = 0.0;

  for (final block in blocks) {
    final units = block[0];
    final rate = block[1];

    final used = remaining > units ? units : remaining;
    energyCost += used * rate;
    remaining -= used;

    if (remaining <= 0) break;
  }

  if (remaining > 0) {
    energyCost += remaining * 8.77;
  }

  const meterRentalRs = 20.0;
  const increaseFactor = 1.15;

  final total = (energyCost + meterRentalRs) * increaseFactor;

  return total < 184.0 ? 184.0 : total;
}

Future<void> _generateFullDaySimulation(DateTime dayStart) async {
  final rand = Random();

  for (int i = 0; i < 288; i++) {
    final ts = dayStart.add(Duration(minutes: i * 5));

    double baseSockets;
    double baseLights;

    if (ts.hour < 6) {
      baseSockets = 100;
      baseLights = 20;
    } else if (ts.hour < 12) {
      baseSockets = 300;
      baseLights = 80;
    } else if (ts.hour < 18) {
      baseSockets = 500;
      baseLights = 120;
    } else {
      baseSockets = 1200;
      baseLights = 180;
    }

    final gfSockets = baseSockets + rand.nextDouble() * 200;
    final ffSockets = baseSockets * 0.8 + rand.nextDouble() * 200;
    final gfLights = baseLights + rand.nextDouble() * 40;
    final ffLights = baseLights * 0.7 + rand.nextDouble() * 40;

    await DBService.instance.insertReading(
      Reading(
        channel: chGfSockets,
        ts: ts,
        currentA: gfSockets / 230,
        powerW: gfSockets,
        alertType: 'NONE',
      ),
    );

    await DBService.instance.insertReading(
      Reading(
        channel: chFfSockets,
        ts: ts,
        currentA: ffSockets / 230,
        powerW: ffSockets,
        alertType: 'NONE',
      ),
    );

    await DBService.instance.insertReading(
      Reading(
        channel: chGfLights,
        ts: ts,
        currentA: gfLights / 230,
        powerW: gfLights,
        alertType: 'NONE',
      ),
    );

    await DBService.instance.insertReading(
      Reading(
        channel: chFfLights,
        ts: ts,
        currentA: ffLights / 230,
        powerW: ffLights,
        alertType: 'NONE',
      ),
    );
  }
}

class _BucketPoint {
  final DateTime time;
  final double v1;
  final double v2;

  _BucketPoint({
    required this.time,
    required this.v1,
    required this.v2,
  });
}

List<_BucketPoint> _bucketReadings({
  required List<Reading> readings,
  required int bucketMinutes,
  required List<String> channels,
}) {
  if (readings.isEmpty) return [];

  final firstTs = readings.first.ts;
  final dayStart = DateTime(firstTs.year, firstTs.month, firstTs.day);

  final bucketMap = <int, Map<String, List<double>>>{};

  for (final r in readings) {
    if (!channels.contains(r.channel)) continue;

    final minutes = r.ts.difference(dayStart).inMinutes;
    final bucketIndex = minutes ~/ bucketMinutes;

    bucketMap.putIfAbsent(
        bucketIndex,
        () => {
              channels[0]: <double>[],
              channels[1]: <double>[],
            });

    bucketMap[bucketIndex]![r.channel]!.add(r.powerW);
  }

  if (bucketMap.isEmpty) return [];

  final maxBucket = bucketMap.keys.reduce(max);
  final out = <_BucketPoint>[];

  double avg(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  for (int i = 0; i <= maxBucket; i++) {
    final bucketStart = dayStart.add(Duration(minutes: i * bucketMinutes));
    final bucket = bucketMap[i];

    out.add(
      _BucketPoint(
        time: bucketStart,
        v1: avg(bucket?[channels[0]] ?? []),
        v2: avg(bucket?[channels[1]] ?? []),
      ),
    );
  }

  return out;
}

class _HistorySummary {
  final double gfSocketsMax;
  final double ffSocketsMax;
  final double gfLightsMax;
  final double ffLightsMax;

  _HistorySummary({
    required this.gfSocketsMax,
    required this.ffSocketsMax,
    required this.gfLightsMax,
    required this.ffLightsMax,
  });
}

_HistorySummary _buildSummary(List<Reading> readings) {
  double maxFor(String channel) {
    final vals = readings
        .where((r) => r.channel == channel)
        .map((r) => r.powerW)
        .toList();
    if (vals.isEmpty) return 0;
    return vals.reduce(max);
  }

  return _HistorySummary(
    gfSocketsMax: maxFor(chGfSockets),
    ffSocketsMax: maxFor(chFfSockets),
    gfLightsMax: maxFor(chGfLights),
    ffLightsMax: maxFor(chFfLights),
  );
}

class _DateCard extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTap;

  const _DateCard({
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF171C2C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, color: Colors.white70),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

class _SectionChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_BucketPoint> points;
  final String line1Label;
  final String line2Label;
  final Color line1Color;
  final Color line2Color;

  const _SectionChartCard({
    required this.title,
    required this.subtitle,
    required this.points,
    required this.line1Label,
    required this.line2Label,
    required this.line1Color,
    required this.line2Color,
  });

  @override
  Widget build(BuildContext context) {
    final spots1 = <FlSpot>[];
    final spots2 = <FlSpot>[];

    for (int i = 0; i < points.length; i++) {
      spots1.add(FlSpot(i.toDouble(), points[i].v1));
      spots2.add(FlSpot(i.toDouble(), points[i].v2));
    }

    final allY = [
      ...points.map((e) => e.v1),
      ...points.map((e) => e.v2),
    ];

    final maxY = _maxWithHeadroom(allY);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF171C2C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF9AA3B2),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: points.isEmpty
                ? const Center(
                    child: Text(
                      'No data available',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (points.length - 1).toDouble(),
                      minY: 0,
                      maxY: maxY,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY / 4,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.white.withOpacity(0.06),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
                            interval: maxY / 4,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()} W',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 4,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();

                              if (index < 0 || index >= points.length) {
                                return const SizedBox.shrink();
                              }

                              final t = points[index].time;

                              if (t.minute != 0) {
                                return const SizedBox.shrink();
                              }

                              final hour = t.hour;

                              if (hour % 4 != 0 && hour != 23) {
                                return const SizedBox.shrink();
                              }

                              final hh = hour.toString().padLeft(2, '0');

                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '$hh:00',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        enabled: true,
                        handleBuiltInTouches: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => const Color(0xFF252B42),
                          getTooltipItems: (spots) {
                            return spots.map((spot) {
                              return LineTooltipItem(
                                '${spot.y.toStringAsFixed(0)} W',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      lineBarsData: [
                        _line(spots1, line1Color, isPrimary: true),
                        _line(spots2, line2Color),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _LegendChip(label: line1Label, color: line1Color),
              _LegendChip(label: line2Label, color: line2Color),
            ],
          ),
          const SizedBox(height: 10),
          _buildInsightText(points, line1Label, line2Label),
        ],
      ),
    );
  }

  Widget _buildInsightText(
    List<_BucketPoint> points,
    String line1Label,
    String line2Label,
  ) {
    if (points.isEmpty) return const SizedBox();

    double avg1 =
        points.map((e) => e.v1).reduce((a, b) => a + b) / points.length;

    double avg2 =
        points.map((e) => e.v2).reduce((a, b) => a + b) / points.length;

    String insight;

    if (avg1 > avg2) {
      insight = '$line1Label consuming more on average';
    } else if (avg2 > avg1) {
      insight = '$line2Label consuming more on average';
    } else {
      insight = 'Both circuits consuming similar power';
    }

    return Text(
      insight,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color,
      {bool isPrimary = false}) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.25,
      barWidth: isPrimary ? 3.2 : 2.0,
      color: color,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withOpacity(isPrimary ? 0.22 : 0.12),
      ),
    );
  }

  double _maxWithHeadroom(List<double> values) {
    if (values.isEmpty) return 1000;
    final m = values.reduce(max);
    if (m <= 300) return 300;
    if (m <= 1000) return 1000;
    if (m <= 2000) return 2000;
    return 3000;
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyBillTrendCard extends StatelessWidget {
  final List<MonthlyBill> bills;

  const _MonthlyBillTrendCard({
    required this.bills,
  });

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];

    for (int i = 0; i < bills.length; i++) {
      spots.add(FlSpot(i.toDouble(), bills[i].estimatedRs));
    }

    final values = bills.map((b) => b.estimatedRs).toList();
    final maxBill =
        values.isEmpty ? 3000.0 : values.reduce((a, b) => a > b ? a : b);
    final maxY = maxBill < 3000 ? 3500.0 : maxBill + 500.0;

    final avgBill = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a + b) / values.length.toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF171C2C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '12-Month Electricity Cost Trend',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Estimated CEB monthly bill history',
            style: TextStyle(
              color: Color(0xFF9AA3B2),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _billMiniTile(
                  label: 'Average',
                  value: 'Rs ${avgBill.toStringAsFixed(0)}',
                  color: const Color(0xFF22C55E),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _billMiniTile(
                  label: 'Target',
                  value: 'Rs 3000',
                  color: const Color(0xFFFACC15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 210,
            child: bills.isEmpty
                ? const Center(
                    child: Text(
                      'No monthly bill data available',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (bills.length - 1).toDouble(),
                      minY: 0,
                      maxY: maxY,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY / 4,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.white.withOpacity(0.06),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 70,
                            interval: 1000,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${(value / 1000).toStringAsFixed(0)}k',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();

                              if (index < 0 || index >= bills.length) {
                                return const SizedBox.shrink();
                              }

                              final b = bills[index];
                              final label = _shortMonth(b.month);

                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: 3000,
                            color: const Color(0xFFFACC15).withOpacity(0.85),
                            strokeWidth: 1.5,
                            dashArray: [6, 4],
                          ),
                          HorizontalLine(
                            y: avgBill,
                            color: const Color(0xFF9CA3AF).withOpacity(0.85),
                            strokeWidth: 1.2,
                            dashArray: [4, 4],
                          ),
                        ],
                      ),
                      lineTouchData: LineTouchData(
                        enabled: true,
                        handleBuiltInTouches: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => const Color(0xFF252B42),
                          getTooltipItems: (spots) {
                            return spots.map((spot) {
                              final index = spot.x.toInt();
                              final b = bills[index];

                              return LineTooltipItem(
                                '${_shortMonth(b.month)} ${b.year}\nRs ${b.estimatedRs.toStringAsFixed(0)}\n${b.energyKwh.toStringAsFixed(0)} kWh',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.25,
                          barWidth: 3,
                          color: const Color(0xFF22C55E),
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF22C55E).withOpacity(0.16),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              const _LegendChip(
                label: 'Monthly bill',
                color: Color(0xFF22C55E),
              ),
              const _LegendChip(
                label: 'Rs 3000 target',
                color: Color(0xFFFACC15),
              ),
              _LegendChip(
                label: '12-month average: Rs ${avgBill.toStringAsFixed(0)}',
                color: const Color(0xFF9CA3AF),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _billMiniTile({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  static String _shortMonth(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return months[month - 1];
  }
}

class _SummaryCard extends StatelessWidget {
  final _HistorySummary summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF171C2C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Peak Values',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _summaryRow(
              'GF Sockets', summary.gfSocketsMax, const Color(0xFF42A5F5)),
          _summaryRow(
              'FF Sockets', summary.ffSocketsMax, const Color(0xFF26C6DA)),
          _summaryRow(
              'GF Lights', summary.gfLightsMax, const Color(0xFFFFD54F)),
          _summaryRow(
              'FF Lights', summary.ffLightsMax, const Color(0xFFEC407A)),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '${value.toStringAsFixed(0)} W',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
