# ── R8 규칙 ─────────────────────────────────────────────────────────────
# Flutter 엔진·플러그인 대부분은 자체 consumer 규칙을 갖고 있고,
# 아래는 규칙이 없거나 리플렉션을 쓰는 부분만 지정합니다.

# flutter_local_notifications: 예약 알림을 Gson 으로 저장/복원 (제네릭 타입 정보 필요)
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# Flutter 지연 컴포넌트(Play Core) — 사용하지 않음
-dontwarn com.google.android.play.core.**

# 비정상 종료 보고서의 줄 번호는 남기고 원본 파일 이름은 숨김
-keepattributes LineNumberTable
-renamesourcefileattribute SourceFile
