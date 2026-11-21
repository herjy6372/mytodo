import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/ledger_repository.dart';
import '../data/mood_repository.dart';
import '../data/todo_repository.dart';
import '../models/ledger.dart';
import '../models/mood.dart';

/// 하루 알림 시간대. 각 슬롯은 사용자가 개별적으로 켜고 끌 수 있습니다.
enum DailyNotifSlot {
  morning(id: 9001, hour: 9, prefKey: 'daily_notif_slot_morning'),
  lunch(id: 9002, hour: 12, prefKey: 'daily_notif_slot_lunch'),
  evening(id: 9003, hour: 18, prefKey: 'daily_notif_slot_evening'),
  bedtime(id: 9004, hour: 21, prefKey: 'daily_notif_slot_bedtime'),
  weeklySummary(id: 9005, hour: 10, prefKey: 'daily_notif_slot_weekly');

  const DailyNotifSlot({
    required this.id,
    required this.hour,
    required this.prefKey,
  });

  /// 알림 ID (할 일 알림 9000 미만과 겹치지 않도록 큰 값 사용)
  final int id;

  /// 예약 시각(시). [weeklySummary] 는 매주 일요일 이 시각에 발송됩니다.
  final int hour;

  /// 개별 on/off 상태를 저장하는 SharedPreferences 키.
  final String prefKey;
}

/// 하루 4회(아침·점심·저녁·잠자리) + 매주 일요일 10시(주간 요약) 알림 서비스.
///
/// 동작 방식:
/// 1. 매일 9시·12시·18시·21시에 OS 예약 알림이 발송됩니다.
/// 2. 매주 일요일 10시에 지난 주(일~토) 요약 알림이 발송됩니다.
/// 3. [onNotificationTap] 콜백을 설정하면 알림 탭 시 화면 이동 등을 처리할 수 있습니다.
/// 4. 전체 알림은 [isEnabled]/[setEnabled] 로, 시간대별 알림은
///    [isSlotEnabled]/[setSlotEnabled] 로 개별 제어할 수 있습니다.
class DailyNotificationService extends ChangeNotifier {
  DailyNotificationService._();
  static final DailyNotificationService instance = DailyNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _enabled = true;

  // 시간대별 개별 on/off. 기본값은 전체 켜짐(기존 사용자와의 하위 호환).
  final Map<DailyNotifSlot, bool> _slotEnabled = {
    for (final slot in DailyNotifSlot.values) slot: true,
  };

  static const String _channelId       = 'daily_reminder';
  static const String _channelName     = '일일 비서 알림';
  static const String _weeklyChannelId   = 'weekly_summary';
  static const String _weeklyChannelName = '주간 요약 알림';

  static const String _prefEnabled = 'daily_notif_enabled';

  /// 알림 탭 핸들러. 'weekly_summary' 페이로드를 받으면 주간 요약 화면으로 이동하도록
  /// main.dart 에서 설정한다.
  static void Function(String payload)? onNotificationTap;

  bool get isEnabled => _enabled;

  /// 특정 시간대 알림의 개별 활성화 여부.
  bool isSlotEnabled(DailyNotifSlot slot) => _slotEnabled[slot] ?? true;

