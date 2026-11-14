import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/announcement.dart';

/// 공지사항/업데이트 내역의 종류.
enum AnnouncementKind {
  notice('notices'),
  update('updates');

  const AnnouncementKind(this.collection);
  final String collection;
}

/// Firestore 기반 공지/업데이트 저장소.
/// - notices/* : 공지사항
/// - updates/* : 업데이트 내역
///
/// 보안 규칙은 docs/firebase_setup_steps.md 참고.
class AnnouncementRepository {
  AnnouncementRepository(this.kind);
  final AnnouncementKind kind;

  static final notices = AnnouncementRepository(AnnouncementKind.notice);
  static final updates = AnnouncementRepository(AnnouncementKind.update);

  CollectionReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection(kind.collection);

  /// 최신 순 스트림.
  Stream<List<Announcement>> watch() {
    return _ref
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Announcement.fromFirestore).toList());
  }

  Future<Announcement> create({
    required String title,
    required String body,
    required String authorEmail,
    String? version,
  }) async {
    final now = DateTime.now();
    final doc = await _ref.add({
      'title': title,
      'body': body,
      'version': version,
      'authorEmail': authorEmail,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final snap = await doc.get();
    return Announcement.fromFirestore(snap);
  }

  Future<void> update(Announcement a) async {
    await _ref.doc(a.id).set(a.toFirestore(), SetOptions(merge: true));
  }

  Future<void> delete(String id) async {
    await _ref.doc(id).delete();
  }
}
