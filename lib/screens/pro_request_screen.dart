import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/auth_repository.dart';
import '../data/notification_repository.dart';
import '../data/parent_consent_repository.dart';
import '../data/profile_repository.dart';
import '../models/parent_consent.dart';
import '../models/user_profile.dart';

// ─── 모델 ──────────────────────────────────────────────────────────────

enum ProRequestStatus {
  pending('pending', '검토 중'),
  approved('approved', '승인됨'),
  rejected('rejected', '거절됨');

  const ProRequestStatus(this.code, this.label);
  final String code;
  final String label;

  static ProRequestStatus fromCode(String? code) {
    for (final s in ProRequestStatus.values) {
      if (s.code == code) return s;
    }
    return ProRequestStatus.pending;
  }
}

class ProRequest {
  ProRequest({
    required this.id,
    required this.uid,
    required this.email,
    required this.currentRole,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
    this.note,
  });

  final String id;
  final String uid;
  final String email;
  final UserRole currentRole;
  ProRequestStatus status;
  final DateTime createdAt;
  DateTime? reviewedAt;
  String? note;

  factory ProRequest.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ProRequest(
      id: doc.id,
      uid: d['uid'] as String? ?? '',
      email: d['email'] as String? ?? '',
      currentRole: UserRole.fromCode(d['currentRole'] as String?),
      status: ProRequestStatus.fromCode(d['status'] as String?),
      createdAt: (d['createdAt'] is Timestamp)
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      reviewedAt: (d['reviewedAt'] is Timestamp)
          ? (d['reviewedAt'] as Timestamp).toDate()
          : null,
      note: d['note'] as String?,
    );
  }
}

// ─── 저장소 ────────────────────────────────────────────────────────────

class ProRequestRepository {
  static final _col = FirebaseFirestore.instance.collection('pro_requests');

  /// 신청 생성 (이미 pending 이면 재신청 불가).
  static Future<void> submit({
    required String uid,
    required String email,
    required UserRole currentRole,
  }) async {
    final existing = await _col
        .where('uid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception('already_pending');
    }
    await _col.add({
      'uid': uid,
      'email': email,
      'currentRole': currentRole.code,
      'targetRole': 'PRO',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    // 관리자에게 알림
    await NotificationRepository.notifyAdmin(
      title: 'Pro 등급 신청',
      body: '$email 님이 Pro 등급을 신청했습니다.',
      type: 'pro_request_submitted',
      extra: {'uid': uid, 'email': email},
    );
  }

  /// 관리자용: 전체 목록 스트림.
  static Stream<List<ProRequest>> watchAll() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ProRequest.fromFirestore).toList());
  }

  /// 승인: users/{uid}.role = PRO + 요청 status = approved
  static Future<void> approve(ProRequest req) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.update(_col.doc(req.id), {
      'status': 'approved',
      'reviewedAt': FieldValue.serverTimestamp(),
    });
    batch.update(
      FirebaseFirestore.instance.collection('users').doc(req.uid),
      {'role': 'PRO'},
    );
    await batch.commit();
    // 신청자에게 알림
    await NotificationRepository.notifyUser(
      uid: req.uid,
      title: 'Pro 등급 승인',
      body: 'Pro 등급 신청이 승인되었습니다. 🎉 이제 Pro 혜택을 이용하세요!',
      type: 'pro_approved',
    );
  }

  /// 거절: 요청 status = rejected + note (사유)
  static Future<void> reject(ProRequest req, {String? note}) async {
    await _col.doc(req.id).update({
      'status': 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
      if (note != null && note.isNotEmpty) 'note': note,
    });
    // 신청자에게 알림
    await NotificationRepository.notifyUser(
      uid: req.uid,
      title: 'Pro 등급 거절',
      body: note != null && note.isNotEmpty
          ? 'Pro 등급 신청이 거절되었습니다.\n사유: $note'
          : 'Pro 등급 신청이 거절되었습니다.',
      type: 'pro_rejected',
      extra: note != null && note.isNotEmpty ? {'reason': note} : null,
    );
  }

  /// 현재 사용자의 최신 신청 (없으면 null).
  static Future<ProRequest?> myLatest(String uid) async {
    final snap = await _col
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return ProRequest.fromFirestore(snap.docs.first);
  }
}

