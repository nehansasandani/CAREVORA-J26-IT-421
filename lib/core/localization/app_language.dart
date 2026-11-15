import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  english,
  sinhala,
}

class LanguageNotifier extends ChangeNotifier {
  static const String _prefKey = 'carevora_app_language';
  AppLanguage _currentLanguage = AppLanguage.english;

  LanguageNotifier() {
    _loadSavedLanguage();
  }

  AppLanguage get currentLanguage => _currentLanguage;
  bool get isSinhala => _currentLanguage == AppLanguage.sinhala;
  bool get isEnglish => _currentLanguage == AppLanguage.english;

  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefKey);
      if (savedCode == 'si') {
        _currentLanguage = AppLanguage.sinhala;
        notifyListeners();
      } else if (savedCode == 'en') {
        _currentLanguage = AppLanguage.english;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_currentLanguage == language) return;
    _currentLanguage = language;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, language == AppLanguage.sinhala ? 'si' : 'en');
    } catch (_) {}
  }

  void toggleLanguage() {
    setLanguage(_currentLanguage == AppLanguage.english ? AppLanguage.sinhala : AppLanguage.english);
  }
}

final languageProvider = ChangeNotifierProvider<LanguageNotifier>((ref) {
  return LanguageNotifier();
});
