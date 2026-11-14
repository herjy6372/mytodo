import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/auth_repository.dart';
import '../data/language_repository.dart';
import '../data/notification_repository.dart';
import '../l10n/app_localizations.dart';
import '../data/todo_repository.dart';
import '../models/user_profile.dart';
import '../services/daily_notification_service.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart' show SyncService, BackupMeta;
import '../data/profile_repository.dart';
import '../widgets/beta_badge.dart';
import '../widgets/user_avatar.dart';
import 'language_settings_screen.dart';
import 'login_screen.dart';
import 'manual_screen.dart';
import 'notice_screen.dart';
import 'notifications_screen.dart';
import 'pro_request_screen.dart';
import 'profile_edit_screen.dart';
import 'support_screen.dart';
import 'theme_settings_screen.dart';
import 'update_history_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = AuthRepository.instance;
  final _profile = ProfileRepository.instance;
  final _sync = SyncService.instance;
  final _daily = DailyNotificationService.instance;
  String _version = '1.0.0';
  String _rawVersion = ''; // "1.0.2" 형태의 순수 버전
  String _deviceModel = '';

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onChange);
    _profile.addListener(_onChange);
    _sync.addListener(_onChange);
    _daily.addListener(_onChange);
    _loadVersion();
    _loadDeviceModel();
  }

  @override
  void dispose() {
    _auth.removeListener(_onChange);
    _profile.removeListener(_onChange);
    _sync.removeListener(_onChange);
    _daily.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _rawVersion = info.version;
        _version = '${info.version} (${info.buildNumber})';
      });
    } catch (_) {/* ignore */}
  }

  Future<void> _loadDeviceModel() async {
    try {
      final plugin = DeviceInfoPlugin();
      String model = '';
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        model = info.model; // 예: "SM-X610" / "Pixel 7"
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        model = info.utsname.machine; // 예: "iPad14,5"
      }
      if (!mounted || model.isEmpty) return;
      setState(() => _deviceModel = model);
    } catch (_) {/* ignore */}
  }

  /// URL을 외부 브라우저로 안전하게 엽니다.
  /// canLaunchUrl 대신 직접 launchUrl을 시도하고 실패 시 SnackBar를 표시합니다.
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('브라우저를 열 수 없습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('링크 열기 실패: $e')),
        );
      }
    }
  }

  Future<void> _login() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _confirmLogout() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(l.settingsSignOutTitle),
        content: Text(l.settingsSignOutConfirm),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(AppLocalizations.of(ctx).cancel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(AppLocalizations.of(ctx).settingsSignOut),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (ok == true) {
      await _auth.signOut();
      await _sync.setEnabled(false);
    }
  }

  Future<void> _restoreFromCloud() async {
    // context 참조를 async gap 이전에 캡처
    final l = AppLocalizations.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dl = AppLocalizations.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          title: Text(dl.settingsSyncRestoreTitle),
          // ── 경고 메시지 (기존 파일 삭제 안내) ────────────────────
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dl.settingsSyncRestoreConfirm),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  border: Border.all(color: const Color(0xFFFFB74D)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  dl.syncRestoreWarning,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7A4F00),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                // ── NO 버튼 ────────────────────────────────────────
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(dl.syncRestoreNo),
                  ),
                ),
                const SizedBox(width: 10),
                // ── OK 버튼 ────────────────────────────────────────
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(dl.syncRestoreOk),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    try {
      await _sync.restoreFromCloud();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.settingsSyncRestoreSuccess)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.settingsSyncRestoreFail(e.toString()))));
    }
  }

  Future<void> _requestNotifPermission() async {
    final ok = await NotificationService.instance.requestPermission();
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? l.settingsNotifGranted : l.settingsNotifDenied),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loggedIn = _auth.isLoggedIn;
    final role = _profile.role;
    final uid = _auth.uid;
    // 클라우드 동기화 — Beta·Admin 전용 (Pro 제외)
    final showSync = loggedIn && role.canSync;
    final syncEnabled = _sync.enabled;
    final lastSync = _sync.lastSyncedAt;

    final l = AppLocalizations.of(context);
    String syncSubtitle;
    if (!syncEnabled) {
      syncSubtitle = l.settingsSyncOff;
    } else if (_sync.busy) {
      syncSubtitle = l.settingsSyncBusy;
    } else if (lastSync != null) {
      syncSubtitle = l.settingsSyncLast(
          DateFormat(l.settingsSyncLastFormat, l.settingsSyncLastLocale).format(lastSync));
    } else {
      syncSubtitle = l.settingsSyncNever;
    }

    // 구버전 여부 (1.0.x = 구버전, 1.1.x+ = 최신)
    final isOldVersion = _rawVersion.startsWith('1.0.');

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 계정 카드 (프로필 편집 진입)
            _SettingCard(
              child: InkWell(
                onTap: loggedIn
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ProfileEditScreen()),
                        )
                    : _login,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: [
                      UserAvatar(
                        photoUrl: loggedIn
                            ? _profile.displayPhotoUrl
                            : null,
                        radius: 24,
                        fallbackIcon: loggedIn
                            ? Icons.person_rounded
                            : Icons.person_outline_rounded,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    loggedIn
                                        ? (_profile.profile
                                                ?.displayName() ??
                                            (_auth.email ?? l.settingsAccountLoginRequired))
                                        : l.settingsAccountLoginRequired,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                if (loggedIn) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: scheme.primary
                                          .withValues(alpha: 0.10),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _profile.role.label,
                                      style: TextStyle(
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              loggedIn
                                  ? (_auth.email ?? '')
                                  : l.settingsAccountLoginHint,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CompactButton(
                        label: loggedIn ? l.settingsSignOut : l.settingsSignIn,
                        filled: !loggedIn,
                        onTap: loggedIn ? _confirmLogout : _login,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // ── Pro 등급 신청 버튼 (일반 등급 + 로그인 상태만) ──
            if (loggedIn && role == UserRole.normal) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const ProRequestScreen()),
                  ),
                  icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                  label: Text(l.settingsProApply),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6C5CE7),
                    side: const BorderSide(color: Color(0xFF6C5CE7)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
            // ── 관리자 전용: Pro 신청 관리 ──
            if (loggedIn && role == UserRole.admin) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const AdminProRequestScreen()),
                  ),
                  icon: const Icon(Icons.manage_accounts_rounded, size: 18),
                  label: Text(l.settingsProManage),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6C5CE7),
                    side: const BorderSide(color: Color(0xFF6C5CE7)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
            // 알림 버튼 (로그인된 사용자 전체)
            if (loggedIn) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: StreamBuilder<int>(
                  stream: NotificationRepository.watchUnreadCount(
                    role == UserRole.admin
                        ? NotificationRepository.adminTargetId
                        : (uid ?? ''),
                  ),
                  builder: (context, snap) {
                    final count = snap.data ?? 0;
                    return OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const NotificationsScreen()),
                      ),
                      icon: Badge(
                        isLabelVisible: count > 0,
                        label: Text('$count'),
                        child: const Icon(Icons.notifications_rounded, size: 18),
                      ),
                      label: Text(AppLocalizations.of(context).notifBtn(count)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    );
                  },
                ),
              ),
            ],
            // ── Beta/Admin 전용: 클라우드 동기화 ──
            if (showSync) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  _SectionLabel(l.settingsSectionSync),
                  const SizedBox(width: 6),
                  const BetaBadge(compact: true),
                ],
              ),
              const SizedBox(height: 8),

              // ── 테스트 진행 중 안내 배너 ────────────────────────────
              _SyncTestingBanner(message: l.syncTestingNotice),
              const SizedBox(height: 8),

              _SettingCard(
                child: Column(
                  children: [
                    // 동기화 스위치
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      child: Row(
                        children: [
                          _CircleIcon(
                            color: const Color(0xFF6C5CE7),
                            icon: Icons.cloud_sync_rounded,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.settingsSyncAuto,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  syncSubtitle,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: syncEnabled,
                            onChanged: (v) async {
                              await _sync.setEnabled(v);
                              if (v && mounted) {
                                await _sync.syncNow(
                                    TodoRepository.instance.todos);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: scheme.outlineVariant),
                    // 지금 동기화 / 복원하기
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _sync.busy
                                  ? null
                                  : () => _sync.syncNow(
                                      TodoRepository.instance.todos),
                              icon: const Icon(Icons.backup_rounded, size: 18),
                              label: Text(l.settingsSyncBackup),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _sync.busy
                                  ? null
                                  : _restoreFromCloud,
                              icon: const Icon(
                                  Icons.cloud_download_outlined,
                                  size: 18),
                              label: Text(l.settingsSyncRestore),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── 백업 통계 카드 (백업 이력 있을 때만 표시) ──────────
              if (_sync.backupMeta != null) ...[
                const SizedBox(height: 10),
                _BackupMetaCard(meta: _sync.backupMeta!),
              ],
            ],
            const SizedBox(height: 16),
            _SectionLabel(l.settingsSectionNotifThemeLang),
            const SizedBox(height: 8),
            // 일일 비서 알림 상태 카드
            _DailyNotifCard(
              enabled: _daily.isEnabled,
              onChanged: (v) => _daily.setEnabled(v),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                l.dailyNotifSlotSectionTitle,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _DailyNotifSlotCard(masterEnabled: _daily.isEnabled),
            const SizedBox(height: 8),
            _SettingCard(
              child: Column(
                children: [
                  _SettingTapRow(
                    color: const Color(0xFFFF6B81),
                    icon: Icons.notifications_active_outlined,
                    title: l.settingsNotifTitle,
                    subtitle: l.settingsNotifSubtitle,
                    onTap: _requestNotifPermission,
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  _SettingTapRow(
                    color: const Color(0xFFC97B5C),
                    icon: Icons.palette_rounded,
                    title: l.settingsThemeTitle,
                    subtitle: l.settingsThemeSubtitle,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ThemeSettingsScreen()),
                    ),
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  _SettingTapRow(
                    color: const Color(0xFF4F8DFF),
                    icon: Icons.language_rounded,
                    title: l.settingsLanguageTitle,
                    subtitle: l.settingsLanguageSubtitle,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const LanguageSettingsScreen()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionLabel(l.settingsSectionAppInfo),
            const SizedBox(height: 8),
            _SettingCard(
              child: Column(
                children: [
                  _SettingTapRow(
                    color: const Color(0xFF4F8DFF),
                    icon: Icons.campaign_outlined,
                    title: l.settingsNoticesTitle,
                    subtitle: l.settingsNoticesSubtitle,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const NoticeScreen()),
                    ),
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  _SettingTapRow(
                    color: const Color(0xFF22B6A0),
                    icon: Icons.update_rounded,
                    title: l.settingsUpdatesTitle,
                    subtitle: l.settingsUpdatesSubtitle,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const UpdateHistoryScreen()),
                    ),
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  _SettingTapRow(
                    color: const Color(0xFF7B83EB),
                    icon: Icons.support_agent_rounded,
                    title: l.settingsSupportTitle,
                    subtitle: l.settingsSupportSubtitle,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const SupportScreen()),
                    ),
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  _SettingTapRow(
                    color: const Color(0xFF00B894),
                    icon: Icons.auto_stories_rounded,
                    title: l.settingsManualTitle,
                    subtitle: l.settingsManualSubtitle,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ManualScreen()),
                    ),
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  _PolicyRow(
                    color: const Color(0xFF6C5CE7),
                    icon: Icons.privacy_tip_rounded,
                    title: l.settingsPrivacyTitle,
                    subtitle: l.settingsPrivacySubtitle,
                    koUrl: 'https://herjy6372.github.io/todolist/index.html',
                    enUrl: 'https://herjy6372.github.io/todolist/index_en.html',
                    onOpen: _openUrl,
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  _PolicyRow(
                    color: const Color(0xFF00B894),
                    icon: Icons.gavel_rounded,
                    title: l.settingsTermsTitle,
                    subtitle: l.settingsTermsSubtitle,
                    koUrl: 'https://herjy6372.github.io/todolist/terms.html',
                    enUrl: 'https://herjy6372.github.io/todolist/terms_en.html',
                    onOpen: _openUrl,
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  _SettingTapRow(
                    color: const Color(0xFF78909C),
                    icon: Icons.smartphone_rounded,
                    title: '기기 정보',
                    subtitle: _deviceModel.isEmpty ? '불러오는 중...' : _deviceModel,
                    onTap: null,
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  _SettingTapRow(
                    color: const Color(0xFFFFA94D),
                    icon: Icons.info_outline_rounded,
                    title: l.settingsVersionTitle,
                    subtitle: _version,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOldVersion
                            ? const Color(0xFFFFEDED)
                            : const Color(0xFFE9F8F2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isOldVersion ? l.settingsVersionOld : l.settingsVersionLatest,
                        style: TextStyle(
                          color: isOldVersion
                              ? const Color(0xFFCC0000)
                              : const Color(0xFF22B6A0),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                l.settingsFooter,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 헬퍼 위젯들 ──────────────────────────────────────────────────────

class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.color, required this.icon});
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

// ─── 개인정보·약관 전용 행 (KO / EN 버튼 내장) ──────────────────────────────

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.koUrl,
    required this.enUrl,
    required this.onOpen,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final String koUrl;
  final String enUrl;
  final void Function(String url) onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CircleIcon(color: color, icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                // ── 언어 선택 버튼 ──────────────────────────────────────
                Row(
                  children: [
                    _LangButton(
                      label: l.settingsPolicyKo,
                      onTap: () => onOpen(koUrl),
                      primary: color,
                    ),
                    const SizedBox(width: 8),
                    _LangButton(
                      label: l.settingsPolicyEn,
                      onTap: () => onOpen(enUrl),
                      primary: color,
                      filled: false,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LangButton extends StatelessWidget {
  const _LangButton({
    required this.label,
    required this.onTap,
    required this.primary,
    this.filled = true,
  });

  final String label;
  final VoidCallback onTap;
  final Color primary;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (filled) {
      return FilledButton.tonal(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: primary.withValues(alpha: 0.10),
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
        side: BorderSide(color: scheme.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(label),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SettingTapRow extends StatelessWidget {
  const _SettingTapRow({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            _CircleIcon(color: color, icon: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ] else ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant),
            ],
          ],
        ),
      ),
    );
  }
}

/// 섹션 라벨 옆에 표시되는 작은 (Pro) 뱃지.

/// 테마의 minimumSize 영향을 받지 않는 작은 인라인 버튼.
class _CompactButton extends StatelessWidget {
  const _CompactButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: filled ? scheme.primary : Colors.transparent,
      shape: StadiumBorder(
        side: filled
            ? BorderSide.none
            : BorderSide(color: scheme.outline),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: filled ? scheme.onPrimary : scheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}


// ─── 일일 비서 알림 상태 카드 ────────────────────────────────────────────────

class _DailyNotifCard extends StatelessWidget {
  const _DailyNotifCard({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isOn = enabled;
    final bgColor  = isOn ? const Color(0xFFE8F5E9) : scheme.surfaceContainerHighest;
    final bdColor  = isOn ? const Color(0xFF81C784) : scheme.outlineVariant;
    final txtColor = isOn ? const Color(0xFF1B5E20) : scheme.onSurfaceVariant;
    final l = AppLocalizations.of(context);
    final label = isOn ? l.dailyNotifOn : l.dailyNotifOff;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bdColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: txtColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Checkbox(
            value: isOn,
            activeColor: const Color(0xFF4CAF50),
            onChanged: (v) => onChanged(v ?? isOn),
          ),
        ],
      ),
    );
  }
}

// ─── 시간대별 알림 개별 설정 카드 ────────────────────────────────────────────

class _DailyNotifSlotCard extends StatelessWidget {
  const _DailyNotifSlotCard({required this.masterEnabled});

  /// 전체 알림 스위치([DailyNotificationService.isEnabled]) 상태.
  /// 꺼져 있으면 개별 항목도 함께 비활성화(회색) 표시한다.
  final bool masterEnabled;

  @override
  Widget build(BuildContext context) {
    final daily = DailyNotificationService.instance;
    final l = AppLocalizations.of(context);
    final locale = LanguageRepository.instance.language.calendarLocale;

    String timeLabel(DailyNotifSlot slot) {
      final time = DateFormat.jm(locale).format(DateTime(2024, 1, 1, slot.hour));
      return slot == DailyNotifSlot.weeklySummary
          ? l.dailyNotifSlotWeeklyTime(time)
          : l.dailyNotifSlotDailyTime(time);
    }

    final slots = <(DailyNotifSlot, IconData, Color, String)>[
      (DailyNotifSlot.morning, Icons.wb_sunny_outlined, const Color(0xFFFFB74D), l.dailyNotifSlotMorning),
      (DailyNotifSlot.lunch, Icons.restaurant_outlined, const Color(0xFFFF8A65), l.dailyNotifSlotLunch),
      (DailyNotifSlot.evening, Icons.wb_twilight_rounded, const Color(0xFF7C5CFF), l.dailyNotifSlotEvening),
      (DailyNotifSlot.bedtime, Icons.bedtime_outlined, const Color(0xFF4F5B93), l.dailyNotifSlotBedtime),
      (DailyNotifSlot.weeklySummary, Icons.bar_chart_rounded, const Color(0xFF22B6A0), l.dailyNotifSlotWeekly),
    ];

    return _SettingCard(
      child: Column(
        children: [
          for (int i = 0; i < slots.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1, color: Theme.of(context).colorScheme.outlineVariant),
            _SettingTapRow(
              color: slots[i].$3,
              icon: slots[i].$2,
              title: slots[i].$4,
              subtitle: timeLabel(slots[i].$1),
              trailing: Switch(
                value: masterEnabled && daily.isSlotEnabled(slots[i].$1),
                onChanged: masterEnabled
                    ? (v) => daily.setSlotEnabled(slots[i].$1, v)
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 테스트 진행 중 안내 배너 ──────────────────────────────────────────────────

class _SyncTestingBanner extends StatelessWidget {
  const _SyncTestingBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🧪', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF7A4F00),
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 백업 통계 카드 ────────────────────────────────────────────────────────────

class _BackupMetaCard extends StatelessWidget {
  const _BackupMetaCard({required this.meta});
  final BackupMeta meta;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final dateStr = DateFormat(
      l.syncBackupDateFormat,
      l.syncBackupDateLocale,
    ).format(meta.date);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더 ────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.cloud_done_rounded,
                  size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                l.syncBackupMetaTitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── 항목 수 ──────────────────────────────────────────────
          Row(
            children: [
              _MetaChip(
                emoji: '✅',
                label: l.syncBackupTodos,
                count: l.syncBackupCount(meta.todosCount),
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              _MetaChip(
                emoji: '😊',
                label: l.syncBackupMoods,
                count: l.syncBackupCount(meta.moodsCount),
                color: const Color(0xFF22B6A0),
              ),
              const SizedBox(width: 8),
              _MetaChip(
                emoji: '💰',
                label: l.syncBackupLedger,
                count: l.syncBackupCount(meta.ledgerCount),
                color: const Color(0xFFFF8C42),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.emoji,
    required this.label,
    required this.count,
    required this.color,
  });

  final String emoji;
  final String label;
  final String count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 2),
            Text(
              count,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: color.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
