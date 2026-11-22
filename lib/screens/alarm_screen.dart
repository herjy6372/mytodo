import 'package:flutter/material.dart';

import '../data/alarm_repository.dart';
import '../models/alarm.dart';
import '../services/notification_service.dart';

/// 알람 목록 화면 — 아침 깨우기 / 잘 때 알람 / 일반 알람.
class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  final _repo = AlarmRepository.instance;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onChange);
    _repo.load();
    // 알람이 울리려면 알림 권한이 필요
    NotificationService.instance.requestPermission();
  }

  @override
  void dispose() {
    _repo.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _openEdit({Alarm? alarm, AlarmType? type}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => AlarmEditScreen(alarm: alarm, initialType: type)),
    );
  }

  Future<void> _pickTypeAndAdd() async {
    final type = await showModalBottomSheet<AlarmType>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in AlarmType.values)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: t.color.withValues(alpha: 0.15),
                  child: Icon(t.icon, color: t.color),
                ),
                title: Text(t.label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(t.defaultMessage),
                onTap: () => Navigator.pop(ctx, t),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (type != null) await _openEdit(type: type);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final list = _repo.alarms;
    return Scaffold(
      appBar: AppBar(title: const Text('알람')),
      body: list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.alarm_rounded,
                        size: 72,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      '등록된 알람이 없어요.\n아침 기상이나 잠들 시간을 알람으로 받아보세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, height: 1.5),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: list.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                if (i == list.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '할 일에도 알람을 걸 수 있어요. 할 일 추가 화면에서 "알람으로 알리기"를 켜 주세요.\n'
                      '휴대폰이 무음 모드이면 알람음이 작게 들리거나 들리지 않을 수 있어요.',
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: scheme.onSurfaceVariant),
                    ),
                  );
                }
                final a = list[i];
                return _AlarmTile(
                  alarm: a,
                  onTap: () => _openEdit(alarm: a),
                  onToggle: (v) => _repo.setEnabled(a.id, v),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickTypeAndAdd,
        icon: const Icon(Icons.add_alarm_rounded),
        label: const Text('알람 추가'),
      ),
    );
  }
}

class _AlarmTile extends StatelessWidget {
  const _AlarmTile({
    required this.alarm,
    required this.onTap,
    required this.onToggle,
  });
  final Alarm alarm;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = alarm.enabled;
    final h = alarm.hour;
    final period = h < 12 ? '오전' : '오후';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    final mm = alarm.minute.toString().padLeft(2, '0');
    final fg = on ? scheme.onSurface : scheme.onSurfaceVariant.withValues(alpha: 0.6);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: alarm.type.color.withValues(alpha: on ? 0.15 : 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(alarm.type.icon,
                    color: alarm.type.color.withValues(alpha: on ? 1 : 0.4)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(period,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: fg)),
                        const SizedBox(width: 4),
                        Text('$h12:$mm',
                            style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: fg)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        alarm.label.trim().isNotEmpty
                            ? alarm.label.trim()
                            : alarm.type.label,
                        alarm.repeatText,
                      ].join(' · '),
                      style: TextStyle(fontSize: 13, color: fg),
                    ),
                  ],
                ),
              ),
              Switch(value: on, onChanged: onToggle),
            ],
          ),
        ),
      ),
    );
  }
}

/// 알람 추가·수정 화면.
class AlarmEditScreen extends StatefulWidget {
  const AlarmEditScreen({super.key, this.alarm, this.initialType});
  final Alarm? alarm;
  final AlarmType? initialType;

  @override
  State<AlarmEditScreen> createState() => _AlarmEditScreenState();
}

class _AlarmEditScreenState extends State<AlarmEditScreen> {
  final _repo = AlarmRepository.instance;
  late AlarmType _type;
  late TimeOfDay _time;
  late Set<int> _weekdays;
  late final TextEditingController _labelCtrl;

  bool get _isNew => widget.alarm == null;

