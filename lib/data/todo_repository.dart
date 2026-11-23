import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/todo.dart';
import '../services/notification_service.dart';

/// 인메모리 + SharedPreferences 기반의 간단한 할 일 저장소.
/// ChangeNotifier 를 통해 화면이 자동으로 갱신됩니다.
class TodoRepository extends ChangeNotifier {
  TodoRepository._();
  static final TodoRepository instance = TodoRepository._();

  static const _storageKey = 'todos_v1';
  final List<Todo> _todos = [];
  final _uuid = const Uuid();
  bool _loaded = false;

  List<Todo> get todos => List.unmodifiable(_todos);

  /// 백업 복원 후 다시 읽습니다. 기존 할 일 알림을 지운 뒤 새로 예약합니다.
  Future<void> reloadFromBackup() async {
    for (final t in _todos) {
      await NotificationService.instance.cancelTodo(t.id);
    }
    _todos.clear();
    await reload();
  }

  /// 홈 화면 위젯 등 앱 밖에서 바뀐 저장 데이터를 다시 읽어옵니다.
  Future<void> reload() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    _loaded = false;
    await load();
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => Todo.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _todos
          ..clear()
          ..addAll(list);
      } catch (_) {
        // 손상된 데이터는 무시.
      }
    }
    _loaded = true;
    notifyListeners();

    // 앱 시작 후 미완료 항목들의 알림을 다시 예약.
    for (final t in _todos) {
      if (!t.isDone) {
        // ignore: discarded_futures
        NotificationService.instance.scheduleTodo(t);
      }
    }
  }

  /// 동기화 결과를 한 번에 반영. 기존 할 일 알림만 취소 후 재예약(일일 비서 알림 보존).
  Future<void> replaceAll(List<Todo> todos) async {
    for (final old in _todos) {
      await NotificationService.instance.cancelTodo(old.id);
    }
    _todos
      ..clear()
      ..addAll(todos);
    await _save();
    notifyListeners();
    for (final t in _todos) {
      if (!t.isDone) {
        await NotificationService.instance.scheduleTodo(t);
      }
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_todos.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }

  Future<Todo> add({
    required String title,
    required String place,
    required DateTime dueDate,
    required TodoCategory category,
    String memo = '',
    bool alarm = false,
  }) async {
    final todo = Todo(
      id: _uuid.v4(),
      title: title,
      place: place,
      dueDate: dueDate,
      category: category,
      memo: memo,
      alarm: alarm,
    );
    _todos.add(todo);
    await _save();
    notifyListeners();
    await NotificationService.instance.scheduleTodo(todo);
    return todo;
  }

  Future<void> update(Todo updated) async {
    final idx = _todos.indexWhere((t) => t.id == updated.id);
    if (idx == -1) return;
    _todos[idx] = updated;
    await _save();
    notifyListeners();
    await NotificationService.instance.scheduleTodo(updated);
  }

  Future<void> remove(String id) async {
    _todos.removeWhere((t) => t.id == id);
    await _save();
    notifyListeners();
    await NotificationService.instance.cancelTodo(id);
  }

  /// 삭제를 되돌립니다 (같은 id 로 다시 넣고 알림도 다시 예약).
  Future<void> restore(Todo todo) async {
    if (_todos.any((t) => t.id == todo.id)) return;
    _todos.add(todo);
    await _save();
    notifyListeners();
    if (!todo.isDone) await NotificationService.instance.scheduleTodo(todo);
  }

  Future<void> toggleDone(String id) async {
    final idx = _todos.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    _todos[idx] = _todos[idx].copyWith(isDone: !_todos[idx].isDone);
    await _save();
    notifyListeners();
    if (_todos[idx].isDone) {
      await NotificationService.instance.cancelTodo(id);
    } else {
      await NotificationService.instance.scheduleTodo(_todos[idx]);
    }
  }

  /// 카테고리별 그룹.
  Map<TodoCategory, List<Todo>> groupByCategory() {
    final map = <TodoCategory, List<Todo>>{
      for (final c in TodoCategory.values) c: <Todo>[],
    };
    for (final t in _todos) {
      map[t.category]!.add(t);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    }
    return map;
  }

  /// 특정 날짜의 할 일.
  List<Todo> forDate(DateTime date) {
    return _todos.where((t) {
      return t.dueDate.year == date.year &&
          t.dueDate.month == date.month &&
          t.dueDate.day == date.day;
    }).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  /// 일요일 시작 주간(어떤 일자든 [any] 가 포함된 일~토요일).
  static DateTime startOfWeekSunday(DateTime any) {
    final base = DateTime(any.year, any.month, any.day);
    // DateTime.weekday: Mon=1 ... Sun=7. 일요일 시작 기준 오프셋 = weekday % 7
    return base.subtract(Duration(days: any.weekday % 7));
  }

  /// 일요일~토요일 주간 할 일 (정렬됨).
  List<Todo> forWeekSunday(DateTime any) {
    final start = startOfWeekSunday(any);
    final end = start.add(const Duration(days: 7));
    return _todos
        .where((t) =>
            !t.dueDate.isBefore(start) && t.dueDate.isBefore(end))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  /// 해당 월의 할 일 (정렬됨).
  List<Todo> forMonth(DateTime any) {
    return _todos
        .where((t) =>
            t.dueDate.year == any.year && t.dueDate.month == any.month)
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }
}
