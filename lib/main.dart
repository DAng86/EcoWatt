import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'models/reading.dart';
import 'services/db_service.dart';
import 'package:provider/provider.dart';
import 'models/app_settings.dart';
import 'screens/dashboard_db.dart';
import 'services/simulator_service.dart';
import 'screens/history_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppSettings(),
      child: const EcoWattApp(),
    ),
  );
}

class EcoWattApp extends StatelessWidget {
  const EcoWattApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    SimulatorService.instance.start(settings);

    return MaterialApp(
      title: 'EcoWatt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: settings.themeMode,
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  Widget _buildPage() {
    if (_index == 0) {
      return DashboardDbPage(
        onOpenAlerts: () {
          setState(() {
            _index = 2;
          });
        },
      );
    }

    if (_index == 1) {
      return const HistoryPage();
    }

    return SettingsPage(
      key: ValueKey(DateTime.now().millisecondsSinceEpoch),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      backgroundColor: const Color(0xFF0E1320),
      appBar: AppBar(
        titleSpacing: 16,
        backgroundColor: const Color(0xFF0E1320),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF3D4EDA),
              ),
              child: const Icon(
                Icons.flash_on,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'EcoWatt',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF3FA7E0),
                shadows: [
                  Shadow(
                    color: const Color(0xFF3D4EDA).withOpacity(0.9),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _buildPage(),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF171C2C),
        indicatorColor: const Color(0xFF2A3F8F),
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() {
            _index = i;
          });
        },
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.speed_outlined),
            selectedIcon: Icon(Icons.speed),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.warning_amber_outlined),
            selectedIcon: Icon(Icons.warning_amber_rounded),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }
}

// --- Channel IDs ---
const String chGfSockets = 'GF_SOCKETS';
const String chGfLights = 'GF_LIGHTS';
const String chFfSockets = 'FF_SOCKETS';
const String chFfLights = 'FF_LIGHTS';

class LiveReading {
  final String channel;
  final DateTime ts;
  final double currentA;
  final double powerW;
  final String status; // OK / ALERT
  final String alertType; // NONE / HIGH / SPIKE / NIGHT / STANDBY / SUSTAINED

  const LiveReading({
    required this.channel,
    required this.ts,
    required this.currentA,
    required this.powerW,
    required this.status,
    required this.alertType,
  });
}

class ChannelConfig {
  double thresholdW;
  double spikeDeltaW;
  double nightThresholdW;

  // standby detection range (W)
  double standbyMinW;
  double standbyMaxW;

  // sustained high usage (samples)
  int sustainedSamples;

  ChannelConfig({
    required this.thresholdW,
    required this.spikeDeltaW,
    required this.nightThresholdW,
    required this.standbyMinW,
    required this.standbyMaxW,
    required this.sustainedSamples,
  });
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const int intervalSeconds = 5;
  static const double assumedVoltage = 230.0;

  IconData _channelIcon(String ch) {
    if (ch == chGfLights || ch == chFfLights) return Icons.lightbulb_rounded;
    return Icons.power_rounded;
  }

  List<Color> _channelGradient(String ch, bool isAlert) {
    if (isAlert) return [Colors.red.shade700, Colors.orange.shade500];

    switch (ch) {
      case chGfSockets:
        return [Colors.blue.shade700, Colors.cyan.shade400];
      case chGfLights:
        return [Colors.amber.shade700, Colors.orange.shade400];
      case chFfSockets:
        return [Colors.purple.shade700, Colors.pink.shade300];
      case chFfLights:
        return [Colors.green.shade700, Colors.teal.shade300];
      default:
        return [Colors.indigo.shade700, Colors.indigo.shade300];
    }
  }

  final _rng = Random();

  late final Map<String, ChannelConfig> _cfg;
  final Map<String, LiveReading> _latest = {};
  final Map<String, double> _prevPower = {};
  final Map<String, int> _sustainedCounter = {};

  final List<String> _alerts = []; // store last N alert messages
  Timer? _timer;

  DateTime? _lastTickTime;
  final Map<String, double> _energyWh = {}; // accumulated energy per channel

