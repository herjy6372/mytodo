import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/memo_drawing.dart';
import 'memo_drawing_painter.dart';

enum _Tool { pen, highlighter, eraser, text, hand }

/// 펜·형광펜 색상
const memoInkColors = <int>[
  0xFF222222, // 검정
  0xFF7A7F88, // 회색
  0xFFE53935, // 빨강
  0xFFFB8C00, // 주황
  0xFFFDD835, // 노랑
  0xFF43A047, // 초록
  0xFF1E88E5, // 파랑
  0xFF8E24AA, // 보라
];

const _penSizes = [4.0, 8.0, 16.0];
const _highlighterSizes = [20.0, 34.0, 52.0];
const _eraserSizes = [20.0, 44.0, 90.0];
const _sizeLabels = ['가늘게', '보통', '굵게'];

/// 메모 그리기 판.
///
/// - 한 손가락(또는 펜)으로 그리고, 두 손가락으로 위아래로 움직입니다.
/// - 펜 · 형광펜 · 지우개(부분/획 전체) · 글상자 · 손(화면 이동) 도구
/// - 실행 취소 · 다시 실행 · 모두 지우기
/// - 그림은 가로 1000 기준 가상 좌표로 저장해 세로·가로 모드와 태블릿에서 같은 비율로 보입니다.
class MemoCanvas extends StatefulWidget {
  const MemoCanvas({
    super.key,
    required this.initial,
    required this.onChanged,
    required this.paper,
  });

  final MemoDrawing initial;
  final ValueChanged<MemoDrawing> onChanged;

  /// 종이 색 (메모 색상)
  final Color paper;

  @override
  State<MemoCanvas> createState() => _MemoCanvasState();
}

class _MemoCanvasState extends State<MemoCanvas> {
  late MemoDrawing _d = widget.initial;
  final _undo = <MemoDrawing>[];
  final _redo = <MemoDrawing>[];
  final _scroll = ScrollController();

  _Tool _tool = _Tool.pen;
  int _color = memoInkColors.first;
  int _penSize = 1, _highlighterSize = 1, _eraserSize = 1;
  bool _strokeEraser = false;

  double _scale = 1;
  final _pointers = <int, Offset>{};
  bool _multi = false;

  /// 획 지우개로 문지르는 중
  bool _erasing = false;

  // 그리는 중인 획
  DrawTool? _curTool;
  List<Offset>? _curPoints;
  DrawStroke? _cur;
  MemoDrawing? _before;

  // 글상자 이동
  String? _dragTextId;
  Offset? _dragStart;
  Offset? _dragOrigPos;
  bool _moved = false;
  Offset? _tapAt;
  String? _selectedText;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  MemoDrawing _copy({double? height, List<DrawStroke>? strokes, List<DrawText>? texts}) =>
      MemoDrawing(
        height: height ?? _d.height,
        strokes: strokes ?? _d.strokes,
        texts: texts ?? _d.texts,
      );

  void _pushUndo(MemoDrawing before) {
    _undo.add(before);
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
    widget.onChanged(_d);
  }

  void _doUndo() {
    if (_undo.isEmpty) return;
    setState(() {
      _redo.add(_d);
      _d = _undo.removeLast();
      _selectedText = null;
    });
    widget.onChanged(_d);
  }

  void _doRedo() {
    if (_redo.isEmpty) return;
    setState(() {
      _undo.add(_d);
      _d = _redo.removeLast();
      _selectedText = null;
    });
    widget.onChanged(_d);
  }

