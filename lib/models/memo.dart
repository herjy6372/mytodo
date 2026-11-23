import 'package:flutter/material.dart';

import 'memo_drawing.dart';

/// 메모 카드 색상.
enum MemoColor {
  white(Color(0xFFFFFFFF), Color(0xFF2B2B2B)),
  yellow(Color(0xFFFFF4C2), Color(0xFF5C4A00)),
  pink(Color(0xFFFFE1E8), Color(0xFF7A1F3D)),
  mint(Color(0xFFDDF6EF), Color(0xFF0F5C4A)),
  sky(Color(0xFFDDEBFF), Color(0xFF1C3D7A)),
  lavender(Color(0xFFECE6FF), Color(0xFF3F2D7A));

  const MemoColor(this.background, this.foreground);
  final Color background;
  final Color foreground;

  static MemoColor fromName(String? name) => MemoColor.values
      .firstWhere((c) => c.name == name, orElse: () => MemoColor.white);
}

class Memo {
  Memo({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.color = MemoColor.white,
    this.pinned = false,
    this.rich,
    this.drawing,
  });

  final String id;
  String title;
  String content;
  MemoColor color;
  bool pinned;

  /// 서식이 들어간 본문 (Quill Delta ops). 없으면 [content] 를 그대로 사용.
  /// [content] 에는 항상 서식 없는 글자를 함께 저장해 검색·위젯·이전 버전에서 씁니다.
  List<dynamic>? rich;

  /// 손글씨·그림 (없으면 null)
  MemoDrawing? drawing;
  final DateTime createdAt;
  DateTime updatedAt;

  /// 목록·위젯에 표시할 제목. 제목이 비어 있으면 본문 첫 줄을 사용.
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    final firstLine = content.trim().split('\n').first.trim();
    if (firstLine.isNotEmpty) return firstLine;
    return hasDrawing ? '그림 메모' : '제목 없음';
  }

  bool get hasDrawing => drawing != null && !drawing!.isEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'color': color.name,
        'pinned': pinned,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (rich != null) 'rich': rich,
        if (hasDrawing) 'drawing': drawing!.toJson(),
      };

  factory Memo.fromJson(Map<String, dynamic> json) {
    final created = DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.now();
    return Memo(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      color: MemoColor.fromName(json['color'] as String?),
      pinned: json['pinned'] as bool? ?? false,
      createdAt: created,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? created,
      rich: json['rich'] is List ? List<dynamic>.from(json['rich'] as List) : null,
      drawing: MemoDrawing.fromJson(json['drawing']),
    );
  }
}
