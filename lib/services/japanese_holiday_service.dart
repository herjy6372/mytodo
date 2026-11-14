import 'package:holiday_jp/holiday_jp.dart' as jp;

/// 일본 공휴일 서비스 (오프라인 — holiday_jp 패키지 사용).
///
/// 한국 공휴일 서비스(KoreanHolidayService)와 달리
/// 네트워크 요청이 필요 없으며, ChangeNotifier 도 필요 없습니다.
class JapaneseHolidayService {
  JapaneseHolidayService._();
  static final JapaneseHolidayService instance = JapaneseHolidayService._();

  // holiday_jp 는 UTC 기준 날짜로 조회해야 정확합니다.
  DateTime _toUtc(DateTime day) => DateTime.utc(day.year, day.month, day.day);

  /// 해당 날짜가 일본 공휴일인지 여부.
  bool isHoliday(DateTime day) => jp.isHoliday(_toUtc(day));

  /// 해당 날짜의 일본 공휴일 이름 (공휴일이 아니면 null).
  ///
  /// [japanese] 가 true 이면 일본어 이름(예: '元日'),
  /// false 이면 영어 이름(예: 'New Year\'s Day') 을 반환합니다.
  String? holidayName(DateTime day, {bool japanese = true}) {
    final h = jp.getHoliday(_toUtc(day));
    if (h == null) return null;
    return japanese ? h.name : h.nameEn;
  }
}