  Future<void> _clearAll() async {
    if (_d.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('그림 모두 지우기'),
        content: const Text('그린 그림과 글상자를 모두 지울까요?\n실행 취소로 되돌릴 수 있어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('모두 지우기')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final before = _d;
    setState(() {
      _d = const MemoDrawing();
      _selectedText = null;
    });
    _pushUndo(before);
  }

  Offset _v(Offset local) => local / _scale;

  double get _strokeWidth => switch (_curTool) {
        DrawTool.highlighter => _highlighterSizes[_highlighterSize],
        DrawTool.eraser => _eraserSizes[_eraserSize],
        _ => _penSizes[_penSize],
      };

  // ───────────── 포인터 처리 ─────────────

  void _onDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_tool == _Tool.hand && e.kind != PointerDeviceKind.invertedStylus) return;
    if (_pointers.length >= 2) {
      // 두 손가락: 그리던 획을 취소하고 화면 이동으로 전환
      _cancelCurrent();
      _multi = true;
      return;
    }
    _multi = false;
    final p = _v(e.localPosition);
    var tool = _tool;
    // 펜 뒤쪽(지우개 버튼)으로 문지르면 지우개
    if (e.kind == PointerDeviceKind.invertedStylus) tool = _Tool.eraser;

    switch (tool) {
      case _Tool.pen:
      case _Tool.highlighter:
      case _Tool.eraser:
        _before = _d;
        _selectedText = null;
        if (tool == _Tool.eraser && _strokeEraser) {
          _curTool = null;
          _erasing = true;
          _eraseAt(p);
          return;
        }
        _curTool = switch (tool) {
          _Tool.highlighter => DrawTool.highlighter,
          _Tool.eraser => DrawTool.eraser,
          _ => DrawTool.pen,
        };
        _curPoints = [p];
        setState(() => _cur = DrawStroke(
            tool: _curTool!, color: _color, width: _strokeWidth, points: _curPoints!));
      case _Tool.text:
        _moved = false;
        _tapAt = p;
        _dragTextId = null;
        for (final t in _d.texts.reversed) {
          if (drawTextRect(t).contains(p)) {
            _dragTextId = t.id;
            _dragStart = p;
            _dragOrigPos = t.pos;
            _before = _d;
            break;
          }
        }
        setState(() => _selectedText = _dragTextId);
      case _Tool.hand:
        break;
    }
  }

  void _onMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    if (_tool == _Tool.hand && _curPoints == null && !_multi && !_erasing) return;
    if (_multi) {
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      final next = (pos.pixels - e.delta.dy / _pointers.length)
          .clamp(pos.minScrollExtent, pos.maxScrollExtent);
      _scroll.jumpTo(next);
      return;
    }
    final p = _v(e.localPosition);

