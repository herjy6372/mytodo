import 'package:cloud_firestore/cloud_firestore.dart';

enum ParentConsentStatus {
  pending('pending', '승인 대기'),
  approved('approved', '승인됨'),
  rejected('rejected', '거절됨');

  const ParentConsentStatus(this.code, this.label);
  final String code;
  final String label;

  static ParentConsentStatus fromCode(String? code) {
    for (final s in ParentConsentStatus.values) {
      if (s.code == code) return s;
    }
    return ParentConsentStatus.pending;
  }
}

/// 만 14세 미만 보호자 동의 정보. Firestore: parent_consents/{uid}
class ParentConsent {
  ParentConsent({
    required this.uid,
    required this.childEmail,
    required this.parentName,
    required this.parentAge,
    required this.parentPhone,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
    this.note,
  });

  final String uid;
  final String childEmail;
  final String parentName;
  final int parentAge;
  final String parentPhone;
  ParentConsentStatus status;
  final DateTime createdAt;
  DateTime? reviewedAt;
  String? note;

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'childEmail': childEmail,
        'parentName': parentName,
        'parentAge': parentAge,
        'parentPhone': parentPhone,
        'status': status.code,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory ParentConsent.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ParentConsent(
      uid: d['uid'] as String? ?? doc.id,
      childEmail: d['childEmail'] as String? ?? '',
      parentName: d['parentName'] as String? ?? '',
      parentAge: (d['parentAge'] as num?)?.toInt() ?? 0,
      parentPhone: d['parentPhone'] as String? ?? '',
      status: ParentConsentStatus.fromCode(d['status'] as String?),
      createdAt: (d['createdAt'] is Timestamp)
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      reviewedAt: (d['reviewedAt'] is Timestamp)
          ? (d['reviewedAt'] as Timestamp).toDate()
          : null,
      note: d['note'] as String?,
    );
  }
}
