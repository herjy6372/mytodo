# ✅ 나의 할 일 — 올인원 라이프 관리 앱
> **개발 기간:** 2026.04 ~ 진행중 (개인 프로젝트, 1인 개발)
> **플랫폼:** Android (Google Play Store 비공개 테스트) / iOS
> **패키지명:** com.terablack.mytodo
> **현재 버전:** 1.6.2+41

---

## 💡 1. 프로젝트 소개

**"나의 할 일"** 은 할 일 관리를 중심으로 캘린더·가계부·기분 기록·타이머·세계시각까지 하나의 앱에서 관리하는 **올인원 라이프 관리 Flutter 앱**입니다.

기능이 늘어날수록 "누가 어떤 기능까지 쓸 수 있는가"를 명확히 관리할 필요가 있다고 판단해, 관리자·베타·프로·학생·일반 5단계로 나뉜 등급별 접근 권한(RBAC) 구조를 처음부터 설계에 포함시켰습니다.

---

## 🛠 2. 사용 기술 및 개발 환경 (Tech Stack)

| 분류 | 기술 |
|------|------|
| **언어** | Dart |
| **프레임워크** | Flutter |
| **로컬 저장** | SharedPreferences |
| **인증** | Firebase Auth, Google Sign-In |
| **데이터베이스** | Cloud Firestore |
| **로컬 알림** | flutter_local_notifications, timezone |
| **캘린더/그래프** | table_calendar, fl_chart |
| **네트워크** | http (한국 공휴일 API) |
| **공휴일 데이터** | holiday_jp(오프라인), 자체 한국 공휴일 서비스 |
| **앱 정보** | package_info_plus, device_info_plus |
| **배포 (Android)** | Google Play Store (AAB, Release Signing) |
| **버전 관리** | Git |
| **개발 환경** | macOS, VS Code, Android Studio |

---

## 🌟 3. 핵심 기능 및 구현 내용

### 🔑 주요 기능

- **할 일 관리**
  - 목록·캘린더 뷰(table_calendar), 카테고리·메모·장소 태깅
  - 주간 요약(Weekly Summary) 화면으로 완료율 시각화

- **가계부**
  - 수입/지출 기록 및 fl_chart 기반 그래프 통계

- **기분 기록**
  - 날짜별 기분 로그 기록·조회

- **타이머 · 세계시각**
  - 집중 타이머, 여러 도시 동시 시각 조회

- **알람 · 메모**
  - 아침 깨우기·잘 때·일반 알람, 1분간 울리는 알람 화면과 1·5·10·30분 다시 울림
  - 색상·고정 기능이 있는 메모

- **홈 화면 위젯 (Android / iOS)**
  - 할 일 체크, 일별·연간 완료 현황, 기분·가계부·메모·타이머·세계시각 위젯 9종

- **클라우드 동기화 (Beta·Admin 전용)**
  - Firebase Auth(Google 로그인) + Firestore로 기기 간 데이터 백업/복원

- **알림 · 공휴일**
  - 로컬 푸시(일일 알림), 한국/일본 공휴일 자동 반영

- **다국어 · 테마**
  - 한국어/영어/일본어/필리핀어/베트남어 지원
  - 시스템(라이트/다크) 테마와 고양이·강아지·기린·커피 테마

- **보기 편하게 (접근성)**
  - 큰 글씨 모드(기본·크게·아주 크게) — 휴대폰 글꼴 크기에 곱해 적용, 크게 이상이면 버튼·카드 테두리를 진하게
  - 홈 화면 메뉴 켜고 끄기·순서 바꾸기

- **삭제 되돌리기 · 백업 파일**
  - 할 일·메모·가계부·기분 기록 삭제 후 6초간 "되돌리기"
  - 기록·설정을 JSON 백업 파일로 내보내고(공유 시트) 불러오기 — 동기화가 없는 등급도 기기 변경 가능

- **보호자 동의 (만 14세 미만)**
  - 학생(Student) 등급 대상 보호자 동의 플로우(`parent_consent`)

### 🔒 5단계 RBAC 권한 시스템

