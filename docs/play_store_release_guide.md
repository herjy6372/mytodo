# 플레이 스토어 공개 베타 출시 가이드

전체 흐름은 다음과 같습니다.

1. **applicationId 변경** (★ 매우 중요)
2. **업로드 키스토어 생성**
3. **`android/key.properties` 설정**
4. **AAB(App Bundle) 빌드**
5. **Google Play Console 에서 공개 테스트 트랙 만들기**

---

## 0. 사전 점검

| 항목 | 현재 | 필요 |
|---|---|---|
| applicationId | `com.example.mytodo` | 본인 도메인 기반(예: `com.terablack.mytodo`)으로 변경 필요 ★ |
| versionName | `pubspec.yaml: 1.0.0+1` | 베타 첫 빌드는 `1.0.0+1` 그대로 OK |
| 업로드 키 | 없음 | 1번 단계에서 생성 |
| Firebase 앱 등록 | `com.example.mytodo` 로 등록됨 | applicationId 바꾸면 재등록 필요 |
| 개인정보 처리방침 URL | 노션 링크 보유 | 그대로 사용 가능 |
| 아이콘 / 피쳐 그래픽 | `store/` 폴더에 생성됨 | 그대로 업로드 |

---

## 1. applicationId 변경 (★ 첫 단계)

**왜?** 플레이 스토어는 `com.example.*` 같은 예제 패키지명을 거부합니다. 또한 한 번 출시한 applicationId 는 이후로 절대 바꿀 수 없으니 처음부터 본인 소유 도메인 기반으로 정하셔야 합니다.

`android/app/build.gradle.kts` 의 두 줄(주석 + applicationId)에서 다음으로 변경:

```kotlin
applicationId = "com.terablack.mytodo"   // 본인 도메인 기반으로
```

`namespace` 도 일치시키는 게 좋습니다:

```kotlin
namespace = "com.terablack.mytodo"
```

그리고 **MainActivity 패키지 경로**도 옮겨야 합니다:
```bash
# 기존
android/app/src/main/kotlin/com/example/mytodo/MainActivity.kt
# 새 위치
android/app/src/main/kotlin/com/terablack/mytodo/MainActivity.kt
```
파일 이동 후 `MainActivity.kt` 첫 줄 `package com.terablack.mytodo` 로 수정.

마지막으로 **Firebase 재구성**:
```bash
flutterfire configure --project=todolist-4f9ef
```
새 패키지로 안드로이드 앱이 자동 등록됩니다. 기존 `com.example.mytodo` Android 앱은 Firebase Console 에서 삭제하셔도 됩니다.

> iOS bundle id 도 동일 패턴으로 바꾸시려면 Xcode 의 PRODUCT_BUNDLE_IDENTIFIER 만 같이 변경하시면 됩니다. 안드로이드 출시만 우선 한다면 iOS 는 그대로 두셔도 무방합니다.

---

## 2. 업로드 키스토어 생성

터미널에서 (어디든 OK):

```bash
keytool -genkey -v \
  -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload \
  -storetype JKS
```

질문에 답하시면 됩니다. **storePassword / keyPassword / 별칭 (`upload`) 은 절대 분실하지 마세요** — 분실하면 향후 동일 앱 업데이트가 불가능합니다(앱을 새로 출시해야 함).

생성된 `upload-keystore.jks` 를 프로젝트의 `android/app/upload-keystore.jks` 로 복사하시면 관리가 편합니다.

```bash
cp ~/upload-keystore.jks /Users/terablack/StudioProjects/mytodo/android/app/upload-keystore.jks
```

---

## 3. android/key.properties 작성

`android/key.properties.example` 을 복사:
```bash
cp android/key.properties.example android/key.properties
```

`android/key.properties` 를 열어 본인 값으로 채우기:
```
storePassword=실제_storePassword
keyPassword=실제_keyPassword
keyAlias=upload
storeFile=upload-keystore.jks
```

`storeFile` 은 `android/app/` 기준 상대경로입니다. (절대경로도 허용)

