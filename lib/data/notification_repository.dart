import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  AppNotification({
    required this.id,
    required this.targetId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.read = false,
    this.extra,
  });

  final String id;
  final String targetId; // uid 또는 'ADMIN'
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  bool read;
  final Map<String, dynamic>? extra;

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final d = Map<String, dynamic>.from(doc.data() as Map);
    return AppNotification(
      id: doc.id,
      targetId: d['targetId'] as String? ?? '',
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      type: d['type'] as String? ?? '',
      createdAt: (d['createdAt'] is Timestamp)
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      read: d['read'] as bool? ?? false,
      extra: d['extra'] as Map<String, dynamic>?,
    );
  }
}

class NotificationRepository {
  static const adminTargetId = 'ADMIN';
  static final _col =
      FirebaseFirestore.instance.collection('notifications');

  static Future<void> notifyAdmin({
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic>? extra,
  }) async {
    try {
      await _col.add({
        'targetId': adminTargetId,
        'title': title,
        'body': body,
        'type': type,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'extra': ?extra,
      });
    } catch (_) {}
  }

  static Future<void> notifyUser({
    required String uid,
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic>? extra,
  }) async {
    try {
      await _col.add({
        'targetId': uid,
        'title': title,
        'body': body,
        'type': type,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'extra': ?extra,
      });
    } catch (_) {}
  }

  static Stream<List<AppNotification>> watchFor(String targetId) {
    return _col
        .where('targetId', isEqualTo: targetId)
        .snapshots()
        .map((s) {
      final list = s.docs.map(AppNotification.fromFirestore).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  static Stream<int> watchUnreadCount(String targetId) {
    return _col
        .where('targetId', isEqualTo: targetId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  static Future<void> markRead(String docId) async {
    try {
      await _col.doc(docId).update({'read': true});
    } catch (_) {}
  }

  static Future<void> markAllRead(String targetId) async {
    try {
      final snap = await _col
          .where('targetId', isEqualTo: targetId)
          .where('read', isEqualTo: false)
          .get();
      if (snap.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (_) {}
  }
}