    if (_curPoints != null) {
      final last = _curPoints!.last;
      if ((p - last).distance < 1.5) return;
      _curPoints!.add(p);
      _maybeExtend(p);
      setState(() => _cur = DrawStroke(
          tool: _curTool!, color: _color, width: _strokeWidth, points: _curPoints!));
    } else if (_erasing) {
      _eraseAt(p);
    } else if (_tool == _Tool.text && _dragTextId != null) {
      final delta = p - _dragStart!;
      if (!_moved && delta.distance < 8) return;
      _moved = true;
      final np = Offset(
        (_dragOrigPos!.dx + delta.dx).clamp(0, MemoDrawing.pageWidth - 40),
        (_dragOrigPos!.dy + delta.dy).clamp(0, _d.height - 40),
      );
      _maybeExtend(np);
      setState(() {
        _d = _copy(texts: [
          for (final t in _d.texts) t.id == _dragTextId ? t.copyWith(pos: np) : t,
        ]);
      });
    }
  }

  void _onUp(PointerEvent e, {bool cancel = false}) {
    _pointers.remove(e.pointer);
    if (_multi) {
      if (_pointers.isEmpty) _multi = false;
      return;
    }
    if (_curPoints != null) {
      final stroke = DrawStroke(
          tool: _curTool!, color: _color, width: _strokeWidth, points: List.of(_curPoints!));
      final before = _before ?? _d;
      _curPoints = null;
      _curTool = null;
      if (cancel) {
        setState(() => _cur = null);
        return;
      }
      // 지울 획이 없는데 지우개로 문지른 경우는 저장하지 않음
      final useless = stroke.tool == DrawTool.eraser && _d.strokes.isEmpty;
      setState(() {
        _cur = null;
        if (!useless) _d = _copy(strokes: [..._d.strokes, stroke]);
      });
      if (!useless) _pushUndo(before);
      return;
    }
    if (_erasing) {
      _erasing = false;
      if (_before != null && !identical(_before, _d)) _pushUndo(_before!);
      _before = null;
      return;
    }
    if (_tool == _Tool.text && !cancel) {
      if (_dragTextId != null) {
        if (_moved) {
          _pushUndo(_before!);
        } else {
          _editText(_d.texts.firstWhere((t) => t.id == _dragTextId));
        }
      } else if (_tapAt != null) {
        _editText(null, at: _tapAt!);
      }
      _dragTextId = null;
      _before = null;
    }
  }

  void _cancelCurrent() {
    if (_curPoints != null) {
      _curPoints = null;
      _curTool = null;
      setState(() => _cur = null);
    }
    if (_dragTextId != null && _dragOrigPos != null && _moved) {
      final id = _dragTextId;
      setState(() {
        _d = _copy(texts: [
          for (final t in _d.texts) t.id == id ? t.copyWith(pos: _dragOrigPos) : t,
        ]);
      });
    }
    _dragTextId = null;
    _tapAt = null;
  }

  /// 아래쪽 가까이 그리면 페이지를 늘림
  void _maybeExtend(Offset p) {
    if (p.dy > _d.height - 220) {
      _d = _copy(height: _d.height + 700);
    }
  }

  /// 획 지우개: 닿은 획과 글상자를 통째로 지움
  void _eraseAt(Offset p) {
    final r = _eraserSizes[_eraserSize] / 2;
    final strokes = _d.strokes.where((s) {
      if (s.tool == DrawTool.eraser) return true;
      final reach = r + s.width / 2;
      for (var i = 0; i < s.points.length; i++) {
        final a = s.points[i];
        final b = i + 1 < s.points.length ? s.points[i + 1] : a;
        if (_distToSegment(p, a, b) <= reach) return false;
      }
      return true;
    }).toList();
    final texts = _d.texts.where((t) => !drawTextRect(t).inflate(r).contains(p)).toList();
    if (strokes.length != _d.strokes.length || texts.length != _d.texts.length) {
      setState(() => _d = _copy(strokes: strokes, texts: texts));
    }
  }

  static double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  // ───────────── 글상자 ─────────────

  Future<void> _editText(DrawText? existing, {Offset? at}) async {
    final result = await showDialog<_TextResult>(
      context: context,
      builder: (_) => _TextBoxDialog(
        initial: existing,
        // 노란색은 흰 종이에서 잘 안 보여 글상자는 검정으로 시작
        defaultColor: _color == 0xFFFDD835 ? memoInkColors.first : _color,
      ),
    );
    if (!mounted || result == null) return;
    final before = _d;
    setState(() {
      if (result.delete) {
        _d = _copy(texts: _d.texts.where((t) => t.id != existing?.id).toList());
        _selectedText = null;
      } else if (existing != null) {
        _d = _copy(texts: [
          for (final t in _d.texts)
            t.id == existing.id
                ? t.copyWith(
                    text: result.text, size: result.size, color: result.color, bold: result.bold)
                : t,
        ]);
      } else {
        final pos = Offset(
          at!.dx.clamp(0, MemoDrawing.pageWidth - 80),
          math.max(0, at.dy - result.size / 2),
        );
        final t = DrawText(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          pos: pos,
          text: result.text,
          size: result.size,
          color: result.color,
          bold: result.bold,
        );
        _d = _copy(texts: [..._d.texts, t]);
        _selectedText = t.id;
      }
    });
    _pushUndo(before);
  }

  // ───────────── 화면 ─────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, c) {
      final tools = _toolItems(scheme);
      final actions = _actionItems();
      final options = _optionItems(scheme);
      // 가로 모드처럼 세로 공간이 좁으면 도구를 왼쪽 세로 막대로 옮겨 그림 영역을 넓힘
      if (c.maxHeight < 420) {
        Widget rule() => SizedBox(
            width: 120, child: Divider(height: 12, color: scheme.outlineVariant));
        return Row(
          children: [
            SizedBox(
              width: 136,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 16),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 2,
                  runSpacing: 4,
                  children: [
                    ...tools,
                    rule(),
                    ...actions,
                    if (options.isNotEmpty) ...[rule(), ...options],
                  ],
                ),
              ),
            ),
            VerticalDivider(width: 1, color: scheme.outlineVariant),
            Expanded(child: _page(scheme)),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              ...tools,
              const SizedBox(width: 6),
              Container(width: 1, height: 32, color: scheme.outlineVariant),
              const SizedBox(width: 2),
              ...actions,
            ]),
          ),
          if (options.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
              child: Row(children: options),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
            child: Text(_hint,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
          Expanded(child: _page(scheme)),
        ],
      );
    });
  }

  String get _hint => switch (_tool) {
        _Tool.text => '빈 곳을 누르면 글상자를 만들고, 글상자를 누르면 고치고, 끌면 옮겨요.',
        _Tool.hand => '한 손가락으로 위아래로 움직여요.',
        _ => '두 손가락으로 위아래로 움직여요.',
      };

  /// 종이 (스크롤되는 그림판)
  Widget _page(ColorScheme scheme) {
    return LayoutBuilder(builder: (context, c) {
      const margin = 10.0;
      final pageW = c.maxWidth - margin * 2;
      _scale = pageW / MemoDrawing.pageWidth;
      final pageH = _d.height * _scale;
      return Listener(
        onPointerSignal: (e) {
          if (e is PointerScrollEvent && _scroll.hasClients) {
            final pos = _scroll.position;
            _scroll.jumpTo((pos.pixels + e.scrollDelta.dy)
                .clamp(pos.minScrollExtent, pos.maxScrollExtent));
          }
        },
        child: Scrollbar(
          controller: _scroll,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scroll,
            physics: _tool == _Tool.hand
                ? const ClampingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(margin, 4, margin, 40),
            child: Container(
              decoration: BoxDecoration(
                color: widget.paper,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Semantics(
                label: '그림 그리는 곳. 한 손가락으로 그리고 두 손가락으로 위아래로 움직여요.',
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _onDown,
                  onPointerMove: _onMove,
                  onPointerUp: _onUp,
                  onPointerCancel: (e) => _onUp(e, cancel: true),
                  child: CustomPaint(
                    size: Size(pageW, pageH),
                    painter: _PaperPainter(scale: _scale),
                    foregroundPainter: MemoDrawingPainter(
                      drawing: _d,
                      current: _cur,
                      selectedTextId: _tool == _Tool.text ? _selectedText : null,
                      selectColor: scheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  List<Widget> _toolItems(ColorScheme scheme) {
    Widget tool(_Tool t, IconData icon, String label) {
      final on = _tool == t;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: on ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() {
              _tool = t;
              _selectedText = null;
            }),
            child: Semantics(
              selected: on,
              button: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon,
                        size: 22,
                        color: on ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
                    const SizedBox(height: 2),
                    Text(label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                          color: on ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                        )),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return [
      tool(_Tool.pen, Icons.draw_rounded, '펜'),
      tool(_Tool.highlighter, Icons.border_color_rounded, '형광펜'),
      tool(_Tool.eraser, Icons.auto_fix_normal_rounded, '지우개'),
      tool(_Tool.text, Icons.text_fields_rounded, '글상자'),
      tool(_Tool.hand, Icons.pan_tool_alt_rounded, '이동'),
    ];
  }

  List<Widget> _actionItems() => [
        IconButton(
          tooltip: '실행 취소',
          onPressed: _undo.isEmpty ? null : _doUndo,
          icon: const Icon(Icons.undo_rounded),
        ),
        IconButton(
          tooltip: '다시 실행',
          onPressed: _redo.isEmpty ? null : _doRedo,
          icon: const Icon(Icons.redo_rounded),
        ),
        IconButton(
          tooltip: '모두 지우기',
          onPressed: _d.isEmpty ? null : _clearAll,
          icon: const Icon(Icons.delete_sweep_outlined),
        ),
      ];

  List<Widget> _optionItems(ColorScheme scheme) {
    final children = <Widget>[];
    if (_tool == _Tool.pen || _tool == _Tool.highlighter || _tool == _Tool.text) {
      for (final c in memoInkColors) {
        final on = _color == c;
        children.add(Semantics(
          button: true,
          selected: on,
          label: '펜 색상',
          child: GestureDetector(
            onTap: () => setState(() => _color = c),
            child: Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(
                  color: on ? scheme.primary : scheme.outlineVariant,
                  width: on ? 3 : 1,
                ),
              ),
              child: on
                  ? Icon(Icons.check_rounded,
                      size: 16, color: c == 0xFFFDD835 ? Colors.black87 : Colors.white)
                  : null,
            ),
          ),
        ));
      }
    }
    if (_tool == _Tool.eraser) {
      for (final (stroke, label) in const [(false, '부분 지우기'), (true, '획 지우기')]) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: ChoiceChip(
            label: Text(label),
            visualDensity: VisualDensity.compact,
            selected: _strokeEraser == stroke,
            onSelected: (_) => setState(() => _strokeEraser = stroke),
          ),
        ));
      }
    }
    if (_tool == _Tool.pen || _tool == _Tool.highlighter || _tool == _Tool.eraser) {
      children.add(const SizedBox(width: 8));
      final sizes = switch (_tool) {
        _Tool.highlighter => _highlighterSizes,
        _Tool.eraser => _eraserSizes,
        _ => _penSizes,
      };
      final sel = switch (_tool) {
        _Tool.highlighter => _highlighterSize,
        _Tool.eraser => _eraserSize,
        _ => _penSize,
      };
      for (var i = 0; i < sizes.length; i++) {
        final on = sel == i;
        children.add(Tooltip(
          message: _sizeLabels[i],
          child: Semantics(
            button: true,
            selected: on,
            label: '굵기 ${_sizeLabels[i]}',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(() {
                switch (_tool) {
                  case _Tool.highlighter:
                    _highlighterSize = i;
                  case _Tool.eraser:
                    _eraserSize = i;
                  default:
                    _penSize = i;
                }
              }),
              child: Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? scheme.primaryContainer : Colors.transparent,
                  border: Border.all(color: on ? scheme.primary : scheme.outlineVariant),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 6.0 + i * 6,
                  height: 6.0 + i * 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _tool == _Tool.eraser
                        ? scheme.onSurfaceVariant
                        : Color(_color).withValues(alpha: _tool == _Tool.highlighter ? 0.5 : 1),
                  ),
                ),
              ),
            ),
          ),
        ));
      }
    }
    return children;
  }
}

