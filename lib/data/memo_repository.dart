import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/memo.dart';

/// 메모 저장소. 기기(SharedPreferences)에 저장합니다.
class MemoRepository extends ChangeNotifier {
  MemoRepository._();
  static final MemoRepository instance = MemoRepository._();

  static const _key = 'memos_v1';
  final List<Memo> _memos = [];
  final _uuid = const Uuid();
  bool _loaded = false;

  /// 고정한 메모가 먼저, 그다음 최근 수정 순.
  List<Memo> get memos {
    final list = [..._memos];
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  /// 백업 복원 후 저장된 데이터를 다시 읽습니다.
  Future<void> reload() async {
    _loaded = false;
    _memos.clear();
    await load();
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => Memo.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _memos
          ..clear()
          ..addAll(list);
      } catch (_) {/* 손상된 데이터는 건너뜀 */}
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(_memos.map((m) => m.toJson()).toList()));
  }

  Future<Memo> add({
    required String title,
    required String content,
    MemoColor color = MemoColor.white,
    bool pinned = false,
  }) async {
    final now = DateTime.now();
    final memo = Memo(
      id: _uuid.v4(),
      title: title,
      content: content,
      color: color,
      pinned: pinned,
      createdAt: now,
      updatedAt: now,
    );
    _memos.add(memo);
    await _save();
    notifyListeners();
    return memo;
  }

  Future<void> update(Memo memo) async {
    final i = _memos.indexWhere((m) => m.id == memo.id);
    if (i == -1) return;
    memo.updatedAt = DateTime.now();
    _memos[i] = memo;
    await _save();
    notifyListeners();
  }

  Future<void> togglePinned(String id) async {
    final i = _memos.indexWhere((m) => m.id == id);
    if (i == -1) return;
    _memos[i].pinned = !_memos[i].pinned;
    await _save();
    notifyListeners();
  }

  /// 삭제를 되돌립니다 (같은 id 로 다시 넣음).
  Future<void> restore(Memo item) async {
    if (_memos.any((e) => e.id == item.id)) return;
    _memos.add(item);
    await _save();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _memos.removeWhere((m) => m.id == id);
    await _save();
    notifyListeners();
  }
}
