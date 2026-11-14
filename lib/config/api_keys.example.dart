/// API 키 설정 예시 파일.
///
/// 사용 방법:
///   1. 이 파일을 같은 폴더에 `api_keys.dart` 라는 이름으로 복사하세요.
///   2. 아래 값을 실제 발급받은 키로 바꾸세요.
///
/// `api_keys.dart` 는 .gitignore 에 포함되어 있어 깃허브에 올라가지 않습니다.
class ApiKeys {
  ApiKeys._();

  /// 공공데이터포털 — 한국천문연구원 특일정보조회 서비스 API 키
  /// 발급 주소: https://www.data.go.kr/data/15012690/openapi.do
  /// ⚠️ "디코딩된 API 키(인코딩 안 된 키)"를 입력하세요.
  static const String koreanHoliday = 'YOUR_DATA_GO_KR_API_KEY';
}