  static const _dayNames = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  void initState() {
    super.initState();
    final a = widget.alarm;
    _type = a?.type ?? widget.initialType ?? AlarmType.custom;
    _time = a?.time ?? _defaultTime(_type);
    _weekdays = {...?a?.weekdays};
    if (a == null && _type != AlarmType.custom) {
      _weekdays = {1, 2, 3, 4, 5, 6, 7};
    }
    _labelCtrl = TextEditingController(text: a?.label ?? '');
  }

  static TimeOfDay _defaultTime(AlarmType t) => switch (t) {
        AlarmType.wakeUp => const TimeOfDay(hour: 7, minute: 0),
        AlarmType.bedtime => const TimeOfDay(hour: 23, minute: 0),
        AlarmType.custom => TimeOfDay.fromDateTime(
            DateTime.now().add(const Duration(minutes: 5))),
      };

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _save() async {
    final a = widget.alarm;
    if (a == null) {
      await _repo.add(
        type: _type,
        hour: _time.hour,
        minute: _time.minute,
        weekdays: _weekdays,
        label: _labelCtrl.text.trim(),
      );
    } else {
      a
        ..type = _type
        ..hour = _time.hour
        ..minute = _time.minute
        ..weekdays = _weekdays
        ..label = _labelCtrl.text.trim()
        ..enabled = true;
      await _repo.update(a);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_nextRingText())),
    );
    Navigator.of(context).pop();
  }

  /// "8시간 30분 후에 알람이 울려요" 안내.
  String _nextRingText() {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, _time.hour, _time.minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    if (_weekdays.isNotEmpty) {
      while (!_weekdays.contains(next.weekday)) {
        next = next.add(const Duration(days: 1));
      }
    }
    // 남은 시간을 분 단위로 올림 (4분 40초 → 5분)
    final totalMin = (next.difference(now).inSeconds / 60).ceil();
    final d = totalMin ~/ (24 * 60);
    final h = (totalMin ~/ 60) % 24;
    final m = totalMin % 60;
    final parts = [
      if (d > 0) '$d일',
      if (h > 0) '$h시간',
      if (m > 0) '$m분',
    ];
    return '${parts.join(' ')} 후에 알람이 울려요.';
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('알람 삭제'),
        content: const Text('이 알람을 삭제할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.remove(widget.alarm!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final h = _time.hour;
    final period = h < 12 ? '오전' : '오후';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    final mm = _time.minute.toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '알람 추가' : '알람 편집'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: '삭제',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // 시각
            InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: _type.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(period,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Text('$h12:$mm',
                            style: const TextStyle(
                                fontSize: 56, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    Text('눌러서 시간 변경',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const _Label('종류'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final t in AlarmType.values)
                  ChoiceChip(
                    avatar: Icon(t.icon, size: 18, color: t.color),
                    label: Text(t.label),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const _Label('반복'),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(
                      () => _weekdays = {1, 2, 3, 4, 5, 6, 7}),
                  child: const Text('매일'),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _weekdays = {1, 2, 3, 4, 5}),
                  child: const Text('평일'),
                ),
                TextButton(
                  onPressed: () => setState(() => _weekdays = {}),
                  child: const Text('한 번'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var d = 1; d <= 7; d++)
                  _DayChip(
                    label: _dayNames[d - 1],
                    selected: _weekdays.contains(d),
                    weekend: d >= 6,
                    onTap: () => setState(() {
                      _weekdays.contains(d)
                          ? _weekdays.remove(d)
                          : _weekdays.add(d);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const _Label('알람 이름 (선택)'),
            const SizedBox(height: 8),
            TextField(
              controller: _labelCtrl,
              maxLength: 30,
              decoration: InputDecoration(
                hintText: _type.defaultMessage,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('저장'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700));
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.weekend,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final bool weekend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? scheme.primary : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected
                ? scheme.onPrimary
                : (weekend ? const Color(0xFFFF6B81) : scheme.onSurface),
          ),
        ),
      ),
    );
  }
}
