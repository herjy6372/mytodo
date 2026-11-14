import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 사용 가능한 앱 테마.
enum AppThemeChoice {
  system('system', '시스템'),
  cat('cat', '고양이 테마'),
  dog('dog', '강아지 테마'),
  giraffe('giraffe', '기린 테마'),
  coffee('coffee', '커피 테마');

  const AppThemeChoice(this.code, this.label);
  final String code;
  final String label;

  static AppThemeChoice fromCode(String? code) {
    for (final v in AppThemeChoice.values) {
      if (v.code == code) return v;
    }
    return AppThemeChoice.system;
  }

  /// 동물/특별 테마 여부 (system이 아닌 경우)
  bool get isCustomTheme => this != AppThemeChoice.system;
}

/// 시스템 테마의 라이트/다크 세부 모드.
enum SystemDisplayMode {
  auto('auto', '시스템 따름'),
  light('light', '라이트 고정'),
  dark('dark', '다크 고정');

  const SystemDisplayMode(this.code, this.label);
  final String code;
  final String label;

  static SystemDisplayMode fromCode(String? code) {
    for (final v in SystemDisplayMode.values) {
      if (v.code == code) return v;
    }
    return SystemDisplayMode.auto;
  }

  ThemeMode get themeMode {
    switch (this) {
      case SystemDisplayMode.light:
        return ThemeMode.light;
      case SystemDisplayMode.dark:
        return ThemeMode.dark;
      case SystemDisplayMode.auto:
        return ThemeMode.system;
    }
  }
}

/// 테마 선택을 영속화하는 저장소.
class ThemeRepository extends ChangeNotifier {
  ThemeRepository._();
  static final ThemeRepository instance = ThemeRepository._();

  static const _key = 'app_theme_v1';
  static const _displayModeKey = 'app_display_mode_v1';

  AppThemeChoice _choice = AppThemeChoice.system;
  SystemDisplayMode _displayMode = SystemDisplayMode.auto;
  bool _loaded = false;

  AppThemeChoice get choice => _choice;
  SystemDisplayMode get displayMode => _displayMode;

  /// 현재 설정에 따른 MaterialApp ThemeMode.
  ThemeMode get themeMode {
    // 고양이·강아지 테마는 항상 시스템 모드(system) 사용 — 자체 라이트/다크 존재
    if (_choice != AppThemeChoice.system) return ThemeMode.system;
    return _displayMode.themeMode;
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _choice = AppThemeChoice.fromCode(prefs.getString(_key));
    _displayMode = SystemDisplayMode.fromCode(prefs.getString(_displayModeKey));
    _loaded = true;
    notifyListeners();
  }

  Future<void> setChoice(AppThemeChoice c) async {
    if (_choice == c) return;
    _choice = c;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, c.code);
    notifyListeners();
  }

  Future<void> setDisplayMode(SystemDisplayMode mode) async {
    if (_displayMode == mode) return;
    _displayMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_displayModeKey, mode.code);
    notifyListeners();
  }
}
