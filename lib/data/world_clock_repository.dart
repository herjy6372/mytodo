import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 세계시각 도시 카탈로그(고정 목록).
class WorldCity {
  const WorldCity(this.label, this.tzId);
  final String label; // 사용자에게 보일 한글 이름
  final String tzId; // tz 데이터베이스 ID

  static const all = <WorldCity>[
    WorldCity('서울', 'Asia/Seoul'),
    WorldCity('도쿄', 'Asia/Tokyo'),
    WorldCity('베이징', 'Asia/Shanghai'),
    WorldCity('홍콩', 'Asia/Hong_Kong'),
    WorldCity('싱가포르', 'Asia/Singapore'),
    WorldCity('방콕', 'Asia/Bangkok'),
    WorldCity('자카르타', 'Asia/Jakarta'),
    WorldCity('뉴델리', 'Asia/Kolkata'),
    WorldCity('두바이', 'Asia/Dubai'),
    WorldCity('이스탄불', 'Europe/Istanbul'),
    WorldCity('모스크바', 'Europe/Moscow'),
    WorldCity('파리', 'Europe/Paris'),
    WorldCity('베를린', 'Europe/Berlin'),
    WorldCity('런던', 'Europe/London'),
    WorldCity('마드리드', 'Europe/Madrid'),
    WorldCity('로마', 'Europe/Rome'),
    WorldCity('뉴욕', 'America/New_York'),
    WorldCity('토론토', 'America/Toronto'),
    WorldCity('시카고', 'America/Chicago'),
    WorldCity('덴버', 'America/Denver'),
    WorldCity('로스앤젤레스', 'America/Los_Angeles'),
    WorldCity('밴쿠버', 'America/Vancouver'),
    WorldCity('호놀룰루', 'Pacific/Honolulu'),
    WorldCity('상파울루', 'America/Sao_Paulo'),
    WorldCity('멕시코시티', 'America/Mexico_City'),
    WorldCity('시드니', 'Australia/Sydney'),
    WorldCity('오클랜드', 'Pacific/Auckland'),
    WorldCity('카이로', 'Africa/Cairo'),
    WorldCity('요하네스버그', 'Africa/Johannesburg'),
  ];

  static WorldCity? byTz(String tzId) {
    for (final c in all) {
      if (c.tzId == tzId) return c;
    }
    return null;
  }
}

class WorldClockRepository extends ChangeNotifier {
  WorldClockRepository._();
  static final WorldClockRepository instance = WorldClockRepository._();

  static const _key = 'world_clock_cities_v1';
  static const _defaults = <String>[
    'Asia/Seoul',
    'America/Los_Angeles',
    'America/New_York',
    'Europe/London',
  ];

  final List<String> _selectedTz = [];
  bool _loaded = false;

  List<WorldCity> get selected => _selectedTz
      .map((id) => WorldCity.byTz(id))
      .whereType<WorldCity>()
      .toList();

  /// 백업 복원 후 저장된 도시 목록을 다시 읽습니다.
  Future<void> reload() async {
    _loaded = false;
    await load();
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key);
    _selectedTz
      ..clear()
      ..addAll(list ?? _defaults);
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _selectedTz);
  }

  Future<void> add(String tzId) async {
    if (_selectedTz.contains(tzId)) return;
    _selectedTz.add(tzId);
    await _save();
    notifyListeners();
  }

  Future<void> remove(String tzId) async {
    _selectedTz.remove(tzId);
    await _save();
    notifyListeners();
  }

  /// [newIndex] 는 `onReorderItem` 콜백 기준으로, oldIndex 위치의 항목이 이미
  /// 제거된 상태를 가정한 인덱스이므로 별도 보정이 필요 없다.
  Future<void> reorder(int oldIndex, int newIndex) async {
    final id = _selectedTz.removeAt(oldIndex);
    _selectedTz.insert(newIndex, id);
    await _save();
    notifyListeners();
  }
}