`.gitignore` 가 `key.properties` 와 `*.jks` 를 모두 제외하므로 git 에 올라가지 않습니다.

> ⚠️ `key.properties` 가 없으면 릴리스 빌드는 **실패**합니다. (예전처럼 공개된 디버그 키로 조용히 서명하지 않음)
> 스토어에 올리지 않는 로컬 테스트용 릴리스 빌드가 필요하면 디버그 키 서명을 명시적으로 허용하세요:
> ```bash
> flutter build apk --release --android-project-arg=allowDebugSigning=true
> # 또는: cd android && ./gradlew assembleRelease -PallowDebugSigning
> # 또는: ORG_GRADLE_PROJECT_allowDebugSigning=true flutter build apk --release
> ```
> 이렇게 만든 빌드는 디버그 키로 서명되어 Play Console 에 업로드할 수 없습니다.

---

## 4. AAB 빌드

```bash
cd /Users/terablack/StudioProjects/mytodo
flutter clean
flutter pub get
flutter build appbundle --release
```

성공하면:
```
build/app/outputs/bundle/release/app-release.aab
```

이 파일을 Play Console 에 업로드합니다.

> Tip: 빌드 후 `flutter install --use-application-binary=build/app/outputs/bundle/release/app-release.aab` 로 실기기 사전 검증이 가능합니다.

---

## 5. Google Play Console 설정

