import 'package:flutter/material.dart';

/// 기분 한 줄 — 5단계 기분.
enum MoodLevel {
  veryGood('최고 좋음', '😄', Icons.sentiment_very_satisfied,
      Color(0xFF22B6A0)),
  good('좋음', '🙂', Icons.sentiment_satisfied, Color(0xFF6C5CE7)),
  neutral('보통', '😐', Icons.sentiment_neutral, Color(0xFFFFA94D)),
  bad('나쁨', '🙁', Icons.sentiment_dissatisfied, Color(0xFFFF8FA3)),
  veryBad('최고 나쁨', '😞', Icons.sentiment_very_dissatisfied,
      Color(0xFFFF6B81));

  const MoodLevel(this.label, this.emoji, this.icon, this.color);
  final String label;
  final String emoji;
  final IconData icon;
  final Color color;

  static MoodLevel fromName(String name) =>
      MoodLevel.values.firstWhere((m) => m.name == name,
          orElse: () => MoodLevel.neutral);
}

class MoodEntry {
  MoodEntry({
    required this.id,
    required this.date,
    required this.level,
    required this.note,
  });

  final String id;
  DateTime date; // YYYY-MM-DD 의미만 사용
  MoodLevel level;
  String note; // 100자 이내

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'level': level.name,
        'note': note,
      };

  factory MoodEntry.fromJson(Map<String, dynamic> json) => MoodEntry(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        level: MoodLevel.fromName(json['level'] as String? ?? 'neutral'),
        note: json['note'] as String? ?? '',
      );

  MoodEntry copyWith({DateTime? date, MoodLevel? level, String? note}) =>
      MoodEntry(
        id: id,
        date: date ?? this.date,
        level: level ?? this.level,
        note: note ?? this.note,
      );
}