| 등급 | 이용 가능 기능 |
|------|----------------|
| 비로그인 | 고객지원·알람·설정만 (기능 메뉴와 타이머 위젯은 로그인 필요) |
| Normal | 할 일·그래프·기분·가계부·타이머·세계시각·알람·메모·테마·언어 |
| Student | Normal과 동일 (만 14세 미만, Beta·Pro 부여 불가) |
| Pro | Normal과 동일 (1.6.1부터 기분·가계부·테마를 모든 등급에 개방) |
| Beta | Normal + 클라우드 동기화 |
| Admin | 모든 기능 + 공지 작성·회원 등급 관리 |

---

## 🪵 4. 아키텍처 및 시스템 구조

```
lib/
├── main.dart                        # 앱 진입점, Firebase 초기화
├── config/api_keys.dart
├── models/
│   ├── todo.dart / ledger.dart / mood.dart
│   ├── user_profile.dart            # UserRole enum — 등급별 기능 접근 getter
│   ├── announcement.dart
│   └── parent_consent.dart
├── data/                            # 도메인별 Repository (Todo/Ledger/Mood/Profile/
│   ├── todo_repository.dart         # Theme/Language/WorldClock/Notification/
│   ├── ledger_repository.dart       # Announcement/ParentConsent/Auth)
│   ├── mood_repository.dart
│   ├── profile_repository.dart
│   ├── auth_repository.dart
│   └── ...
├── services/
│   ├── sync_service.dart            # Firebase 동기화
│   ├── notification_service.dart / daily_notification_service.dart
│   ├── korean_holiday_service.dart / japanese_holiday_service.dart
│   └── permission_service.dart
├── screens/                         # 23개 화면 (할일/캘린더/가계부/기분/타이머/
│                                     #  세계시각/설정/로그인/공지/온보딩 등)
├── theme/app_theme.dart
└── widgets/
```

- **권한 매핑을 모델 레이어에 집중:** `UserRole` enum이 `canSync` / `canUsePro` / `canUseBeta` / `canEditAnnouncements` / `canManageUsers` 같은 getter로 등급-기능 매핑을 캡슐화 — 화면마다 권한 체크 로직을 흩어놓지 않고 `role.canSync` 한 줄로 판단
- **도메인별 Repository 분리:** 할 일·가계부·기분·프로필·테마·언어·세계시각·공지·보호자동의를 각각 독립된 Repository로 분리해, 로컬 저장(SharedPreferences)과 Firebase 연동을 도메인 단위로 관리

---

## 📈 5. 성과 및 회고

- 기능이 하나둘 늘어나는 개인 프로젝트 특성상, 등급 체계를 코드 전역에 흩어놓지 않고 모델 레이어(UserRole)에 모아 새 기능 추가 시 권한 로직 누락 위험을 줄이는 구조를 설계·적용했습니다.
- 할 일 관리를 중심으로 가계부·기분 기록·타이머 등 서로 다른 도메인을 하나의 앱으로 묶으면서도, 도메인별 Repository 분리로 각 기능의 독립성을 유지했습니다.
- 향후 계획: Google Play 비공개 테스트 결과를 반영한 정식 출시, 등급별 기능을 활용한 프로 플랜 확장 검토.

---

## 🔧 6. 추가 업데이트 및 보완 내역 (v1.5.2+35)

### 🔐 1) 앱 실행 시 인증 세션 복원 및 비로그인 UX 개선
- **초기 로그인 세션 복원 타이밍 보완 (`auth_repository.dart`)**
  - 앱 시작 시 `FirebaseAuth` 로컬 세션 복원이 완료되기 전에 `currentUser`가 `null`로 평가되어 비로그인 상태로 보이는 문제를 해결하기 위해 `authStateChanges().first` 대기 로직 적용
  - 사용자가 명시적으로 로그아웃(`signOut`)하지 않은 상태에서 토큰 만료 등으로 세션이 풀린 경우 `GoogleSignIn.signInSilently()`를 통해 자동 복구하도록 개선
- **비로그인 상태 진입 동선 개선 (`permission_service.dart`, `home_screen.dart`, `rounded_menu_button.dart`)**
  - 최초 설치 시에만 로그인 화면을 띄우던 기존 방식에서, 비로그인 상태로 앱을 실행할 때마다 로그인 화면으로 안내하도록 개선
  - 홈 화면의 비로그인 안내 배너 및 비활성화된 하단 메뉴 탭 시 로그인 화면(또는 Pro 등급 신청 안내)으로 즉시 이동하도록 연결
