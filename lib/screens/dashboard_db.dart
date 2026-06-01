import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../models/reading.dart';
import '../services/db_service.dart';
import 'package:fl_chart/fl_chart.dart';

// Must match your channel IDs
const String chGfSockets = 'GF_SOCKETS';
const String chGfLights = 'GF_LIGHTS';
const String chFfSockets = 'FF_SOCKETS';
const String chFfLights = 'FF_LIGHTS';

class CircuitApplianceProfile {
  final String label;
  final List<String> appliances;
  final List<String> nightRisk;
  final List<String> eveningRisk;
  final List<String> highLoadRisk;

  const CircuitApplianceProfile({
    required this.label,
    required this.appliances,
    required this.nightRisk,
    required this.eveningRisk,
    required this.highLoadRisk,
  });
}

const Map<String, CircuitApplianceProfile> applianceProfiles = {
  chGfSockets: CircuitApplianceProfile(
    label: 'GF Sockets',
    appliances: [
      'Dishwasher',
      'Oven',
      'Microwave',
      'Ceramic hob',
      'Kettle',
      'Fridge',
      'TV',
      'Router',
      'PlayStation',
      'Nintendo',
      'Nespresso machine',
      'Robot vacuum',
      'Chargers',
      'Hair dryer',
      'Mosquito repellent plugs',
    ],
    nightRisk: [
      'kettle',
      'oven',
      'microwave',
      'robot vacuum',
      'chargers',
      'mosquito repellent plugs',
    ],
    eveningRisk: [
      'oven',
      'microwave',
      'kettle',
      'ceramic hob',
      'dishwasher',
    ],
    highLoadRisk: [
      'oven',
      'kettle',
      'microwave',
      'ceramic hob',
      'dishwasher',
    ],
  ),
  chFfSockets: CircuitApplianceProfile(
    label: 'FF Sockets',
    appliances: [
      'Boiler',
      'Washing machine',
      'Treadmill',
      'Dehumidifier',
      'Laptop sockets',
      'Chargers',
    ],
    nightRisk: [
      'boiler',
      'dehumidifier',
      'chargers',
    ],
    eveningRisk: [
      'boiler',
      'washing machine',
      'treadmill',
      'dehumidifier',
    ],
    highLoadRisk: [
      'boiler',
      'washing machine',
      'treadmill',
      'dehumidifier',
    ],
  ),
  chGfLights: CircuitApplianceProfile(
    label: 'GF Lights',
    appliances: [
      'Kitchen ceiling spots',
      'Living room lights',
      'Exterior lights',
      'Terrace lights',
      'Bathroom lights',
      'Toilet lights',
    ],
    nightRisk: [
      'exterior lights',
      'terrace lights',
      'kitchen lights',
      'living room lights',
    ],
    eveningRisk: [
      'kitchen lights',
      'living room lights',
      'terrace lights',
      'exterior lights',
    ],
    highLoadRisk: [
      'kitchen ceiling spots',
      'exterior lights',
      'terrace lights',
    ],
  ),
  chFfLights: CircuitApplianceProfile(
    label: 'FF Lights',
    appliances: [
      'Bedroom lights',
      'Corridor lights',
      'Bathroom lights',
      'Toilet lights',
      'Terrace lights',
    ],
    nightRisk: [
      'bedroom lights',
      'corridor lights',
      'terrace lights',
    ],
    eveningRisk: [
      'bedroom lights',
      'corridor lights',
      'bathroom lights',
      'terrace lights',
    ],
    highLoadRisk: [
      'corridor lights',
      'terrace lights',
      'bedroom lights',
    ],
  ),
};

CircuitApplianceProfile profileForCircuit(String channel) {
  return applianceProfiles[channel] ??
      const CircuitApplianceProfile(
        label: 'Unknown circuit',
        appliances: [],
        nightRisk: [],
        eveningRisk: [],
        highLoadRisk: [],
      );
}

String prettyChannelName(String ch) {
  switch (ch) {
    case chGfSockets:
      return 'GF Sockets';
    case chGfLights:
      return 'GF Lights';
    case chFfSockets:
      return 'FF Sockets';
    case chFfLights:
      return 'FF Lights';
    default:
      return ch;
  }
}

class DashboardDbPage extends StatefulWidget {
  final VoidCallback? onOpenAlerts;

  const DashboardDbPage({
    super.key,
    this.onOpenAlerts,
  });

  @override
  State<DashboardDbPage> createState() => _DashboardDbPageState();
}

class _DashboardDbPageState extends State<DashboardDbPage> {
  static const Duration lastHourWindow = Duration(hours: 1);
  static const Duration graphWindow = Duration(minutes: 10);

