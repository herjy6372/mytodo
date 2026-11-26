import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/world_clock_repository.dart';

class WorldClockScreen extends StatefulWidget {
  const WorldClockScreen({super.key});

  @override
  State<WorldClockScreen> createState() => _WorldClockScreenState();
}

class _WorldClockScreenState extends State<WorldClockScreen> {
  final _repo = WorldClockRepository.instance;
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onChange);
    _repo.load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    _repo.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _addCity() async {
    final selected = _repo.selected.map((c) => c.tzId).toSet();
    final pick = await showModalBottomSheet<WorldCity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final available =
            WorldCity.all.where((c) => !selected.contains(c.tzId)).toList();
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text('도시 선택',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.6,
                child: available.isEmpty
                    ? const Center(child: Text('추가할 수 있는 도시가 없습니다.'))
                    : ListView.builder(
                        itemCount: available.length,
                        itemBuilder: (_, i) {
                          final c = available[i];
                          return ListTile(
                            leading: const Icon(Icons.public_rounded),
                            title: Text(c.label),
                            subtitle: Text(c.tzId),
                            onTap: () => Navigator.pop(ctx, c),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
    if (pick != null) {
      await _repo.add(pick.tzId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cities = _repo.selected;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('세계 시각')),
      body: SafeArea(
        child: cities.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.public_rounded,
                          size: 72,
                          color: scheme.onSurfaceVariant
                              .withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(
                        '추가된 도시가 없습니다.\n오른쪽 아래 [+ 추가]로 도시를 골라 보세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: cities.length,
                onReorderItem: (o, n) => _repo.reorder(o, n),
                buildDefaultDragHandles: false,
                itemBuilder: (_, i) {
                  final c = cities[i];
                  return Padding(
                    key: ValueKey(c.tzId),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CityTile(
                      index: i,
                      city: c,
                      onRemove: () => _repo.remove(c.tzId),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCity,
        icon: const Icon(Icons.add_rounded),
        label: const Text('도시 추가'),
      ),
    );
  }
}

class _CityTile extends StatelessWidget {
  const _CityTile({
    required this.index,
    required this.city,
    required this.onRemove,
  });
  final int index;
  final WorldCity city;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    DateTime now;
    try {
      now = tz.TZDateTime.now(tz.getLocation(city.tzId));
    } catch (_) {
      now = DateTime.now();
    }
    final timeText = DateFormat('HH:mm:ss').format(now);
    final dateText = DateFormat('M월 d일 (E)', 'ko_KR').format(now);

    // GMT 오프셋 계산 (해당 도시 기준 - UTC)
    final offset = now.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final h = offset.inHours.abs();
    final m = (offset.inMinutes.abs() % 60);
    final off = 'GMT$sign$h${m == 0 ? '' : ':${m.toString().padLeft(2, '0')}'}';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 4, 12),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Icon(Icons.drag_indicator_rounded,
                  color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 4),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.public_rounded,
                  color: scheme.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    city.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // 큰 글씨에서 한 줄에 다 들어가지 않으면 날짜를 다음 줄로 내려
                  // 잘리지 않고 전부 보이게 함
                  DefaultTextStyle.merge(
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        Text(off),
                        Text(dateText),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              timeText,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: scheme.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              color: scheme.onSurfaceVariant,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
