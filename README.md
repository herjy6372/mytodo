# mytodo

나의 할일에 대해 작성합니다.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## 로컬 설정

이 저장소에는 비밀 키가 포함되어 있지 않습니다. 빌드하기 전에 아래 파일을 직접 준비하세요.

1. **API 키**: `lib/config/api_keys.example.dart` 파일을 `lib/config/api_keys.dart`로 복사한 뒤, 공공데이터포털에서 발급받은 키를 입력합니다.
2. **운영자 설정**: `lib/config/private_config.example.dart` → `lib/config/private_config.dart`, `firestore.rules.example` → `firestore.rules` 로 복사한 뒤 `admin@example.com` 을 운영자 이메일로 바꿉니다.
3. **Android 릴리스 서명** (선택): `android/key.properties.example` 파일을 참고해 `android/key.properties`를 만들고, 키스토어 파일을 준비합니다.
