import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/todo.dart';

/// 로컬 푸시 알림 서비스.
/// 할 일의 [dueDate] 시간이 되면 사용자에게 알림을 보냅니다.
/// 외부 서버 없이 OS 의 로컬 알림만 사용하므로 오프라인에서도 동작합니다.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// 알람 예약 등 다른 서비스에서 같은 플러그인을 사용하기 위한 접근자.
  FlutterLocalNotificationsPlugin get plugin => _plugin;

  /// iOS 알람음 파일 이름 (Library/Sounds 에 복사해 사용).
  static const iosAlarmSound = 'alarm.wav';

  /// 알람음으로 울리는 알림 설정.
  /// Android: 시스템 알람음 + 알람 볼륨 + 끌 때까지 반복.
  /// iOS: 앱에 포함된 30초 알람음.
  static NotificationDetails alarmDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'alarm_channel_v1',
        '알람',
        channelDescription: '설정한 시간에 알람음으로 알려드립니다.',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        playSound: true,
        sound: const UriAndroidNotificationSound(
            'content://settings/system/alarm_alert'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        // FLAG_INSISTENT(4): 사용자가 알림을 확인할 때까지 소리 반복
        additionalFlags: Int32List.fromList(const [4]),
        visibility: NotificationVisibility.public,
        ticker: '알람',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
        sound: iosAlarmSound,
      ),
    );
  }

  static const _todoDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'todo_channel',
      '할 일 알림',
      channelDescription: '예정된 할 일 시간이 되면 알려드립니다.',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// iOS 는 알림 소리 파일이 앱 번들이나 Library/Sounds 에 있어야 합니다.
  /// 앱 에셋의 알람음을 Library/Sounds 로 복사해 둡니다.
  Future<void> _installIosAlarmSound() async {
    if (!Platform.isIOS) return;
    try {
      final lib = await getLibraryDirectory();
      final file = File('${lib.path}/Sounds/$iosAlarmSound');
      if (await file.exists()) return;
      await file.parent.create(recursive: true);
      final data = await rootBundle.load('assets/sounds/$iosAlarmSound');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    } catch (e) {
      debugPrint('알람음 설치 실패: $e');
    }
  }

  /// 앱 시작 시 한 번 호출합니다.
  Future<void> init() async {
    if (_initialized) return;
    try {
      tzdata.initializeTimeZones();
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz.identifier));
    } catch (e) {
      // 시간대 초기화 실패 시 UTC 로 폴백.
      debugPrint('타임존 초기화 실패: $e');
    }

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    await _installIosAlarmSound();
    _initialized = true;
  }

  /// 사용자에게 알림 권한을 요청합니다.
  /// 이미 허용된 경우에도 호출은 안전합니다.
  Future<bool> requestPermission() async {
    await init();
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      return granted;
    }
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted =
          await android?.requestNotificationsPermission() ?? false;
      // 정확한 알람을 위해 Android 12+ 에서 별도 권한 필요할 수 있음.
      await android?.requestExactAlarmsPermission();
      return granted;
    }
    return false;
  }

  /// 할 일 단건 예약. 기존 예약이 있다면 덮어씁니다.
  Future<void> scheduleTodo(Todo todo) async {
    await init();
    await _plugin.cancel(_idOf(todo.id));
    if (todo.isDone) return;
    if (todo.dueDate.isBefore(DateTime.now())) return;

    final scheduled = tz.TZDateTime.from(todo.dueDate, tz.local);
    final details = todo.alarm ? alarmDetails() : _todoDetails;
    final body = StringBuffer();
    if (todo.place.isNotEmpty) body.write('${todo.place} · ');
    body.write(todo.category.label);

    try {
      await _plugin.zonedSchedule(
        _idOf(todo.id),
        todo.alarm ? '⏰ ${todo.title}' : '${todo.title} 시간이에요',
        body.toString(),
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: todo.id,
      );
    } catch (e) {
      // 정확 알람 권한이 없으면 inexact 로 폴백.
      debugPrint('정확 알람 예약 실패, inexact로 재시도: $e');
      await _plugin.zonedSchedule(
        _idOf(todo.id),
        todo.alarm ? '⏰ ${todo.title}' : '${todo.title} 시간이에요',
        body.toString(),
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: todo.id,
      );
    }
  }

  Future<void> cancelTodo(String todoId) async {
    await init();
    await _plugin.cancel(_idOf(todoId));
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  /// String id 를 안정적인 32-bit int 로 변환.
  int _idOf(String id) => id.hashCode & 0x7fffffff;
}
