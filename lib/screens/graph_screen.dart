import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/todo_repository.dart';
import '../models/todo.dart';

enum GraphRange { day, month, year }

/// 그래프형 목록: 년/월/일 단위 완료/미완료 막대그래프.
class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  final _repo = TodoRepository.instance;
  GraphRange _range = GraphRange.month;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onChange);
  }

  @override
  void dispose() {
    _repo.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  /// 선택된 범위에 따라 (라벨, 완료, 미완료) 시리즈를 만든다.
  List<_Bucket> _buildBuckets() {
    final now = DateTime.now();
    final all = _repo.todos;

    switch (_range) {
      case GraphRange.day:
        // 최근 7일
        return List.generate(7, (i) {
          final d = DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: 6 - i));
          final items = all.where((t) =>
              t.dueDate.year == d.year &&
              t.dueDate.month == d.month &&
              t.dueDate.day == d.day);
          return _Bucket(
            label: DateFormat('M/d', 'ko_KR').format(d),
            done: items.where((t) => t.isDone).length,
            todo: items.where((t) => !t.isDone).length,
          );
        });

      case GraphRange.month:
        // 최근 6개월
        return List.generate(6, (i) {
          final d = DateTime(now.year, now.month - (5 - i), 1);
          final items = all.where(
              (t) => t.dueDate.year == d.year && t.dueDate.month == d.month);
          return _Bucket(
            // 6칸에 들어가도록 연도는 두 자리로 (예: 26.11)
            label: DateFormat('yy.M', 'ko_KR').format(d),
            done: items.where((t) => t.isDone).length,
            todo: items.where((t) => !t.isDone).length,
          );
        });

      case GraphRange.year:
        // 최근 5년
        return List.generate(5, (i) {
          final y = now.year - (4 - i);
          final items = all.where((t) => t.dueDate.year == y);
          return _Bucket(
            label: '$y',
            done: items.where((t) => t.isDone).length,
            todo: items.where((t) => !t.isDone).length,
          );
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final buckets = _buildBuckets();
    final total = _repo.todos.length;
    final done = _repo.todos.where((t) => t.isDone).length;
    final ratio = total == 0 ? 0.0 : done / total;
    final maxY = _maxY(buckets);

    return Scaffold(
      appBar: AppBar(title: const Text('그래프형 목록')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            _RangeSelector(
              range: _range,
              onChanged: (r) => setState(() => _range = r),
            ),
            const SizedBox(height: 16),
            _SummaryCard(total: total, done: done, ratio: ratio),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('완료 vs 미완료',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 240,
                    child: BarChart(
                      BarChartData(
                        maxY: maxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: Theme.of(context).dividerColor,
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: maxY <= 5 ? 1 : (maxY / 5).ceilToDouble(),
                              getTitlesWidget: (v, _) => Text(
                                v.toInt().toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (v, meta) {
                                final i = v.toInt();
                                if (i < 0 || i >= buckets.length) {
                                  return const SizedBox.shrink();
                                }
                                // 큰 글씨 모드에서도 이웃 라벨과 겹치지 않도록
                                // 한 칸 너비 안에 맞춰 필요하면 글자를 줄임
                                final slot = meta.parentAxisSize / buckets.length;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: SizedBox(
                                    // 이웃 라벨과 붙어 보이지 않도록 칸의 85%만 사용
                                    width: slot * 0.85,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        buckets[i].label,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          for (int i = 0; i < buckets.length; i++)
                            BarChartGroupData(
                              x: i,
                              barsSpace: 4,
                              barRods: [
                                BarChartRodData(
                                  toY: buckets[i].done.toDouble(),
                                  color: const Color(0xFF6C5CE7),
                                  width: 10,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                BarChartRodData(
                                  toY: buckets[i].todo.toDouble(),
                                  color: const Color(0xFFFFC078),
                                  width: 10,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LegendDot(color: Color(0xFF6C5CE7), label: '완료'),
                      SizedBox(width: 16),
                      _LegendDot(color: Color(0xFFFFC078), label: '미완료'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _CategoryBreakdown(todos: _repo.todos),
          ],
        ),
      ),
    );
  }

  double _maxY(List<_Bucket> buckets) {
    double m = 0;
    for (final b in buckets) {
      if (b.done > m) m = b.done.toDouble();
      if (b.todo > m) m = b.todo.toDouble();
    }
    if (m == 0) return 5;
    return (m + 1).ceilToDouble();
  }
}

class _Bucket {
  _Bucket({required this.label, required this.done, required this.todo});
  final String label;
  final int done;
  final int todo;
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.range, required this.onChanged});
  final GraphRange range;
  final ValueChanged<GraphRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget btn(GraphRange r, String label) {
      final selected = range == r;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? scheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? scheme.onPrimary
                    : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          btn(GraphRange.day, '일별 (7일)'),
          btn(GraphRange.month, '월별 (6개월)'),
          btn(GraphRange.year, '년별 (5년)'),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.done,
    required this.ratio,
  });
  final int total;
  final int done;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            height: 86,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 86,
                  height: 86,
                  child: CircularProgressIndicator(
                    value: ratio,
                    strokeWidth: 9,
                    backgroundColor:
                        scheme.primary.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(scheme.primary),
                  ),
                ),
                Text(
                  '${(ratio * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('전체 진행률',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    )),
                const SizedBox(height: 4),
                Text(
                  '$done / $total 개 완료',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            )),
      ],
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.todos});
  final List<Todo> todos;

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final c in TodoCategory.values)
        c: todos.where((t) => t.category == c).length,
    };
    final maxCount =
        counts.values.fold<int>(0, (m, v) => v > m ? v : m).clamp(1, 1 << 30);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('카테고리 분포',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          for (final c in TodoCategory.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(c.icon, color: c.color, size: 18),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 50,
                    child: Text(c.label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: counts[c]! / maxCount,
                        minHeight: 10,
                        backgroundColor: c.color.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation(c.color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${counts[c]}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
