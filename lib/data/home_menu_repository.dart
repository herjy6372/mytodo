import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 홈 화면 기능 메뉴.
enum HomeMenu {
  todos('todos'),
  calendar('calendar'),
  graph('graph'),
  mood('mood'),
  ledger('ledger'),
  timer('timer'),
  worldClock('world_clock'),
  memo('memo'),
  support('support');

  const HomeMenu(this.code);
  final String code;

  static HomeMenu? fromCode(String code) {
    for (final m in HomeMenu.values) {
      if (m.code == code) return m;
    }
    return null;
  }
}

/// 홈 화면 메뉴의 순서와 표시 여부를 저장합니다.
class HomeMenuRepository extends ChangeNotifier {
  HomeMenuRepository._();
  static final HomeMenuRepository instance = HomeMenuRepository._();

  static const key = 'home_menu_v1';

  final List<HomeMenu> _order = [...HomeMenu.values];
  final Set<HomeMenu> _hidden = {};

  /// 전체 메뉴 (사용자가 정한 순서).
  List<HomeMenu> get order => List.unmodifiable(_order);

  /// 홈 화면에 보이는 메뉴 (순서대로).
  List<HomeMenu> get visible =>
      _order.where((m) => !_hidden.contains(m)).toList();

  bool isHidden(HomeMenu m) => _hidden.contains(m);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    _order
      ..clear()
      ..addAll(HomeMenu.values);
    _hidden.clear();
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final saved = ((map['order'] as List?) ?? const [])
            .map((e) => HomeMenu.fromCode(e as String))
            .whereType<HomeMenu>()
            .toList();
        // 저장된 순서 + 나중에 추가된 메뉴는 뒤에 붙임
        _order
          ..clear()
          ..addAll(saved)
          ..addAll(HomeMenu.values.where((m) => !saved.contains(m)));
        _hidden.addAll(((map['hidden'] as List?) ?? const [])
            .map((e) => HomeMenu.fromCode(e as String))
            .whereType<HomeMenu>());
      } catch (_) {/* 손상된 설정은 기본값 사용 */}
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        key,
        jsonEncode({
          'order': _order.map((m) => m.code).toList(),
          'hidden': _hidden.map((m) => m.code).toList(),
        }));
    notifyListeners();
  }

  Future<void> setHidden(HomeMenu m, bool hidden) async {
    hidden ? _hidden.add(m) : _hidden.remove(m);
    await _save();
  }

  /// [newIndex] 는 [oldIndex] 항목을 뺀 뒤의 위치입니다 (onReorderItem 기준).
  Future<void> move(int oldIndex, int newIndex) async {
    final m = _order.removeAt(oldIndex);
    _order.insert(newIndex, m);
    await _save();
  }

  Future<void> reset() async {
    _order
      ..clear()
      ..addAll(HomeMenu.values);
    _hidden.clear();
    await _save();
  }
}