// ─── 거절 사유 선택 다이얼로그 (공통) ──────────────────────────────────────

/// [reasons]: 선택지 리스트. 마지막 항목이 "기타사유" 취급.
/// 반환값: 선택된 사유 문자열, 취소면 null.
Future<String?> showRejectReasonDialog(
  BuildContext context, {
  required String title,
  required List<String> reasons,
}) async {
  return await showDialog<String>(
    context: context,
    builder: (ctx) => _RejectReasonDialog(title: title, reasons: reasons),
  );
}

class _RejectReasonDialog extends StatefulWidget {
  const _RejectReasonDialog({required this.title, required this.reasons});
  final String title;
  final List<String> reasons;

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  int? _selectedIndex;
  final _customCtrl = TextEditingController();

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  bool get _isCustomSelected =>
      _selectedIndex == widget.reasons.length - 1;

  String? get _result {
    if (_selectedIndex == null) return null;
    if (_isCustomSelected) {
      final custom = _customCtrl.text.trim();
      return custom.isEmpty ? widget.reasons.last : '기타: $custom';
    }
    return widget.reasons[_selectedIndex!];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < widget.reasons.length; i++)
              InkWell(
                onTap: () => setState(() => _selectedIndex = i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      // Radio 스타일 커스텀 (deprecated API 회피)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedIndex == i
                                ? scheme.primary
                                : scheme.outline,
                            width: _selectedIndex == i ? 6 : 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.reasons[i],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _selectedIndex == i
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: _selectedIndex == i
                                ? scheme.primary
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // 기타사유 선택 시 텍스트 입력
            if (_isCustomSelected)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _customCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '직접 입력 (선택)',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  maxLines: 2,
                  onChanged: (_) => setState(() {}),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _selectedIndex == null
              ? null
              : () => Navigator.pop(context, _result),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE74C3C),
          ),
          child: const Text('거절'),
        ),
      ],
    );
  }
}

// ─── 사용자 화면: Pro 등급 신청 ─────────────────────────────────────────

class ProRequestScreen extends StatefulWidget {
  const ProRequestScreen({super.key});

  @override
  State<ProRequestScreen> createState() => _ProRequestScreenState();
}

class _ProRequestScreenState extends State<ProRequestScreen> {
  final _auth = AuthRepository.instance;
  final _profile = ProfileRepository.instance;

