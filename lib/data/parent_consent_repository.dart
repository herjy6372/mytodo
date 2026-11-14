import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/parent_consent.dart';
import '../models/user_profile.dart';
import 'notification_repository.dart';

/// 보호자 동의 저장소. Firestore: parent_consents/{uid}
class ParentConsentRepository {
  static final _col =
      FirebaseFirestore.instance.collection('parent_consents');

  /// 현재 사용자의 보호자 동의 정보 조회.
  static Future<ParentConsent?> getFor(String uid) async {
    final doc = await _col.doc(uid).get();
    if (!doc.exists) return null;
    return ParentConsent.fromFirestore(doc);
  }

  /// 보호자 동의 신청 생성/덮어쓰기.
  static Future<void> submit({
    required String uid,
    required String childEmail,
    required String parentName,
    required int parentAge,
    required String parentPhone,
  }) async {
    await _col.doc(uid).set({
      'uid': uid,
      'childEmail': childEmail,
      'parentName': parentName,
      'parentAge': parentAge,
      'parentPhone': parentPhone,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await NotificationRepository.notifyAdmin(
      title: '보호자 동의(학생 등급) 신청',
      body: '$childEmail 님이 보호자 동의를 신청했습니다.',
      type: 'parent_consent_submitted',
      extra: {'uid': uid, 'email': childEmail},
    );
  }

  /// 관리자용: 전체 목록 스트림 (pending 포함 전체).
  static Stream<List<ParentConsent>> watchAll() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ParentConsent.fromFirestore).toList());
  }

  /// 승인: users/{uid}.role = STUDENT + status = approved
  static Future<void> approve(ParentConsent consent) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.update(_col.doc(consent.uid), {
      'status': 'approved',
      'reviewedAt': FieldValue.serverTimestamp(),
    });
    batch.update(
      FirebaseFirestore.instance.collection('users').doc(consent.uid),
      {'role': UserRole.student.code},
    );
    await batch.commit();
    await NotificationRepository.notifyUser(
      uid: consent.uid,
      title: '보호자 동의 승인 완료',
      body: '보호자 동의가 승인되어 학생 등급으로 앱을 이용하실 수 있습니다. 🎉',
      type: 'parent_consent_approved',
    );
  }

  /// 거절: status = rejected + 사유
  static Future<void> reject(ParentConsent consent, {String? note}) async {
    await _col.doc(consent.uid).update({
      'status': 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
      if (note != null && note.isNotEmpty) 'note': note,
    });
    await NotificationRepository.notifyUser(
      uid: consent.uid,
      title: '보호자 동의 거절 안내',
      body: note != null && note.isNotEmpty
          ? '보호자 동의 신청이 거절되었습니다.\n사유: $note'
          : '보호자 동의 신청이 거절되었습니다.',
      type: 'parent_consent_rejected',
      extra: note != null && note.isNotEmpty ? {'reason': note} : null,
    );
  }
}
