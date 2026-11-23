import 'dart:ui';

/// 그리기 도구 종류. (지우개 획은 그린 획 위를 투명하게 지웁니다.)
enum DrawTool { pen, highlighter, eraser }

/// 손가락·펜으로 그린 한 획.
///
/// 좌표는 화면 크기와 상관없이 같은 그림이 보이도록 가로 [MemoDrawing.pageWidth]
/// 기준의 가상 좌표로 저장합니다. (세로·가로 모드, 태블릿에서도 같은 비율)
class DrawStroke {
  const DrawStroke({
    required this.tool,
    required this.color,
    required this.width,
    required this.points,
  });

  final DrawTool tool;
  final int color;
  final double width;
  final List<Offset> points;

  Map<String, dynamic> toJson() => {
        't': tool.name,
        'c': color,
        'w': width,
        // 저장 용량을 줄이려고 소수점 한 자리로 [x, y, x, y, ...] 평탄화
        'p': [
          for (final p in points) ...[
            (p.dx * 10).roundToDouble() / 10,
            (p.dy * 10).roundToDouble() / 10,
          ]
        ],
      };

  static DrawStroke? fromJson(Map<String, dynamic> j) {
    final raw = j['p'];
    if (raw is! List || raw.length < 2) return null;
    final pts = <Offset>[];
    for (var i = 0; i + 1 < raw.length; i += 2) {
      pts.add(Offset((raw[i] as num).toDouble(), (raw[i + 1] as num).toDouble()));
    }
    return DrawStroke(
      tool: DrawTool.values.firstWhere((t) => t.name == j['t'],
          orElse: () => DrawTool.pen),
      color: (j['c'] as num?)?.toInt() ?? 0xFF222222,
      width: (j['w'] as num?)?.toDouble() ?? 6,
      points: pts,
    );
  }
}

/// 그림 위에 올리는 글상자.
class DrawText {
  const DrawText({
    required this.id,
    required this.pos,
    required this.text,
    this.size = 40,
    this.color = 0xFF222222,
    this.bold = false,
  });

  final String id;

  /// 왼쪽 위 모서리 (가상 좌표)
  final Offset pos;
  final String text;

  /// 글자 크기 (가상 좌표 단위)
  final double size;
  final int color;
  final bool bold;

  DrawText copyWith({Offset? pos, String? text, double? size, int? color, bool? bold}) =>
      DrawText(
        id: id,
        pos: pos ?? this.pos,
        text: text ?? this.text,
        size: size ?? this.size,
        color: color ?? this.color,
        bold: bold ?? this.bold,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'x': (pos.dx * 10).roundToDouble() / 10,
        'y': (pos.dy * 10).roundToDouble() / 10,
        't': text,
        's': size,
        'c': color,
        'b': bold,
      };

  static DrawText? fromJson(Map<String, dynamic> j) {
    final text = j['t'] as String? ?? '';
    if (text.trim().isEmpty) return null;
    return DrawText(
      id: j['id'] as String? ?? '${j.hashCode}',
      pos: Offset((j['x'] as num?)?.toDouble() ?? 0, (j['y'] as num?)?.toDouble() ?? 0),
      text: text,
      size: (j['s'] as num?)?.toDouble() ?? 40,
      color: (j['c'] as num?)?.toInt() ?? 0xFF222222,
      bold: j['b'] as bool? ?? false,
    );
  }
}

/// 메모 한 장의 그림 (획 + 글상자).
class MemoDrawing {
  const MemoDrawing({
    this.height = defaultHeight,
    this.strokes = const [],
    this.texts = const [],
  });

  /// 가상 좌표의 페이지 너비. 실제 화면 너비에 맞춰 확대·축소해 그립니다.
  static const double pageWidth = 1000;
  static const double defaultHeight = 1400;

  /// 페이지 높이 (아래쪽까지 그리면 자동으로 늘어남)
  final double height;
  final List<DrawStroke> strokes;
  final List<DrawText> texts;

  /// 지우개 획만 남은 경우도 빈 그림으로 봅니다.
  bool get isEmpty =>
      texts.isEmpty && strokes.every((s) => s.tool == DrawTool.eraser);

  Map<String, dynamic> toJson() => {
        'h': height,
        's': [for (final s in strokes) s.toJson()],
        'x': [for (final t in texts) t.toJson()],
      };

  static MemoDrawing? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final j = Map<String, dynamic>.from(raw);
    final strokes = <DrawStroke>[];
    for (final e in (j['s'] as List? ?? const [])) {
      if (e is Map) {
        final s = DrawStroke.fromJson(Map<String, dynamic>.from(e));
        if (s != null) strokes.add(s);
      }
    }
    final texts = <DrawText>[];
    for (final e in (j['x'] as List? ?? const [])) {
      if (e is Map) {
        final t = DrawText.fromJson(Map<String, dynamic>.from(e));
        if (t != null) texts.add(t);
      }
    }
    final d = MemoDrawing(
      height: (j['h'] as num?)?.toDouble() ?? defaultHeight,
      strokes: strokes,
      texts: texts,
    );
    return d.isEmpty ? null : d;
  }

  /// 그림이 실제로 차지하는 영역 (목록 미리보기에서 이 부분만 확대해 보여줌).
  Rect? get contentBounds {
    Rect? r;
    void add(Rect b) => r = r == null ? b : r!.expandToInclude(b);
    for (final s in strokes) {
      if (s.tool == DrawTool.eraser || s.points.isEmpty) continue;
      var minX = s.points.first.dx, maxX = minX;
      var minY = s.points.first.dy, maxY = minY;
      for (final p in s.points) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
      add(Rect.fromLTRB(minX, minY, maxX, maxY).inflate(s.width / 2));
    }
    for (final t in texts) {
      // 대략적인 글상자 크기 (정확한 크기는 그릴 때 계산)
      final lines = t.text.split('\n');
      final longest = lines.fold<int>(0, (m, l) => l.length > m ? l.length : m);
      add(Rect.fromLTWH(t.pos.dx, t.pos.dy,
          (longest * t.size).clamp(t.size, pageWidth - t.pos.dx),
          lines.length * t.size * 1.35));
    }
    return r;
  }

  /// 글상자 글자 (검색용)
  String get searchText => texts.map((t) => t.text).join('\n');
}
