import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../models/alarm.dart';
import '../services/notification_service.dart';

/// 알람 저장소. 기기에 저장하고, 변경될 때마다 OS 알림 예약을 다시 맞춥니다.
class AlarmRepository extends ChangeNotifier {
  AlarmRepository._();
  static final AlarmRepository instance = AlarmRepository._();

  static const _key = 'alarms_v1';
  final List<Alarm> _alarms = [];
  final _uuid = const Uuid();
  bool _loaded = false;

  /// 시각 순 정렬.
  List<Alarm> get alarms {
    final list = [..._alarms];
    list.sort((a, b) =>
        (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    return list;
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => Alarm.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _alarms
          ..clear()
          ..addAll(list);
      } catch (_) {/* 손상된 데이터는 건너뜀 */}
    }
    // 이미 울린 "한 번" 알람은 끈 상태로 정리
    final now = DateTime.now();
    var changed = false;
    for (final a in _alarms) {
      if (a.enabled &&
          a.weekdays.isEmpty &&
          a.onceAt != null &&
          !a.onceAt!.isAfter(now)) {
        a.enabled = false;
        changed = true;
      }
    }
    if (changed) await _save();
    _loaded = true;
    notifyListeners();
    // 앱 시작 시 예약 상태를 저장된 알람과 맞춤 (재설치·시간대 변경 대비)
    for (final a in _alarms) {
      await _schedule(a);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(_alarms.map((a) => a.toJson()).toList()));
  }

  Future<Alarm> add({
    required AlarmType type,
    required int hour,
    required int minute,
    Set<int>? weekdays,
    String label = '',
  }) async {
    final alarm = Alarm(
      id: _uuid.v4(),
      type: type,
      hour: hour,
      minute: minute,
      weekdays: weekdays,
      label: label,
    );
    _alarms.add(alarm);
    await _save();
    notifyListeners();
    await _schedule(alarm);
    return alarm;
  }

  Future<void> update(Alarm alarm) async {
    final i = _alarms.indexWhere((a) => a.id == alarm.id);
    if (i == -1) return;
    _alarms[i] = alarm;
    await _save();
    notifyListeners();
    await _schedule(alarm);
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final i = _alarms.indexWhere((a) => a.id == id);
    if (i == -1) return;
    _alarms[i].enabled = enabled;
    await _save();
    notifyListeners();
    await _schedule(_alarms[i]);
  }

  Future<void> remove(String id) async {
    _alarms.removeWhere((a) => a.id == id);
    await _save();
    notifyListeners();
    await _cancel(id);
  }

  // ── 예약 ───────────────────────────────────────────────────────────

  /// 알람 하나당 최대 8개 알림 ID: 요일별 7개(1~7) + 한 번 울림(0).
  static int _notifId(String alarmId, int slot) =>
      ('alarm_${alarmId}_$slot').hashCode & 0x7fffffff;

  Future<void> _cancel(String alarmId) async {
    final plugin = NotificationService.instance.plugin;
    for (var slot = 0; slot <= 7; slot++) {
      await plugin.cancel(_notifId(alarmId, slot));
    }
  }

  Future<void> _schedule(Alarm alarm) async {
    await NotificationService.instance.init();
    await _cancel(alarm.id);
    if (!alarm.enabled) return;

    final details = NotificationService.alarmDetails();
    final body = alarm.type == AlarmType.custom
        ? '알림을 눌러 알람을 끄세요.'
        : '${alarm.type.label} · 알림을 눌러 알람을 끄세요.';

    if (alarm.weekdays.isEmpty) {
      final when = _nextTime(alarm.hour, alarm.minute);
      if (alarm.onceAt == null || !alarm.onceAt!.isAtSameMomentAs(when)) {
        alarm.onceAt = when;
        await _save();
      }
      await _zoned(
        _notifId(alarm.id, 0),
        alarm.title,
        body,
        when,
        details,
        null,
        alarm.id,
      );
      return;
    }
    if (alarm.weekdays.length == 7) {
      // 매일 → 시각만 맞춰 반복 (알림 1개로 충분)
      await _zoned(
        _notifId(alarm.id, 0),
        alarm.title,
        body,
        _nextTime(alarm.hour, alarm.minute),
        details,
        DateTimeComponents.time,
        alarm.id,
      );
      return;
    }
    for (final day in alarm.weekdays) {
      await _zoned(
        _notifId(alarm.id, day),
        alarm.title,
        body,
        _nextWeekday(day, alarm.hour, alarm.minute),
        details,
        DateTimeComponents.dayOfWeekAndTime,
        alarm.id,
      );
    }
  }

  Future<void> _zoned(
    int id,
    String title,
    String body,
    tz.TZDateTime when,
    NotificationDetails details,
    DateTimeComponents? repeat,
    String payload,
  ) async {
    final plugin = NotificationService.instance.plugin;
    Future<void> go(AndroidScheduleMode mode) => plugin.zonedSchedule(
          id,
          title,
          body,
          when,
          details,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: repeat,
          payload: 'alarm:$payload',
        );
    try {
      // 알람 시계 모드: 절전 중에도 정확한 시각에 울림
      await go(AndroidScheduleMode.alarmClock);
    } catch (e) {
      debugPrint('정확한 알람 예약 실패, 일반 예약으로 재시도: $e');
      await go(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  /// 오늘 해당 시각이 지났으면 내일.
  static tz.TZDateTime _nextTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  /// 다음 [weekday] 요일의 해당 시각.
  static tz.TZDateTime _nextWeekday(int weekday, int hour, int minute) {
    var t = _nextTime(hour, minute);
    while (t.weekday != weekday) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }
}
