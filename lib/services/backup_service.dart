import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/alarm_repository.dart';
import '../data/home_menu_repository.dart';
import '../data/ledger_repository.dart';
import '../data/memo_repository.dart';
import '../data/mood_repository.dart';
import '../data/theme_repository.dart';
import '../data/todo_repository.dart';
import '../data/world_clock_repository.dart';
import 'widget_service.dart';

/// 기기 안의 기록을 백업 파일(JSON)로 내보내고 다시 불러옵니다.
/// 로그인·동기화 없이도 기기 변경이나 재설치 때 기록을 옮길 수 있게 합니다.
class BackupService {
  BackupService._();

  static const _app = 'mytodo';
  static const _format = 1;

  /// 백업에 담는 저장 키. (값이 문자열 목록인 키는 [_listKeys])
  static const _stringKeys = [
    'todos_v1',
    'memos_v1',
    'ledger_entries_v1',
    'mood_entries_v1',
    'alarms_v1',
    'app_theme_v1',
    'app_display_mode_v1',
    'app_text_size_v1',
    HomeMenuRepository.key,
  ];
  static const _listKeys = ['world_clock_cities_v1'];

  /// 백업 파일을 만들어 공유 시트(드라이브·파일·메일 등에 저장)를 엽니다.
  static Future<void> export({Rect? origin}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, Object>{};
    for (final k in _stringKeys) {
      final v = prefs.getString(k);
      if (v != null) data[k] = v;
    }
    for (final k in _listKeys) {
      final v = prefs.getStringList(k);
      if (v != null) data[k] = v;
    }
    final now = DateTime.now();
    final json = const JsonEncoder.withIndent(' ').convert({
      'app': _app,
      'format': _format,
      'exportedAt': now.toIso8601String(),
      'data': data,
    });
    final dir = await getTemporaryDirectory();
    final name = 'mytodo_backup_${DateFormat('yyyyMMdd_HHmm').format(now)}.json';
    final file = File('${dir.path}/$name');
    await file.writeAsString(json, flush: true);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      subject: '나의 할 일 백업',
      sharePositionOrigin: origin,
    ));
  }

  /// 백업 파일을 고릅니다. 취소하면 null.
  /// 올바른 백업 파일이 아니면 [FormatException].
  static Future<BackupFile?> pick() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (files.isEmpty) return null;
    final text = utf8.decode(await files.first.readAsBytes());
    final map = jsonDecode(text);
    if (map is! Map || map['app'] != _app || map['data'] is! Map) {
      throw const FormatException('나의 할 일 백업 파일이 아니에요.');
    }
    if ((map['format'] as num? ?? 0) > _format) {
      throw const FormatException('더 새로운 버전의 앱에서 만든 백업 파일이에요. 앱을 업데이트해 주세요.');
    }
    return BackupFile(
      exportedAt: DateTime.tryParse(map['exportedAt'] as String? ?? ''),
      data: Map<String, dynamic>.from(map['data'] as Map),
    );
  }

  /// 백업 내용으로 기기의 기록을 바꿉니다 (백업에 없는 항목은 비워짐).
  static Future<void> restore(BackupFile backup) async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in _stringKeys) {
      final v = backup.data[k];
      if (v is String) {
        await prefs.setString(k, v);
      } else {
        await prefs.remove(k);
      }
    }
    for (final k in _listKeys) {
      final v = backup.data[k];
      if (v is List) {
        await prefs.setStringList(k, v.map((e) => '$e').toList());
      } else {
        await prefs.remove(k);
      }
    }
    await TodoRepository.instance.reloadFromBackup();
    await MemoRepository.instance.reload();
    await LedgerRepository.instance.reload();
    await MoodRepository.instance.reload();
    await AlarmRepository.instance.reload();
    await WorldClockRepository.instance.reload();
    await ThemeRepository.instance.reload();
    await HomeMenuRepository.instance.load();
    await WidgetService.publishAll();
  }
}

/// 불러온 백업 파일 내용.
class BackupFile {
  BackupFile({required this.exportedAt, required this.data});
  final DateTime? exportedAt;
  final Map<String, dynamic> data;

  int _count(String key) {
    final v = data[key];
    if (v is! String) return 0;
    try {
      return (jsonDecode(v) as List).length;
    } catch (_) {
      return 0;
    }
  }

  int get todoCount => _count('todos_v1');
  int get memoCount => _count('memos_v1');
  int get ledgerCount => _count('ledger_entries_v1');
  int get moodCount => _count('mood_entries_v1');
  int get alarmCount => _count('alarms_v1');
}
