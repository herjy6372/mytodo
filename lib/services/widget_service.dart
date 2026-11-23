import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/auth_repository.dart';
import '../data/ledger_repository.dart';
import '../data/memo_repository.dart';
import '../data/mood_repository.dart';
import '../data/todo_repository.dart';
import '../data/world_clock_repository.dart';
import '../models/ledger.dart';
import '../models/memo.dart';
import '../models/mood.dart';
import '../models/todo.dart';
import 'notification_service.dart';

/// 홈 화면 위젯(Android·iOS)에 앱 데이터를 전달합니다.
///
/// iOS 는 App Group([appGroupId])으로 데이터를 공유하고, 위젯 버튼은
/// 위젯 쪽(App Intent)에서 처리한 뒤 대기열에 남겨 두면 앱이 열릴 때 반영합니다.
///
/// 날짜가 바뀌어도 앱을 열지 않고 위젯이 "오늘"을 스스로 계산할 수 있도록
/// 날짜별 원본 데이터를 넘기고, 오늘·이번 주·연간 집계는 Android 쪽에서 합니다.
class WidgetService {
  WidgetService._();

  static const _pkg = 'com.terablack.mytodo.widget';
  static const providers = <String>[
    '$_pkg.TodoWidgetProvider',
    '$_pkg.DailyDoneWidgetProvider',
    '$_pkg.YearlyWidgetProvider',
    '$_pkg.MoodWidgetProvider',
    '$_pkg.LedgerWidgetProvider',
    '$_pkg.MemoWidgetProvider',
    '$_pkg.TimerWidgetProvider',
    '$_pkg.WorldClockWidgetProvider',
    '$_pkg.WorldClockDualWidgetProvider',
  ];

  /// 날짜가 바뀌면 다시 그려야 하는 위젯.
  static const _dateSensitive = <String>[
    '$_pkg.TodoWidgetProvider',
    '$_pkg.DailyDoneWidgetProvider',
    '$_pkg.YearlyWidgetProvider',
    '$_pkg.MoodWidgetProvider',
    '$_pkg.LedgerWidgetProvider',
  ];

  /// iOS WidgetKit 위젯 종류(kind). ios/MyTodoWidgets 와 같아야 합니다.
  static const iosKinds = <String>[
    'TodoWidget',
    'DailyDoneWidget',
    'YearlyWidget',
    'MoodWidget',
    'LedgerWidget',
    'MemoWidget',
    'TimerWidget',
    'WorldClockWidget',
    'WorldClockDualWidget',
  ];
  static const appGroupId = 'group.com.example.mytodo';

  static const _timerProvider = '$_pkg.TimerWidgetProvider';
  static const _timerNotifId = 0x7A11E5;
  static const _timerEndKey = 'widget_timer_end_ms';
  static const _timerTotalKey = 'widget_timer_total_s';

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get _isIOS => !kIsWeb && Platform.isIOS;
  static bool get _supported => _isAndroid || _isIOS;

  static Timer? _debounce;

