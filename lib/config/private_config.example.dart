/// 운영자 개인 설정 예시 파일.
///
/// 사용 방법:
///   1. 이 파일을 같은 폴더에 `private_config.dart` 라는 이름으로 복사하세요.
///   2. 아래 값을 본인 이메일로 바꾸세요.
///
/// `private_config.dart` 는 .gitignore 에 포함되어 깃허브에 올라가지 않습니다.
class PrivateConfig {
  PrivateConfig._();

  /// 항상 ADMIN 으로 부여되고, 고객지원 화면에 표시되는 운영자 이메일.
  static const String adminEmail = 'admin@example.com';
}
