import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/todo_repository.dart';
import '../models/todo.dart';

/// 할 일 추가/편집 화면.
class TodoEditScreen extends StatefulWidget {
  const TodoEditScreen({super.key, this.todo, this.initialDate});

  final Todo? todo;
  final DateTime? initialDate;

  @override
  State<TodoEditScreen> createState() => _TodoEditScreenState();
}

class _TodoEditScreenState extends State<TodoEditScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _placeCtrl;
  late final TextEditingController _memoCtrl;
  late DateTime _dueDate;
  late TodoCategory _category;

  bool get _isEditing => widget.todo != null;

  @override
  void initState() {
    super.initState();
    final t = widget.todo;
    _titleCtrl = TextEditingController(text: t?.title ?? '');
    _placeCtrl = TextEditingController(text: t?.place ?? '');
    _memoCtrl = TextEditingController(text: t?.memo ?? '');
    _dueDate = t?.dueDate ??
        widget.initialDate ??
        DateTime.now().add(const Duration(hours: 1));
    _category = t?.category ?? TodoCategory.work;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _placeCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('ko', 'KR'),
    );
    if (picked == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate),
    );
    if (time == null) return;
    setState(() {
      _dueDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('무엇을 할지 입력해 주세요.')),
      );
      return;
    }
    final repo = TodoRepository.instance;
    if (_isEditing) {
      await repo.update(
        widget.todo!.copyWith(
          title: title,
          place: _placeCtrl.text.trim(),
          dueDate: _dueDate,
          category: _category,
          memo: _memoCtrl.text.trim(),
        ),
      );
    } else {
      await repo.add(
        title: title,
        place: _placeCtrl.text.trim(),
        dueDate: _dueDate,
        category: _category,
        memo: _memoCtrl.text.trim(),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text('삭제하시겠어요?'),
        content: const Text('한 번 삭제하면 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await TodoRepository.instance.remove(widget.todo!.id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final dateText =
        DateFormat('y년 M월 d일 (E) HH:mm', 'ko_KR').format(_dueDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '할 일 편집' : '할 일 추가'),
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
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Label('무엇을 (제목)'),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  hintText: '예) 보고서 마무리, 운동 다녀오기',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              const _Label('어디서 (장소)'),
              TextField(
                controller: _placeCtrl,
                decoration: const InputDecoration(
                  hintText: '예) 사무실, 헬스장, 집',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              const _Label('언제 (날짜·시간)'),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(20),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.event_outlined),
                  ),
                  child: Text(
                    dateText,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const _Label('카테고리'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TodoCategory.values.map((c) {
                  final selected = c == _category;
                  return ChoiceChip(
                    selected: selected,
                    label: Text(c.label),
                    avatar: Icon(c.icon,
                        size: 18,
                        color: selected ? Colors.white : c.color),
                    selectedColor: c.color,
                    backgroundColor: c.color.withValues(alpha: 0.10),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : c.color,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(color: c.color.withValues(alpha: 0.4)),
                    shape: const StadiumBorder(),
                    onSelected: (_) => setState(() => _category = c),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const _Label('메모 (선택)'),
              TextField(
                controller: _memoCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: '추가로 남기고 싶은 메모',
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(_isEditing ? '수정 완료' : '추가하기'),
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
