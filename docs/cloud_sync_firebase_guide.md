# 클라우드 동기화 - Firebase 도입 가이드

이 앱은 클라우드 동기화를 위한 인터페이스(`SyncBackend`)를 갖추고 있으며,
기본은 아무 동작도 하지 않는 `NoopSyncBackend`로 설정되어 있습니다.
실제 동기화를 활성화하려면 아래 절차에 따라 Firebase 백엔드를 연결하세요.

## 1. 왜 Firebase 인가

- 무료 티어(Spark plan) 만으로 개인 프로젝트는 충분
- Authentication(이메일/비밀번호, Google, Apple) + Firestore(실시간 DB) 조합이
  Flutter 와 가장 잘 맞고 공식 SDK가 잘 관리됨
- 오프라인 캐시 내장 → 비행기 모드에서도 자연스럽게 동작
- 보안 규칙으로 사용자별 데이터 격리 가능

## 2. 설치 단계

1. https://console.firebase.google.com 에서 프로젝트 생성
2. CLI 설치 후 로그인
   ```bash
   npm i -g firebase-tools
   firebase login
   dart pub global activate flutterfire_cli
   ```
3. 프로젝트 루트에서
   ```bash
   flutterfire configure
   ```
   → 자동으로 안드로이드/iOS 앱 등록 + `firebase_options.dart` 생성
4. `pubspec.yaml` 에 패키지 추가
   ```yaml
   dependencies:
     firebase_core: ^3.6.0
     firebase_auth: ^5.3.1
     cloud_firestore: ^5.4.4
     google_sign_in: ^6.2.1   # 구글 로그인을 추가하려면
   ```
5. `lib/main.dart` 의 main() 가장 위쪽에 초기화 코드를 넣습니다.
   ```dart
   import 'package:firebase_core/firebase_core.dart';
   import 'firebase_options.dart';
   ...
   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
   ```

## 3. Firestore 데이터 모델 권장안

```
todos (collection)
  └── {userId} (doc)
       └── items (subcollection)
            └── {todoId} (doc)
                ├─ title       : string
                ├─ place       : string
                ├─ dueDate     : timestamp
                ├─ category    : string
                ├─ memo        : string
                ├─ isDone      : boolean
                ├─ createdAt   : timestamp
                └─ updatedAt   : timestamp
```

이 구조면 사용자별 데이터가 자연스럽게 분리되고,
`updatedAt` 으로 last-write-wins 동기화 정책을 구현하기 쉽습니다.

## 4. 보안 규칙(필수)

```
service cloud.firestore {
  match /databases/{db}/documents {
    match /todos/{userId}/items/{itemId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## 5. 코드 연결

`lib/services/sync_service.dart` 의 `SyncBackend` 인터페이스를 따라
`FirebaseSyncBackend` 를 만들면 됩니다. 예시 골격:

```dart
class FirebaseSyncBackend implements SyncBackend {
  final _db = FirebaseFirestore.instance;

  @override
  Future<void> uploadAll(String userId, List<Todo> todos) async {
    final batch = _db.batch();
    final ref = _db.collection('todos').doc(userId).collection('items');
    for (final t in todos) {
      batch.set(ref.doc(t.id), {
        ...t.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  @override
  Future<List<Todo>> downloadAll(String userId) async {
    final snap = await _db.collection('todos').doc(userId)
        .collection('items').get();
    return snap.docs.map((d) => Todo.fromJson(d.data())).toList();
  }
}
```

main() 에서:
```dart
SyncService.instance.backend = FirebaseSyncBackend();
```

## 6. 인증 교체

현재 `AuthRepository` 는 단순 로컬 저장이므로,
Firebase Auth 로 교체할 때는 `email` getter 를
`FirebaseAuth.instance.currentUser?.uid` (또는 email) 로 매핑하면 됩니다.
이 때도 `SyncService` 는 그대로 동작합니다.

## 7. 무엇을 추가로 고려해야 하나

- iOS 는 푸시 토큰을 받기 위해 APNs 인증서/키 등록이 필요합니다.
  (단, 우리 앱은 "로컬 알림"만 쓰고 있어서 서버 푸시가 필요 없으면
   APNs 설정 없이도 알림이 동작합니다.)
- 최초 로그인 직후에는 다운로드(downloadAll) → 로컬 머지 후 업로드 순서가 안전합니다.
- 충돌 정책: `updatedAt` 더 큰 쪽 우선(LWW) 또는 사용자 선택 다이얼로그.
- Firestore 비용은 read/write/delete 단위 과금이므로,
  실시간 listen 보다 화면 진입 시점/주기적 sync 가 안정적입니다.
