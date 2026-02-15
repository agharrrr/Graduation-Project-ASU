import 'package:flutter/material.dart';
import '../../Auth/app_role.dart';

class ThemeController extends ChangeNotifier {
  AppRole _role = AppRole.user;

  // ✅ Make the app non-white by default
  ThemeMode _mode = ThemeMode.dark;

  AppRole get role => _role;
  ThemeMode get mode => _mode;

  bool get isDark => _mode == ThemeMode.dark;

  void setRole(AppRole role) {
    if (_role == role) return;
    _role = role;
    notifyListeners();
  }

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  void toggleMode() {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void resetToUser() {
    _role = AppRole.user;
    notifyListeners();
  }
}