  @override
  void initState() {
    super.initState();

    _cfg = {
      chGfLights: ChannelConfig(
        thresholdW: 250,
        spikeDeltaW: 80,
        nightThresholdW: 60,
        standbyMinW: 0,
        standbyMaxW: 0,
        sustainedSamples: 36,
      ),
      chFfLights: ChannelConfig(
        thresholdW: 250,
        spikeDeltaW: 80,
        nightThresholdW: 60,
        standbyMinW: 0,
        standbyMaxW: 0,
        sustainedSamples: 36,
      ),
      chGfSockets: ChannelConfig(
        thresholdW: 1800,
        spikeDeltaW: 600,
        nightThresholdW: 250,
        standbyMinW: 5,
        standbyMaxW: 30,
        sustainedSamples: 36,
      ),
      chFfSockets: ChannelConfig(
        thresholdW: 1800,
        spikeDeltaW: 600,
        nightThresholdW: 250,
        standbyMinW: 5,
        standbyMaxW: 30,
        sustainedSamples: 36,
      ),
    };

    for (final ch in _cfg.keys) {
      _sustainedCounter[ch] = 0;
    }

    _tick();

    _timer = Timer.periodic(
      const Duration(seconds: intervalSeconds),
      (_) => _tick(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _addAlert(String msg) {
    _alerts.insert(0, msg);
    if (_alerts.length > 6) _alerts.removeLast();
  }

  bool _isNight(DateTime t) {
    final h = t.hour;
    return (h >= 23 || h < 5);
  }

  double _simulateCurrent(String ch) {
    final r = _rng.nextDouble();

    switch (ch) {
      case chGfSockets:
        return 0.4 + (r * 10.0);
      case chFfSockets:
        return 0.3 + (r * 8.0);
      case chGfLights:
        return 0.05 + (r * 1.0);
      case chFfLights:
        return 0.05 + (r * 0.8);
      default:
        return 0.2 + (r * 3.0);
    }
  }

  void _tick() {
    final settings = context.read<AppSettings>();
    final now = DateTime.now();

    final prevT = _lastTickTime ?? now;
    final dtSeconds = now.difference(prevT).inMilliseconds / 1000.0;
    _lastTickTime = now;

    final voltageV = (settings.voltageV > 0) ? settings.voltageV : 230.0;
    final pf = settings.powerFactor;

    for (final ch in _cfg.keys) {
      final cfg = _cfg[ch]!;
      final currentA = _simulateCurrent(ch);
      final powerW = voltageV * currentA * pf;

      final addWh = powerW * (dtSeconds / 3600.0);
      _energyWh[ch] = (_energyWh[ch] ?? 0.0) + addWh;

      final prev = _prevPower[ch] ?? powerW;
      _prevPower[ch] = powerW;

      String alertType = 'NONE';
      bool isAlert = false;

      final threshold = (ch == chGfLights || ch == chFfLights)
          ? settings.lightsHighW
          : settings.socketsHighW;

      if (powerW > threshold) {
        alertType = 'HIGH';
        isAlert = true;
      }

      final delta = (powerW - prev);
      if (delta > cfg.spikeDeltaW) {
        alertType = 'SPIKE';
        isAlert = true;
      }

      if (_isNight(now) && powerW > cfg.nightThresholdW) {
        alertType = 'NIGHT';
        isAlert = true;
      }

      if (cfg.standbyMinW > 0 &&
          powerW >= cfg.standbyMinW &&
          powerW <= cfg.standbyMaxW) {
        alertType = 'STANDBY';
        isAlert = true;
      }

      if (powerW > threshold) {
        _sustainedCounter[ch] = (_sustainedCounter[ch] ?? 0) + 1;
      } else {
        _sustainedCounter[ch] = 0;
      }

      if ((_sustainedCounter[ch] ?? 0) >= cfg.sustainedSamples) {
        alertType = 'SUSTAINED';
        isAlert = true;
      }

      final status = isAlert ? 'ALERT' : 'OK';

      final reading = LiveReading(
        channel: ch,
        ts: now,
        currentA: currentA,
        powerW: powerW,
        status: status,
        alertType: alertType,
      );

      _latest[ch] = reading;
      DBService.instance.insertReading(
        Reading(
          channel: reading.channel,
          ts: reading.ts,
          currentA: reading.currentA,
          powerW: reading.powerW,
          alertType: reading.alertType,
        ),
      );

      if (isAlert && alertType != 'NONE') {
        final pretty = _prettyChannel(ch);
        _addAlert(
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}  '
          '$pretty → $alertType (${powerW.toStringAsFixed(0)} W)',
        );
      }
    }

    setState(() {});
  }

  String _prettyChannel(String ch) {
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

  Color _statusColor(String status, BuildContext context) {
    if (status == 'ALERT') return Colors.red;
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _latest[chGfSockets],
      _latest[chGfLights],
      _latest[chFfSockets],
      _latest[chFfLights],
    ].whereType<LiveReading>().toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 380,
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.85,
              children: items.map((r) {
                final isAlert = r.status == 'ALERT';
                final settings = context.read<AppSettings>();

                final threshold =
                    (r.channel == chGfLights || r.channel == chFfLights)
                        ? settings.lightsHighW
                        : settings.socketsHighW;

                final energyKwh = (_energyWh[r.channel] ?? 0.0) / 1000.0;

                return _ChannelCard(
                  title: _prettyChannel(r.channel),
                  icon: _channelIcon(r.channel),
                  gradient: _channelGradient(r.channel, isAlert),
                  status: r.status,
                  alertType: r.alertType,
                  voltageV: settings.voltageV,
                  currentA: r.currentA,
                  powerW: r.powerW,
                  energyKwh: energyKwh,
                  thresholdW: threshold,
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Text('Recent Alerts', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _alerts.isEmpty
                ? const Text('No alerts yet (wait for simulated events).')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _alerts.map((a) => Text('• $a')).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final String status;
  final String alertType;
  final double voltageV;
  final double currentA;
  final double powerW;
  final double energyKwh;
  final double thresholdW;

  const _ChannelCard({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.status,
    required this.alertType,
    required this.voltageV,
    required this.currentA,
    required this.powerW,
    required this.energyKwh,
    required this.thresholdW,
  });

  @override
  Widget build(BuildContext context) {
    final isAlert = status == 'ALERT';
    final onColor = Colors.white;
    final usage = thresholdW <= 0 ? 0.0 : (powerW / thresholdW).clamp(0.0, 1.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: Card(
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
                          ),
                        ),
                        child: Icon(icon, color: onColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: onColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _statusChip(status, onColor),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${powerW.toStringAsFixed(0)} W',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: onColor,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: usage,
                      minHeight: 8,
                      backgroundColor: Colors.black.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isAlert
                            ? Colors.yellowAccent
                            : Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Threshold: ${thresholdW.toStringAsFixed(0)} W',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: onColor.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _pill('V', voltageV.toStringAsFixed(0), onColor),
                      _pill('A', currentA.toStringAsFixed(2), onColor),
                      _pill('kWh', energyKwh.toStringAsFixed(3), onColor),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Text(
                      'AIoT: $alertType${isAlert ? ' • check usage' : ''}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: onColor,
                            fontWeight: FontWeight.w700,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _statusChip(String text, Color onColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.30)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: onColor,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  static Widget _pill(String label, String value, Color onColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<List<Reading>> _future;

  @override
  void initState() {
    super.initState();
    _future = DBService.instance.latestReadings(limit: 300);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = DBService.instance.latestReadings(limit: 300);
    });
  }

  String _prettyChannel(String ch) {
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

  double _limitFor(String ch) {
    switch (ch) {
      case chGfLights:
        return 300;
      case chFfLights:
        return 200;
      case chGfSockets:
        return 1800;
      case chFfSockets:
        return 2500;
      default:
        return 1000;
    }
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'ALERT':
        return Colors.redAccent;
      case 'WARNING':
        return Colors.orangeAccent;
      default:
        return Colors.grey;
    }
  }

  IconData _levelIcon(String level) {
    return level == 'ALERT' ? Icons.error_rounded : Icons.warning_amber_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Reading>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final logs = snapshot.data!.where((r) {
          final limit = _limitFor(r.channel);
          final ratio = limit <= 0 ? 0.0 : r.powerW / limit;

          final isAlert = r.alertType != 'NONE' || ratio >= 1.0;
          final isWarning = ratio >= 0.8 && ratio < 1.0;

          return isAlert || isWarning;
        }).toList()
          ..sort((a, b) => b.ts.compareTo(a.ts));

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              const Text(
                'Warnings & Alerts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Warnings show circuits close to their limit. Alerts show exceeded limits or AIoT anomalies.',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              if (logs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171C2C),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'No warnings or alerts recorded yet.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ...logs.map((r) {
                final limit = _limitFor(r.channel);
                final ratio = limit <= 0 ? 0.0 : r.powerW / limit;
                final percent = (ratio * 100).clamp(0, 999).toStringAsFixed(0);

                final level = (r.alertType != 'NONE' || ratio >= 1.0)
                    ? 'ALERT'
                    : 'WARNING';

                final title = level == 'WARNING'
                    ? '${_prettyChannel(r.channel)} close to limit'
                    : '${_prettyChannel(r.channel)} limit/anomaly detected';

                final time =
                    '${r.ts.hour.toString().padLeft(2, '0')}:${r.ts.minute.toString().padLeft(2, '0')}';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171C2C),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _levelColor(level).withOpacity(0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _levelColor(level).withOpacity(0.18),
                        child: Icon(
                          _levelIcon(level),
                          color: _levelColor(level),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$time • ${r.powerW.toStringAsFixed(0)} W / ${limit.toStringAsFixed(0)} W • $percent% of limit',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            if (r.alertType != 'NONE')
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'AIoT type: ${r.alertType}',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        level,
                        style: TextStyle(
                          color: _levelColor(level),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