[Google Play Console](https://play.google.com/console) 접속 (개발자 계정 필요, 1회 25 USD).

### 5-1. 앱 만들기
1. **앱 만들기** 버튼 → 앱 이름: `나의 할 일`
2. 기본 언어: 한국어
3. 앱/게임: 앱 / 무료
4. 약관 체크 → 만들기

### 5-2. 앱 설정 (왼쪽 메뉴 → 앱 설정 → 앱 콘텐츠)

다음 항목을 모두 작성:

- **개인정보처리방침 URL**: `https://www.notion.so/herjy6372/350255869d0a80ad8ed8e72cc2e05cf2?source=copy_link`
- **앱 액세스 권한**: 일부 기능에 로그인 필요 (이메일/Google 로그인)
- **광고**: 광고 없음
- **콘텐츠 등급**: 설문지 작성 후 자동 부여 (대부분 전체이용가)
- **타겟층 및 콘텐츠**:
  - 대상 연령대: 13세 이상 (앱이 만 14세 이상만 가입 받으므로)
- **뉴스 앱**: 아니오
- **COVID-19 추적/접촉자 앱**: 해당 없음
- **데이터 보안**: 수집하는 데이터 항목 표시 (이메일·이름·생년월일·할 일 데이터·기기 ID)
- **정부 앱**: 아니오
- **금융 기능**: 가계부가 있지만 외부 연동/결제 X → 해당 없음

### 5-3. 스토어 등록정보 (왼쪽 메뉴 → 스토어 정보 → 기본 스토어 정보)

- **앱 이름**: `나의 할 일`
- **간단한 설명** (80자):
  ```
  할 일·캘린더·그래프·기분한줄·가계부·타이머·세계시각을 한 앱에서 관리하세요.
  ```
- **자세한 설명** (4000자, 아래 예시 그대로 또는 수정해서 사용):
  ```
  📝 나의 할 일
  
  매일을 조금 더 가볍게. 할 일부터 가계부, 기분 일기까지 하나의 앱에서 관리하세요.
  
  ✓ 할 일 목록 — 카테고리(업무/공부/생활 등)별 정리, 둥근 디자인의 깔끔한 리스트
  ✓ 캘린더(날짜형) — 월간·주간·2주 보기, 일자별 일정 한눈에
  ✓ 그래프형 통계 — 일/월/년 단위 완료 vs 미완료, 카테고리 분포
  ✓ 기분 한 줄 — 5단계 기분 + 100자 메모로 매일을 기록
  ✓ 가계부 — 입금/출금 구분, 월별 합계, 입력 부담 없는 미니멀 UI
  ✓ 타이머 — 1초~99시간 59분 59초, 진동·알림으로 종료 신호
  ✓ 세계 시각 — 인기 도시 30곳 중 골라 실시간으로 확인
  ✓ 클라우드 동기화 — 로그인하면 여러 기기에서 자동 동기화 + 복원
  ✓ 푸시 알림 — 설정한 시간이 되면 잊지 않게 알려드립니다
  ✓ 다크모드 + 고양이·강아지·기린·커피 테마
  
  🔒 개인정보는 만 14세 이상 동의 절차를 거쳐 수집되며, 회원 탈퇴 시 즉시 삭제됩니다.
  ```
- **앱 아이콘** (512×512): `store/play_store_icon_512.png`
- **그래픽 이미지** (1024×500): `store/play_store_feature_1024x500.png`
- **휴대전화 스크린샷** (최소 2장, 권장 4~8장): `store/screenshots/` 의 1080×1920 이미지 8장

#### 스크린샷 빠르게 찍는 법
1. 안드로이드 에뮬레이터에서 `flutter run`
2. 홈 / 할 일 목록 / 캘린더 / 그래프 / 가계부 / 세계시각 / 설정 화면 각각 캡처
3. 1080×1920 또는 1080×2340 정도면 OK (16:9 ~ 19.5:9 사이)

---

## 6. 공개 테스트 트랙 만들기

왼쪽 메뉴 → **테스트 → 공개 테스트** → **새 버전 만들기**.

1. **앱 무결성** → Google 에서 키 관리(권장) 선택
2. **App Bundle 업로드** → `build/app/outputs/bundle/release/app-release.aab` 끌어다 놓기
3. **버전 이름**: `1.0.0 (Beta 1)`
4. **출시 노트** (각 언어 ko-KR):
   ```
   🎉 첫 베타 출시!
   - 할 일 / 캘린더 / 그래프 / 기분한줄 / 가계부 / 타이머 / 세계시각
   - 클라우드 동기화 + 복원
   - 다크모드 + 고양이/강아지 테마(Beta)
   ```
5. **저장 → 검토 → 공개 테스트로 출시 시작**

### 6-1. 테스터 모집
같은 화면 아래쪽 **테스터** 탭:
- **테스트 참여 방법**: "오픈 베타" 선택 → 누구나 링크로 참여 가능
- **선택 사항**: 인원 제한(예: 100명)을 두고 싶으면 설정
- **참여 URL** 이 만들어지면 그 링크를 공유하시면 됩니다

> 공개 테스트는 첫 배포 후 보통 **하루~7일** 내에 검토 완료되고 링크가 활성화됩니다.

---

## 7. 출시 후 운영 팁

- 새 버전 올릴 때마다 `pubspec.yaml` 의 `version: 1.0.0+1` → `1.0.1+2` 식으로 올리기  
  (`+숫자` 가 versionCode, 항상 증가해야 함)
- 다음 빌드 시 같은 절차로 `flutter build appbundle --release` 후 Play Console 에서 새 버전 만들기
- 키스토어 백업: `upload-keystore.jks` 와 비밀번호를 **반드시 안전한 곳에 별도 백업** (1Password, Bitwarden, 외장 드라이브 등). 분실 시 같은 앱으로 업데이트 불가능

---

## 자주 만나는 에러

| 증상 | 원인 / 해결 |
|---|---|
| `applicationId 'com.example.*' is reserved` | 1번 단계 (applicationId 변경) 필수 |
| `릴리스 서명 키가 없습니다` | 3번 단계, `android/key.properties` 만들기 (로컬 테스트용이면 `-PallowDebugSigning`) |
| `keystore was tampered with, or password was incorrect` | key.properties 의 비밀번호 또는 storeFile 경로 오타 |
| `Default FirebaseApp is not initialized` | applicationId 변경 후 `flutterfire configure` 재실행 |
| Play Console 업로드 시 `이 키로 서명되지 않았습니다` | Play 가 이미 다른 키로 알고 있는 경우. **Play 앱 서명**(권장) 활성화 후 처음 업로드한 키가 인정됨 |