  /// main() 에서 저장소 로드 후 한 번 호출.
  static Future<void> init(GlobalKey<NavigatorState> navigatorKey,
      void Function(String screen) openScreen) async {
    if (!_supported) return;
    if (_isIOS) {
      await HomeWidget.setAppGroupId(appGroupId);
    } else {
      await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
    }

    void schedule() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), publishAll);
    }

    TodoRepository.instance.addListener(schedule);
    MoodRepository.instance.addListener(schedule);
    LedgerRepository.instance.addListener(schedule);
    MemoRepository.instance.addListener(schedule);
    WorldClockRepository.instance.addListener(schedule);
    AuthRepository.instance.addListener(schedule);

    // 위젯을 눌러 앱이 열린 경우 해당 화면으로 이동
    void handle(Uri? uri) {
      if (uri == null || uri.host != 'open') return;
      final screen = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
      if (screen.isNotEmpty) openScreen(screen);
    }

    HomeWidget.widgetClicked.listen(handle);
    final initial = await HomeWidget.initiallyLaunchedFromHomeWidget();
    WidgetsBinding.instance.addPostFrameCallback((_) => handle(initial));

    await publishAll();
  }

  /// 저장된 데이터를 읽어 모든 위젯 데이터를 갱신.
  static Future<void> publishAll() async {
    if (!_supported) return;
    try {
      if (_isIOS) await _applyIosPendingActions();
      // 위젯 타이머는 앱 없이 동작하므로 로그인 여부를 위젯에 알려 줌
      await _save('logged_in', AuthRepository.instance.isLoggedIn ? '1' : '0');
      final prefs = await SharedPreferences.getInstance();
      await _publishFromPrefs(prefs);
    } catch (e) {
      debugPrint('위젯 갱신 실패: $e');
    }
  }

  static Future<void> _publishFromPrefs(SharedPreferences prefs) async {
    final todos = _readList(prefs, 'todos_v1', Todo.fromJson);
    final moods = _readList(prefs, 'mood_entries_v1', MoodEntry.fromJson);
    final ledger = _readList(prefs, 'ledger_entries_v1', LedgerEntry.fromJson);
    final memos = _readList(prefs, 'memos_v1', Memo.fromJson);
    final cityTz = prefs.getStringList('world_clock_cities_v1') ??
        const ['Asia/Seoul', 'America/Los_Angeles'];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // ── 할 일: 어제~7일 뒤 항목 (위젯이 오늘 것만 골라 표시)
    final from = today.subtract(const Duration(days: 1));
    final to = today.add(const Duration(days: 8));
    final upcoming = todos
        .where((t) => !t.dueDate.isBefore(from) && t.dueDate.isBefore(to))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    await _save('todo_items', jsonEncode([
      for (final t in upcoming)
        {
          'id': t.id,
          'title': t.title,
          'due': t.dueDate.millisecondsSinceEpoch,
          'day': _dayKey(t.dueDate),
          'done': t.isDone,
          'color': t.category.color.toARGB32(),
        }
    ]));

    // ── 날짜별 완료 현황 [완료, 전체] (최근 약 1년)
    final stats = <String, List<int>>{};
    final statsFrom = today.subtract(const Duration(days: 380));
    for (final t in todos) {
      if (t.dueDate.isBefore(statsFrom)) continue;
      final k = _dayKey(t.dueDate);
      final s = stats.putIfAbsent(k, () => [0, 0]);
      s[1]++;
      if (t.isDone) s[0]++;
    }
    await _save('todo_stats', jsonEncode(stats));

    // ── 기분 한 줄: 가장 최근 기록
    final moodSorted = [...moods]..sort((a, b) => b.date.compareTo(a.date));
    final mood = moodSorted.isEmpty ? null : moodSorted.first;
    await _save('mood_day', mood == null ? '' : _dayKey(mood.date));
    await _save('mood_emoji', mood?.level.emoji ?? '');
    await _save('mood_label', mood?.level.label ?? '');
    await _save('mood_note', mood?.note ?? '');
    await _save('mood_color', mood?.level.color.toARGB32() ?? 0);

    // ── 가계부: 날짜별 [입금, 출금] (최근 약 2달)
    final ledgerDays = <String, List<int>>{};
    final ledgerFrom = DateTime(today.year, today.month - 1, 1);
    for (final e in ledger) {
      if (e.date.isBefore(ledgerFrom)) continue;
      final s = ledgerDays.putIfAbsent(_dayKey(e.date), () => [0, 0]);
      if (e.type == LedgerType.income) {
        s[0] += e.amount;
      } else {
        s[1] += e.amount;
      }
    }
    await _save('ledger_days', jsonEncode(ledgerDays));

    // ── 메모: 고정 우선, 최근 수정 순 첫 메모
    final memoSorted = [...memos]..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    final memo = memoSorted.isEmpty ? null : memoSorted.first;
    await _save('memo_title', memo?.displayTitle ?? '');
    await _save(
        'memo_body',
        memo == null
            ? ''
            : (memo.title.trim().isEmpty
                ? memo.content.trim().split('\n').skip(1).join('\n')
                : memo.content.trim()));
    await _save('memo_color', memo?.color.background.toARGB32() ?? 0);
    await _save('memo_count', memos.length);

    // ── 세계시각: 첫 번째 도시 = 메인, 두 번째 = 서브
    String nameOf(String id) => WorldCity.byTz(id)?.label ?? id;
    final mainTz = cityTz.isNotEmpty ? cityTz[0] : 'Asia/Seoul';
    final subTz = cityTz.length > 1 ? cityTz[1] : 'America/Los_Angeles';
    await _save('clock_main_tz', mainTz);
    await _save('clock_main_name', nameOf(mainTz));
    await _save('clock_sub_tz', subTz);
    await _save('clock_sub_name', nameOf(subTz));

    // ── 타이머 (iOS 는 위젯이 직접 관리하므로 덮어쓰지 않음)
    if (!_isIOS) {
      final end = prefs.getInt(_timerEndKey) ?? 0;
      await _save('timer_end_ms',
          end > DateTime.now().millisecondsSinceEpoch ? end : 0);
      await _save('timer_total_s', prefs.getInt(_timerTotalKey) ?? 0);
    }

    if (_isIOS) {
      for (final k in iosKinds) {
        await HomeWidget.updateWidget(iOSName: k);
      }
      return;
    }

    for (final p in providers) {
      await HomeWidget.updateWidget(qualifiedAndroidName: p);
    }

    // 자정마다 날짜 기준 위젯을 다시 그리도록 예약 (앞으로 7일)
    final midnights = [
      for (var i = 1; i <= 7; i++)
        DateTime(today.year, today.month, today.day + i, 0, 0, 5)
    ];
    for (final p in _dateSensitive) {
      try {
        await HomeWidget.scheduleWidgetUpdates(midnights,
            qualifiedAndroidName: p);
      } catch (_) {/* 위젯이 아직 추가되지 않은 경우 */}
    }
  }

  /// iOS 위젯에서 누른 할 일 체크를 실제 데이터(및 동기화)에 반영.
  static Future<void> _applyIosPendingActions() async {
    final raw = await HomeWidget.getWidgetData<String>('pending_toggles');
    if (raw == null || raw.isEmpty || raw == '[]') return;
    await HomeWidget.saveWidgetData<String>('pending_toggles', '[]');
    try {
      final ids = (jsonDecode(raw) as List).cast<String>();
      for (final id in ids) {
        if (TodoRepository.instance.todos.any((t) => t.id == id)) {
          await TodoRepository.instance.toggleDone(id);
        }
      }
    } catch (e) {
      debugPrint('위젯 체크 반영 실패: $e');
    }
  }

  // ── 위젯 버튼 처리 (앱이 꺼져 있어도 백그라운드에서 실행) ─────────────────

  static Future<void> handleBackground(Uri? uri) async {
    if (uri == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    if (uri.host == 'todo' && uri.path == '/toggle') {
      final id = uri.queryParameters['id'];
      final raw = prefs.getString('todos_v1');
      if (id != null && raw != null) {
        final list = (jsonDecode(raw) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        for (final t in list) {
          if (t['id'] == id) t['isDone'] = !(t['isDone'] as bool? ?? false);
        }
        await prefs.setString('todos_v1', jsonEncode(list));
      }
    } else if (uri.host == 'timer') {
      // 로그인해야 쓸 수 있음 (위젯 화면에서도 버튼을 막지만 한 번 더 확인)
      final loggedIn = await HomeWidget.getWidgetData<String>('logged_in');
      if (loggedIn != '1') return;
      await NotificationService.instance.init();
      final plugin = NotificationService.instance.plugin;
      await plugin.cancel(_timerNotifId);
      if (uri.path == '/start') {
        final min = int.tryParse(uri.queryParameters['min'] ?? '') ?? 5;
        final end = DateTime.now().add(Duration(minutes: min));
        await prefs.setInt(_timerEndKey, end.millisecondsSinceEpoch);
        await prefs.setInt(_timerTotalKey, min * 60);
        try {
          await plugin.zonedSchedule(
            _timerNotifId,
            '⏱️ 타이머 종료',
            '$min분 타이머가 끝났어요.',
            tz.TZDateTime.from(end, tz.local),
            NotificationService.alarmDetails(),
            androidScheduleMode: AndroidScheduleMode.alarmClock,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (e) {
          debugPrint('타이머 알림 예약 실패: $e');
        }
        // 끝나는 순간 위젯을 다시 그려 카운트다운을 멈춤
        try {
          await HomeWidget.scheduleWidgetUpdates(
              [end.add(const Duration(seconds: 1))],
              qualifiedAndroidName: _timerProvider);
        } catch (_) {}
      } else {
        await prefs.setInt(_timerEndKey, 0);
      }
    }
    await _publishFromPrefs(prefs);
  }

  // ── 유틸 ───────────────────────────────────────────────────────────

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static List<T> _readList<T>(SharedPreferences prefs, String key,
      T Function(Map<String, dynamic>) fromJson) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) {
            try {
              return fromJson(Map<String, dynamic>.from(e as Map));
            } catch (_) {
              return null;
            }
          })
          .whereType<T>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 숫자는 Android 쪽 Int/Long 형 혼동을 피하려고 문자열로 저장.
  static Future<void> _save(String key, Object value) =>
      HomeWidget.saveWidgetData<String>(
          key, value is num ? value.toString() : value as String);
}

/// home_widget 백그라운드 진입점. 최상위 함수여야 합니다.
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  await WidgetService.handleBackground(uri);
}
