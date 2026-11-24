import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global, persistent, live accessibility & preference settings for Carevora.
/// Wired directly into MaterialApp (Text Size, Warm Eye-Comfort Tint, High Contrast)
/// and ElderInviteNotificationHost (Game Invite Popups).
class AppSettingsController extends ChangeNotifier {
  static const String _kTextScale = 'carevora_text_scale_v2';
  static const String _kDarkMode = 'carevora_dark_mode_v2';
  static const String _kWarmTint = 'carevora_warm_tint_v2';
  static const String _kHighContrast = 'carevora_high_contrast_v2';
  static const String _kGameInvitePopups = 'carevora_game_invite_popups_v2';
  static const String _kCgRiskAlerts = 'carevora_cg_risk_alerts_v2';
  static const String _kCgExportFormat = 'carevora_cg_export_format_v2';

  static bool gameInvitePopupsEnabledLive = true;

  double _textScaleFactor = 1.0; // 1.0 (Normal), 1.12 (Large), 1.22 (Extra Large)
  bool _isDarkMode = false;
  bool _eyeComfortWarmTint = false;
  bool _highContrastMode = false;
  bool _gameInvitePopupsEnabled = true;

  // Staff / Caregiver preferences
  bool _clinicalHighRiskAlerts = true;
  String _clinicalExportFormat = 'pdf'; // 'pdf' or 'csv'

  bool _loaded = false;

  double get textScaleFactor => _textScaleFactor;
  bool get isDarkMode => _isDarkMode;
  bool get eyeComfortWarmTint => _eyeComfortWarmTint;
  bool get highContrastMode => _highContrastMode;
  bool get gameInvitePopupsEnabled => _gameInvitePopupsEnabled;
  bool get clinicalHighRiskAlerts => _clinicalHighRiskAlerts;
  String get clinicalExportFormat => _clinicalExportFormat;
  bool get isLoaded => _loaded;

  AppSettingsController() {
    gameInvitePopupsEnabledLive = _gameInvitePopupsEnabled;
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _textScaleFactor =
          (prefs.getDouble(_kTextScale) ?? 1.0).clamp(0.95, 1.30);
      _isDarkMode = prefs.getBool(_kDarkMode) ?? false;
      _eyeComfortWarmTint = prefs.getBool(_kWarmTint) ?? false;
      _highContrastMode = prefs.getBool(_kHighContrast) ?? false;
      _gameInvitePopupsEnabled = prefs.getBool(_kGameInvitePopups) ?? true;
      _clinicalHighRiskAlerts = prefs.getBool(_kCgRiskAlerts) ?? true;
      _clinicalExportFormat = prefs.getString(_kCgExportFormat) ?? 'pdf';
      gameInvitePopupsEnabledLive = _gameInvitePopupsEnabled;
      _loaded = true;
      notifyListeners();
    } catch (_) {
      _loaded = true;
    }
  }

  Future<void> setTextScaleFactor(double scale) async {
    _textScaleFactor = scale.clamp(0.95, 1.30);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kTextScale, _textScaleFactor);
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDarkMode, value);
  }

  Future<void> setEyeComfortWarmTint(bool value) async {
    _eyeComfortWarmTint = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWarmTint, value);
  }

  Future<void> setHighContrastMode(bool value) async {
    _highContrastMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHighContrast, value);
  }

  Future<void> setGameInvitePopupsEnabled(bool value) async {
    _gameInvitePopupsEnabled = value;
    gameInvitePopupsEnabledLive = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kGameInvitePopups, value);
  }

  Future<void> setClinicalHighRiskAlerts(bool value) async {
    _clinicalHighRiskAlerts = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCgRiskAlerts, value);
  }

  Future<void> setClinicalExportFormat(String format) async {
    _clinicalExportFormat = format;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCgExportFormat, format);
  }

  Future<void> resetToRecommendedDefaults() async {
    _textScaleFactor = 1.0;
    _isDarkMode = false;
    _eyeComfortWarmTint = false;
    _highContrastMode = false;
    _gameInvitePopupsEnabled = true;
    _clinicalHighRiskAlerts = true;
    _clinicalExportFormat = 'pdf';
    gameInvitePopupsEnabledLive = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kTextScale, _textScaleFactor);
    await prefs.setBool(_kDarkMode, _isDarkMode);
    await prefs.setBool(_kWarmTint, _eyeComfortWarmTint);
    await prefs.setBool(_kHighContrast, _highContrastMode);
    await prefs.setBool(_kGameInvitePopups, _gameInvitePopupsEnabled);
    await prefs.setBool(_kCgRiskAlerts, _clinicalHighRiskAlerts);
    await prefs.setString(_kCgExportFormat, _clinicalExportFormat);
  }
}

final appSettingsProvider = ChangeNotifierProvider<AppSettingsController>(
  (ref) => AppSettingsController(),
);
