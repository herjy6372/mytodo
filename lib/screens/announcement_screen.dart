import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/announcement_repository.dart';
import '../data/auth_repository.dart';
import '../data/profile_repository.dart';
import '../models/announcement.dart';

/// 공지사항/업데이트 내역 공용 화면.
class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({
    super.key,
    required this.kind,
    required this.title,
    this.showVersion = false,
  });

  final AnnouncementKind kind;
  final String title;
  final bool showVersion;

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  late final AnnouncementRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = AnnouncementRepository(widget.kind);
    ProfileRepository.instance.addListener(_onChange);
  }

  @override
  void dispose() {
    ProfileRepository.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  bool get _canEdit =>
      ProfileRepository.instance.role.canEditAnnouncements;

  bool get _canView =>
      ProfileRepository.instance.role.canViewAnnouncements;

  Future<void> _openEdit({Announcement? entry}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AnnouncementEditScreen(
          repo: _repo,
          showVersion: widget.showVersion,
          entry: entry,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!_canView) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              '게스트 등급은 공지/업데이트 내역을 볼 수 없습니다.\n'
              '설정 → 프로필에서 닉네임 입력과 개인정보 동의를 마치면 일반 등급으로 전환됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.6),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: StreamBuilder<List<Announcement>>(
        stream: _repo.watch(),
        builder: (context, snap) {
          if (snap.hasError) {
            final errStr = snap.error.toString();
            final isPermDenied = errStr.contains('permission-denied') ||
                errStr.contains('PERMISSION_DENIED');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPermDenied
                          ? Icons.lock_outline_rounded
                          : Icons.cloud_off_rounded,
                      size: 52,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isPermDenied
                          ? '로그인 후 이용할 수 있습니다.'
                          : '불러오기 실패: ${snap.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 64,
                        color: scheme.onSurfaceVariant
                            .withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    Text(
                      _canEdit
                          ? '아직 게시글이 없습니다.\n오른쪽 아래 [+ 작성] 으로 첫 글을 올려보세요.'
                          : '아직 등록된 ${widget.title}이 없습니다.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _AnnouncementTile(
              entry: list[i],
              showVersion: widget.showVersion,
              canEdit: _canEdit,
              onEdit: () => _openEdit(entry: list[i]),
              onDelete: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    title: const Text('삭제하시겠어요?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('취소')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('삭제')),
                    ],
                  ),
                );
                if (ok == true) {
                  await _repo.delete(list[i].id);
                }
              },
            ),
          );
        },
      ),
      floatingActionButton: _canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _openEdit(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('작성'),
            )
          : null,
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({
    required this.entry,
    required this.showVersion,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  final Announcement entry;
  final bool showVersion;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showVersion && (entry.version?.isNotEmpty ?? false))
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('v${entry.version}',
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      )),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('공지',
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      )),
                ),
              const Spacer(),
              Text(
                DateFormat('y년 M월 d일', 'ko_KR').format(entry.createdAt),
                style:
                    TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
              if (canEdit)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz_rounded,
                      color: scheme.onSurfaceVariant),
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('수정')),
                    PopupMenuItem(value: 'delete', child: Text('삭제')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(entry.title,
              style: const TextStyle(
                  fontSize: 15.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            entry.body,
            style:
                const TextStyle(fontSize: 13.5, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementEditScreen extends StatefulWidget {
  const _AnnouncementEditScreen({
    required this.repo,
    required this.showVersion,
    this.entry,
  });
  final AnnouncementRepository repo;
  final bool showVersion;
  final Announcement? entry;

  @override
  State<_AnnouncementEditScreen> createState() =>
      _AnnouncementEditScreenState();
}

class _AnnouncementEditScreenState extends State<_AnnouncementEditScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  late final TextEditingController _versionCtrl;
  bool _busy = false;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _bodyCtrl = TextEditingController(text: e?.body ?? '');
    _versionCtrl = TextEditingController(text: e?.version ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _versionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 내용을 입력해 주세요.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      if (_isEditing) {
        widget.entry!
          ..title = title
          ..body = body
          ..version = widget.showVersion ? _versionCtrl.text.trim() : null;
        await widget.repo.update(widget.entry!);
      } else {
        await widget.repo.create(
          title: title,
          body: body,
          version: widget.showVersion ? _versionCtrl.text.trim() : null,
          authorEmail: AuthRepository.instance.email ?? '',
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? '게시글 수정' : '게시글 작성')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showVersion) ...[
                const _Label('버전 (예: 1.0.0)'),
                TextField(
                  controller: _versionCtrl,
                  decoration: const InputDecoration(
                    hintText: '1.0.0',
                    prefixIcon: Icon(Icons.tag_rounded),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const _Label('제목'),
              TextField(
                controller: _titleCtrl,
                maxLength: 80,
                decoration: const InputDecoration(
                  hintText: '제목을 입력하세요',
                ),
              ),
              const _Label('내용'),
              TextField(
                controller: _bodyCtrl,
                maxLines: 12,
                decoration: const InputDecoration(
                  hintText: '내용을 입력하세요',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_isEditing ? '수정 완료' : '게시'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        text,
        style:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}
