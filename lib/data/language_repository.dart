import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 지원 언어.
enum AppLanguage {
  korean(
    code: 'ko',
    label: '한국어',
    locale: Locale('ko', 'KR'),
    flag: '🇰🇷',
    description: '한국어로 표시합니다.',
    calendarLocale: 'ko_KR',
  ),
  english(
    code: 'en',
    label: 'English',
    locale: Locale('en', 'US'),
    flag: '🇺🇸',
    description: 'Display in English.',
    calendarLocale: 'en_US',
  ),
  japanese(
    code: 'ja',
    label: '日本語',
    locale: Locale('ja', 'JP'),
    flag: '🇯🇵',
    description: '日本語で表示します。',
    calendarLocale: 'ja_JP',
  ),
  filipino(
    code: 'fil',
    label: 'Filipino',
    locale: Locale('fil', 'PH'),
    flag: '🇵🇭',
    description: 'Ipakita sa Filipino.',
    // intl 패키지가 fil_PH를 미지원 → en_US 포맷 사용
    calendarLocale: 'en_US',
  ),
  vietnamese(
    code: 'vi',
    label: 'Tiếng Việt',
    locale: Locale('vi', 'VN'),
    flag: '🇻🇳',
    description: 'Hiển thị bằng Tiếng Việt.',
    calendarLocale: 'vi_VN',
  );

  const AppLanguage({
    required this.code,
    required this.label,
    required this.locale,
    required this.flag,
    required this.description,
    required this.calendarLocale,
  });

  final String code;
  final String label;
  final Locale locale;
  /// 언어 설정 화면에 표시할 국기 이모지.
  final String flag;
  /// 언어 설정 화면 부제목 (해당 언어로 표기).
  final String description;
  /// table_calendar / intl 에 넘길 로케일 문자열.
  final String calendarLocale;

  static AppLanguage fromCode(String? code) {
    for (final v in AppLanguage.values) {
      if (v.code == code) return v;
    }
    return AppLanguage.korean;
  }
}

/// 언어 선택을 영속화하는 저장소.
class LanguageRepository extends ChangeNotifier {
  LanguageRepository._();
  static final LanguageRepository instance = LanguageRepository._();

  static const _key = 'app_language_v1';
  AppLanguage _language = AppLanguage.korean;
  bool _loaded = false;

  AppLanguage get language => _language;
  Locale get locale => _language.locale;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _language = AppLanguage.fromCode(prefs.getString(_key));
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage lang) async {
    if (_language == lang) return;
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, lang.code);
    notifyListeners();
  }
}