/// 공책처럼 옅은 가로줄
class _PaperPainter extends CustomPainter {
  _PaperPainter({required this.scale});
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x14000000)
      ..strokeWidth = 1;
    final gap = 70 * scale;
    for (var y = gap; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PaperPainter old) => old.scale != scale;
}

class _TextResult {
  const _TextResult({
    this.text = '',
    this.size = 40,
    this.color = 0xFF222222,
    this.bold = false,
    this.delete = false,
  });
  final String text;
  final double size;
  final int color;
  final bool bold;
  final bool delete;
}

/// 글상자 만들기·고치기
class _TextBoxDialog extends StatefulWidget {
  const _TextBoxDialog({this.initial, required this.defaultColor});
  final DrawText? initial;
  final int defaultColor;

  @override
  State<_TextBoxDialog> createState() => _TextBoxDialogState();
}

class _TextBoxDialogState extends State<_TextBoxDialog> {
  static const _sizes = <(double, String)>[(28, '작게'), (40, '보통'), (60, '크게'), (88, '아주 크게')];

  late final _ctrl = TextEditingController(text: widget.initial?.text ?? '');
  late double _size = widget.initial?.size ?? 40;
  late int _color = widget.initial?.color ?? widget.defaultColor;
  late bool _bold = widget.initial?.bold ?? false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _ok() {
    final text = _ctrl.text.trimRight();
    if (text.trim().isEmpty) {
      // 글자를 모두 지우면 글상자 삭제
      Navigator.pop(
          context, widget.initial == null ? null : const _TextResult(delete: true));
      return;
    }
    Navigator.pop(context, _TextResult(text: text, size: _size, color: _color, bold: _bold));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.initial == null ? '글상자 만들기' : '글상자 고치기'),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            minLines: 1,
            maxLines: 5,
            style: TextStyle(
              fontWeight: _bold ? FontWeight.w800 : FontWeight.w500,
              color: Color(_color),
            ),
            decoration: const InputDecoration(hintText: '글자를 입력하세요'),
          ),
          const SizedBox(height: 14),
          const Text('글자 크기', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (size, label) in _sizes)
                ChoiceChip(
                  label: Text(label),
                  selected: _size == size,
                  onSelected: (_) => setState(() => _size = size),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilterChip(
            avatar: const Icon(Icons.format_bold_rounded, size: 18),
            label: const Text('굵게'),
            selected: _bold,
            onSelected: (v) => setState(() => _bold = v),
          ),
          const SizedBox(height: 12),
          const Text('글자 색', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in memoInkColors)
                GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == c ? scheme.primary : scheme.outlineVariant,
                        width: _color == c ? 3 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        if (widget.initial != null)
          TextButton(
            onPressed: () => Navigator.pop(context, const _TextResult(delete: true)),
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: const Text('삭제'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(onPressed: _ok, child: const Text('확인')),
      ],
    );
  }
}
