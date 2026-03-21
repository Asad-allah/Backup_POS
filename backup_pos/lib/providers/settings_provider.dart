import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  double _exchangeRate = 90000.0;

  double get exchangeRate => _exchangeRate;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _exchangeRate = prefs.getDouble('exchange_rate') ?? 90000.0;
    notifyListeners();
  }

  Future<void> setExchangeRate(double rate) async {
    _exchangeRate = rate;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('exchange_rate', rate);
    notifyListeners();
  }

  double getLbp(double usd) {
    return usd * _exchangeRate;
  }

  String formatLbp(double usd) {
    final lbp = getLbp(usd);
    // Format clearly, e.g. 1,000,000
    // Using a simple regex or int conversion for cleaner looks
    return lbp
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}
