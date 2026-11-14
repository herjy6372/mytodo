import 'package:cloud_firestore/cloud_firestore.dart';

/// 사용자 등급. 새로운 권한이 추가되면 enum 에 명시적으로 표현합니다.
///
/// 기능 접근 권한 요약:
///   normal  → 할일·그래프·기본설정·언어
///   pro     → normal + 기분·가계부·타이머·세계시각·동물테마 (클라우드 동기화 제외)
///   beta    → pro  + 클라우드 동기화
///   admin   → 모든 기능
///   student → normal 과 동일 (만 14세 미만, Beta·Pro 부여 불가)
enum UserRole {
  admin('ADMIN', '관리자'),
  beta('BETA', '베타'),
  pro('PRO', '프로'),
  student('STUDENT', '학생'),
  normal('NORMAL', '일반');

  const UserRole(this.code, this.label);
  final String code;
  final String label;

  static UserRole fromCode(String? code) {
    for (final r in UserRole.values) {
      if (r.code == code) return r;
    }
    // 'GUEST' 포함 알 수 없는 코드는 일반으로 처리
    return UserRole.normal;
  }

  // ── 기능별 접근 권한 ────────────────────────────────────────────

  /// 클라우드 동기화 — Beta·Admin 전용 (Pro 는 제외).
  bool get canSync => this == UserRole.beta || this == UserRole.admin;

  /// Pro 기능 (기분·가계부·타이머·세계시각·동물테마) — Pro·Beta·Admin.
  bool get canUsePro =>
      this == UserRole.pro ||
      this == UserRole.beta ||
      this == UserRole.admin;

  /// Beta 전용 기능 — Beta·Admin.
  bool get canUseBeta => this == UserRole.beta || this == UserRole.admin;

  /// 동물 테마 (고양이·강아지) — Pro·Beta·Admin.
  bool get canUseAnimalTheme => canUsePro;

  /// 공지/업데이트 내역 조회 가능 여부 (모든 등급 가능).
  bool get canViewAnnouncements => true;

  /// 공지/업데이트 내역 작성·수정·삭제 가능 여부 (ADMIN 만).
  bool get canEditAnnouncements => this == UserRole.admin;

  /// 다른 사용자 등급 변경 가능 여부.
  bool get canManageUsers => this == UserRole.admin;

  /// 앱 핵심 기능 이용 가능 여부 (학생 이상 + 개인정보 동의).
  bool get canUseApp =>
      this == UserRole.normal ||
      this == UserRole.pro ||
      this == UserRole.beta ||
      this == UserRole.student ||
      this == UserRole.admin;
}

/// 사용자 프로필. Firestore: users/{uid}
class UserProfile {
  UserProfile({
    required this.uid,
    required this.email,
    this.nickname,
    this.birthDate,
    this.photoUrl,
    required this.role,
    required this.ageVerified,
    required this.privacyAgreed,
    this.phoneCountryCode,
    this.phoneNumber,
    this.countryCode,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String uid;
  final String email;
  String? nickname;
  DateTime? birthDate;
  String? photoUrl;
  UserRole role;
  bool ageVerified;
  bool privacyAgreed;
  String? phoneCountryCode; // 예: '+82'
  String? phoneNumber;      // 예: '01012345678'
  /// 거주 국가 코드: 'KR' = 대한민국, 'US' = 미국, null = 미설정
  String? countryCode;
  final DateTime createdAt;
  DateTime? updatedAt;

  bool get hasCompletedProfile =>
      (nickname?.trim().isNotEmpty ?? false) &&
      ageVerified &&
      privacyAgreed;

  /// 온보딩 완료 여부: 생년월일 + 개인정보 동의.
  bool get hasCompletedOnboarding =>
      birthDate != null && privacyAgreed;

  int? get age {
    final b = birthDate;
    if (b == null) return null;
    final now = DateTime.now();
    var a = now.year - b.year;
    final hadBirthday = (now.month > b.month) ||
        (now.month == b.month && now.day >= b.day);
    if (!hadBirthday) a -= 1;
    return a;
  }

  /// 만 14세 미만 여부.
  bool get isUnder14 {
    final a = age;
    return a != null && a < 14;
  }

  String displayName() {
    final n = nickname?.trim();
    if (n != null && n.isNotEmpty) return n;
    return email;
  }

  Map<String, dynamic> toFirestore() => {
        'email': email,
        'nickname': nickname,
        'birthDate':
            birthDate == null ? null : Timestamp.fromDate(birthDate!),
        'photoUrl': photoUrl,
        'role': role.code,
        'ageVerified': ageVerified,
        'privacyAgreed': privacyAgreed,
        'phoneCountryCode': phoneCountryCode,
        'phoneNumber': phoneNumber,
        'countryCode': countryCode,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory UserProfile.fromFirestore(
      String uid, Map<String, dynamic> data) {
    final created = data['createdAt'];
    final updated = data['updatedAt'];
    DateTime? birthDate;
    final raw = data['birthDate'];
    if (raw is Timestamp) {
      birthDate = raw.toDate();
    } else if (raw is String && raw.isNotEmpty) {
      birthDate = DateTime.tryParse(raw);
    } else if (data['birthYear'] is num) {
      // 구버전 호환: birthYear(int) 만 있으면 1월 1일로 가정
      final y = (data['birthYear'] as num).toInt();
      birthDate = DateTime(y, 1, 1);
    }
    return UserProfile(
      uid: uid,
      email: data['email'] as String? ?? '',
      nickname: data['nickname'] as String?,
      birthDate: birthDate,
      photoUrl: data['photoUrl'] as String?,
      role: UserRole.fromCode(data['role'] as String?),
      ageVerified: data['ageVerified'] as bool? ?? false,
      privacyAgreed: data['privacyAgreed'] as bool? ?? false,
      phoneCountryCode: data['phoneCountryCode'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      countryCode: data['countryCode'] as String?,
      createdAt: created is Timestamp ? created.toDate() : DateTime.now(),
      updatedAt: updated is Timestamp ? updated.toDate() : null,
    );
  }

  UserProfile copyWith({
    String? nickname,
    DateTime? birthDate,
    bool clearBirthDate = false,
    String? photoUrl,
    UserRole? role,
    bool? ageVerified,
    bool? privacyAgreed,
    String? phoneCountryCode,
    String? phoneNumber,
    String? countryCode,
  }) =>
      UserProfile(
        uid: uid,
        email: email,
        nickname: nickname ?? this.nickname,
        birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
        photoUrl: photoUrl ?? this.photoUrl,
        role: role ?? this.role,
        ageVerified: ageVerified ?? this.ageVerified,
        privacyAgreed: privacyAgreed ?? this.privacyAgreed,
        phoneCountryCode: phoneCountryCode ?? this.phoneCountryCode,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        countryCode: countryCode ?? this.countryCode,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