  bool _loading = true;
  bool _submitting = false;
  ProRequest? _latest;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = _auth.uid;
      if (uid != null) {
        _latest = await ProRequestRepository.myLatest(uid);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    final uid = _auth.uid;
    final email = _auth.email;
    if (uid == null || email == null) return;

    setState(() => _submitting = true);
    try {
      await ProRequestRepository.submit(
        uid: uid,
        email: email,
        currentRole: _profile.role,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pro 등급 신청이 완료되었습니다. 관리자 검토 후 알려드립니다.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('already_pending')
          ? '이미 검토 중인 신청이 있습니다.'
          : '신청 중 오류가 발생했습니다: $e';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final role = _profile.role;
    final isPro = role.canUsePro;

    return Scaffold(
      appBar: AppBar(title: const Text('Pro 등급 신청')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C5CE7), Color(0xFF9B59B6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.star_rounded,
                                color: Colors.white, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Pro 등급 혜택',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...[
                          '📝  기분 한 줄 (감정 일기)',
                          '💰  가계부 (수입·지출 관리)',
                          '🐱  고양이·강아지·기린·커피 테마',
                        ].map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                e,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  height: 1.3,
                                ),
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (isPro) ...[
                    _StatusBox(
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF22B6A0),
                      title: '이미 Pro 등급입니다',
                      subtitle: '모든 Pro 혜택을 이용하고 계십니다.',
                    ),
                  ] else if (_latest != null) ...[
                    _RequestStatusCard(request: _latest!),
                    const SizedBox(height: 16),
                    if (_latest!.status == ProRequestStatus.rejected ||
                        _latest!.status == ProRequestStatus.approved) ...[
                      _SubmitButton(
                        loading: _submitting,
                        onTap: _submit,
                        label: '다시 신청하기',
                      ),
                    ],
                  ] else ...[
                    Text(
                      '현재 등급: ',
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        role.label,
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SubmitButton(
                      loading: _submitting,
                      onTap: _submit,
                      label: 'Pro 등급 신청하기',
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    '※ 신청 후 관리자 검토까지 시간이 소요될 수 있습니다.\n'
                    '※ 신청 내역은 관리자만 확인할 수 있습니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.loading,
    required this.onTap,
    required this.label,
  });
  final bool loading;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: loading ? null : onTap,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.send_rounded, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  const _StatusBox({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: color,
                      fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                      fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestStatusCard extends StatelessWidget {
  const _RequestStatusCard({required this.request});
  final ProRequest request;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color color, IconData icon) = switch (request.status) {
      ProRequestStatus.pending =>
        (const Color(0xFFFFA94D), Icons.hourglass_top_rounded),
      ProRequestStatus.approved =>
        (const Color(0xFF22B6A0), Icons.check_circle_rounded),
      ProRequestStatus.rejected =>
        (const Color(0xFFE74C3C), Icons.cancel_rounded),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Text(
                request.status.label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '신청일: ${DateFormat('y년 M월 d일', 'ko_KR').format(request.createdAt)}',
            style:
                TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
          if (request.reviewedAt != null)
            Text(
              '검토일: ${DateFormat('y년 M월 d일', 'ko_KR').format(request.reviewedAt!)}',
              style: TextStyle(
                  fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          if (request.note?.isNotEmpty ?? false) ...[
            const SizedBox(height: 6),
            Text(
              '거절 사유: ${request.note}',
              style: TextStyle(
                  fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 관리자 통합 관리 화면 (4탭) ──────────────────────────────────────────

class AdminProRequestScreen extends StatelessWidget {
  const AdminProRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('관리자 관리'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pro 신청'),
              Tab(text: '학생 승인'),
              Tab(text: '회원'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ProRequestTab(),
            _StudentApprovalTab(),
            _AllUsersTab(),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// 탭 1 · Pro 신청 목록
// ══════════════════════════════════════════════════════════════════════════

class _ProRequestTab extends StatelessWidget {
  const _ProRequestTab();

  Widget _errorWidget(BuildContext context, Object? error) {
    final scheme = Theme.of(context).colorScheme;
    final errStr = error.toString();
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
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              isPermDenied
                  ? 'Firestore 보안 규칙을 배포해야 합니다.\n\nfirebase deploy --only firestore:rules'
                  : '오류: $error',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: scheme.onSurfaceVariant, height: 1.6, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProRequest>>(
      stream: ProRequestRepository.watchAll(),
      builder: (context, snap) {
        if (snap.hasError) return _errorWidget(context, snap.error);
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return const Center(child: Text('접수된 Pro 신청이 없습니다.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: list.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _AdminRequestTile(request: list[i]),
        );
      },
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════
// 탭 3 · 학생 등급 신청 (보호자 동의) 관리
// ══════════════════════════════════════════════════════════════════════════

class _StudentApprovalTab extends StatelessWidget {
  const _StudentApprovalTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ParentConsent>>(
      stream: ParentConsentRepository.watchAll(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('오류: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.family_restroom_rounded,
                      size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('접수된 학생 신청이 없습니다.',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: list.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _StudentConsentTile(consent: list[i]),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Pro 신청 타일 (관리자용)
// ══════════════════════════════════════════════════════════════════════════

class _AdminRequestTile extends StatefulWidget {
  const _AdminRequestTile({required this.request});
  final ProRequest request;

  @override
  State<_AdminRequestTile> createState() => _AdminRequestTileState();
}

class _AdminRequestTileState extends State<_AdminRequestTile> {
  bool _busy = false;

  // Pro 거절 사유 선택지
  static const _proRejectReasons = [
    '1. 모집종료',
    '2. 나이제한',
    '3. 중복참여',
    '4. 기타사유',
  ];

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      await ProRequestRepository.approve(widget.request);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('승인 완료. 해당 사용자가 Pro 등급으로 전환되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('승인 실패: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final note = await showRejectReasonDialog(
      context,
      title: 'Pro 거절 사유 선택',
      reasons: _proRejectReasons,
    );
    if (note == null) return;
    setState(() => _busy = true);
    try {
      await ProRequestRepository.reject(widget.request, note: note);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('거절 처리되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('거절 처리 실패: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final req = widget.request;

    final (Color statusColor, String statusLabel) = switch (req.status) {
      ProRequestStatus.pending => (const Color(0xFFFFA94D), '검토 중'),
      ProRequestStatus.approved => (const Color(0xFF22B6A0), '승인됨'),
      ProRequestStatus.rejected => (const Color(0xFFE74C3C), '거절됨'),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.email,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '현재 등급: ${req.currentRole.label}  →  Pro',
                      style: TextStyle(
                          fontSize: 12.5, color: scheme.onSurfaceVariant),
                    ),
                    Text(
                      DateFormat('y.M.d HH:mm', 'ko_KR')
                          .format(req.createdAt),
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          // 거절 사유 표시 (거절됐을 때)
          if (req.note?.isNotEmpty ?? false) ...[
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE74C3C).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: Color(0xFFE74C3C)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '거절 사유: ${req.note}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE74C3C),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (req.status == ProRequestStatus.pending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _reject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE74C3C),
                      side: const BorderSide(color: Color(0xFFE74C3C)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('거절'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _approve,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF22B6A0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('승인'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// 학생 신청 타일 (관리자용)
// ══════════════════════════════════════════════════════════════════════════

class _StudentConsentTile extends StatefulWidget {
  const _StudentConsentTile({required this.consent});
  final ParentConsent consent;

  @override
  State<_StudentConsentTile> createState() => _StudentConsentTileState();
}

// ══════════════════════════════════════════════════════════════════════════
// 탭 3 · 전체 회원 목록 (등급 변경)
// ══════════════════════════════════════════════════════════════════════════

class _AllUsersTab extends StatefulWidget {
  const _AllUsersTab();

  @override
  State<_AllUsersTab> createState() => _AllUsersTabState();
}

class _AllUsersTabState extends State<_AllUsersTab> {
  late final Stream<List<Map<String, dynamic>>> _stream;
  final Map<String, bool> _changing = {};
  final Map<String, bool> _disabling = {};

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .map((s) => s.docs.map((d) {
              final map = Map<String, dynamic>.from(d.data());
              map['uid'] = d.id;
              return map;
            }).toList());
  }

  Future<void> _changeRole(Map<String, dynamic> user, String newRole) async {
    final uid = user['uid'] as String;
    final email = (user['email'] as String?) ?? uid;

    // 강등 시 사유 입력
    String? reason;
    if (newRole == 'NORMAL') {
      reason = await _showDemotionReasonDialog();
      if (reason == null) return; // 취소
    }

    final currentRole = (user['role'] as String?) ?? 'NORMAL';

    setState(() => _changing[uid] = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'role': newRole, 'updatedAt': FieldValue.serverTimestamp()});

      // 사용자 알림
      if (newRole == 'PRO') {
        await NotificationRepository.notifyUser(
          uid: uid,
          title: '등급 변경 안내',
          body: '이제부터 "Pro" 기능을 사용할 수 있습니다. 🎉',
          type: 'role_upgraded',
        );
        await NotificationRepository.notifyAdmin(
          title: '등급 변경',
          body: '$email 님이 일반 → Pro 등급으로 변경되었습니다.',
          type: 'role_changed_admin',
          extra: {'uid': uid, 'email': email, 'to': 'PRO'},
        );
      } else if (newRole == 'BETA') {
        await NotificationRepository.notifyUser(
          uid: uid,
          title: '등급 변경 안내',
          body: '이제부터 "Beta" 전용 기능을 사용할 수 있습니다. 🎉',
          type: 'role_upgraded',
        );
        await NotificationRepository.notifyAdmin(
          title: '등급 변경',
          body: '$email 님이 $currentRole → Beta 등급으로 변경되었습니다.',
          type: 'role_changed_admin',
          extra: {'uid': uid, 'email': email, 'from': currentRole, 'to': 'BETA'},
        );
      } else if (newRole == 'NORMAL' && reason != null) {
        await NotificationRepository.notifyUser(
          uid: uid,
          title: '등급 변경 안내',
          body: '당신은 "$reason"의 이유로 일반 등급으로 변경이 되었습니다.',
          type: 'role_downgraded',
          extra: {'reason': reason},
        );
        await NotificationRepository.notifyAdmin(
          title: '등급 변경',
          body: '$email 님이 $currentRole → 일반 등급으로 변경되었습니다.\n사유: $reason',
          type: 'role_changed_admin',
          extra: {'uid': uid, 'email': email, 'from': currentRole, 'to': 'NORMAL', 'reason': reason},
        );
      }

      if (!mounted) return;
      final label = switch (newRole) {
        'PRO' => 'Pro',
        'BETA' => 'Beta',
        'NORMAL' => '일반',
        'STUDENT' => '학생',
        _ => newRole,
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$email → $label 등급으로 변경되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('변경 실패: $e')));
    } finally {
      if (mounted) setState(() => _changing.remove(uid));
    }
  }

  /// 강등 사유 입력 다이얼로그. 취소하면 null 반환.
  Future<String?> _showDemotionReasonDialog() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('강등 사유 입력'),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 3,
              maxLength: 100,
              decoration: const InputDecoration(
                hintText: '강등 사유를 입력해 주세요.',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setSt(() {}),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: ctrl.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(ctx, ctrl.text.trim()),
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE74C3C)),
                child: const Text('강등'),
              ),
            ],
          ),
        );
      },
    );
    ctrl.dispose();
    return result;
  }

  Future<void> _toggleDisabled(Map<String, dynamic> user) async {
    final uid = user['uid'] as String;
    final email = (user['email'] as String?) ?? uid;
    final isDisabled = user['disabled'] == true;

    // 탈퇴 처리 전 확인 다이얼로그
    if (!isDisabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('탈퇴 처리'),
          content: Text(
            '$email 계정을 비활성화하시겠습니까?\n\n'
            '해당 사용자는 즉시 로그아웃되며 앱을 사용할 수 없게 됩니다.\n'
            '언제든지 재활성화할 수 있습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE74C3C)),
              child: const Text('탈퇴 처리'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _disabling[uid] = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        'disabled': !isDisabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDisabled ? '$email 계정이 재활성화되었습니다.' : '$email 계정이 비활성화되었습니다.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('처리 실패: $e')));
    } finally {
      if (mounted) setState(() => _disabling.remove(uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('오류: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final raw = snap.data!;
        if (raw.isEmpty) {
          return const Center(child: Text('가입자가 없습니다.'));
        }

        // 역할 우선순위: ADMIN > BETA > PRO > STUDENT > NORMAL > 비활성(맨 아래)
        const roleOrder = {'ADMIN': 0, 'BETA': 1, 'PRO': 2, 'STUDENT': 3, 'NORMAL': 4};
        final sorted = List<Map<String, dynamic>>.from(raw)
          ..sort((a, b) {
            final aDisabled = a['disabled'] == true;
            final bDisabled = b['disabled'] == true;
            if (aDisabled != bDisabled) return aDisabled ? 1 : -1;
            final ra = roleOrder[a['role'] as String? ?? 'NORMAL'] ?? 9;
            final rb = roleOrder[b['role'] as String? ?? 'NORMAL'] ?? 9;
            if (ra != rb) return ra.compareTo(rb);
            return ((a['email'] as String?) ?? '')
                .compareTo((b['email'] as String?) ?? '');
          });

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: sorted.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
                child: Text(
                  '전체 가입자 ${sorted.length}명',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              );
            }

            final user = sorted[i - 1];
            final uid = user['uid'] as String;
            final email = (user['email'] as String?) ?? '(이메일 없음)';
            final nickname = user['nickname'] as String?;
            final role = (user['role'] as String?) ?? 'NORMAL';
            final isDisabled = user['disabled'] == true;
            final isBusy = _changing[uid] == true;
            final isDisabling = _disabling[uid] == true;
            final isAdmin = role == 'ADMIN';

            // 생년월일 & 나이 계산
            final birthRaw = user['birthDate'];
            DateTime? birthDate;
            if (birthRaw is Timestamp) birthDate = birthRaw.toDate();
            int? age;
            if (birthDate != null) {
              final now = DateTime.now();
              age = now.year - birthDate.year;
              if (now.month < birthDate.month ||
                  (now.month == birthDate.month &&
                      now.day < birthDate.day)) {
                age--;
              }
            }
            final isUnder14 = age != null && age < 14;

            final (Color roleColor, String roleLabel) = isDisabled
                ? (Colors.grey, '비활성')
                : switch (role) {
                    'ADMIN' => (Colors.deepPurple, '관리자'),
                    'BETA' => (const Color(0xFFFF8C42), '베타'),
                    'PRO' => (const Color(0xFF6C5CE7), 'Pro'),
                    'STUDENT' => (const Color(0xFF22B6A0), '학생'),
                    _ => (Colors.grey, '일반'),
                  };

            return Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: isDisabled
                    ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
                    : scheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDisabled
                      ? scheme.outlineVariant.withValues(alpha: 0.5)
                      : scheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단: 뱃지 + 이메일/닉네임
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          roleLabel,
                          style: TextStyle(
                            color: roleColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (nickname != null && nickname.isNotEmpty)
                              Text(
                                nickname,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDisabled
                                      ? scheme.onSurfaceVariant
                                      : null,
                                ),
                              ),
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            if (birthDate != null) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    '만 $age세 · ${DateFormat('yyyy.MM.dd').format(birthDate)}생',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                  if (isUnder14) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        '14세 미만 고정',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  // 하단: 액션 버튼 (관리자 계정 제외)
                  if (!isAdmin) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isDisabled) ...[
                          // 재활성화 버튼
                          OutlinedButton(
                            onPressed: isDisabling
                                ? null
                                : () => _toggleDisabled(user),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF22B6A0),
                              side: const BorderSide(
                                  color: Color(0xFF22B6A0)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              minimumSize: const Size(64, 32),
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            child: isDisabling
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF22B6A0)))
                                : const Text('재활성화'),
                          ),
                        ] else if (isUnder14) ...[
                          // 14세 미만: 역할 변경 불가 안내
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              '🔒 학생 등급 고정',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton(
                            onPressed: isDisabling
                                ? null
                                : () => _toggleDisabled(user),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey,
                              side: const BorderSide(color: Colors.grey),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              minimumSize: const Size(64, 32),
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            child: isDisabling
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.grey))
                                : const Text('탈퇴 처리'),
                          ),
                        ] else ...[
                          // 등급 변경 버튼 (14세 이상)
                          // STUDENT는 Pro 승급 불가 — 일반 전환만 가능
                          if (role == 'STUDENT')
                            OutlinedButton(
                              onPressed: isBusy
                                  ? null
                                  : () => _changeRole(user, 'NORMAL'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.teal,
                                side: const BorderSide(color: Colors.teal),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                minimumSize: const Size(64, 32),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              child: isBusy
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.teal))
                                  : const Text('일반 전환'),
                            )
                          else if (role == 'NORMAL') ...[
                            OutlinedButton(
                              onPressed: isBusy
                                  ? null
                                  : () => _changeRole(user, 'PRO'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF6C5CE7),
                                side: const BorderSide(
                                    color: Color(0xFF6C5CE7)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                minimumSize: const Size(64, 32),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              child: isBusy
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF6C5CE7)))
                                  : const Text('Pro 승급'),
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton(
                              onPressed: isBusy
                                  ? null
                                  : () => _changeRole(user, 'BETA'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFFF8C42),
                                side: const BorderSide(
                                    color: Color(0xFFFF8C42)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                minimumSize: const Size(64, 32),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              child: isBusy
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFFFF8C42)))
                                  : const Text('Beta 부여'),
                            ),
                          ] else if (role == 'PRO') ...[
                            OutlinedButton(
                              onPressed: isBusy
                                  ? null
                                  : () => _changeRole(user, 'BETA'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFFF8C42),
                                side: const BorderSide(
                                    color: Color(0xFFFF8C42)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                minimumSize: const Size(64, 32),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              child: isBusy
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFFFF8C42)))
                                  : const Text('Beta 부여'),
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton(
                              onPressed: isBusy
                                  ? null
                                  : () => _changeRole(user, 'NORMAL'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFE74C3C),
                                side: const BorderSide(
                                    color: Color(0xFFE74C3C)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                minimumSize: const Size(64, 32),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              child: isBusy
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFFE74C3C)))
                                  : const Text('일반 강등'),
                            ),
                          ] else if (role == 'BETA')
                            OutlinedButton(
                              onPressed: isBusy
                                  ? null
                                  : () => _changeRole(user, 'NORMAL'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFE74C3C),
                                side: const BorderSide(
                                    color: Color(0xFFE74C3C)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                minimumSize: const Size(64, 32),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              child: isBusy
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFFE74C3C)))
                                  : const Text('Beta 해제'),
                            ),
                          const SizedBox(width: 6),
                          // 탈퇴 처리 버튼
                          OutlinedButton(
                            onPressed: isDisabling
                                ? null
                                : () => _toggleDisabled(user),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey,
                              side:
                                  const BorderSide(color: Colors.grey),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              minimumSize: const Size(64, 32),
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10)),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            child: isDisabling
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.grey))
                                : const Text('탈퇴 처리'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _StudentConsentTileState extends State<_StudentConsentTile> {
  bool _busy = false;

  // 학생 거절 사유 선택지
  static const _studentRejectReasons = [
    '1. 부모미동의',
    '2. 개인정보 미동의',
    '3. 정보미기입',
    '4. 기타사유',
  ];

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      await ParentConsentRepository.approve(widget.consent);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('승인 완료. 학생 등급으로 전환되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('승인 실패: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final note = await showRejectReasonDialog(
      context,
      title: '학생 거절 사유 선택',
      reasons: _studentRejectReasons,
    );
    if (note == null) return;
    setState(() => _busy = true);
    try {
      await ParentConsentRepository.reject(widget.consent, note: note);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('거절 처리되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('거절 실패: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = widget.consent;

    final (Color statusColor, String statusLabel) = switch (c.status) {
      ParentConsentStatus.pending => (const Color(0xFFFFA94D), '검토 중'),
      ParentConsentStatus.approved => (const Color(0xFF22B6A0), '승인됨'),
      ParentConsentStatus.rejected => (const Color(0xFFE74C3C), '거절됨'),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('자녀: ${c.childEmail}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('보호자: ${c.parentName} (만 ${c.parentAge}세)',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: scheme.onSurfaceVariant)),
                    Text('연락처: ${c.parentPhone}',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: scheme.onSurfaceVariant)),
                    Text(
                        DateFormat('y.M.d HH:mm', 'ko_KR')
                            .format(c.createdAt),
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          // 거절 사유 표시
          if (c.note?.isNotEmpty ?? false) ...[
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE74C3C).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: Color(0xFFE74C3C)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '거절 사유: ${c.note}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE74C3C),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (c.status == ParentConsentStatus.pending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _reject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE74C3C),
                      side: const BorderSide(color: Color(0xFFE74C3C)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('거절'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _approve,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF22B6A0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('승인 (학생 등급)'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
