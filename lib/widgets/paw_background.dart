import 'package:flutter/material.dart';

import '../data/theme_repository.dart';

// ─── 테마별 배경색 ──────────────────────────────────────────────────────────

/// 각 테마의 배경 단색을 반환한다. [PawBackground]와 home_screen 그래디언트에서 공유.
Color themeBgColor(AppThemeChoice choice, bool isDark) {
  switch (choice) {
    case AppThemeChoice.cat:
      return isDark ? const Color(0xFF3E001A) : const Color(0xFFFF80AB);
    case AppThemeChoice.dog:
      return isDark ? const Color(0xFF2E1B0E) : const Color(0xFF8D6E63);
    case AppThemeChoice.giraffe:
      return isDark ? const Color(0xFF2E1800) : const Color(0xFFFF9800);
    case AppThemeChoice.coffee:
      return isDark ? const Color(0xFF1A2E0A) : const Color(0xFF7CB342);
    default:
      return Colors.transparent;
  }
}

// ─── 메인 배경 위젯 ─────────────────────────────────────────────────────────

/// 고양이·강아지·기린·커피 테마용 패턴 배경 위젯.
/// MaterialApp.builder 에서 주입되어 모든 Scaffold 뒤에 깔린다.
class PawBackground extends StatelessWidget {
  const PawBackground({
    super.key,
    required this.choice,
    required this.isDark,
    required this.child,
  });

  final AppThemeChoice choice;
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final CustomPainter painter;
    switch (choice) {
      case AppThemeChoice.cat:
        painter = _CatFacePainter(isDark: isDark);
      case AppThemeChoice.dog:
        painter = _DogFacePainter(isDark: isDark);
      case AppThemeChoice.giraffe:
        painter = _GiraffePainter(isDark: isDark);
      case AppThemeChoice.coffee:
        painter = _CoffeePainter(isDark: isDark);
      default:
        return child;
    }

    return ColoredBox(
      color: themeBgColor(choice, isDark),
      child: CustomPaint(
        painter: painter,
        child: child,
      ),
    );
  }
}

// ─── 공통 유틸 ──────────────────────────────────────────────────────────────

Paint _fillPaint(bool isDark) => Paint()
  ..color = Color.fromRGBO(255, 255, 255, isDark ? 0.09 : 0.15)
  ..style = PaintingStyle.fill;

Paint _strokePaint(bool isDark, {double width = 2.0}) => Paint()
  ..color = Color.fromRGBO(255, 255, 255, isDark ? 0.09 : 0.15)
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

void _tile(
  Canvas canvas,
  Size size,
  double spacing,
  double yStart,
  void Function(Canvas, Offset) draw,
) {
  int row = 0;
  for (double y = yStart; y < size.height + spacing; y += spacing, row++) {
    final xStart = row.isOdd ? -spacing / 2 : 0.0;
    for (double x = xStart; x < size.width + spacing; x += spacing) {
      draw(canvas, Offset(x, y));
    }
  }
}

// ─── 고양이 얼굴 패턴 ───────────────────────────────────────────────────────

class _CatFacePainter extends CustomPainter {
  const _CatFacePainter({required this.isDark});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final p = _fillPaint(isDark);
    _tile(canvas, size, 80, 28, (c, o) => _drawCat(c, o, p));
  }

  void _drawCat(Canvas canvas, Offset c, Paint p) {
    // 머리 (원)
    canvas.drawCircle(c, 13, p);
    // 왼쪽 귀 (삼각형)
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - 10, c.dy - 7)
        ..lineTo(c.dx - 5,  c.dy - 19)
        ..lineTo(c.dx - 1,  c.dy - 9)
        ..close(),
      p,
    );
    // 오른쪽 귀
    canvas.drawPath(
      Path()
        ..moveTo(c.dx + 10, c.dy - 7)
        ..lineTo(c.dx + 5,  c.dy - 19)
        ..lineTo(c.dx + 1,  c.dy - 9)
        ..close(),
      p,
    );
    // 코 (작은 삼각형)
    canvas.drawPath(
      Path()
        ..moveTo(c.dx,       c.dy + 2)
        ..lineTo(c.dx - 2.5, c.dy + 5.5)
        ..lineTo(c.dx + 2.5, c.dy + 5.5)
        ..close(),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _CatFacePainter old) => old.isDark != isDark;
}

// ─── 강아지 얼굴 패턴 ───────────────────────────────────────────────────────

