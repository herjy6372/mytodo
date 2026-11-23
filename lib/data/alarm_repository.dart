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

  /// 백업 복원 후 다시 읽습니다. 기존 알람 예약을 모두 지운 뒤 새로 예약합니다.
  Future<void> reload() async {
    for (final a in _alarms) {
      await _cancel(a.id);
    }
    _alarms.clear();
    _loaded = false;
    await load();
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

  /// 알람 하나당 알림 ID: 요일별 7개(1~7) + 한 번/매일(0),
  /// iOS 후속 알림은 같은 슬롯 + 10.
  static int _notifId(String alarmId, int slot) =>
      ('alarm_${alarmId}_$slot').hashCode & 0x7fffffff;

  Future<void> _cancel(String alarmId) async {
    final plugin = NotificationService.instance.plugin;
    for (var slot = 0; slot <= 7; slot++) {
      await plugin.cancel(_notifId(alarmId, slot));
      await plugin.cancel(_notifId(alarmId, slot + 10));
    }
  }

  Alarm? byId(String id) {
    for (final a in _alarms) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// 알람이 울린 뒤 정리: 울리는 알림을 지우고, 한 번 알람은 끄고,
  /// 반복 알람은 다음 시각으로 다시 예약합니다.
  Future<void> finishRing(String id) async {
    final alarm = byId(id);
    if (alarm == null) return;
    if (alarm.weekdays.isEmpty) {
      await setEnabled(id, false);
    } else {
      await _schedule(alarm);
    }
  }

  /// 가장 최근에 울렸어야 할 시각 (지금 이전). 알람 화면의 남은 시간 계산용.
  DateTime lastFireTime(Alarm alarm) {
    final now = DateTime.now();
    var t = DateTime(now.year, now.month, now.day, alarm.hour, alarm.minute);
    if (t.isAfter(now)) t = t.subtract(const Duration(days: 1));
    return t;
  }

  /// 앞으로 울릴 시각 (켜진 알람만). 앱이 열려 있을 때 알람 화면을 띄우는 데 사용.
  DateTime? nextFireTime(Alarm alarm) {
    if (!alarm.enabled) return null;
    if (alarm.weekdays.isEmpty || alarm.weekdays.length == 7) {
      return _nextTime(alarm.hour, alarm.minute);
    }
    tz.TZDateTime? best;
    for (final d in alarm.weekdays) {
      final t = _nextWeekday(d, alarm.hour, alarm.minute);
      if (best == null || t.isBefore(best)) best = t;
    }
    return best;
  }

  Future<void> _schedule(Alarm alarm) async {
    await NotificationService.instance.init();
    await _cancel(alarm.id);
    if (!alarm.enabled) return;

    final body = alarm.type == AlarmType.custom
        ? '알림을 눌러 알람을 끄거나 미루세요.'
        : '${alarm.type.label} · 알림을 눌러 알람을 끄거나 미루세요.';

    if (alarm.weekdays.isEmpty) {
      final when = _nextTime(alarm.hour, alarm.minute);
      if (alarm.onceAt == null || !alarm.onceAt!.isAtSameMomentAs(when)) {
        alarm.onceAt = when;
        await _save();
      }
      await _zoned(
        alarm,
        0,
        body,
        when,
        null,
      );
      return;
    }
    if (alarm.weekdays.length == 7) {
      // 매일 → 시각만 맞춰 반복 (알림 1개로 충분)
      await _zoned(
        alarm,
        0,
        body,
        _nextTime(alarm.hour, alarm.minute),
        DateTimeComponents.time,
      );
      return;
    }
    for (final day in alarm.weekdays) {
      await _zoned(
        alarm,
        day,
        body,
        _nextWeekday(day, alarm.hour, alarm.minute),
        DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> _zoned(
    Alarm alarm,
    int slot,
    String body,
    tz.TZDateTime when,
    DateTimeComponents? repeat,
  ) =>
      NotificationService.instance.scheduleAlarm(
        id: _notifId(alarm.id, slot),
        followUpId: _notifId(alarm.id, slot + 10),
        title: alarm.title,
        body: body,
        when: when,
        repeat: repeat,
        payload: 'alarm:${alarm.id}',
      );

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
