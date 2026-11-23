import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/auth_repository.dart';
import '../data/home_menu_repository.dart';
import '../data/parent_consent_repository.dart';
import '../l10n/app_localizations.dart';
import '../data/profile_repository.dart';
import '../data/theme_repository.dart';
import '../widgets/paw_background.dart' show themeBgColor;
import '../data/todo_repository.dart';
import '../models/parent_consent.dart';
import '../models/user_profile.dart';
import '../models/todo.dart';
import '../services/permission_service.dart';
import '../widgets/home_menu_items.dart';
import '../widgets/rounded_menu_button.dart';
import 'alarm_screen.dart';
import 'calendar_screen.dart';
import 'graph_screen.dart';
import 'ledger_screen.dart';
import 'login_screen.dart';
import 'memo_screen.dart';
import 'mood_screen.dart';
import 'onboarding_screen.dart';
import 'settings_screen.dart';
import 'support_screen.dart';
import 'timer_screen.dart';
import 'todo_list_screen.dart';
import 'world_clock_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = TodoRepository.instance;
  final _auth = AuthRepository.instance;
  final _profile = ProfileRepository.instance;

  bool _shownCountryDialog = false;
  bool _checkingOnboarding = false;
  bool _wasLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _wasLoggedIn = _auth.isLoggedIn;
    _repo.addListener(_onChange);
    _auth.addListener(_onAuthStateChanged);
    _profile.addListener(_onChange);
    HomeMenuRepository.instance.addListener(_onChange);

    // 권한 확인 (첫 설치: 안내 다이얼로그 + 요청 / 이후: 조용히 확인)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await PermissionService.instance.checkAndRequest(context);
      if (!mounted) return;
      // 로그인 상태이면 온보딩 완료 여부 확인
      await _checkOnboarding();
    });
  }

  @override
  void dispose() {
    _repo.removeListener(_onChange);
    _auth.removeListener(_onAuthStateChanged);
    _profile.removeListener(_onChange);
    HomeMenuRepository.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  void _onAuthStateChanged() {
    final nowLoggedIn = _auth.isLoggedIn;
    final justLoggedIn = !_wasLoggedIn && nowLoggedIn;
    _wasLoggedIn = nowLoggedIn;
    if (mounted) setState(() {});
    if (justLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkOnboarding();
      });
    }
  }

  /// 로그인된 사용자가 온보딩을 마쳤는지 확인. 미완료면 온보딩 화면으로 이동.
  Future<void> _checkOnboarding() async {
    if (!_auth.isLoggedIn || _checkingOnboarding) return;
    _checkingOnboarding = true;
    try {
      // 프로필이 아직 로드 중이면 잠시 대기
      final profile = _profile.profile ??
          await _profile.waitForProfile(timeout: const Duration(seconds: 5));
      if (profile == null) return;
      if (!mounted) return;

      // 생년월일 미입력 OR 개인정보 미동의 → 온보딩
      if (!profile.hasCompletedOnboarding) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const OnboardingScreen(),
            fullscreenDialog: true,
          ),
        );
      }

      // 온보딩 완료 후에도 국가 미설정이면 다이얼로그 표시 (기존 가입자 마이그레이션)
      if (!mounted) return;
      final updated = _profile.profile;
      if (updated != null &&
          updated.hasCompletedOnboarding &&
          updated.countryCode == null &&
          !_shownCountryDialog) {
        _shownCountryDialog = true;
        await _showCountryDialog();
      }
    } finally {
      _checkingOnboarding = false;
    }
  }

  /// 기존 가입자에게 거주 국가를 묻는 다이얼로그.
  Future<void> _showCountryDialog() async {
    String? selected;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Widget card({
            required String code,
            required String flag,
            required String label,
          }) {
            final isSelected = selected == code;
            final scheme = Theme.of(ctx).colorScheme;
            return GestureDetector(
              onTap: () => setDialogState(() => selected = code),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? scheme.primary.withValues(alpha: 0.10)
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        isSelected ? scheme.primary : scheme.outlineVariant,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(flag, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? scheme.primary : null,
                      ),
                    ),
                    const Spacer(),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded,
                          color: scheme.primary, size: 20),
                  ],
                ),
              ),
            );
          }

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              '거주 국가 선택',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '달력에 표시할 공휴일 기준을 선택해 주세요.',
                  style: TextStyle(fontSize: 13.5),
                ),
                const SizedBox(height: 16),
                card(code: 'KR', flag: '🇰🇷', label: '대한민국 / South Korea'),
                const SizedBox(height: 8),
                card(code: 'US', flag: '🇺🇸', label: '미국 / United States'),
                const SizedBox(height: 8),
                card(code: 'JP', flag: '🇯🇵', label: '일본 / Japan'),
                const SizedBox(height: 8),
                card(code: 'PH', flag: '🇵🇭', label: '필리핀 / Philippines'),
                const SizedBox(height: 8),
                card(code: 'VN', flag: '🇻🇳', label: '베트남 / Vietnam'),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: selected == null
                    ? null
                    : () async {
                        Navigator.of(ctx).pop();
                        try {
                          await ProfileRepository.instance
                              .updateCountryCode(selected!);
                        } catch (e) {
                          debugPrint('[HomeScreen] 국가 저장 실패: $e');
                        }
                      },
                child: const Text('확인'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _go(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _promptLogin() {
    _go(const LoginScreen());
  }


  /// 켜 둔 메뉴를 순서대로 3개씩 묶어 둥근 메뉴 바로 만듭니다.
  List<Widget> _menuRows(bool loggedIn) {
    final menus = HomeMenuRepository.instance.visible;
    final rows = <Widget>[];
    for (var i = 0; i < menus.length; i += 3) {
      final chunk = menus.sublist(i, (i + 3).clamp(0, menus.length));
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 12));
      rows.add(RoundedMenuBar(
        children: [
          for (final m in chunk) _menuPill(m, loggedIn),
          // 마지막 줄이 3개보다 적으면 빈 칸으로 너비를 맞춤
          for (var k = chunk.length; k < 3; k++) const SizedBox.shrink(),
        ],
      ));
    }
    return rows;
  }

  Widget _menuPill(HomeMenu m, bool loggedIn) {
    final info = homeMenuInfo(m);
    // 로그인해야 쓸 수 있는 메뉴 (고객지원만 로그인 없이 열림)
    final needsLogin = m != HomeMenu.support;
    final Widget page = switch (m) {
      HomeMenu.todos => const TodoListScreen(),
      HomeMenu.calendar => const CalendarScreen(),
      HomeMenu.graph => const GraphScreen(),
      HomeMenu.mood => const MoodScreen(),
      HomeMenu.ledger => const LedgerScreen(),
      HomeMenu.timer => const TimerScreen(),
      HomeMenu.worldClock => const WorldClockScreen(),
      HomeMenu.memo => const MemoScreen(),
      HomeMenu.support => const SupportScreen(),
    };
    return MenuPill(
      icon: info.icon,
      label: info.label(context),
      color: info.color,
      onTap: () => _go(page),
      onDisabledTap: _promptLogin,
      disabled: needsLogin && !loggedIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final loggedIn = _auth.isLoggedIn;
    final role = _profile.role;
    final profile = _profile.profile;
    // Beta·Admin: 클라우드 동기화·건강 기능 사용 가능
    final isBetaOrAdmin = loggedIn && role.canUseBeta;

    final themeChoice = ThemeRepository.instance.choice;
    // 테마 배경색과 그래디언트 상단색을 통일 (커스텀 테마는 패턴 배경색과 동일)
    final gradientTop = themeChoice.isCustomTheme
        ? themeBgColor(themeChoice, isDark)
        : (isDark ? const Color(0xFF1F1A2E) : const Color(0xFFEFEAFE));
    final gradientBottom = Theme.of(context).scaffoldBackgroundColor;

    final today = DateTime.now();
    final l = AppLocalizations.of(context);
    final greeting = DateFormat(l.homeGreetingFormat, l.homeGreetingLocale).format(today);
    final todayCount = _repo.forDate(today).length;
    final weekTodos = _repo.forWeekSunday(today);
    final weekCount = weekTodos.length;
    final monthCount = _repo.forMonth(today).length;

    // 이용불가: 로그인했지만 개인정보 미동의 (생일은 있음)
    if (loggedIn &&
        profile != null &&
        profile.birthDate != null &&
        !profile.privacyAgreed) {
      return _BlockedScreen(
        icon: Icons.block_rounded,
        color: const Color(0xFFE74C3C),
        title: '이용 불가',
        message: '개인정보 처리방침에 동의하지 않아 앱을 이용할 수 없습니다.\n'
            '설정 → 프로필에서 동의 후 다시 시도해 주세요.',
        onSettings: () => _go(const SettingsScreen()),
      );
    }

    // 승인 대기: 만 14세 미만, 부모 동의 제출 후 관리자 검토 중
    if (loggedIn &&
        profile != null &&
        profile.birthDate != null &&
        profile.isUnder14 &&
        profile.privacyAgreed &&
        role == UserRole.normal) {
      return _PendingApprovalScreen(uid: profile.uid);
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [gradientTop, gradientBottom],
            stops: const [0.0, 0.5],
          ),
          color: gradientBottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단 오른쪽 알람 · 설정 버튼
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(Icons.alarm_rounded,
                          color: scheme.onSurfaceVariant),
                      tooltip: '알람',
                      onPressed: () => _go(const AlarmScreen()),
                    ),
                    IconButton(
                      icon: Icon(Icons.settings_rounded,
                          color: scheme.onSurfaceVariant),
                      tooltip: '설정',
                      onPressed: () => _go(const SettingsScreen()),
                    ),
                  ],
                ),
                // 안내 배너
                if (isBetaOrAdmin) ...[
                  // Beta·Admin: 베타 동기화 안내
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE7F6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF9C6FE4)),
                    ),
                    child: Row(
                      children: [
                        const Text('🧪', style: TextStyle(fontSize: 15)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l.bannerBetaSync,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF4A148C),
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // 비로그인 or 일반 등급: 기록 삭제 주의
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFD700)),
                    ),
                    child: Row(
                      children: [
                        const Text('⚠️', style: TextStyle(fontSize: 15)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l.bannerNoSync,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF856404),
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 비로그인 전용: 로그인 유도 배너 (탭 시 로그인 화면 이동)
                  if (!loggedIn) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _promptLogin,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: scheme.primary.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Text('🔐', style: TextStyle(fontSize: 15)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l.bannerLoginRequired,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: scheme.onPrimaryContainer,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 8),
                Text(
                  greeting,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l.homeTitle,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                // (1) 요약 카드 — 오늘/이번주/이번달
                _SummaryCard(
                  todayCount: todayCount,
                  weekCount: weekCount,
                  monthCount: monthCount,
                ),
                const SizedBox(height: 20),
                // (2) 이번주 일정
                _WeekScheduleSection(
                  weekTodos: weekTodos,
                  onSeeAll: loggedIn ? () => _go(const TodoListScreen()) : _promptLogin,
                ),
                const SizedBox(height: 20),
                // (3) 기능 메뉴 — 설정 → 홈 화면 메뉴에서 켜고 끄기·순서 변경
                ..._menuRows(loggedIn),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 오늘/이번주/이번달 갯수 요약 카드.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.todayCount,
    required this.weekCount,
    required this.monthCount,
  });

  final int todayCount;
  final int weekCount;
  final int monthCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            scheme.primary,
            scheme.primary.withValues(alpha: 0.78),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Builder(builder: (context) {
        final l = AppLocalizations.of(context);
        return Row(
          children: [
            _SummaryCell(label: l.summaryToday, count: todayCount, unit: l.summaryUnit),
            _Divider(),
            _SummaryCell(label: l.summaryWeek, count: weekCount, unit: l.summaryUnit),
            _Divider(),
            _SummaryCell(label: l.summaryMonth, count: monthCount, unit: l.summaryUnit),
          ],
        );
      }),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({required this.label, required this.count, required this.unit});
  final String label;
  final int count;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: unit.isEmpty ? '' : '  $unit',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withValues(alpha: 0.25),
    );
  }
}

