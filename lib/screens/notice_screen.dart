import 'package:flutter/material.dart';

import '../data/announcement_repository.dart';
import 'announcement_screen.dart';

/// 공지사항 — Firestore notices 컬렉션을 표시.
class NoticeScreen extends StatelessWidget {
  const NoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AnnouncementScreen(
      kind: AnnouncementKind.notice,
      title: '공지사항',
    );
  }
}
