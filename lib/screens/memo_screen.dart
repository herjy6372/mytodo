import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/memo_repository.dart';
import '../models/memo.dart';
import '../widgets/undo_snackbar.dart';

/// 메모 목록 화면.
class MemoScreen extends StatefulWidget {
  const MemoScreen({super.key});

  @override
  State<MemoScreen> createState() => _MemoScreenState();
}

class _MemoScreenState extends State<MemoScreen> {
  final _repo = MemoRepository.instance;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onChange);
    _repo.load();
  }

  @override
  void dispose() {
    _repo.removeListener(_onChange);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _openEdit({Memo? memo}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MemoEditScreen(memo: memo)),
    );
  }

  List<Memo> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _repo.memos;
    return _repo.memos
        .where((m) =>
            m.title.toLowerCase().contains(q) ||
            m.content.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final all = _repo.memos;
    final list = _filtered;
    return Scaffold(
      appBar: AppBar(title: const Text('메모')),
      body: all.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sticky_note_2_outlined,
                        size: 72,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      '아직 작성한 메모가 없어요.\n떠오르는 생각을 가볍게 남겨보세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, height: 1.5),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: '메모 검색',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            ),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                Expanded(
                  child: list.isEmpty
                      ? Center(
                          child: Text('검색 결과가 없어요.',
                              style:
                                  TextStyle(color: scheme.onSurfaceVariant)),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.9,
                          ),
                          itemCount: list.length,
                          itemBuilder: (_, i) => _MemoCard(
                            memo: list[i],
                            onTap: () => _openEdit(memo: list[i]),
                            onLongPress: () =>
                                _repo.togglePinned(list[i].id),
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEdit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('새 메모'),
      ),
    );
  }
}

class _MemoCard extends StatelessWidget {
  const _MemoCard({
    required this.memo,
    required this.onTap,
    required this.onLongPress,
  });
  final Memo memo;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = memo.color == MemoColor.white
        ? (Theme.of(context).cardTheme.color ?? scheme.surface)
        : (isDark
            ? memo.color.background.withValues(alpha: 0.18)
            : memo.color.background);
    final fg = memo.color == MemoColor.white || isDark
        ? scheme.onSurface
        : memo.color.foreground;
    final body = memo.title.trim().isEmpty
        ? memo.content.trim().split('\n').skip(1).join('\n')
        : memo.content.trim();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      memo.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: fg,
                      ),
                    ),
                  ),
                  if (memo.pinned)
                    Icon(Icons.push_pin_rounded,
                        size: 18, color: fg.withValues(alpha: 0.7)),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  body,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: fg.withValues(alpha: 0.8),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                DateFormat('M월 d일 HH:mm', 'ko_KR').format(memo.updatedAt),
                style: TextStyle(
                    fontSize: 11, color: fg.withValues(alpha: 0.55)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 메모 작성·수정 화면. 뒤로 가면 자동 저장합니다.
class MemoEditScreen extends StatefulWidget {
  const MemoEditScreen({super.key, this.memo});
  final Memo? memo;

  @override
  State<MemoEditScreen> createState() => _MemoEditScreenState();
}

class _MemoEditScreenState extends State<MemoEditScreen> {
  final _repo = MemoRepository.instance;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late MemoColor _color;
  late bool _pinned;
  bool _deleted = false;

  bool get _isNew => widget.memo == null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.memo?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.memo?.content ?? '');
    _color = widget.memo?.color ?? MemoColor.white;
    _pinned = widget.memo?.pinned ?? false;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  bool get _isEmpty =>
      _titleCtrl.text.trim().isEmpty && _contentCtrl.text.trim().isEmpty;

  bool get _changed {
    final m = widget.memo;
    if (m == null) return !_isEmpty;
    return m.title != _titleCtrl.text ||
        m.content != _contentCtrl.text ||
        m.color != _color ||
        m.pinned != _pinned;
  }

  Future<void> _save() async {
    if (_deleted || !_changed) return;
    final m = widget.memo;
    if (m == null) {
      await _repo.add(
        title: _titleCtrl.text,
        content: _contentCtrl.text,
        color: _color,
        pinned: _pinned,
      );
    } else if (_isEmpty) {
      // 내용을 모두 지우면 메모를 삭제
      await _repo.remove(m.id);
    } else {
      m
        ..title = _titleCtrl.text
        ..content = _contentCtrl.text
        ..color = _color
        ..pinned = _pinned;
      await _repo.update(m);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('메모 삭제'),
        content: const Text('이 메모를 삭제할까요? 삭제한 뒤 잠시 동안 되돌릴 수 있어요.'),
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
    if (ok != true || !mounted) return;
    _deleted = true;
    final memo = widget.memo;
    if (memo != null) {
      final messenger = ScaffoldMessenger.of(context);
      await _repo.remove(memo.id);
      showUndoSnackBar(messenger, '메모 삭제됨', () => _repo.restore(memo));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _color == MemoColor.white
        ? null
        : (isDark ? _color.background.withValues(alpha: 0.18) : _color.background);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save();
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          title: Text(_isNew ? '새 메모' : '메모'),
          actions: [
            IconButton(
              tooltip: _pinned ? '고정 해제' : '맨 위에 고정',
              icon: Icon(_pinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined),
              onPressed: () => setState(() => _pinned = !_pinned),
            ),
            if (!_isNew)
              IconButton(
                tooltip: '삭제',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: _delete,
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    TextField(
                      controller: _titleCtrl,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800),
                      decoration: const InputDecoration(
                        hintText: '제목',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                    TextField(
                      controller: _contentCtrl,
                      autofocus: _isNew,
                      maxLines: null,
                      minLines: 12,
                      keyboardType: TextInputType.multiline,
                      style: const TextStyle(fontSize: 15, height: 1.6),
                      decoration: const InputDecoration(
                        hintText: '내용을 입력하세요',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),
              // 색상 선택
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final c in MemoColor.values)
                      GestureDetector(
                        onTap: () => setState(() => _color = c),
                        child: Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: c.background,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _color == c
                                  ? scheme.primary
                                  : scheme.outlineVariant,
                              width: _color == c ? 3 : 1,
                            ),
                          ),
                        ),
                      ),
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
