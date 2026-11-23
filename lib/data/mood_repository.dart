import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/mood.dart';

class MoodRepository extends ChangeNotifier {
  MoodRepository._();
  static final MoodRepository instance = MoodRepository._();

  static const _key = 'mood_entries_v1';
  final List<MoodEntry> _entries = [];
  final _uuid = const Uuid();
  bool _loaded = false;

  List<MoodEntry> get entries {
    final list = [..._entries];
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// 백업 복원 후 저장된 데이터를 다시 읽습니다.
  Future<void> reload() async {
    _loaded = false;
    _entries.clear();
    await load();
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => MoodEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _entries
          ..clear()
          ..addAll(list);
      } catch (_) {/* skip */}
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(_entries.map((e) => e.toJson()).toList()));
  }

  Future<MoodEntry> add({
    required DateTime date,
    required MoodLevel level,
    required String note,
  }) async {
    final entry = MoodEntry(
        id: _uuid.v4(), date: date, level: level, note: note);
    _entries.add(entry);
    await _save();
    notifyListeners();
    return entry;
  }

  Future<void> update(MoodEntry entry) async {
    final i = _entries.indexWhere((e) => e.id == entry.id);
    if (i == -1) return;
    _entries[i] = entry;
    await _save();
    notifyListeners();
  }

  /// 삭제를 되돌립니다 (같은 id 로 다시 넣음).
  Future<void> restore(MoodEntry item) async {
    if (_entries.any((e) => e.id == item.id)) return;
    _entries.add(item);
    await _save();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _entries.removeWhere((e) => e.id == id);
    await _save();
    notifyListeners();
  }

  /// 로컬 데이터를 [newEntries] 로 완전히 교체합니다 (복원 전용).
  Future<void> replaceAll(List<MoodEntry> newEntries) async {
    _entries
      ..clear()
      ..addAll(newEntries);
    await _save();
    notifyListeners();
  }
}
