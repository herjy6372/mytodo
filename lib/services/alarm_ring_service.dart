import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/alarm_repository.dart';
import '../data/todo_repository.dart';
import '../screens/alarm_ring_screen.dart';
import 'notification_service.dart';

/// 알람이 울릴 때 알람 화면을 띄우고, 1분 동안 소리를 내고,
/// 중지·다시 울림(미루기)을 처리합니다.
///
/// 알림 payload 형식:
///   alarm:<알람 id>        알람 화면에서 만든 알람
///   todoalarm:<할 일 id>   "알람으로 알리기"를 켠 할 일
///   snooze:<제목>          미룬 알람
class AlarmRingService {
  AlarmRingService._();
  static final AlarmRingService instance = AlarmRingService._();

  static const _sound = MethodChannel('mytodo/alarm_sound');
  static const _snoozeId = 0x7A1A0001;
  static const _snoozeFollowUpId = 0x7A1A0002;
  static const snoozeChoices = [1, 5, 10, 30];

  GlobalKey<NavigatorState>? _nav;
  String? _showingPayload;
  Timer? _foregroundTimer;

  /// 미룬 알람이 울릴 시각 (앱이 열려 있을 때 화면을 띄우는 데 사용).
  DateTime? _snoozeAt;
  String _snoozeTitle = '';

  static bool isAlarmPayload(String p) =>
      p.startsWith('alarm:') || p.startsWith('todoalarm:') || p.startsWith('snooze:');

  /// 앱 시작 시 한 번 호출. 알람 알림으로 앱이 열렸으면 바로 알람 화면을 띄웁니다.
  Future<void> init(GlobalKey<NavigatorState> nav) async {
    _nav = nav;
    AlarmRepository.instance.addListener(_armForegroundTimer);
    TodoRepository.instance.addListener(_armForegroundTimer);
    _armForegroundTimer();
    try {
      final details = await NotificationService.instance.plugin
          .getNotificationAppLaunchDetails();
      final payload = details?.notificationResponse?.payload;
      if ((details?.didNotificationLaunchApp ?? false) &&
          payload != null &&
          isAlarmPayload(payload)) {
        open(payload);
      }
    } catch (e) {
      debugPrint('알람 실행 정보 확인 실패: $e');
    }
  }

  /// 알람 알림을 누르거나, 알람 알림으로 앱이 열렸을 때.
  void open(String payload, {DateTime? firedAt}) {
    if (_showingPayload == payload) return;
    final nav = _nav?.currentState;
    if (nav == null) return;

    String title = '알람';
    String subtitle = '';
    DateTime fired = firedAt ?? DateTime.now();

    if (payload.startsWith('alarm:')) {
      final alarm = AlarmRepository.instance.byId(payload.substring(6));
      if (alarm == null) return;
      title = alarm.title;
      subtitle = alarm.type.label;
      fired = firedAt ?? AlarmRepository.instance.lastFireTime(alarm);
    } else if (payload.startsWith('todoalarm:')) {
      final id = payload.substring(10);
      final todo = TodoRepository.instance.todos
          .where((t) => t.id == id)
          .firstOrNull;
      if (todo == null) return;
      title = todo.title;
      subtitle = '할 일 알람';
      fired = firedAt ?? todo.dueDate;
    } else if (payload.startsWith('snooze:')) {
      title = payload.substring(7);
      subtitle = '다시 울림';
      fired = firedAt ?? _snoozeAt ?? DateTime.now();
      _snoozeAt = null;
    }

    _showingPayload = payload;
    // 알림 쪽 소리는 끄고, 이제부터는 알람 화면이 소리를 냅니다.
    unawaited(_clearNotification(payload));
    nav
        .push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => AlarmRingScreen(
            title: title,
            subtitle: subtitle,
            firedAt: fired,
          ),
        ))
        .then((result) async {
      _showingPayload = null;
      await stopSound();
      if (result is int) await snooze(result, title);
    });
  }

  /// 울리고 있는 알림을 지우고 다음 예약을 정리합니다.
  Future<void> _clearNotification(String payload) async {
    final plugin = NotificationService.instance.plugin;
    if (payload.startsWith('alarm:')) {
      await AlarmRepository.instance.finishRing(payload.substring(6));
    } else if (payload.startsWith('todoalarm:')) {
      await NotificationService.instance.cancelTodo(payload.substring(10));
    } else if (payload.startsWith('snooze:')) {
      await plugin.cancel(_snoozeId);
      await plugin.cancel(_snoozeFollowUpId);
    }
  }

  Future<void> startSound() async {
    try {
      await _sound.invokeMethod('start');
    } catch (e) {
      debugPrint('알람음 재생 실패: $e');
    }
  }

  Future<void> stopSound() async {
    try {
      await _sound.invokeMethod('stop');
    } catch (e) {
      debugPrint('알람음 중지 실패: $e');
    }
  }

  /// [minutes]분 뒤 다시 울리도록 예약합니다.
  Future<void> snooze(int minutes, String title) async {
    final at = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));
    _snoozeAt = at;
    _snoozeTitle = title;
    await NotificationService.instance.scheduleAlarm(
      id: _snoozeId,
      followUpId: _snoozeFollowUpId,
      title: title,
      body: '$minutes분 미룬 알람이에요. 눌러서 끄거나 다시 미루세요.',
      when: at,
      payload: 'snooze:$title',
    );
    _armForegroundTimer();
  }

  /// 앱이 화면에 떠 있는 동안 알람 시각이 되면 알림을 누르지 않아도 알람 화면을 띄웁니다.
  void _armForegroundTimer() {
    _foregroundTimer?.cancel();
    final now = DateTime.now();
    DateTime? best;
    String? bestPayload;
    void consider(DateTime? t, String payload) {
      if (t == null || !t.isAfter(now)) return;
      if (best == null || t.isBefore(best!)) {
        best = t;
        bestPayload = payload;
      }
    }

    for (final a in AlarmRepository.instance.alarms) {
      consider(AlarmRepository.instance.nextFireTime(a), 'alarm:${a.id}');
    }
    for (final t in TodoRepository.instance.todos) {
      if (t.alarm && !t.isDone) consider(t.dueDate, 'todoalarm:${t.id}');
    }
    consider(_snoozeAt, 'snooze:$_snoozeTitle');
    if (best == null) return;

    final wait = best!.difference(now);
    // 아주 먼 알람은 타이머를 걸지 않음 (앱을 다시 열 때 다시 계산)
    if (wait > const Duration(days: 1)) return;
    final payload = bestPayload!;
    final fireAt = best!;
    _foregroundTimer = Timer(wait, () {
      final state = WidgetsBinding.instance.lifecycleState;
      if (state == AppLifecycleState.resumed) {
        open(payload, firedAt: fireAt);
      }
      // 다음 알람을 위해 다시 계산 (finishRing 이 알림 목록을 바꾸면 다시 호출됨)
      Timer(const Duration(seconds: 2), _armForegroundTimer);
    });
  }

  /// 앱으로 돌아올 때 다음 알람 타이머를 다시 맞춥니다.
  void onResume() => _armForegroundTimer();
}
