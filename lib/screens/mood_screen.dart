import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/mood_repository.dart';
import '../models/mood.dart';

class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  final _repo = MoodRepository.instance;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onChange);
    _repo.load();
  }

  @override
  void dispose() {
    _repo.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _openEdit({MoodEntry? entry}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MoodEditScreen(entry: entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final list = _repo.entries;
    return Scaffold(
      appBar: AppBar(title: const Text('기분 한 줄')),
      body: list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_note_rounded,
                        size: 72,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      '아직 작성한 기분 한 줄이 없어요.\n오늘 기분을 한 줄로 남겨보세요.',
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
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final e = list[i];
                return _MoodTile(entry: e, onTap: () => _openEdit(entry: e));
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEdit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('오늘 기분'),
      ),
    );
  }
}

class _MoodTile extends StatelessWidget {
  const _MoodTile({required this.entry, required this.onTap});
  final MoodEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateText = DateFormat('y년 M월 d일 (E)', 'ko_KR').format(entry.date);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: entry.level.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(entry.level.icon,
                    color: entry.level.color, size: 32),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          entry.level.label,
                          style: TextStyle(
                            color: entry.level.color,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateText,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (entry.note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MoodEditScreen extends StatefulWidget {
  const MoodEditScreen({super.key, this.entry});
  final MoodEntry? entry;

  @override
  State<MoodEditScreen> createState() => _MoodEditScreenState();
}

class _MoodEditScreenState extends State<MoodEditScreen> {
  late DateTime _date;
  late MoodLevel _level;
  late final TextEditingController _noteCtrl;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _date = e?.date ?? DateTime.now();
    _level = e?.level ?? MoodLevel.neutral;
    _noteCtrl = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(today.year, today.month, today.day),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final note = _noteCtrl.text.trim();
    final repo = MoodRepository.instance;
    if (_isEditing) {
      await repo.update(widget.entry!.copyWith(
        date: _date,
        level: _level,
        note: note,
      ));
    } else {
      await repo.add(date: _date, level: _level, note: note);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: const Text('삭제하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await MoodRepository.instance.remove(widget.entry!.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateText = DateFormat('y년 M월 d일 (E)', 'ko_KR').format(_date);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '기분 수정' : '기분 한 줄'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Label('날짜'),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(20),
                child: InputDecorator(
                  decoration:
                      const InputDecoration(prefixIcon: Icon(Icons.event)),
                  child: Text(dateText),
                ),
              ),
              const SizedBox(height: 16),
              _Label('오늘의 기분'),
              SizedBox(
                height: 96,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final m in MoodLevel.values)
                      _MoodPicker(
                        level: m,
                        selected: _level == m,
                        onTap: () => setState(() => _level = m),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Label('한 줄 메모 (100자 이내)'),
              TextField(
                controller: _noteCtrl,
                maxLength: 100,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '오늘 하루는 어땠나요?',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(_isEditing ? '수정 완료' : '저장하기'),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '※ 미래 날짜는 선택할 수 없어요.',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF555566),
        ),
      ),
    );
  }
}

class _MoodPicker extends StatelessWidget {
  const _MoodPicker({
    required this.level,
    required this.selected,
    required this.onTap,
  });
  final MoodLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: selected ? 64 : 52,
            height: selected ? 64 : 52,
            decoration: BoxDecoration(
              color: level.color
                  .withValues(alpha: selected ? 0.25 : 0.10),
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    selected ? level.color : Colors.transparent,
                width: 2,
              ),
            ),
            child: Icon(level.icon,
                color: level.color, size: selected ? 36 : 28),
          ),
          const SizedBox(height: 4),
          Text(
            level.label,
            style: TextStyle(
              fontSize: 11,
              color: selected ? level.color : null,
              fontWeight:
                  selected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
