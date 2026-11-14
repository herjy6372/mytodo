import 'package:flutter/material.dart';

import '../data/announcement_repository.dart';
import 'announcement_screen.dart';

/// 업데이트 내역 — Firestore updates 컬렉션을 표시.
/// ADMIN 만 작성·수정·삭제 가능, 일반 등급은 읽기 전용.
class UpdateHistoryScreen extends StatelessWidget {
  const UpdateHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AnnouncementScreen(
      kind: AnnouncementKind.update,
      title: '업데이트 내역',
      showVersion: true,
    );
  }
}
