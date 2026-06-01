import 'dart:async';
import 'dart:math';

import '../models/app_settings.dart';
import '../models/reading.dart';
import 'db_service.dart';

// Channels (must match DB + dashboard)
const String chGfSockets = 'GF_SOCKETS';
const String chGfLights = 'GF_LIGHTS';
const String chFfSockets = 'FF_SOCKETS';
const String chFfLights = 'FF_LIGHTS';

class SimulatorService {
  SimulatorService._();
  static final SimulatorService instance = SimulatorService._();

  final _rng = Random();
  Timer? _timer;

  void start(AppSettings settings) {
    stop(); // avoid multiple timers

    // Run immediately + then repeat
    _tick(settings);
    _timer = Timer.periodic(
      Duration(seconds: settings.updateIntervalSec),
      (_) => _tick(settings),
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
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

  void _tick(AppSettings settings) {
    final now = DateTime.now();
    final voltageV = (settings.voltageV > 0) ? settings.voltageV : 230.0;
    final pf = settings.powerFactor;

    for (final ch in [chGfSockets, chGfLights, chFfSockets, chFfLights]) {
      final rawCurrentA = _simulateCurrent(ch);
      final rawPowerW = voltageV * rawCurrentA * pf;

      double scaledPowerW = rawPowerW;
      final currentA = scaledPowerW / (voltageV * pf);

      final limitForThisCircuit = (ch == chGfLights || ch == chFfLights)
          ? settings.lightsHighW
          : settings.socketsHighW;

      DBService.instance.insertReading(
        Reading(
          channel: ch,
          ts: now,
          currentA: currentA,
          powerW: scaledPowerW,
          alertType: scaledPowerW >= limitForThisCircuit
              ? 'HIGH'
              : scaledPowerW >= limitForThisCircuit * 0.8
                  ? 'WARNING'
                  : 'NONE',
        ),
      );
    }
  }
}
