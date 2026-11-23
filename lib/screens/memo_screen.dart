import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:intl/intl.dart';

import '../data/memo_repository.dart';
import '../models/memo.dart';
import '../models/memo_drawing.dart';
import '../widgets/memo_canvas.dart';
import '../widgets/memo_drawing_painter.dart';
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
            m.content.toLowerCase().contains(q) ||
            (m.drawing?.searchText.toLowerCase().contains(q) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final all = _repo.memos;
    final list = _filtered;
    // 카드 크기를 화면 너비와 상관없이 일정하게 유지
    // (세로 휴대폰 2칸, 가로 모드·태블릿은 화면 폭에 따라 3~6칸)
    final textScale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final cardHeight = 150 * textScale.clamp(1.0, 1.35);
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
                      '아직 작성한 메모가 없어요.\n떠오르는 생각을 글이나 그림으로 남겨보세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, height: 1.5),
                    ),
                  ],
                ),
              ),
            )
          : SafeArea(
              bottom: false,
              child: Column(
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
                                style: TextStyle(
                                    color: scheme.onSurfaceVariant)),
                          )
                        : GridView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 200,
                              mainAxisExtent: cardHeight,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
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
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEdit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('새 메모'),
      ),
    );
  }
}

/// 그림을 그리는 종이 색 (어두운 테마에서도 종이처럼 밝게)
Color memoPaperColor(MemoColor c) =>
    c == MemoColor.white ? const Color(0xFFFFFFFF) : c.background;

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
    final hasDrawing = memo.hasDrawing;
    final bodyStyle = TextStyle(
      fontSize: 12.5,
      height: 1.35,
      color: fg.withValues(alpha: 0.8),
    );
    return Semantics(
      button: true,
      label: [
        memo.displayTitle,
        if (hasDrawing) '그림 있음',
        if (memo.pinned) '고정됨',
      ].join(', '),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: fg,
                        ),
                      ),
                    ),
                    if (memo.pinned)
                      Icon(Icons.push_pin_rounded,
                          size: 16, color: fg.withValues(alpha: 0.7)),
                  ],
                ),
                const SizedBox(height: 4),
                if (hasDrawing) ...[
                  if (body.isNotEmpty) ...[
                    Text(body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: bodyStyle),
                    const SizedBox(height: 4),
                  ],
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: memoPaperColor(memo.color),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.6)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      padding: const EdgeInsets.all(4),
                      child: CustomPaint(
                        painter: MemoDrawingPainter(
                            drawing: memo.drawing!, fit: true),
                      ),
                    ),
                  ),
                ] else
                  Expanded(
                    child: Text(
                      body,
                      overflow: TextOverflow.fade,
                      style: bodyStyle,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('M월 d일 HH:mm', 'ko_KR').format(memo.updatedAt),
                  style: TextStyle(
                      fontSize: 11, color: fg.withValues(alpha: 0.55)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _EditMode { text, draw }

/// 메모 작성·수정 화면. 뒤로 가면 자동 저장합니다.
///
/// - 글: 글자 크기 · 굵게 · 기울임 · 밑줄 · 취소선 · 글자색 · 형광 · 정렬 · 목록 · 체크리스트
/// - 그림: 펜 · 형광펜 · 지우개 · 글상자 ([MemoCanvas])
class MemoEditScreen extends StatefulWidget {
  const MemoEditScreen({super.key, this.memo});
  final Memo? memo;

  @override
  State<MemoEditScreen> createState() => _MemoEditScreenState();
}

class _MemoEditScreenState extends State<MemoEditScreen> {
  final _repo = MemoRepository.instance;
  late final TextEditingController _titleCtrl;
  late final QuillController _quill;
  final _editorFocus = FocusNode();
  final _editorScroll = ScrollController();
  late MemoColor _color;
  late bool _pinned;
  late MemoDrawing _drawing;
  late _EditMode _mode;
  late final String _initialSnapshot;
  bool _deleted = false;

  bool get _isNew => widget.memo == null;

  @override
  void initState() {
    super.initState();
    final m = widget.memo;
    _titleCtrl = TextEditingController(text: m?.title ?? '');
    _quill = QuillController(
      document: _documentFor(m),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _color = m?.color ?? MemoColor.white;
    _pinned = m?.pinned ?? false;
    _drawing = m?.drawing ?? const MemoDrawing();
    // 글 없이 그림만 있는 메모는 그림 화면으로 열기
    _mode = (m != null && m.hasDrawing && m.content.trim().isEmpty)
        ? _EditMode.draw
        : _EditMode.text;
    _initialSnapshot = _snapshot();
    if (_isNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mode == _EditMode.text) _editorFocus.requestFocus();
      });
    }
  }

  static Document _documentFor(Memo? m) {
    if (m?.rich != null) {
      try {
        return Document.fromJson(m!.rich!);
      } catch (_) {/* 손상된 서식은 글자만 살림 */}
    }
    final doc = Document();
    final text = m?.content ?? '';
    if (text.isNotEmpty) doc.insert(0, text);
    return doc;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _quill.dispose();
    _editorFocus.dispose();
    _editorScroll.dispose();
    super.dispose();
  }

  String get _plain => _quill.document.toPlainText().trimRight();

  List<dynamic> get _richOps => _quill.document.toDelta().toJson();

  String _snapshot() => jsonEncode({
        't': _titleCtrl.text,
        'r': _richOps,
        'd': _drawing.isEmpty ? null : _drawing.toJson(),
        'c': _color.name,
        'p': _pinned,
      });

  bool get _isEmpty =>
      _titleCtrl.text.trim().isEmpty && _plain.trim().isEmpty && _drawing.isEmpty;

  bool get _changed {
    if (widget.memo == null) return !_isEmpty;
    return _snapshot() != _initialSnapshot;
  }

  Future<void> _save() async {
    if (_deleted || !_changed) return;
    final m = widget.memo;
    final drawing = _drawing.isEmpty ? null : _drawing;
    if (m == null) {
      await _repo.add(
        title: _titleCtrl.text,
        content: _plain,
        color: _color,
        pinned: _pinned,
        rich: _richOps,
        drawing: drawing,
      );
    } else if (_isEmpty) {
      // 내용을 모두 지우면 메모를 삭제
      await _repo.remove(m.id);
    } else {
      m
        ..title = _titleCtrl.text
        ..content = _plain
        ..rich = _richOps
        ..drawing = drawing
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

  Future<void> _pickColor() async {
    final scheme = Theme.of(context).colorScheme;
    final picked = await showModalBottomSheet<MemoColor>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('메모 색상',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final c in MemoColor.values)
                    Semantics(
                      button: true,
                      selected: _color == c,
                      label: '메모 색상 ${c.name}',
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, c),
                        child: Container(
                          width: 44,
                          height: 44,
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
                          child: _color == c
                              ? Icon(Icons.check_rounded, color: c.foreground)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _color = picked);
  }

  void _setMode(_EditMode mode) {
    if (mode == _mode) return;
    FocusScope.of(context).unfocus();
    setState(() => _mode = mode);
  }

  Widget _titleField({double fontSize = 20}) => TextField(
        controller: _titleCtrl,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) {
          if (_mode == _EditMode.text) _editorFocus.requestFocus();
        },
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800),
        decoration: const InputDecoration(
          hintText: '제목',
          filled: false,
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      );

  Widget _modeSwitch() => SegmentedButton<_EditMode>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: const [
          ButtonSegment(
            value: _EditMode.text,
            icon: Icon(Icons.notes_rounded, size: 18),
            label: Text('글'),
          ),
          ButtonSegment(
            value: _EditMode.draw,
            icon: Icon(Icons.draw_rounded, size: 18),
            label: Text('그림'),
          ),
        ],
        selected: {_mode},
        onSelectionChanged: (s) => _setMode(s.first),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _color == MemoColor.white
        ? null
        : (isDark ? _color.background.withValues(alpha: 0.18) : _color.background);
    // 가로 모드처럼 세로가 짧으면 제목과 글/그림 전환을 상단 바에 넣어 공간 확보
    final compact = MediaQuery.sizeOf(context).height < 500;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save();
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          centerTitle: !compact,
          title: compact ? _titleField(fontSize: 18) : Text(_isNew ? '새 메모' : '메모'),
          actions: [
            if (compact) ...[_modeSwitch(), const SizedBox(width: 4)],
            IconButton(
              tooltip: '메모 색상',
              icon: const Icon(Icons.palette_outlined),
              onPressed: _pickColor,
            ),
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
          top: false,
          child: Column(
            children: [
              if (!compact) ...[
                // 제목 + 글/그림 전환
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                  child: Row(
                    children: [
                      Expanded(child: _titleField()),
                      const SizedBox(width: 8),
                      _modeSwitch(),
                    ],
                  ),
                ),
              ],
              Divider(height: 1, color: scheme.outlineVariant),
              Expanded(
                child: IndexedStack(
                  index: _mode.index,
                  children: [
                    _textEditor(scheme),
                    MemoCanvas(
                      initial: _drawing,
                      paper: memoPaperColor(_color),
                      onChanged: (d) => setState(() => _drawing = d),
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

  Widget _textEditor(ColorScheme scheme) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          child: QuillSimpleToolbar(
            controller: _quill,
            config: const QuillSimpleToolbarConfig(
              multiRowsDisplay: false,
              showDividers: true,
              showFontFamily: false,
              showFontSize: true,
              showBoldButton: true,
              showItalicButton: true,
              showUnderLineButton: true,
              showStrikeThrough: true,
              showInlineCode: false,
              showColorButton: true,
              showBackgroundColorButton: true,
              showClearFormat: true,
              showAlignmentButtons: true,
              showLeftAlignment: true,
              showCenterAlignment: true,
              showRightAlignment: true,
              showJustifyAlignment: false,
              showHeaderStyle: false,
              showListNumbers: true,
              showListBullets: true,
              showListCheck: true,
              showCodeBlock: false,
              showQuote: false,
              showIndent: false,
              showLink: false,
              showUndo: true,
              showRedo: true,
              showDirection: false,
              showSearchButton: false,
              showSubscript: false,
              showSuperscript: false,
              buttonOptions: QuillSimpleToolbarButtonOptions(
                fontSize: QuillToolbarFontSizeButtonOptions(
                  tooltip: '글자 크기',
                  defaultDisplayText: '크기',
                  items: {
                    '아주 작게': '11',
                    '작게': '13',
                    '기본': '0',
                    '크게': '20',
                    '아주 크게': '26',
                    '제목': '32',
                  },
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: QuillEditor(
            controller: _quill,
            focusNode: _editorFocus,
            scrollController: _editorScroll,
            config: const QuillEditorConfig(
              placeholder: '내용을 입력하세요',
              padding: EdgeInsets.fromLTRB(20, 12, 20, 40),
              expands: true,
            ),
          ),
        ),
      ],
    );
  }
}