class _DogFacePainter extends CustomPainter {
  const _DogFacePainter({required this.isDark});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final p = _fillPaint(isDark);
    _tile(canvas, size, 80, 32, (c, o) => _drawDog(c, o, p));
  }

  void _drawDog(Canvas canvas, Offset c, Paint p) {
    // 축 처진 귀 (타원, 머리 뒤)
    canvas.drawOval(
        Rect.fromCenter(center: Offset(c.dx - 14, c.dy + 2), width: 11, height: 17), p);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(c.dx + 14, c.dy + 2), width: 11, height: 17), p);
    // 머리 (타원)
    canvas.drawOval(Rect.fromCenter(center: c, width: 26, height: 22), p);
    // 주둥이 (아래쪽 타원)
    canvas.drawOval(
        Rect.fromCenter(center: Offset(c.dx, c.dy + 5), width: 14, height: 10), p);
    // 코 (작은 원)
    canvas.drawCircle(Offset(c.dx, c.dy + 2), 3, p);
  }

  @override
  bool shouldRepaint(covariant _DogFacePainter old) => old.isDark != isDark;
}

// ─── 기린 패턴 ──────────────────────────────────────────────────────────────

class _GiraffePainter extends CustomPainter {
  const _GiraffePainter({required this.isDark});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final p = _fillPaint(isDark);
    // 기린은 세로가 길어서 간격을 넓게
    _tile(canvas, size, 90, 24, (c, o) => _drawGiraffe(c, o, p));
  }

  void _drawGiraffe(Canvas canvas, Offset c, Paint p) {
    // 몸통 (넓은 타원) — 기준점 c가 몸통 중심
    canvas.drawOval(Rect.fromCenter(center: c, width: 22, height: 14), p);
    // 목 (좁은 둥근 사각형)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(c.dx, c.dy - 17), width: 8, height: 18),
        const Radius.circular(3),
      ),
      p,
    );
    // 머리 (작은 타원)
    canvas.drawOval(
        Rect.fromCenter(center: Offset(c.dx, c.dy - 29), width: 12, height: 9), p);
    // 귀 (양쪽 작은 타원)
    canvas.drawOval(
        Rect.fromCenter(center: Offset(c.dx - 8, c.dy - 31), width: 5, height: 7), p);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(c.dx + 8, c.dy - 31), width: 5, height: 7), p);
    // 뿔(오시콘) — 짧은 둥근 막대 2개
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(c.dx - 3, c.dy - 37), width: 3, height: 7),
        const Radius.circular(2),
      ),
      p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(c.dx + 3, c.dy - 37), width: 3, height: 7),
        const Radius.circular(2),
      ),
      p,
    );
    // 다리 4개 (짧은 막대)
    for (final dx in [-7.0, -2.5, 2.5, 7.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(c.dx + dx, c.dy + 12), width: 3, height: 10),
          const Radius.circular(1.5),
        ),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GiraffePainter old) => old.isDark != isDark;
}

// ─── 커피 잔 패턴 ───────────────────────────────────────────────────────────

class _CoffeePainter extends CustomPainter {
  const _CoffeePainter({required this.isDark});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final fill   = _fillPaint(isDark);
    final stroke = _strokePaint(isDark, width: 2.2);
    _tile(canvas, size, 82, 28, (c, o) => _drawCoffee(c, o, fill, stroke));
  }

  void _drawCoffee(Canvas canvas, Offset c, Paint fill, Paint stroke) {
    // ── 컵 몸통 (사다리꼴 Path) ──
    final cup = Path()
      ..moveTo(c.dx - 11, c.dy - 8)
      ..lineTo(c.dx + 11, c.dy - 8)
      ..lineTo(c.dx + 8,  c.dy + 10)
      ..lineTo(c.dx - 8,  c.dy + 10)
      ..close();
    canvas.drawPath(cup, fill);

    // ── 컵 손잡이 (획으로 D자형 호) ──
    final handle = Path()
      ..moveTo(c.dx + 8,  c.dy - 3)
      ..cubicTo(
        c.dx + 20, c.dy - 3,
        c.dx + 20, c.dy + 7,
        c.dx + 8,  c.dy + 7,
      );
    canvas.drawPath(handle, stroke);

    // ── 받침 접시 (납작한 타원) ──
    canvas.drawOval(
        Rect.fromCenter(center: Offset(c.dx, c.dy + 13), width: 28, height: 6), fill);

    // ── 연기 (S자 곡선 2줄) ──
    canvas.drawPath(_steamPath(c.dx - 4, c.dy - 10), stroke);
    canvas.drawPath(_steamPath(c.dx + 4, c.dy - 12), stroke);
  }

  Path _steamPath(double x, double y) {
    return Path()
      ..moveTo(x, y)
      ..cubicTo(x + 5,  y - 5,  x - 5, y - 10, x,      y - 15)
      ..cubicTo(x + 5,  y - 20, x - 5, y - 25, x,      y - 30);
  }

  @override
  bool shouldRepaint(covariant _CoffeePainter old) => old.isDark != isDark;
}
