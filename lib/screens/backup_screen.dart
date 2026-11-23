import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/backup_service.dart';

/// 백업 파일 내보내기 / 불러오기.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

  Future<void> _export(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _busy = true);
    try {
      await BackupService.export(origin: origin);
    } catch (e) {
      _snack('백업 파일을 만들지 못했어요: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final backup = await BackupService.pick();
      if (backup == null || !mounted) return;
      final when = backup.exportedAt == null
          ? '알 수 없음'
          : DateFormat('y년 M월 d일 HH:mm', 'ko_KR').format(backup.exportedAt!);
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('백업을 불러올까요?'),
          content: Text(
            '백업한 때: $when\n'
            '할 일 ${backup.todoCount}개 · 메모 ${backup.memoCount}개\n'
            '가계부 ${backup.ledgerCount}건 · 기분 ${backup.moodCount}개 · 알람 ${backup.alarmCount}개\n\n'
            '지금 이 기기의 기록은 백업 파일 내용으로 바뀌고, 되돌릴 수 없어요.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('불러오기')),
          ],
        ),
      );
      if (ok != true) return;
      await BackupService.restore(backup);
      _snack('백업을 불러왔어요.');
    } on FormatException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('백업 파일을 읽지 못했어요: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('기록 백업')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Text(
              '휴대폰을 바꾸거나 앱을 다시 설치하기 전에 백업 파일을 만들어 두세요. '
              '할 일·메모·가계부·기분·알람·세계 시각과 화면 설정이 한 파일에 담겨요.',
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            _ActionCard(
              icon: Icons.upload_file_rounded,
              color: const Color(0xFF6C5CE7),
              title: '백업 파일 내보내기',
              description: '파일을 만든 뒤 Google 드라이브, 내 파일, 메일 등 원하는 곳에 저장해요.',
              builder: (ctx) => FilledButton(
                onPressed: _busy ? null : () => _export(ctx),
                child: const Text('내보내기'),
              ),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.download_rounded,
              color: const Color(0xFF22B6A0),
              title: '백업 파일 불러오기',
              description: '저장해 둔 백업 파일(.json)을 골라 기록을 되살려요.',
              builder: (_) => OutlinedButton(
                onPressed: _busy ? null : _import,
                child: const Text('불러오기'),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '※ 백업 파일에는 기록이 그대로 담겨 있으니 다른 사람과 공유하지 말고 '
              '안전한 곳에 보관해 주세요.',
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.builder,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(description,
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: 13, height: 1.45)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: Builder(builder: builder)),
        ],
      ),
    );
  }
}