  // Thresholds
  static const double gfLightsLimitW = 450.0;
  static const double gfSocketsLimitW = 7000.0;
  static const double ffLightsLimitW = 250.0;
  static const double ffSocketsLimitW = 7000.0;

  static const double totalWarningW = 8000.0;
  static const double totalPeakW = 11000.0;

  static const double usualBillLowRs = 1400.0;
  static const double cautionBillRs = 2400.0;
  static const double usualBillHighRs = 3000.0;

  static const double averageHistoricalBillRs = 2077.0;

  // Circuit colors
  static const Color cBg = Color(0xFF0E1320); // DARK BACKGROUND

  static const Color cCard = Color(0xFF171C2C);
  static const Color cCard2 = Color(0xFF1D2336);

  static const Color cTextMain = Colors.white;
  static const Color cTextSub = Color(0xFF9AA3B2);

// Circuit colors (clean system)
  static const Color cGfLights = Color(0xFFFFD54F); // yellow
  static const Color cGfSockets = Color(0xFF42A5F5); // blue
  static const Color cFfLights = Color(0xFFEC407A); // pink
  static const Color cFfSockets = Color(0xFF26C6DA); // teal

  Color colorFor(String ch) {
    switch (ch) {
      case chGfLights:
        return cGfLights;
      case chGfSockets:
        return cGfSockets;
      case chFfSockets:
        return cFfSockets;
      case chFfLights:
        return cFfLights;
      default:
        return Colors.grey;
    }
  }

  String pretty(String ch) {
    switch (ch) {
      case chGfSockets:
        return 'GF Sockets';
      case chGfLights:
        return 'GF Lights';
      case chFfSockets:
        return 'FF Sockets';
      case chFfLights:
        return 'FF Lights';
      default:
        return ch;
    }
  }

