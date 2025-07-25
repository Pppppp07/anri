// lib/providers/settings_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  static const REFRESH_INTERVAL_KEY = "refresh_interval";
  static const APP_LOCK_KEY = "app_lock_status";

  Duration _refreshInterval = const Duration(seconds: 15);
  String _refreshIntervalText = '15 detik';
  bool _isAppLockEnabled = false;

  Duration get refreshInterval => _refreshInterval;
  String get refreshIntervalText => _refreshIntervalText;
  bool get isAppLockEnabled => _isAppLockEnabled;

  SettingsProvider() {
    // --- [PERBAIKAN] Hapus pemanggilan loadSettings() dari sini. ---
    // Pemanggilan ini sudah ditangani dengan aman di SplashScreen.
    // loadSettings(); 
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final intervalSeconds = prefs.getInt(REFRESH_INTERVAL_KEY) ?? 15;
    _setDurationAndText(intervalSeconds);

    _isAppLockEnabled = prefs.getBool(APP_LOCK_KEY) ?? false;
    
    notifyListeners();
  }
  
  void _setDurationAndText(int seconds) {
    if (seconds == 0) {
      _refreshInterval = Duration.zero;
      _refreshIntervalText = 'Mati';
    } else {
      _refreshInterval = Duration(seconds: seconds);
      if (seconds >= 60) {
        _refreshIntervalText = '${seconds ~/ 60} menit';
      } else {
        _refreshIntervalText = '$seconds detik';
      }
    }
  }

  Future<void> setRefreshInterval(int seconds) async {
    _setDurationAndText(seconds);
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(REFRESH_INTERVAL_KEY, seconds);
  }

  Future<void> setAppLock(bool isEnabled) async {
    _isAppLockEnabled = isEnabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(APP_LOCK_KEY, isEnabled);
  }
}