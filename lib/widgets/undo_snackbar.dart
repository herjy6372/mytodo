import 'package:flutter/material.dart';

/// 삭제 직후 "되돌리기" 버튼이 있는 안내를 하단에 띄웁니다.
///
/// [messenger] 는 화면을 닫기 전에 `ScaffoldMessenger.of(context)` 로 미리
/// 받아 두면, 이전 화면으로 돌아간 뒤에도 안내가 보입니다.
void showUndoSnackBar(
  ScaffoldMessengerState messenger,
  String message,
  Future<void> Function() onUndo,
) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 6),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(label: '되돌리기', onPressed: () => onUndo()),
    ));
}
