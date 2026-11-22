import 'package:flutter/material.dart';

/// 할 일 카테고리. 사용자가 추가하기 쉽도록 enum 으로 미리 정의했습니다.
enum TodoCategory {
  work('업무', Icons.work_outline, Color(0xFF4F8DFF)),
  study('공부', Icons.menu_book_outlined, Color(0xFF7C5CFF)),
  life('생활', Icons.home_outlined, Color(0xFF22B6A0)),
  health('건강', Icons.favorite_outline, Color(0xFFFF6B81)),
  hobby('취미', Icons.sports_esports_outlined, Color(0xFFFFA94D)),
  etc('기타', Icons.label_outline, Color(0xFF8C8C8C));

  const TodoCategory(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static TodoCategory fromName(String name) {
    return TodoCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => TodoCategory.etc,
    );
  }
}

/// 할 일 모델: 언제(when) / 어디서(where) / 무엇(what) + 카테고리.
class Todo {
  Todo({
    required this.id,
    required this.title,
    required this.place,
    required this.dueDate,
    required this.category,
    this.memo = '',
    this.isDone = false,
    this.alarm = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  String title; // 무엇
  String place; // 어디서
  DateTime dueDate; // 언제
  TodoCategory category;
  String memo;
  bool isDone;
  /// true 면 일반 알림 대신 알람음으로 알려줍니다.
  bool alarm;
  final DateTime createdAt;

  Todo copyWith({
    String? title,
    String? place,
    DateTime? dueDate,
    TodoCategory? category,
    String? memo,
    bool? isDone,
    bool? alarm,
  }) {
    return Todo(
      id: id,
      title: title ?? this.title,
      place: place ?? this.place,
      dueDate: dueDate ?? this.dueDate,
      category: category ?? this.category,
      memo: memo ?? this.memo,
      isDone: isDone ?? this.isDone,
      alarm: alarm ?? this.alarm,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'place': place,
        'dueDate': dueDate.toIso8601String(),
        'category': category.name,
        'memo': memo,
        'isDone': isDone,
        'alarm': alarm,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
        id: json['id'] as String,
        title: json['title'] as String,
        place: json['place'] as String? ?? '',
        dueDate: DateTime.parse(json['dueDate'] as String),
        category: TodoCategory.fromName(json['category'] as String? ?? 'etc'),
        memo: json['memo'] as String? ?? '',
        isDone: json['isDone'] as bool? ?? false,
        alarm: json['alarm'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
