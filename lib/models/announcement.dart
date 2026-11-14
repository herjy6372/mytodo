import 'package:cloud_firestore/cloud_firestore.dart';

/// 공지사항/업데이트 내역 공통 모델.
class Announcement {
  Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.updatedAt,
    this.authorEmail,
    this.version,
  });

  final String id;
  String title;
  String body;
  final DateTime createdAt;
  DateTime? updatedAt;
  String? authorEmail;
  String? version; // 업데이트 내역 전용 (예: "1.0.0")

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'body': body,
        'version': version,
        'authorEmail': authorEmail,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory Announcement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final created = data['createdAt'];
    final updated = data['updatedAt'];
    return Announcement(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      version: data['version'] as String?,
      authorEmail: data['authorEmail'] as String?,
      createdAt: created is Timestamp ? created.toDate() : DateTime.now(),
      updatedAt: updated is Timestamp ? updated.toDate() : null,
    );
  }
}
