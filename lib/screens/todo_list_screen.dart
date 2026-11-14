import 'package:flutter/material.dart';

import '../data/todo_repository.dart';
import '../models/todo.dart';
import '../widgets/rounded_todo_tile.dart';
import 'todo_edit_screen.dart';

/// 할 일 목록 화면.
/// 카테고리 필터(전체/업무/공부/...)를 둥근 칩으로 제공하며,
/// 할 일 항목은 둥근 카드형 타일로 표시됩니다.
class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final _repo = TodoRepository.instance;
  TodoCategory? _filter; // null = 전체

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

  @override
  Widget build(BuildContext context) {
    final grouped = _repo.groupByCategory();
    final categories = _filter == null
        ? TodoCategory.values
        : <TodoCategory>[_filter!];

    return Scaffold(
      appBar: AppBar(title: const Text('할 일 목록')),
      body: SafeArea(
        child: Column(
          children: [
            _FilterBar(
              selected: _filter,
              onChanged: (c) => setState(() => _filter = c),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                children: [
                  for (final c in categories)
                    if (grouped[c]!.isNotEmpty) ...[
                      _CategoryHeader(category: c, count: grouped[c]!.length),
                      const SizedBox(height: 8),
                      ...grouped[c]!.map(
                        (t) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: RoundedTodoTile(
                            todo: t,
                            onToggle: () => _repo.toggleDone(t.id),
                            onTap: () => _openEdit(todo: t),
                            onDelete: () => _repo.remove(t.id),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  if (grouped.values.every((l) => l.isEmpty))
                    const _EmptyState(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEdit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('할 일 추가'),
      ),
    );
  }

  Future<void> _openEdit({Todo? todo}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TodoEditScreen(todo: todo),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});
  final TodoCategory? selected;
  final ValueChanged<TodoCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = <Widget>[
      _Chip(
        label: '전체',
        color: scheme.primary,
        selected: selected == null,
        onTap: () => onChanged(null),
      ),
      ...TodoCategory.values.map(
        (c) => _Chip(
          label: c.label,
          icon: c.icon,
          color: c.color,
          selected: selected == c,
          onTap: () => onChanged(c),
        ),
      ),
    ];

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => items[i],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : color.withValues(alpha: 0.10),
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 16,
                    color: selected ? Colors.white : color),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category, required this.count});
  final TodoCategory category;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4, bottom: 4),
      child: Row(
        children: [
          Icon(category.icon, color: category.color, size: 18),
          const SizedBox(width: 8),
          Text(
            category.label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: category.color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined,
              size: 64, color: Colors.black.withValues(alpha: 0.25)),
          const SizedBox(height: 12),
          Text(
            '아직 할 일이 없습니다.\n오른쪽 아래 [할 일 추가] 버튼으로 시작해 보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.5),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
