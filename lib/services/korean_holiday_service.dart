import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_keys.dart';

/// 공공데이터포털 한국천문연구원 특일정보조회 서비스를 이용해
/// 대한민국 공공 공휴일을 월별로 가져오고 캐싱합니다.
class KoreanHolidayService extends ChangeNotifier {
  KoreanHolidayService._();
  static final KoreanHolidayService instance = KoreanHolidayService._();

  /// date(00:00:00) → 공휴일 이름 (예: '설날', '광복절')
  final Map<DateTime, String> _holidays = {};

  /// 이미 조회한 'YYYYMM' 목록 (중복 요청 방지)
  final Set<String> _fetched = {};

  bool get hasData => _holidays.isNotEmpty;

  /// [day] 가 공휴일이면 true.
  bool isHoliday(DateTime day) =>
      _holidays.containsKey(DateTime(day.year, day.month, day.day));

  /// [day] 의 공휴일 이름. 공휴일이 아니면 null.
  String? holidayName(DateTime day) =>
      _holidays[DateTime(day.year, day.month, day.day)];

  /// [year]/[month] 공휴일을 (아직 조회하지 않은 경우에만) 가져옵니다.
  Future<void> ensureMonth(int year, int month) async {
    if (ApiKeys.koreanHoliday.isEmpty ||
        ApiKeys.koreanHoliday == 'YOUR_API_KEY_HERE') {
      return;
    }

    final key = '$year${month.toString().padLeft(2, '0')}';
    if (_fetched.contains(key)) return;
    _fetched.add(key); // 동시 중복 요청 방지용 선점

    try {
      // ── BUG ①  수정 ──────────────────────────────────────────────────────
      // Uri.https()의 queryParameters 맵은 값을 퍼센트 인코딩하므로,
      // 서비스키에 포함된 +·=·/ 등이 %2B·%3D·%2F 로 이중 인코딩되어
      // 공공데이터 서버에서 "SERVICE_KEY_IS_NOT_REGISTERED_ERROR" 반환.
      // → Uri.parse() 로 URL 문자열을 직접 조합해 인코딩 없이 키를 그대로 전달.
      final monthStr = month.toString().padLeft(2, '0');
      final url = 'https://apis.data.go.kr'
          '/B090041/openapi/service/SpcdeInfoService/getRestDeInfo'
          '?serviceKey=${ApiKeys.koreanHoliday}'
          '&solYear=$year'
          '&solMonth=$monthStr'
          '&_type=json'
          '&numOfRows=50';
      final uri = Uri.parse(url);

      debugPrint('[KoreanHoliday] 요청 → $year/$monthStr');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      debugPrint('[KoreanHoliday] 응답 HTTP ${res.statusCode}');

      if (res.statusCode != 200) {
        _fetched.remove(key);
        return;
      }

      // 응답이 XML(인증 오류 등)이면 jsonDecode에서 FormatException → catch 처리
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;

      // ── BUG ②  수정 ──────────────────────────────────────────────────────
      // 공공데이터 API 특성:
      //   • 공휴일 있음 → body.items = { "item": [...] }  or  { "item": {...} }
      //   • 공휴일 없음 → body.items = ""  (빈 문자열, null 이 아님!)
      // items 가 Map 이 아닌 경우(빈 문자열 포함) ['item'] 접근 시 TypeError 발생.
      // → rawItems 가 Map 인지 먼저 확인 후 ['item'] 접근.
      final body = decoded['response']?['body'];
      final rawItems = body?['items'];

      if (rawItems == null || rawItems is! Map) {
        // 해당 월 공휴일 없음 — 정상 종료 (key 는 _fetched 에 유지해 재요청 방지)
        debugPrint('[KoreanHoliday] $year/$monthStr → 공휴일 없음');
        return;
      }

      final item = rawItems['item'];

      bool changed = false;

      void parseItem(dynamic raw) {
        if (raw is! Map) return;

        // ── isHoliday 필터 ───────────────────────────────────────────────
        // getRestDeInfo 는 isHoliday='N' 인 기념일(기타 특일)도 포함해 반환.
        // 달력에는 법정 공휴일(isHoliday='Y')만 표시.
        if (raw['isHoliday']?.toString() != 'Y') return;

        // locdate 는 JSON 정수(int)로 올 수 있음 — toString() 으로 통일 처리
        final dateStr = raw['locdate']?.toString();
        if (dateStr == null || dateStr.length != 8) return;

        final y = int.tryParse(dateStr.substring(0, 4));
        final m = int.tryParse(dateStr.substring(4, 6));
        final d = int.tryParse(dateStr.substring(6, 8));
        if (y == null || m == null || d == null) return;

        final name = raw['dateName']?.toString() ?? '공휴일';
        _holidays[DateTime(y, m, d)] = name;
        changed = true;
      }

      // 공휴일 여러 개 → List / 정확히 1개 → Map (공공데이터 API 특성)
      if (item is List) {
        for (final e in item) {
          parseItem(e);
        }
      } else if (item is Map) {
        parseItem(item);
      }

      debugPrint('[KoreanHoliday] $year/$monthStr → '
          '${changed ? "공휴일 파싱 완료" : "공휴일 없음(item null)"}');
      if (changed) notifyListeners();
    } catch (e, st) {
      _fetched.remove(key); // 오류 시 재시도 허용
      debugPrint('[KoreanHolidayService] 오류: $e\n$st');
    }
  }

  /// 달력 페이지 이동 시 해당 월 + 다음 달을 미리 가져옵니다.
  Future<void> prefetch(DateTime focused) async {
    await ensureMonth(focused.year, focused.month);
    final next = DateTime(focused.year, focused.month + 1);
    await ensureMonth(next.year, next.month);
  }
}