/// 이번주(일~토) 일정 섹션.
class _WeekScheduleSection extends StatelessWidget {
  const _WeekScheduleSection({
    required this.weekTodos,
    required this.onSeeAll,
  });

  final List<Todo> weekTodos;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final start = TodoRepository.startOfWeekSunday(DateTime.now());
    final end = start.add(const Duration(days: 6));
    final dateFmt = l.isKorean ? 'M월 d일' : 'MMM d';
    final headerSub = '${DateFormat(dateFmt, l.homeGreetingLocale).format(start)} ~ '
        '${DateFormat(dateFmt, l.homeGreetingLocale).format(end)}';

    final visible = weekTodos.take(3).toList();
    final hasMore = weekTodos.length > 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text(
                l.weekScheduleTitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Text(
                headerSub,
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (weekTodos.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 22),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.event_available_rounded,
                    color: scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.weekScheduleEmpty,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          )
        else ...[
          for (final t in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _WeekTile(todo: t),
            ),
          if (hasMore)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSeeAll,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Center(
                    child: Text(
                      l.isKorean
                          ? '▼ 자세히 보기 (${weekTodos.length - 3}개 더)'
                          : '▼ See ${weekTodos.length - 3} more',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _WeekTile extends StatelessWidget {
  const _WeekTile({required this.todo});
  final Todo todo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: todo.category.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(todo.category.icon,
                color: todo.category.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todo.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    decoration: todo.isDone
                        ? TextDecoration.lineThrough
                        : null,
                    color: todo.isDone
                        ? scheme.onSurface.withValues(alpha: 0.45)
                        : scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('E HH:mm', AppLocalizations.of(context).homeGreetingLocale).format(todo.dueDate),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 이용불가 화면 ────────────────────────────────────────────────────

class _BlockedScreen extends StatelessWidget {
  const _BlockedScreen({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.onSettings,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 40),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: onSettings,
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('설정으로 이동'),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => AuthRepository.instance.signOut(),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('로그아웃'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 승인 대기 화면 (만 14세 미만, 보호자 동의 검토 중) ──────────────────

class _PendingApprovalScreen extends StatefulWidget {
  const _PendingApprovalScreen({required this.uid});
  final String uid;

  @override
  State<_PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<_PendingApprovalScreen> {
  ParentConsent? _consent;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _consent = await ParentConsentRepository.getFor(widget.uid);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openParentConsentForm() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OnboardingScreen(initialStep: 2),
        fullscreenDialog: true,
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasSubmitted = _consent != null;
    final isRejected = _consent?.status == ParentConsentStatus.rejected;

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: isRejected
                              ? const Color(0xFFE74C3C).withValues(alpha: 0.12)
                              : const Color(0xFFFFA94D).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isRejected
                              ? Icons.cancel_rounded
                              : hasSubmitted
                                  ? Icons.hourglass_top_rounded
                                  : Icons.family_restroom_rounded,
                          color: isRejected
                              ? const Color(0xFFE74C3C)
                              : const Color(0xFFFFA94D),
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        isRejected
                            ? '보호자 동의 거절됨'
                            : hasSubmitted
                                ? '관리자 승인 대기 중'
                                : '보호자 동의 필요',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isRejected
                              ? const Color(0xFFE74C3C)
                              : const Color(0xFFFFA94D),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isRejected
                            ? '보호자 동의 신청이 거절되었습니다.\n사유: ${_consent?.note ?? "사유 없음"}\n\n아래 버튼을 눌러 보호자 정보를 다시 입력해 주세요.'
                            : hasSubmitted
                                ? '보호자 동의 신청이 접수되었습니다.\n관리자 검토 후 이용 가능합니다.\n잠시만 기다려 주세요.'
                                : '만 14세 미만은 보호자 동의가 필요합니다.\n아래 버튼을 눌러 보호자 정보를 입력해 주세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (!hasSubmitted || isRejected) ...[
                        FilledButton.icon(
                          onPressed: _openParentConsentForm,
                          icon: const Icon(Icons.family_restroom_rounded),
                          label: Text(
                            isRejected ? '보호자 동의 다시 신청하기' : '보호자 정보 입력하기',
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('상태 새로고침'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const SettingsScreen()),
                            ),
                            icon: const Icon(Icons.settings_rounded, size: 18),
                            label: const Text('설정'),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => AuthRepository.instance.signOut(),
                            icon: const Icon(Icons.logout_rounded, size: 18),
                            label: const Text('로그아웃'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

