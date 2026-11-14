import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/ledger.dart';

class LedgerRepository extends ChangeNotifier {
  LedgerRepository._();
  static final LedgerRepository instance = LedgerRepository._();

  static const _key = 'ledger_entries_v1';
  final List<LedgerEntry> _entries = [];
  final _uuid = const Uuid();
  bool _loaded = false;

  List<LedgerEntry> get entries {
    final list = [..._entries];
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// 해당 월의 입금/출금 합계.
  ({int income, int expense, int balance}) summary(DateTime month) {
    int income = 0, expense = 0;
    for (final e in _entries) {
      if (e.date.year != month.year || e.date.month != month.month) continue;
      if (e.type == LedgerType.income) {
        income += e.amount;
      } else {
        expense += e.amount;
      }
    }
    return (income: income, expense: expense, balance: income - expense);
  }

  /// 해당 월의 항목만.
  List<LedgerEntry> forMonth(DateTime month) {
    final list = _entries
        .where((e) => e.date.year == month.year && e.date.month == month.month)
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) =>
                LedgerEntry.fromJson(Map<String, dynamic>.from(e as Map)))
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

  Future<LedgerEntry> add({
    required DateTime date,
    required LedgerType type,
    required int amount,
    required String note,
  }) async {
    final entry = LedgerEntry(
      id: _uuid.v4(),
      date: date,
      type: type,
      amount: amount,
      note: note,
    );
    _entries.add(entry);
    await _save();
    notifyListeners();
    return entry;
  }

  Future<void> update(LedgerEntry entry) async {
    final i = _entries.indexWhere((e) => e.id == entry.id);
    if (i == -1) return;
    _entries[i] = entry;
    await _save();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _entries.removeWhere((e) => e.id == id);
    await _save();
    notifyListeners();
  }

  /// 로컬 데이터를 [newEntries] 로 완전히 교체합니다 (복원 전용).
  Future<void> replaceAll(List<LedgerEntry> newEntries) async {
    _entries
      ..clear()
      ..addAll(newEntries);
    await _save();
    notifyListeners();
  }
}
