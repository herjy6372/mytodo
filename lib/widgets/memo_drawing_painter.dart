import 'package:flutter/material.dart';

import '../models/memo_drawing.dart';

/// 글상자 글자 레이아웃 (편집 화면의 터치 판정과 그리기에 함께 사용).
TextPainter layoutDrawText(DrawText t) {
  final tp = TextPainter(
    text: TextSpan(
      text: t.text,
      style: TextStyle(
        fontSize: t.size,
        height: 1.3,
        color: Color(t.color),
        fontWeight: t.bold ? FontWeight.w800 : FontWeight.w500,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  final maxW = (MemoDrawing.pageWidth - t.pos.dx - 12).clamp(t.size, MemoDrawing.pageWidth);
  tp.layout(maxWidth: maxW);
  return tp;
}

/// 글상자가 차지하는 영역 (가상 좌표, 손가락으로 누르기 쉽게 여백 포함)
Rect drawTextRect(DrawText t) {
  final tp = layoutDrawText(t);
  return Rect.fromLTWH(t.pos.dx, t.pos.dy, tp.width, tp.height).inflate(14);
}

/// 메모 그림을 그리는 페인터.
///
/// [fit] 이 true 면 그림이 있는 영역만 잘라 칸 안에 맞춰 그립니다 (목록 미리보기).
class MemoDrawingPainter extends CustomPainter {
  MemoDrawingPainter({
    required this.drawing,
    this.current,
    this.fit = false,
    this.selectedTextId,
    this.selectColor = const Color(0xFF3D7BFF),
  });

  final MemoDrawing drawing;

  /// 지금 그리고 있는 획
  final DrawStroke? current;
  final bool fit;
  final String? selectedTextId;
  final Color selectColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (fit) {
      final b = drawing.contentBounds;
      if (b == null) {
        canvas.restore();
        return;
      }
      final box = b.inflate(20);
      // 그림 너비에 맞춰 크게 보여주고, 넘치는 아래쪽은 잘라냄
      // (아주 작은 낙서가 지나치게 커지지 않도록 최소 너비 360 기준)
      final s = size.width / (box.width < 360 ? 360 : box.width);
      // 위쪽 가운데 정렬
      canvas.translate((size.width - box.width * s) / 2, 0);
      canvas.scale(s);
      canvas.translate(-box.left, -box.top);
    } else {
      final s = size.width / MemoDrawing.pageWidth;
      canvas.scale(s);
    }

    // 지우개(투명 처리)가 획에만 적용되도록 획은 별도 레이어에 그림
    canvas.saveLayer(null, Paint());
    for (final s in drawing.strokes) {
      _paintStroke(canvas, s);
    }
    if (current != null) _paintStroke(canvas, current!);
    canvas.restore();

    for (final t in drawing.texts) {
      final tp = layoutDrawText(t);
      tp.paint(canvas, t.pos);
      if (t.id == selectedTextId) {
        final r = Rect.fromLTWH(t.pos.dx, t.pos.dy, tp.width, tp.height).inflate(8);
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(8)),
          Paint()
            ..color = selectColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
    }
    canvas.restore();
  }

  void _paintStroke(Canvas canvas, DrawStroke s) {
    if (s.points.isEmpty) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    switch (s.tool) {
      case DrawTool.pen:
        paint.color = Color(s.color);
      case DrawTool.highlighter:
        paint
          ..color = Color(s.color).withValues(alpha: 0.35)
          ..strokeCap = StrokeCap.square;
      case DrawTool.eraser:
        paint
          ..color = const Color(0xFF000000)
          ..blendMode = BlendMode.clear;
    }
    if (s.points.length == 1) {
      canvas.drawCircle(
          s.points.first, s.width / 2, Paint()..color = paint.color..blendMode = paint.blendMode);
      return;
    }
    // 중간점을 잇는 2차 곡선으로 부드럽게
    final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
    for (var i = 1; i < s.points.length - 1; i++) {
      final p = s.points[i];
      final n = s.points[i + 1];
      path.quadraticBezierTo(p.dx, p.dy, (p.dx + n.dx) / 2, (p.dy + n.dy) / 2);
    }
    path.lineTo(s.points.last.dx, s.points.last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant MemoDrawingPainter old) =>
      old.drawing != drawing ||
      old.current != current ||
      old.fit != fit ||
      old.selectedTextId != selectedTextId;
}
