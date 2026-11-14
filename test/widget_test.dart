// 핵심 도메인 로직 단위 테스트.
//
// HomeScreen 등 화면 위젯은 생성 시점에 FirebaseAuth.instance /
// FirebaseFirestore.instance 를 즉시 참조하므로 순수 `flutter test` 환경에서는
// 검증하기 어렵다(플랫폼 채널이 없어 실패). 대신 Firebase 에 의존하지 않는
// 순수 Dart 도메인 모델을 검증해 회귀를 잡는다.
import 'package:flutter_test/flutter_test.dart';

import 'package:mytodo/models/todo.dart';
import 'package:mytodo/models/user_profile.dart';
import 'package:mytodo/services/daily_notification_service.dart';

void main() {
  group('TodoCategory', () {
    test('fromName 은 알려진 이름을 올바른 카테고리로 변환한다', () {
      expect(TodoCategory.fromName('work'), TodoCategory.work);
      expect(TodoCategory.fromName('health'), TodoCategory.health);
    });

    test('fromName 은 알 수 없는 이름을 기타로 처리한다', () {
      expect(TodoCategory.fromName('unknown'), TodoCategory.etc);
    });
  });

  group('UserRole', () {
    test('fromCode 는 알려진 코드를 올바른 등급으로 변환한다', () {
      expect(UserRole.fromCode('ADMIN'), UserRole.admin);
      expect(UserRole.fromCode('BETA'), UserRole.beta);
      expect(UserRole.fromCode('PRO'), UserRole.pro);
      expect(UserRole.fromCode('STUDENT'), UserRole.student);
    });

    test('fromCode 는 알 수 없는 코드(예: 구버전 GUEST)를 일반으로 처리한다', () {
      expect(UserRole.fromCode('GUEST'), UserRole.normal);
      expect(UserRole.fromCode(null), UserRole.normal);
    });

    test('클라우드 동기화는 베타·관리자만 가능하다', () {
      expect(UserRole.beta.canSync, isTrue);
      expect(UserRole.admin.canSync, isTrue);
      expect(UserRole.pro.canSync, isFalse);
      expect(UserRole.normal.canSync, isFalse);
    });

    test('Pro 기능은 프로 이상 등급에서 가능하다', () {
      for (final role in [UserRole.pro, UserRole.beta, UserRole.admin]) {
        expect(role.canUsePro, isTrue, reason: '$role 는 Pro 기능을 사용할 수 있어야 한다');
      }
      for (final role in [UserRole.normal, UserRole.student]) {
        expect(role.canUsePro, isFalse, reason: '$role 는 Pro 기능을 사용할 수 없어야 한다');
      }
    });
  });

  group('DailyNotifSlot', () {
    test('알림 ID 가 서로 겹치지 않는다', () {
      final ids = DailyNotifSlot.values.map((s) => s.id).toSet();
      expect(ids.length, DailyNotifSlot.values.length);
    });

    test('아침·점심·저녁·잠자리는 매일, 주간 요약은 일요일 10시로 설정돼 있다', () {
      expect(DailyNotifSlot.morning.hour, 9);
      expect(DailyNotifSlot.lunch.hour, 12);
      expect(DailyNotifSlot.evening.hour, 18);
      expect(DailyNotifSlot.bedtime.hour, 21);
      expect(DailyNotifSlot.weeklySummary.hour, 10);
    });

    test('슬롯별 SharedPreferences 키가 서로 겹치지 않는다', () {
      final keys = DailyNotifSlot.values.map((s) => s.prefKey).toSet();
      expect(keys.length, DailyNotifSlot.values.length);
    });
  });
}
