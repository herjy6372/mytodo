import 'package:flutter/material.dart';

enum LedgerType {
  income('입금', Icons.arrow_circle_down_rounded, Color(0xFF22B6A0)),
  expense('출금', Icons.arrow_circle_up_rounded, Color(0xFFFF6B81));

  const LedgerType(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;

  static LedgerType fromName(String name) => LedgerType.values
      .firstWhere((t) => t.name == name, orElse: () => LedgerType.expense);
}

class LedgerEntry {
  LedgerEntry({
    required this.id,
    required this.date,
    required this.type,
    required this.amount,
    required this.note,
  });

  final String id;
  DateTime date;
  LedgerType type;
  int amount; // 원 단위, 양수
  String note; // 내역

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'type': type.name,
        'amount': amount,
        'note': note,
      };

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        type: LedgerType.fromName(json['type'] as String? ?? 'expense'),
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        note: json['note'] as String? ?? '',
      );

  LedgerEntry copyWith({
    DateTime? date,
    LedgerType? type,
    int? amount,
    String? note,
  }) =>
      LedgerEntry(
        id: id,
        date: date ?? this.date,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        note: note ?? this.note,
      );
}