- **로그인 직후 온보딩 자동 연동 및 스트림 중복 구독 방지 (`home_screen.dart`, `profile_repository.dart`)**
  - 로그인 상태가 변경되는 즉시 온보딩 완료 여부를 자동 확인하도록 연결
  - `ProfileRepository.init()`에서 인증 리스너 중복 호출로 인한 스트림 구독 누수를 방지하고, 오프라인/네트워크 지연 환경에서도 앱 초기 구동이 멈추지 않도록 타임아웃 및 실시간 스냅샷 구독 순서 개선
- **이용 제한 / 만 14세 미만 승인 대기 화면 동선 보완 (`home_screen.dart`, `onboarding_screen.dart`)**
  - 승인 대기 화면과 이용 제한 화면에서 다른 계정으로 전환하거나 보호자 동의를 재신청할 수 있도록 **보호자 정보 다시 입력(재신청)**, **설정**, **로그아웃** 버튼 추가

### ☁️ 2) 클라우드 동기화 · 알림 · 테마 동작 안정화
- **자동 동기화(Auto Sync) 및 삭제 동기화 버그 수정 (`sync_service.dart`)**
  - 할 일·기분·가계부 데이터 변경 시 2초 디바운스(Debounce) 기반 자동 백업이 동작하도록 리스너 연결
  - 로컬에서 삭제한 항목이 백업(`syncNow`) 시 클라우드의 이전 데이터와 병합되어 다시 살아나던 문제를 수정하고, 로컬에 없는 원격 문서도 배치 삭제되도록 `_batchSet` 로직 보완
- **데이터 복원 시 일일 비서 알림 유지 (`todo_repository.dart`, `main.dart`)**
  - `TodoRepository.replaceAll()` 실행 시 `cancelAll()`로 인해 일일 비서 알림(아침·점심·저녁·잠자리·주간 요약)까지 모두 취소되던 문제를 수정하여 개별 할 일 알림만 취소하도록 변경
  - 할 일·기분·가계부 변경 시 일일 비서 알림 문구가 최신 상태로 자동 갱신되도록 리스너 연결
- **권한 변경 시 테마 폴백 및 Pro 안내 정합성 개선 (`main.dart`, `home_screen.dart`, `pro_request_screen.dart`, `parent_consent_repository.dart`)**
  - 비로그인 또는 일반 등급으로 전환 시 Pro 전용 커스텀 테마(고양이·강아지·기린·커피)가 시스템 테마로 즉시 폴백되도록 처리
  - Pro 신청 화면에서 Beta 등급도 Pro 혜택 보유자로 인식하도록 수정하고, 보호자 동의 신청·승인·거절 시 관리자 및 사용자에게 앱 내 알림이 발송되도록 보완

### 🛡 3) 보안(Security) 강화 및 회원 탈퇴 데이터 완전 정리
- **Firestore 보안 규칙 권한 상승 차단 (`firestore.rules`)**
  - 일반 사용자가 본인 `users/{uid}` 문서의 `role`(등급)이나 `disabled`(계정 정지 여부) 필드를 임의로 수정할 수 없도록 권한 상승(Privilege Escalation) 취약점 차단
  - 만 14세 미만 사용자의 보호자 동의 재신청(`parent_consents/{uid}` 업데이트) 및 회원 탈퇴 시 본인 데이터 삭제가 정상 허용되도록 보안 규칙 보완
- **회원 탈퇴 시 개인정보 완전 삭제 및 프로필 수정 버그 수정 (`profile_repository.dart`)**
  - 프로필 사진을 기본 이미지로 초기화할 때 휴대폰 번호(`phoneNumber`)와 국가 코드(`countryCode`)가 유실되던 버그 수정
  - 회원 탈퇴(`deleteAccount`) 시 Google 재인증을 먼저 수행해 `requires-recent-login` 오류로 인한 부분 삭제 상태를 방지하고, `todos` 외에 `moods`, `ledger`, `parent_consents`, `phone_registry`(휴대폰 중복 방지 컬렉션) 및 로컬 프로필 사진까지 모두 삭제하도록 개선