  // ── 초기화 ────────────────────────────────────────────────────────────────

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefEnabled) ?? true;
    for (final slot in DailyNotifSlot.values) {
      _slotEnabled[slot] = prefs.getBool(slot.prefKey) ?? true;
    }
    await _ensureInit();
  }

  Future<void> _ensureInit() async {
    if (_initialized) return;
    try {
      tzdata.initializeTimeZones();
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz.identifier));
    } catch (e) {
      debugPrint('DailyNotification: 타임존 초기화 실패 $e');
    }
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && onNotificationTap != null) {
          onNotificationTap!(payload);
        }
      },
    );
    _initialized = true;
  }

  // ── 권한 요청 ─────────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    await _ensureInit();
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(
            alert: true, badge: true, sound: true,
          ) ??
          false;
    }
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted =
          await android?.requestNotificationsPermission() ?? false;
      await android?.requestExactAlarmsPermission();
      return granted;
    }
    return false;
  }

  // ── 활성화/비활성화 토글 ──────────────────────────────────────────────────

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, value);
    notifyListeners();
    if (value) {
      await scheduleDailyNotifications();
    } else {
      await _cancelAll();
    }
  }

  /// 특정 시간대 알림만 개별로 켜거나 끈다. 전체 알림([isEnabled])이 켜져 있을 때만
  /// 실제 예약이 반영되며, 꺼져 있는 동안의 선택은 저장만 해 두었다가 다음에
  /// 전체 알림을 켤 때 그대로 적용된다.
  Future<void> setSlotEnabled(DailyNotifSlot slot, bool value) async {
    if (_slotEnabled[slot] == value) return;
    _slotEnabled[slot] = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(slot.prefKey, value);
    notifyListeners();
    if (_enabled) {
      await scheduleDailyNotifications();
    }
  }

  // ── 정기 예약 알림 (매일 반복) ────────────────────────────────────────────

  Future<void> scheduleDailyNotifications() async {
    await _ensureInit();
    await _cancelAll();
    if (!_enabled) return;
    final todos = TodoRepository.instance.todos;
    final now = DateTime.now();

    if (isSlotEnabled(DailyNotifSlot.morning)) {
      await _scheduleMorning(now, todos);
    }
    if (isSlotEnabled(DailyNotifSlot.lunch)) {
      await _scheduleLunch(now, todos);
    }
    if (isSlotEnabled(DailyNotifSlot.evening)) {
      await _scheduleEvening(now, todos);
    }
    if (isSlotEnabled(DailyNotifSlot.bedtime)) {
      await _scheduleBedtime(now);
    }
    if (isSlotEnabled(DailyNotifSlot.weeklySummary)) {
      await _scheduleWeeklySummary(now);
    }
  }

  // ── 정기 예약 내부 메서드 ─────────────────────────────────────────────────

  Future<void> _scheduleMorning(DateTime now, List todos) async {
    final todayTodos = _todayTodos(todos, now);
    final String body;
    if (todayTodos.isEmpty) {
      body = '잘 주무셨나요? 오늘은 예정된 할 일이 없어요. 여유로운 하루 되세요! 😊';
    } else {
      final first = todayTodos.first.title as String;
      final extra = todayTodos.length > 1 ? ' 외 ${todayTodos.length - 1}개' : '';
      body = '잘 주무셨나요? 오늘 할 일: $first$extra이 있어요. 파이팅! 💪';
    }
    await _scheduleAt(
        id: DailyNotifSlot.morning.id,
        title: '🌅 좋은 아침이에요!',
        body: body,
        hour: DailyNotifSlot.morning.hour,
        now: now);
  }

  Future<void> _scheduleLunch(DateTime now, List todos) async {
    final todayTodos = _todayTodos(todos, now);
    final remaining = todayTodos.where((t) => !(t.isDone as bool)).toList();
    final String body;
    if (remaining.isEmpty) {
      body = '많이 배고프시죠? 오늘 할 일을 모두 완료하셨네요! 👏 가계부 쓰는 것도 잊지 마세요!';
    } else {
      body =
          '많이 배고프시죠? 아직 할 일이 ${remaining.length}개 남아 있어요. 가계부 쓰는 것도 잊지 않으셨죠? 오늘도 파이팅! 💪';
    }
    await _scheduleAt(
        id: DailyNotifSlot.lunch.id,
        title: '🍱 점심 시간이에요!',
        body: body,
        hour: DailyNotifSlot.lunch.hour,
        now: now);
  }

  Future<void> _scheduleEvening(DateTime now, List todos) async {
    final todayTodos = _todayTodos(todos, now);
    final remaining = todayTodos.where((t) => !(t.isDone as bool)).toList();
    final String body;
    if (remaining.isEmpty) {
      body =
          '수고하셨어요! 오늘 할 일을 모두 마쳤어요. 가계부도 잊지 말고 오늘치 작성해 주세요! 📒';
    } else {
      body =
          '수고하셨어요! 아직 ${remaining.length}개의 할 일이 남아 있어요. 가계부 작성도 잊지 마세요! 📒';
    }
    await _scheduleAt(
        id: DailyNotifSlot.evening.id,
        title: '🌆 저녁이 되었어요!',
        body: body,
        hour: DailyNotifSlot.evening.hour,
        now: now);
  }

  Future<void> _scheduleBedtime(DateTime now) async {
    await _scheduleAt(
      id: DailyNotifSlot.bedtime.id,
      title: '🌙 오늘 하루도 수고하셨어요!',
      body: '오늘 하루 어떠셨나요? 기분 한 줄을 기록하고 하루를 마무리해 보세요. ✍️ 잘 자요!',
      hour: DailyNotifSlot.bedtime.hour,
      now: now,
    );
  }

  // ── 주간 요약 예약 (매주 일요일 10:00) ───────────────────────────────────

  Future<void> _scheduleWeeklySummary(DateTime now) async {
    final body = _buildWeeklySummaryBody(now);

    // 다음 일요일 10:00 찾기
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day,
        DailyNotifSlot.weeklySummary.hour, 0);
    // DateTime.sunday == 7
    final daysToSunday = (DateTime.sunday - scheduled.weekday + 7) % 7;
    if (daysToSunday > 0) {
      scheduled = scheduled.add(Duration(days: daysToSunday));
    }
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
      scheduled = scheduled.add(const Duration(days: 7));
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _weeklyChannelId,
        _weeklyChannelName,
        channelDescription: '매주 일요일 지난 7일 요약',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _plugin.zonedSchedule(
        DailyNotifSlot.weeklySummary.id,
        '📊 주간 요약',
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'weekly_summary',
      );
    } catch (e) {
      debugPrint('DailyNotification: 주간 정확 알람 실패, inexact 재시도: $e');
      await _plugin.zonedSchedule(
        DailyNotifSlot.weeklySummary.id,
        '📊 주간 요약',
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'weekly_summary',
      );
    }
  }

  /// 지난 완료 주(일~토) 데이터를 집계해 알림 본문 문자열을 반환한다.
  String _buildWeeklySummaryBody(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);

    // 지난 토요일: today.weekday % 7 + 1 일 전
    // Sunday(7): 7%7+1 = 1 → 어제(토) ✓
    // Monday(1): 1%7+1 = 2 → 2일 전(토) ✓
    // Saturday(6): 6%7+1 = 7 → 7일 전(토) ✓
    final lastSaturday = today.subtract(Duration(days: today.weekday % 7 + 1));
    final lastSunday = lastSaturday.subtract(const Duration(days: 6));

    bool inRange(DateTime d) {
      final date = DateTime(d.year, d.month, d.day);
      return !date.isBefore(lastSunday) && !date.isAfter(lastSaturday);
    }

    // 할 일
    final todos = TodoRepository.instance.todos;
    final weekTodos = todos.where((t) => inRange(t.dueDate)).toList();
    final totalTodos = weekTodos.length;
    final doneTodos  = weekTodos.where((t) => t.isDone).toList().length;

    // 기분
    final moods = MoodRepository.instance.entries;
    final weekMoods = moods.where((m) => inRange(m.date)).toList();
    final goodMoods    = weekMoods.where((m) =>
        m.level == MoodLevel.veryGood || m.level == MoodLevel.good).length;
    final neutralMoods = weekMoods.where((m) => m.level == MoodLevel.neutral).length;
    final badMoods     = weekMoods.where((m) =>
        m.level == MoodLevel.bad || m.level == MoodLevel.veryBad).length;

    // 가계부
    final ledger = LedgerRepository.instance.entries;
    int income = 0, expense = 0;
    for (final e in ledger) {
      if (!inRange(e.date)) continue;
      if (e.type == LedgerType.income) {
        income += e.amount;
      } else {
        expense += e.amount;
      }
    }

    final buf = StringBuffer();
    buf.write('지난 7일 할 일 $totalTodos개 중 $doneTodos개 완료');
    if (weekMoods.isNotEmpty) {
      buf.write(' · 기분 좋음 $goodMoods일·보통 $neutralMoods일·나쁨 $badMoods일');
    }
    if (income > 0 || expense > 0) {
      buf.write(' · 입금 ${_won(income)}·지출 ${_won(expense)}');
    }
    return buf.toString();
  }

  // ── 공통 예약 헬퍼 ────────────────────────────────────────────────────────

  Future<void> _scheduleAt({
    required int id,
    required String title,
    required String body,
    required int hour,
    required DateTime now,
  }) async {
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year, now.month, now.day,
      hour, 0,
    );
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: '아침·점심·저녁·잠자리 비서 알림',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _plugin.zonedSchedule(
        id, title, body, scheduled, details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('DailyNotification: 정확 알람 실패, inexact 재시도: $e');
      await _plugin.zonedSchedule(
        id, title, body, scheduled, details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> _cancelAll() async {
    for (final slot in DailyNotifSlot.values) {
      await _plugin.cancel(slot.id);
    }
  }

  // ── 유틸 ─────────────────────────────────────────────────────────────────

  List _todayTodos(List todos, DateTime now) {
    return todos.where((t) {
      final d = t.dueDate as DateTime;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList();
  }

  static String _won(int amount) {
    final s = amount.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${amount < 0 ? "-" : ""}$buf원';
  }
}
