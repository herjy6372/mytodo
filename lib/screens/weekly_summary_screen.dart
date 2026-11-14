import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/ledger_repository.dart';
import '../data/mood_repository.dart';
import '../data/todo_repository.dart';
import '../models/ledger.dart';
import '../models/mood.dart';

class WeeklySummaryScreen extends StatelessWidget {
  const WeeklySummaryScreen({super.key});

  // 지난 완료 주(일~토) 날짜 범위 계산
  static ({DateTime sunday, DateTime saturday}) _lastWeekRange() {
    final today = DateTime.now();
    final date = DateTime(today.year, today.month, today.day);
    // lastSaturday: today.weekday % 7 + 1 일 전
    // Sunday(7): 7%7+1=1 → 어제(토) / Monday(1): 1%7+1=2 → 토요일(2일 전)
    final lastSaturday = date.subtract(Duration(days: date.weekday % 7 + 1));
    final lastSunday   = lastSaturday.subtract(const Duration(days: 6));
    return (sunday: lastSunday, saturday: lastSaturday);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final range  = _lastWeekRange();
    final fmt    = DateFormat('M월 d일', 'ko_KR');
    final rangeLabel =
        '${fmt.format(range.sunday)} ~ ${fmt.format(range.saturday)}';

    bool inRange(DateTime d) {
      final date = DateTime(d.year, d.month, d.day);
      return !date.isBefore(range.sunday) && !date.isAfter(range.saturday);
    }

    // ── 할 일 집계 ─────────────────────────────────────────────────────────
    final todos     = TodoRepository.instance.todos;
    final weekTodos = todos.where((t) => inRange(t.dueDate)).toList();
    final total     = weekTodos.length;
    final done      = weekTodos.where((t) => t.isDone).length;
    final notDone   = total - done;

    // ── 기분 집계 ─────────────────────────────────────────────────────────
    final moods     = MoodRepository.instance.entries;
    final weekMoods = moods.where((m) => inRange(m.date)).toList();
    final moodCounts = <MoodLevel, int>{};
    for (final m in weekMoods) {
      moodCounts[m.level] = (moodCounts[m.level] ?? 0) + 1;
    }

    // ── 가계부 집계 ───────────────────────────────────────────────────────
    final ledger  = LedgerRepository.instance.entries;
    int income = 0, expense = 0;
    for (final e in ledger) {
      if (!inRange(e.date)) continue;
      if (e.type == LedgerType.income) {
        income += e.amount;
      } else {
        expense += e.amount;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('주간 요약'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 날짜 범위 헤더
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded,
                        color: scheme.primary, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      rangeLabel,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '지난 7일 요약',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── 할 일 섹션 ────────────────────────────────────────────
              _SectionCard(
                color: const Color(0xFF6C5CE7),
                icon: Icons.check_circle_outline_rounded,
                title: '할 일',
                child: total == 0
                    ? _EmptyRow('이번 주 등록된 할 일이 없어요.')
                    : Column(
                        children: [
                          _StatRow(
                            label: '전체',
                            value: '$total건',
                            valueColor: scheme.onSurface,
                          ),
                          _StatRow(
                            label: '완료',
                            value: '$done건',
                            valueColor: const Color(0xFF22B6A0),
                          ),
                          _StatRow(
                            label: '미완료',
                            value: '$notDone건',
                            valueColor: notDone > 0
                                ? const Color(0xFFFF6B81)
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          _ProgressBar(
                            value: total == 0 ? 0 : done / total,
                            color: const Color(0xFF6C5CE7),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              total == 0
                                  ? '0%'
                                  : '${(done * 100 ~/ total)}% 달성',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 14),

              // ── 기분 섹션 ─────────────────────────────────────────────
              _SectionCard(
                color: const Color(0xFFFFA94D),
                icon: Icons.mood_rounded,
                title: '기분한줄',
                child: weekMoods.isEmpty
                    ? _EmptyRow('이번 주 기분 기록이 없어요.')
                    : Column(
                        children: MoodLevel.values
                            .where((lv) => (moodCounts[lv] ?? 0) > 0)
                            .map((lv) => _StatRow(
                                  label: '${lv.emoji} ${lv.label}',
                                  value: '${moodCounts[lv]}일',
                                  valueColor: lv.color,
                                ))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 14),

              // ── 가계부 섹션 ───────────────────────────────────────────
              _SectionCard(
                color: const Color(0xFF22B6A0),
                icon: Icons.account_balance_wallet_rounded,
                title: '가계부',
                child: (income == 0 && expense == 0)
                    ? _EmptyRow('이번 주 가계부 기록이 없어요.')
                    : Column(
                        children: [
                          _StatRow(
                            label: '입금',
                            value: _won(income),
                            valueColor: const Color(0xFF22B6A0),
                          ),
                          _StatRow(
                            label: '지출',
                            value: _won(expense),
                            valueColor: const Color(0xFFFF6B81),
                          ),
                          const Divider(height: 20),
                          _StatRow(
                            label: '잔액',
                            value: _won(income - expense),
                            valueColor: income - expense >= 0
                                ? const Color(0xFF22B6A0)
                                : const Color(0xFFFF6B81),
                            bold: true,
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),

              // 자연어 요약
              _NarrativeCard(
                total: total,
                done: done,
                notDone: notDone,
                weekMoods: weekMoods,
                moodCounts: moodCounts,
                income: income,
                expense: expense,
              ),
            ],
          ),
        ),
      ),
    );
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

// ── 자연어 요약 카드 ─────────────────────────────────────────────────────────

class _NarrativeCard extends StatelessWidget {
  const _NarrativeCard({
    required this.total,
    required this.done,
    required this.notDone,
    required this.weekMoods,
    required this.moodCounts,
    required this.income,
    required this.expense,
  });

  final int total, done, notDone, income, expense;
  final List<MoodEntry> weekMoods;
  final Map<MoodLevel, int> moodCounts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final buf = StringBuffer();

    // 할 일 문장
    if (total > 0) {
      buf.write('지난 7일 동안 $total건의 할 일 중 $done건을 완료했고'
          '${notDone > 0 ? " $notDone건을 완료하지 못했어요." : " 모두 완료했어요! 🎉"}');
    } else {
      buf.write('지난 7일 동안 등록된 할 일이 없었어요.');
    }

    // 기분 문장
    if (weekMoods.isNotEmpty) {
      final goodDays    = (moodCounts[MoodLevel.veryGood] ?? 0) +
          (moodCounts[MoodLevel.good] ?? 0);
      final neutralDays = moodCounts[MoodLevel.neutral] ?? 0;
      final badDays     = (moodCounts[MoodLevel.bad] ?? 0) +
          (moodCounts[MoodLevel.veryBad] ?? 0);
      buf.write(' 기분은 좋음 $goodDays일');
      if (neutralDays > 0) buf.write('·보통 $neutralDays일');
      if (badDays > 0) buf.write('·나쁨 $badDays일');
      buf.write('이었어요.');
    }

    // 가계부 문장
    if (income > 0 || expense > 0) {
      buf.write(' 가계부는 입금 ${_won(income)}'
          '${expense > 0 ? "·지출 ${_won(expense)}" : ""}이 있었어요.');
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.auto_awesome_rounded,
                color: scheme.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              '이번 주 한 줄 요약',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            buf.toString(),
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
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

// ── 섹션 카드 ────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.child,
  });

  final Color color;
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ── 통계 행 ──────────────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final weight = bold ? FontWeight.w800 : FontWeight.w600;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              color: scheme.onSurfaceVariant,
              fontWeight: weight,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: weight,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 빈 상태 행 ───────────────────────────────────────────────────────────────

class _EmptyRow extends StatelessWidget {
  const _EmptyRow(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ── 진행률 바 ────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 8,
        backgroundColor: scheme.outlineVariant,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}
