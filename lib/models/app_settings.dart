import 'package:flutter/material.dart';

class AppSettings extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;

  // Thresholds (Watts)
  double socketsHighW = 1800;
  double lightsHighW = 250;
  double powerFactor = 1.0; // ADD THIS LINE

  // Phase 1 settings
  int updateIntervalSec = 5; // 5 / 10 / 30
  double voltageV = 230.0; // adjustable (Mauritius nominal)

  void setThemeMode(ThemeMode m) {
    themeMode = m;
    notifyListeners();
  }

  void setSocketsHigh(double v) {
    socketsHighW = v;
    notifyListeners();
  }

  void setLightsHigh(double v) {
    lightsHighW = v;
    notifyListeners();
  }

  void setUpdateInterval(int sec) {
    updateIntervalSec = sec;
    notifyListeners();
  }

  void setVoltage(double v) {
    voltageV = v;
    notifyListeners();
  }
}
