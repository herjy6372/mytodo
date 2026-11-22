import 'package:flutter/material.dart';

/// 알람 종류.
enum AlarmType {
  wakeUp('아침 깨우기', Icons.wb_sunny_rounded, Color(0xFFFFA94D)),
  bedtime('잘 때 알람', Icons.bedtime_rounded, Color(0xFF6C5CE7)),
  custom('일반 알람', Icons.alarm_rounded, Color(0xFF22B6A0));

  const AlarmType(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;

  /// 알림 제목으로 쓰는 기본 문구.
  String get defaultMessage => switch (this) {
        AlarmType.wakeUp => '좋은 아침이에요! 일어날 시간이에요 ☀️',
        AlarmType.bedtime => '잘 시간이에요. 오늘도 수고했어요 🌙',
        AlarmType.custom => '알람 시간이에요 ⏰',
      };

  static AlarmType fromName(String? name) => AlarmType.values
      .firstWhere((t) => t.name == name, orElse: () => AlarmType.custom);
}

class Alarm {
  Alarm({
    required this.id,
    required this.type,
    required this.hour,
    required this.minute,
    Set<int>? weekdays,
    this.label = '',
    this.enabled = true,
    this.onceAt,
  }) : weekdays = weekdays ?? <int>{};

  final String id;
  AlarmType type;
  int hour;
  int minute;

  /// 반복 요일 (DateTime.monday=1 … DateTime.sunday=7). 비어 있으면 한 번만 울림.
  Set<int> weekdays;
  String label;
  bool enabled;

  /// "한 번" 알람이 예약된 시각. 지나면 알람을 자동으로 끕니다.
  DateTime? onceAt;

  TimeOfDay get time => TimeOfDay(hour: hour, minute: minute);

  /// 알림 제목.
  String get title =>
      label.trim().isNotEmpty ? '⏰ ${label.trim()}' : type.defaultMessage;

  static const _dayNames = ['월', '화', '수', '목', '금', '토', '일'];

  /// "매일", "평일", "주말", "월·수·금", "한 번" 같은 반복 설명.
  String get repeatText {
    if (weekdays.isEmpty) return '한 번';
    if (weekdays.length == 7) return '매일';
    if (weekdays.length == 5 && !weekdays.contains(6) && !weekdays.contains(7)) {
      return '평일';
    }
    if (weekdays.length == 2 && weekdays.contains(6) && weekdays.contains(7)) {
      return '주말';
    }
    final sorted = weekdays.toList()..sort();
    return sorted.map((d) => _dayNames[d - 1]).join('·');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'hour': hour,
        'minute': minute,
        'weekdays': weekdays.toList()..sort(),
        'label': label,
        'enabled': enabled,
        if (onceAt != null) 'onceAt': onceAt!.toIso8601String(),
      };

  factory Alarm.fromJson(Map<String, dynamic> json) => Alarm(
        id: json['id'] as String,
        type: AlarmType.fromName(json['type'] as String?),
        hour: (json['hour'] as num?)?.toInt() ?? 7,
        minute: (json['minute'] as num?)?.toInt() ?? 0,
        weekdays: ((json['weekdays'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .where((d) => d >= 1 && d <= 7)
            .toSet(),
        label: json['label'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
        onceAt: DateTime.tryParse(json['onceAt'] as String? ?? ''),
      );
}