### 📦 4) 릴리스 빌드 환경 업데이트 (`pubspec.yaml`, `gradle-wrapper.properties`)
- Google Play Store 업로드용 버전 업데이트 (`1.5.1+34` → `1.5.2+35`)
- Android Studio 최신 JBR(Java 25) 환경 호환을 위해 Gradle Wrapper 버전을 `9.1.0`으로 업데이트 및 릴리스 `.aab` 번들 빌드 완료

---

## 🔧 7. 추가 업데이트 (v1.6.0 ~ v1.6.2)

### 🧩 1) 메모 · 알람 · 홈 화면 위젯 (v1.6.0)
- 메모 기능과 알람(아침 깨우기·잘 때·일반) 추가
- `home_widget` 기반 홈 화면 위젯 9종 — Android(RemoteViews)와 iOS(WidgetKit, App Group 공유)를 같은 데이터 키로 구성
- iOS 위젯의 할 일 체크는 App Group 대기열에 쌓았다가 앱을 열 때 `TodoRepository`로 반영해 Firebase 동기화와 충돌하지 않도록 처리

### ⏰ 2) 알람이 실제로 울리도록 개선 (v1.6.1)
- 기기 기본 알람음 URI 대신 앱에 포함된 알람음을 알람 볼륨으로 재생하는 새 알림 채널로 교체
- 알람 시각에 전체 화면 알람 화면을 띄우고(잠금 화면 위 표시 포함) 1분 동안 소리·진동 → **알람 중지** 또는 **1·5·10·30분 다시 울림**
- 소리는 네이티브(Android `MediaPlayer`, iOS `AVAudioPlayer`) MethodChannel로 재생하고, iOS는 30초 제한을 후속 알림으로 보완

### 🎉 3) 정식 출시 준비 (v1.6.1)
- 앱 이름과 아이콘에서 Beta 표기 제거
- 기분 한 줄·가계부·동물/커피 테마를 모든 등급에 개방하고 사용설명서에서 등급 안내 제거

### ⚡ 4) 앱 최적화 · 보안 (v1.6.2)
- **R8 코드·리소스 축소와 난독화** — Play Console의 "DEX 코드 최적화 기준점 미만(난독화 2%)" 경고 대응
  - 리플렉션·Gson을 쓰는 `flutter_local_notifications`만 keep 규칙으로 보존(`proguard-rules.pro`)
  - R8 매핑 파일과 네이티브 디버그 심볼을 번들에 포함해 비정상 종료 스택 해독 가능
- **Dart 난독화** — `--obfuscate --split-debug-info` 로 빌드, 심볼 파일은 저장소 밖(`symbols/`, git 제외)에 보관
- **신규 설치 크기 19.7MB → 12.1MB** (약 38% 감소)
- **넓은 화면(edge-to-edge)** — Android 15 미만에서도 화면 끝까지 그리고, 투명한 상태 표시줄·내비게이션 바의 아이콘 색을 테마 밝기에 맞춤 (투명 AppBar에서 아이콘이 흰색으로 보이던 문제 해결)
- **보안** — 암호화되지 않은 http 통신 차단. Android 자동 백업은 동기화가 없는 일반 등급의 기기 이전 수단이라 유지

### ♿ 5) 전 연령 사용성 개선 (v1.6.2)
- 큰 글씨 모드: `MaterialApp.builder`에서 `TextScaler`를 휴대폰 배율 × 앱 배율로 적용(최대 2배), 크게 이상이면 `outlineVariant`를 `outline`으로 바꿔 테두리 강조
- 삭제 되돌리기: 각 Repository에 `restore()`를 두고 화면을 닫기 전에 `ScaffoldMessenger`를 잡아 두어 이전 화면에서도 스낵바 표시
- 백업 파일: 저장 키 화이트리스트를 JSON으로 묶어 내보내고, 불러올 때 항목 수 미리보기 → 각 Repository `reload()`로 알람·할 일 알림까지 다시 예약
- 홈 화면 메뉴: `HomeMenuRepository`(순서·숨김 저장) + `ReorderableListView` 설정 화면
- 타이머·세계시각·메모와 **홈 화면 타이머 위젯**도 로그인 필요 — 앱이 App Group / 위젯 데이터에 로그인 여부를 기록하고, 위젯은 잠금 안내를 보여주며 시작 동작에서도 한 번 더 확인
