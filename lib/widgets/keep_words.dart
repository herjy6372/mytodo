/// 한국어 문장이 한두 글자씩 어색하게 줄바꿈되지 않도록,
/// 단어 안의 글자 사이에 보이지 않는 연결 문자(U+2060 WORD JOINER)를 넣어
/// 띄어쓰기 위치에서만 줄이 바뀌게 합니다. (이모지가 깨지지 않게 코드 포인트 단위로 처리)
String keepWords(String text) {
  const space = 0x20, newline = 0x0A, joiner = '⁠';
  final runes = text.runes.toList();
  final buf = StringBuffer();
  for (var i = 0; i < runes.length; i++) {
    final c = runes[i];
    buf.writeCharCode(c);
    if (i + 1 < runes.length) {
      final n = runes[i + 1];
      final breakable = c == space || c == newline || n == space || n == newline;
      // 이모지 변형 선택자·결합 문자 앞에는 넣지 않음
      final combining = n == 0xFE0F || n == 0x200D || (n >= 0x1F3FB && n <= 0x1F3FF);
      if (!breakable && !combining && c != 0x200D) buf.write(joiner);
    }
  }
  return buf.toString();
}