  IconData iconFor(String ch) {
    switch (ch) {
      case chGfLights:
        return Icons.lightbulb_rounded;
      case chGfSockets:
        return Icons.power_rounded;
      case chFfLights:
        return Icons.light_mode_rounded;
      case chFfSockets:
        return Icons.electrical_services_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  double circuitLimitFor(String ch) {
    switch (ch) {
      case chGfLights:
        return gfLightsLimitW;
      case chGfSockets:
        return gfSocketsLimitW;
      case chFfLights:
        return ffLightsLimitW;
      case chFfSockets:
        return ffSocketsLimitW;
      default:
        return 1000.0;
    }
  }

  String totalStatusFor(double totalPower) {
    if (totalPower >= totalPeakW) return 'Critical';
    if (totalPower >= totalWarningW) return 'Warning';
    return 'Normal';
  }

  String circuitStateFor(String ch, double power) {
    final limit = circuitLimitFor(ch);
    final ratio = limit <= 0 ? 0.0 : power / limit;

    if (ratio > 1.0) return 'Critical';
    if (ratio >= 0.8) return 'Warning';
    return 'Normal';
  }

  Future<_DashData> _load() async {
    final settings = context.read<AppSettings>();
    final now = DateTime.now();

    final lastHourSince = now.subtract(lastHourWindow);
    final graphSince = now.subtract(graphWindow);
    final monthStart = DateTime(now.year, now.month, 1);

    final dtSec = settings.updateIntervalSec.toDouble().clamp(1, 60);

    final sumPowerLastHour =
        await DBService.instance.sumPowerByChannelSince(lastHourSince);

    final lastHourEnergyWh = <String, double>{};
    for (final ch in [chGfLights, chGfSockets, chFfLights, chFfSockets]) {
      final sumP = sumPowerLastHour[ch] ?? 0.0;
      lastHourEnergyWh[ch] = sumP * (dtSec / 3600.0);
    }

    final sumPowerMonth =
        await DBService.instance.sumPowerByChannelSince(monthStart);

    final monthEnergyWhByChannel = <String, double>{};
    for (final ch in [chGfLights, chGfSockets, chFfLights, chFfSockets]) {
      final sumP = sumPowerMonth[ch] ?? 0.0;
      monthEnergyWhByChannel[ch] = sumP * (dtSec / 3600.0);
    }

    final monthTotalEnergyWh = monthEnergyWhByChannel.values.fold<double>(
      0.0,
      (sum, v) => sum + v,
    );

    final recentReadings =
        await DBService.instance.readingsSince(graphSince, limit: 4000);

    final filteredRecent = recentReadings
        .where((r) =>
            r.channel == chGfLights ||
            r.channel == chGfSockets ||
            r.channel == chFfLights ||
            r.channel == chFfSockets)
        .toList();

    return _DashData(
      lastHourEnergyWh: lastHourEnergyWh,
      monthEnergyWhByChannel: monthEnergyWhByChannel,
      monthTotalEnergyWh: monthTotalEnergyWh,
      readings: filteredRecent,
    );
  }

  _DashboardMetrics buildMetrics(_DashData data) {
    final latestByChannel = <String, Reading>{};

    for (final r in data.readings) {
      final existing = latestByChannel[r.channel];
      if (existing == null || r.ts.isAfter(existing.ts)) {
        latestByChannel[r.channel] = r;
      }
    }

    double powerOf(String ch) => latestByChannel[ch]?.powerW ?? 0.0;
    double currentOf(String ch) => latestByChannel[ch]?.currentA ?? 0.0;

    final gfLightsPower = powerOf(chGfLights);

    final gfSocketsPower = powerOf(chGfSockets);

    final ffLightsPower = powerOf(chFfLights);
    final ffSocketsPower = powerOf(chFfSockets);

    final gfLightsCurrent = currentOf(chGfLights);
    final gfSocketsCurrent = currentOf(chGfSockets);
    final ffLightsCurrent = currentOf(chFfLights);
    final ffSocketsCurrent = currentOf(chFfSockets);

    final totalLivePower =
        gfLightsPower + gfSocketsPower + ffLightsPower + ffSocketsPower;

    final groundFloorPower = gfLightsPower + gfSocketsPower;
    final firstFloorPower = ffLightsPower + ffSocketsPower;

    final lightingPower = gfLightsPower + ffLightsPower;
    final socketPower = gfSocketsPower + ffSocketsPower;

    final totalStatus = totalStatusFor(totalLivePower);

    final circuitPowers = <String, double>{
      chGfLights: gfLightsPower,
      chGfSockets: gfSocketsPower,
      chFfLights: ffLightsPower,
      chFfSockets: ffSocketsPower,
    };

    final overLimitChannels = <String>[];
    for (final entry in circuitPowers.entries) {
      if (entry.value > circuitLimitFor(entry.key)) {
        overLimitChannels.add(entry.key);
      }
    }

    int activeAlarms = overLimitChannels.length;
    if (totalLivePower >= totalPeakW) {
      activeAlarms += 1;
    }

    final sortedChannels = circuitPowers.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topChannel =
        sortedChannels.isNotEmpty ? sortedChannels.first.key : chGfSockets;
    final topChannelPower =
        sortedChannels.isNotEmpty ? sortedChannels.first.value : 0.0;
    final topChannelPct =
        totalLivePower <= 0 ? 0.0 : (topChannelPower / totalLivePower * 100.0);

    String alarmTitle;
    String alertDescription;
    String recommendation;
    List<String> recommendations;

    final hour = DateTime.now().hour;

    if (totalLivePower >= totalPeakW) {
      alarmTitle = 'Total demand critical';
      alertDescription =
          'Total household demand is critically high across monitored circuits.';

      recommendations = [
        'Reduce heavy appliances immediately',
        'Avoid oven, kettle, air fryer, boiler and washing machine together',
        'Switch off non-essential loads',
      ];
    } else if (totalLivePower >= totalWarningW) {
      alarmTitle = 'Total demand warning';
      alertDescription =
          'Total household demand is high and should be monitored.';

      recommendations = [
        'Avoid using several heavy appliances at the same time',
        'Check cooking appliances, boiler, washing machine and treadmill',
      ];
    } else if (socketPower > lightingPower * 1.5) {
      final profile = profileForCircuit(topChannel);
      final topLimit = circuitLimitFor(topChannel);
      final topRatio = topLimit <= 0 ? 0.0 : topChannelPower / topLimit;

      if (topRatio >= 0.8) {
        alarmTitle = 'High socket demand';
      } else {
        alarmTitle = 'Socket usage noticeable';
      }

      if (topChannel == chGfSockets) {
        if (hour >= 18 && hour <= 22) {
          alertDescription =
              'Ground-floor socket usage is noticeable during dinner time. Possible contributors include ${profile.eveningRisk.take(4).join(', ')}.';
        } else if (hour >= 22 || hour < 6) {
          alertDescription =
              'Ground-floor socket usage is noticeable at night. Check whether ${profile.nightRisk.take(4).join(', ')} are still running.';
        } else {
          alertDescription =
              'Ground-floor socket usage is currently the dominant socket load.';
        }
      } else if (topChannel == chFfSockets) {
        if (hour >= 22 || hour < 6) {
          alertDescription =
              'First-floor socket usage is noticeable at night. Possible contributors include ${profile.nightRisk.take(4).join(', ')}.';
        } else {
          alertDescription =
              'First-floor socket usage is currently the dominant socket load. Possible contributors include ${profile.highLoadRisk.take(4).join(', ')}.';
        }
      } else {
        alertDescription =
            'Socket circuits are consuming most of the live household power.';
      }

      if (topRatio >= 0.8) {
        recommendations = [
          'Check ${profile.highLoadRisk.take(4).join(', ')}',
          'Avoid running several heavy appliances together',
          'Switch off appliances immediately after use',
        ];
      } else {
        recommendations = [
          'No urgent action is required',
          'Check ${profile.appliances.take(4).join(', ')} only if this usage is unexpected',
          'Continue monitoring this circuit',
        ];
      }
    } else if (lightingPower > socketPower * 0.8) {
      alarmTitle = 'Lighting load noticeable';
      alertDescription =
          'Lighting circuits are using a noticeable share of the live household power.';

      recommendations = [
        'Check lights left ON in unused rooms',
        'Turn off kitchen, corridor, terrace or exterior lights if not needed',
      ];
    } else {
      alarmTitle = 'System normal';
      alertDescription =
          'All monitored circuits are within the defined operating limits.';

      recommendations = [
        'Continue monitoring household usage',
        'No immediate action is required',
      ];
    }

    recommendation = recommendations.join(' ');

    final now = DateTime.now();
    final daysElapsed = now.day.toDouble();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day.toDouble();

    final monthToDateKWh = data.monthTotalEnergyWh / 1000.0;

    final projectedMonthlyKWh = daysElapsed <= 0
        ? monthToDateKWh
        : (monthToDateKWh / daysElapsed) * daysInMonth;

    // Apply CEB Tariff 120 block calculation
    final energyCost = estimateCebMonthlyBill(projectedMonthlyKWh);

    // Apply minimum charge (Tariff 120)
    const minimumCharge = 184.0;

    final projectedMonthlyCostRs =
        energyCost < minimumCharge ? minimumCharge : energyCost;
    final dailyCostRs = projectedMonthlyCostRs / 30.0;

    final billDifferencePercent =
        ((projectedMonthlyCostRs - averageHistoricalBillRs) /
                averageHistoricalBillRs) *
            100;

    String billTitle;
    String billDescription;
    List<String> billRecommendations;

    final estimatedSavingRs = projectedMonthlyCostRs * 0.10;

    if (projectedMonthlyCostRs > 3000) {
      billTitle = 'Critical bill risk';
      billDescription =
          'Projected electricity cost is significantly higher than your usual monthly CEB bill range.';

      final targetDailyRs = 3000 / 30.0;

      billRecommendations = [
        'Switch off standby devices',
        'Avoid oven + kettle together',
        'Use boiler only when needed',
        'Run washing machine separately',
      ];

      final billTargets = [
        'Monthly target: below Rs 3000',
        'Daily target: below Rs 100/day',
        'Possible saving: Rs ${estimatedSavingRs.toStringAsFixed(0)}/month',
      ];
    } else if (projectedMonthlyCostRs > 2200) {
      billTitle = 'High bill trend';
      billDescription =
          'Projected electricity cost is higher than your normal usage pattern.';

      final targetDailyRs = 3000 / 30.0;

      billRecommendations = [
        'Evening cooking loads may increase your monthly bill.',
        'Avoid oven + kettle + air fryer together.',
        'Use boiler only when needed.',
        'Target daily usage: keep below Rs ${targetDailyRs.toStringAsFixed(0)} per day',
      ];
    } else {
      billTitle = 'Normal bill pattern';
      billDescription =
          'Projected electricity cost is within your normal monthly range.';

      final targetDailyRs = 3000 / 30.0;

      billRecommendations = [
        'Continue monitoring usage.',
        'No immediate action required.',
        'Try to stay below Rs ${targetDailyRs.toStringAsFixed(0)} per day',
      ];
    }

    final billStatus = billTitle;
    final billInsight = billDescription;
    final billTargets = [
      'Monthly target: below Rs 3000',
      'Daily target: below Rs 100/day',
      'Possible saving: Rs ${estimatedSavingRs.toStringAsFixed(0)}/month',
    ];

    return _DashboardMetrics(
      latestByChannel: latestByChannel,
      totalLivePower: totalLivePower,
      groundFloorPower: groundFloorPower,
      firstFloorPower: firstFloorPower,
      lightingPower: lightingPower,
      socketPower: socketPower,
      gfLightsPower: gfLightsPower,
      gfSocketsPower: gfSocketsPower,
      ffLightsPower: ffLightsPower,
      ffSocketsPower: ffSocketsPower,
      gfLightsCurrent: gfLightsCurrent,
      gfSocketsCurrent: gfSocketsCurrent,
      ffLightsCurrent: ffLightsCurrent,
      ffSocketsCurrent: ffSocketsCurrent,
      monthTotalEnergyWh: data.monthTotalEnergyWh,
      monthEstimatedCostRs: projectedMonthlyCostRs,
      todayTotalEnergyWh: data.lastHourEnergyWh.values.fold<double>(
        0.0,
        (sum, v) => sum + v,
      ),
      totalStatus: totalStatus,
      activeAlarms: activeAlarms,
      topChannel: topChannel,
      topChannelPower: topChannelPower,
      topChannelPct: topChannelPct,
      alarmTitle: alarmTitle,
      recommendation: recommendation,
      projectedMonthlyEnergyKWh: projectedMonthlyKWh,
      billStatus: billStatus,
      billInsight: billInsight,
      alertDescription: alertDescription,
      recommendations: recommendations,
      billTitle: billTitle,
      billDescription: billDescription,
      billRecommendations: billRecommendations,
      dailyCostRs: dailyCostRs,
      billTargets: billTargets,
      lastHourEnergyWh: data.lastHourEnergyWh,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cBg,
      child: FutureBuilder<_DashData>(
        future: _load(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Dashboard error:\n${snap.error}',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            );
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final metrics = buildMetrics(snap.data!);

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _FourCircuitCard(
                  metrics: metrics,
                  pretty: prettyChannelName,
                  iconFor: iconFor,
                  colorFor: colorFor,
                  limitFor: circuitLimitFor,
                  stateFor: circuitStateFor,
                ),
                const SizedBox(height: 10),
                _PowerDistributionCard(metrics: metrics),
                const SizedBox(height: 10),
                _EnergyOverviewCard(metrics: metrics),
                const SizedBox(height: 10),
                _AiNotificationCard(
                  metrics: metrics,
                  onTap: widget.onOpenAlerts,
                ),
                const SizedBox(height: 10),
                _BillInsightCard(metrics: metrics),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _prettyChannelName(String ch) {
  switch (ch) {
    case chGfSockets:
      return 'GF Sockets';
    case chGfLights:
      return 'GF Lights';
    case chFfSockets:
      return 'FF Sockets';
    case chFfLights:
      return 'FF Lights';
    default:
      return ch;
  }
}

class _DashData {
  final Map<String, double> lastHourEnergyWh;
  final Map<String, double> monthEnergyWhByChannel;
  final double monthTotalEnergyWh;
  final List<Reading> readings;

  _DashData({
    required this.lastHourEnergyWh,
    required this.monthEnergyWhByChannel,
    required this.monthTotalEnergyWh,
    required this.readings,
  });
}

class _DashboardMetrics {
  final Map<String, Reading> latestByChannel;
  final double projectedMonthlyEnergyKWh;

  final double totalLivePower;
  final double groundFloorPower;
  final double firstFloorPower;
  final double lightingPower;
  final double socketPower;

  final double gfLightsPower;
  final double gfSocketsPower;
  final double ffLightsPower;
  final double ffSocketsPower;

  final double gfLightsCurrent;
  final double gfSocketsCurrent;
  final double ffLightsCurrent;
  final double ffSocketsCurrent;

  final double monthTotalEnergyWh;
  final double monthEstimatedCostRs;
  final double todayTotalEnergyWh;

  final String totalStatus;
  final int activeAlarms;

  final String topChannel;
  final double topChannelPower;
  final double topChannelPct;

  final String alarmTitle;
  final String recommendation;

  final String alertDescription;
  final List<String> recommendations;

  final String billStatus;
  final String billInsight;

  final String billTitle;
  final String billDescription;
  final List<String> billRecommendations;
  final double dailyCostRs;
  final List<String> billTargets;

  final Map<String, double> lastHourEnergyWh;

  _DashboardMetrics({
    required this.latestByChannel,
    required this.totalLivePower,
    required this.groundFloorPower,
    required this.firstFloorPower,
    required this.lightingPower,
    required this.socketPower,
    required this.gfLightsPower,
    required this.gfSocketsPower,
    required this.ffLightsPower,
    required this.ffSocketsPower,
    required this.gfLightsCurrent,
    required this.gfSocketsCurrent,
    required this.ffLightsCurrent,
    required this.ffSocketsCurrent,
    required this.monthTotalEnergyWh,
    required this.monthEstimatedCostRs,
    required this.todayTotalEnergyWh,
    required this.totalStatus,
    required this.activeAlarms,
    required this.topChannel,
    required this.topChannelPower,
    required this.topChannelPct,
    required this.alarmTitle,
    required this.recommendation,
    required this.projectedMonthlyEnergyKWh,
    required this.billStatus,
    required this.billInsight,
    required this.alertDescription,
    required this.recommendations,
    required this.billTitle,
    required this.billDescription,
    required this.billRecommendations,
    required this.dailyCostRs,
    required this.billTargets,
    required this.lastHourEnergyWh,
  });
}

class _AiNotificationCard extends StatelessWidget {
  final _DashboardMetrics metrics;
  final VoidCallback? onTap;

  const _AiNotificationCard({
    required this.metrics,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final channelLimit = _limitFor(metrics.topChannel);

    final usageRatio =
        channelLimit > 0 ? (metrics.topChannelPower / channelLimit) : 0.0;

    Color color;
    Color recColor;
    List<Color> gradientColors;
    IconData alertIcon;

    if (usageRatio >= 1.0) {
      // 🔴 CRITICAL
      color = Colors.redAccent;
      recColor = Colors.redAccent;
      gradientColors = [
        const Color(0xFF2A0F0F),
        const Color(0xFF3A1414),
      ];
      alertIcon = Icons.error_rounded;
    } else if (usageRatio >= 0.8) {
      // 🟠 WARNING
      color = Colors.orangeAccent;
      recColor = Colors.orangeAccent;
      gradientColors = [
        const Color(0xFF2A1A0F),
        const Color(0xFF3A2414),
      ];
      alertIcon = Icons.warning_amber_rounded;
    } else if (usageRatio >= 0.5) {
      // 🟡 NOTICEABLE
      color = const Color(0xFFFFD54F);
      recColor = const Color(0xFFFFD54F);
      gradientColors = [
        const Color(0xFF2A2410),
        const Color(0xFF3A3114),
      ];
      alertIcon = Icons.insights_rounded;
    } else {
      // 🔵 INFO / NORMAL
      color = const Color(0xFF4FC3F7);
      recColor = const Color(0xFF4FC3F7);
      gradientColors = [
        const Color(0xFF0F1F2A),
        const Color(0xFF142B3A),
      ];
      alertIcon = Icons.info_outline_rounded;
    }
    final pct = (usageRatio * 100).clamp(0.0, 999.0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: color.withOpacity(0.6),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔥 TITLE
            Row(
              children: [
                Icon(
                  alertIcon,
                  color: color,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    metrics.alarmTitle.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // 📊 DETAILS
            Text(
              "${_prettyChannelName(metrics.topChannel)}: ${metrics.topChannelPower.toStringAsFixed(0)} W (${pct.toStringAsFixed(0)}% of limit)",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 12),

            // 🤖 RECOMMENDATION (VERY IMPORTANT)
            Text(
              metrics.alertDescription,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: recColor.withOpacity(0.10),
                border: Border.all(color: recColor.withOpacity(0.35)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recommended actions',
                    style: TextStyle(
                      color: recColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: metrics.recommendations.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: recColor, // keeps alert color (red/orange)
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _limitFor(String ch) {
    if (ch == chGfLights || ch == chFfLights) {
      return 300;
    }

    if (ch == chGfSockets || ch == chFfSockets) {
      return 1800;
    }

    return 1000;
  }
}

class _PowerDistributionCard extends StatefulWidget {
  final _DashboardMetrics metrics;

  const _PowerDistributionCard({required this.metrics});

  @override
  State<_PowerDistributionCard> createState() => _PowerDistributionCardState();
}

class _PowerDistributionCardState extends State<_PowerDistributionCard> {
  int touchedIndex = -1;

  static const Color gfLightsColor = Color(0xFFFFD54F);
  static const Color gfSocketsColor = Color(0xFF42A5F5);
  static const Color ffLightsColor = Color(0xFFEC407A);
  static const Color ffSocketsColor = Color(0xFF26C6DA);

  @override
  Widget build(BuildContext context) {
    final metrics = widget.metrics;

    final values = [
      _PieItem('GF Lights', metrics.gfLightsPower, gfLightsColor),
      _PieItem('GF Sockets', metrics.gfSocketsPower, gfSocketsColor),
      _PieItem('FF Lights', metrics.ffLightsPower, ffLightsColor),
      _PieItem('FF Sockets', metrics.ffSocketsPower, ffSocketsColor),
    ];

    final total = values.fold<double>(0.0, (sum, item) => sum + item.value);
    if (total <= 0) return const SizedBox();

    final dominant = values.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );

    final selected = touchedIndex >= 0 && touchedIndex < values.length
        ? values[touchedIndex]
        : dominant;

    final selectedPct = selected.value / total * 100;

    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Circuit Power Distribution',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Dominant circuit: ${dominant.label} (${(dominant.value / total * 100).toStringAsFixed(0)}%)',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 48,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.touchedSection == null) {
                        touchedIndex = -1;
                        return;
                      }
                      touchedIndex =
                          response.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                sections: List.generate(values.length, (index) {
                  final item = values[index];
                  final isTouched = index == touchedIndex;
                  final pct = item.value / total * 100;

                  return PieChartSectionData(
                    value: item.value,
                    color: item.color.withOpacity(isTouched ? 1.0 : 0.86),
                    title: pct < 8 ? '' : '${pct.toStringAsFixed(0)}%',
                    radius: isTouched ? 72 : 62,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  );
                }),
              ),
              swapAnimationDuration: const Duration(milliseconds: 700),
              swapAnimationCurve: Curves.easeOutCubic,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected.color.withOpacity(0.35),
              ),
            ),
            child: Text(
              '${selected.label}: ${selected.value.toStringAsFixed(0)} W '
              '(${selectedPct.toStringAsFixed(0)}% of total live power)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 10,
            children: values
                .map((item) => _legend(item.label, item.value, item.color))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, double value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label (${value.toStringAsFixed(0)} W)',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PieItem {
  final String label;
  final double value;
  final Color color;

  _PieItem(this.label, this.value, this.color);
}

class _BillInsightCard extends StatelessWidget {
  final _DashboardMetrics metrics;

  const _BillInsightCard({
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    Color bgColor;

    if (metrics.billStatus == 'Critical bill risk') {
      color = const Color(0xFF22C55E);
      bgColor = const Color(0xFF0F2A1A);
    } else if (metrics.billStatus == 'High bill trend') {
      color = const Color(0xFF22C55E);
      bgColor = const Color(0xFF0F2A1A);
    } else if (metrics.billStatus == 'Normal bill pattern') {
      color = const Color(0xFF22C55E);
      bgColor = const Color(0xFF0F2A1A);
    } else {
      color = const Color(0xFF22C55E);
      bgColor = const Color(0xFF0F2A1A);
    }

    const actionColor = Color(0xFFFACC15);
    const targetColor = Color(0xFF22C55E);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: color.withOpacity(0.50),
          width: 1.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.account_balance_wallet_rounded,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metrics.billStatus.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Projected Bill: Rs ${metrics.monthEstimatedCostRs.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Daily Cost: Rs ${metrics.dailyCostRs.toStringAsFixed(2)}/day',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  metrics.billDescription,
                  style: const TextStyle(
                    color: Colors.white70, // 👈 softer, less aggressive
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: actionColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: actionColor.withOpacity(0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recommended actions',
                        style: TextStyle(
                          color: actionColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: metrics.billRecommendations.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '• ',
                                  style: TextStyle(
                                    color: actionColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12.5,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: targetColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: targetColor.withOpacity(0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Target guidance',
                        style: TextStyle(
                          color: targetColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: metrics.billTargets.map((item) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: targetColor.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: targetColor.withOpacity(0.35),
                              ),
                            ),
                            child: Text(
                              item,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FourCircuitCard extends StatelessWidget {
  final _DashboardMetrics metrics;
  final String Function(String) pretty;
  final IconData Function(String) iconFor;
  final Color Function(String) colorFor;
  final double Function(String) limitFor;
  final String Function(String, double) stateFor;

  const _FourCircuitCard({
    required this.metrics,
    required this.pretty,
    required this.iconFor,
    required this.colorFor,
    required this.limitFor,
    required this.stateFor,
  });

  @override
  Widget build(BuildContext context) {
    final circuits = [
      _CircuitInfo(
        channel: chGfLights,
        power: metrics.gfLightsPower,
        current: metrics.gfLightsCurrent,
        energyWh: metrics.lastHourEnergyWh[chGfLights] ?? 0,
      ),
      _CircuitInfo(
        channel: chGfSockets,
        power: metrics.gfSocketsPower,
        current: metrics.gfSocketsCurrent,
        energyWh: metrics.lastHourEnergyWh[chGfSockets] ?? 0,
      ),
      _CircuitInfo(
        channel: chFfLights,
        power: metrics.ffLightsPower,
        current: metrics.ffLightsCurrent,
        energyWh: metrics.lastHourEnergyWh[chFfLights] ?? 0,
      ),
      _CircuitInfo(
        channel: chFfSockets,
        power: metrics.ffSocketsPower,
        current: metrics.ffSocketsCurrent,
        energyWh: metrics.lastHourEnergyWh[chFfSockets] ?? 0,
      ),
    ];
    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '4-Circuit Monitoring',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF3FA7E0), // cyan
              shadows: [
                Shadow(
                  color: Color(0xFF3FA7E0).withAlpha((255 * 0.3).toInt()),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.18,
            children: circuits.map((c) {
              final color = colorFor(c.channel);
              final limit = limitFor(c.channel);
              final state = stateFor(c.channel, c.power);

              return _circuitGridItem(
                title: pretty(c.channel),
                power: c.power,
                current: c.current,
                energyWh: c.energyWh,
                limit: limit,
                state: state,
                icon: iconFor(c.channel),
                color: color,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _circuitRow({
    required String title,
    required double power,
    required double current,
    required double limit,
    required String state,
    required IconData icon,
    required Color color,
  }) {
    Color chipColor;
    switch (state) {
      case 'Critical':
        chipColor = const Color(0xFFE53935);
        break;
      case 'Warning':
        chipColor = const Color(0xFFFFA000);
        break;
      default:
        chipColor = const Color(0xFF2E7D32);
    }

    final progress = (power / limit).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withAlpha((255 * 0.07).toInt()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha((255 * 0.16).toInt())),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withAlpha((255 * 0.15).toInt()),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: chipColor.withAlpha((255 * 0.12).toInt()),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  state,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: chipColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _inlineMetric('P', '${power.toStringAsFixed(0)} W'),
              _inlineMetric('I', '${current.toStringAsFixed(2)} A'),
              _inlineMetric('L', '${limit.toStringAsFixed(0)} W'),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: Colors.white,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _circuitGridItem({
    required String title,
    required double power,
    required double current,
    required double energyWh,
    required double limit,
    required String state,
    required IconData icon,
    required Color color,
  }) {
    final progress = (power / limit).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha((255 * 0.18).toInt()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: state == 'Critical'
              ? Colors.redAccent
              : state == 'Warning'
                  ? Colors.orangeAccent
                  : color.withAlpha((255 * 0.35).toInt()),
          width: state == 'Normal' ? 1 : 2,
        ),
        boxShadow: state == 'Normal'
            ? []
            : [
                BoxShadow(
                  color: (state == 'Critical'
                          ? Colors.redAccent
                          : Colors.orangeAccent)
                      .withAlpha((255 * 0.35).toInt()),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${power.toStringAsFixed(0)} W now',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Last hour: ${(energyWh / 1000).toStringAsFixed(2)} kWh',
            style: TextStyle(
              fontSize: 10.5,
              color: color.withOpacity(0.95),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Current: ${current.toStringAsFixed(2)} A',
            style: TextStyle(
              fontSize: 10.5,
              color: color.withOpacity(0.80),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Limit: ${limit.toStringAsFixed(0)} W',
            style: TextStyle(
              fontSize: 10.5,
              color: color.withOpacity(0.75),
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: Colors.white,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inlineMetric(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(color: Color(0xFF667085)),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }

  Widget _metricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF667085),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EnergyOverviewCard extends StatelessWidget {
  final _DashboardMetrics metrics;

  const _EnergyOverviewCard({
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Energy Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _overviewTile(
                  title: 'Power Now',
                  value: '${metrics.totalLivePower.toStringAsFixed(0)} W',
                  icon: Icons.bolt_rounded,
                  color: const Color(0xFF60A5FA),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _overviewTile(
                  title: 'Last Hour',
                  value: '${metrics.todayTotalEnergyWh.toStringAsFixed(1)} Wh',
                  icon: Icons.bar_chart_rounded,
                  color: const Color(0xFFF97316),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _overviewTile(
                  title: 'Projected Energy',
                  value:
                      '${metrics.projectedMonthlyEnergyKWh.toStringAsFixed(1)} kWh',
                  icon: Icons.electric_meter_rounded,
                  color: Color(0xFF22C55E),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _overviewTile(
                  title: 'Projected Bill',
                  value:
                      'Rs ${metrics.monthEstimatedCostRs.toStringAsFixed(0)}',
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFFFACC15),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overviewTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.18),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircuitInfo {
  final String channel;
  final double power;
  final double current;
  final double energyWh;

  _CircuitInfo({
    required this.channel,
    required this.power,
    required this.current,
    required this.energyWh,
  });
}

Widget _cardShell({
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.all(16),
}) {
  return Container(
    padding: padding,
    decoration: BoxDecoration(
      color: const Color(0xFF0E1320),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: Colors.white.withAlpha((255 * 0.08).toInt()),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha((255 * 0.6).toInt()),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: child,
  );
}

double estimateCebMonthlyBill(double monthlyKWh) {
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

  // Remaining units above last block
  if (remaining > 0) {
    energyCost += remaining * 8.77;
  }

  const meterRentalRs = 20.0;

  // 15% increase (May 2026)
  const increaseFactor = 1.15;

  final total = (energyCost + meterRentalRs) * increaseFactor;

  // Minimum charge protection
  return total < 184.0 ? 184.0 : total;
}
