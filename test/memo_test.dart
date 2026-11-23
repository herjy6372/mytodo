import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mytodo/models/memo.dart';
import 'package:mytodo/models/memo_drawing.dart';

void main() {
  test('예전 형식(서식·그림 없음) 메모를 그대로 읽는다', () {
    final m = Memo.fromJson({
      'id': 'a',
      'title': '',
      'content': '장보기\n우유',
      'color': 'mint',
      'pinned': false,
      'createdAt': '2026-11-20T10:00:00.000',
      'updatedAt': '2026-11-20T10:00:00.000',
    });
    expect(m.rich, isNull);
    expect(m.drawing, isNull);
    expect(m.displayTitle, '장보기');
    expect(m.toJson().containsKey('rich'), isFalse);
    expect(m.toJson().containsKey('drawing'), isFalse);
  });

  test('서식과 그림이 있는 메모를 저장했다가 다시 읽는다', () {
    final drawing = MemoDrawing(
      height: 2100,
      strokes: const [
        DrawStroke(
            tool: DrawTool.pen,
            color: 0xFF222222,
            width: 8,
            points: [Offset(10, 20), Offset(30.25, 40.04)]),
      ],
      texts: const [
        DrawText(id: 't1', pos: Offset(100, 200), text: '안녕', size: 60, bold: true),
      ],
    );
    final m = Memo(
      id: 'b',
      title: '',
      content: '',
      createdAt: DateTime(2026, 11, 24),
      updatedAt: DateTime(2026, 11, 24),
      rich: [
        {'insert': '굵게', 'attributes': {'bold': true}},
        {'insert': '\n'},
      ],
      drawing: drawing,
    );
    final back = Memo.fromJson(m.toJson());
    expect(back.rich, m.rich);
    expect(back.hasDrawing, isTrue);
    expect(back.displayTitle, '그림 메모');
    final d = back.drawing!;
    expect(d.height, 2100);
    expect(d.strokes.single.points.last, const Offset(30.3, 40.0));
    expect(d.texts.single.text, '안녕');
    expect(d.texts.single.bold, isTrue);
    expect(d.searchText, '안녕');
  });

  test('지우개 획만 남은 그림은 빈 그림으로 본다', () {
    const d = MemoDrawing(strokes: [
      DrawStroke(tool: DrawTool.eraser, color: 0, width: 40, points: [Offset(1, 1)]),
    ]);
    expect(d.isEmpty, isTrue);
    expect(MemoDrawing.fromJson(d.toJson()), isNull);
  });
}
