import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import '../data/profile_repository.dart';
import '../data/theme_repository.dart';
import '../widgets/beta_badge.dart';


class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  final _repo = ThemeRepository.instance;
  final _auth = AuthRepository.instance;
  final _profile = ProfileRepository.instance;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onChange);
    _auth.addListener(_onChange);
    _profile.addListener(_onChange);
  }

  @override
  void dispose() {
    _repo.removeListener(_onChange);
    _auth.removeListener(_onChange);
    _profile.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  // Pro·Beta·Admin 모두 동물 테마 사용 가능
  bool get _isProOrAdmin {
    if (!_auth.isLoggedIn) return false;
    return _profile.role.canUseAnimalTheme;
  }

  void _showProRequired() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('해당 테마는 Pro 이상 등급 전용입니다. 설정에서 Pro 등급을 신청해 보세요.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = _repo.choice;
    final displayMode = _repo.displayMode;
    final isProOrAdmin = _isProOrAdmin;

    return Scaffold(
      appBar: AppBar(title: const Text('테마')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Text(
              isProOrAdmin
                  ? '시스템·고양이·강아지·기린·커피 중에서 선택할 수 있어요.'
                  : '일반 등급은 시스템 테마를 사용할 수 있어요. Pro 등급을 신청하면 더 많은 테마를 사용할 수 있습니다.',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // ── 시스템 테마 카드 ──
            _ThemeCard(
              choice: AppThemeChoice.system,
              selected: current == AppThemeChoice.system,
              iconBuilder: (_) => const Icon(Icons.brightness_6_rounded,
                  color: Color(0xFF6C5CE7), size: 22),
              accent: const Color(0xFF6C5CE7),
              title: '시스템 테마',
              subtitle: '기기 설정에 따라 라이트/다크 전환. 일반 등급도 사용 가능.',
              showBeta: false,
              showNormalBadge: true,
              locked: false,
              previewBuilder: (context) => const _SystemColorRing(),
              onTap: () => _repo.setChoice(AppThemeChoice.system),
            ),

            // 시스템 테마 선택 시 세부 모드 표시
            if (current == AppThemeChoice.system) ...[
              const SizedBox(height: 10),
              _DisplayModeSelector(
                current: displayMode,
                onChanged: _repo.setDisplayMode,
              ),
            ],

            const SizedBox(height: 12),

            // ── 고양이 테마 카드 ──
            _ThemeCard(
              choice: AppThemeChoice.cat,
              selected: current == AppThemeChoice.cat,
              iconBuilder: (_) => Image.asset(
                'assets/icon/cat_paw.png',
                width: 26,
                height: 26,
              ),
              accent: const Color(0xFFFF6B81),
              title: '고양이 테마',
              subtitle: '핑크 톤 배경색 + 반투명 고양이 모양 패턴',
              showBeta: true,
              showProBadge: true,
              locked: !isProOrAdmin,
              previewBuilder: (_) => const _ThemeColorSwatch(
                color: Color(0xFFFF6B81),
              ),
              onTap: isProOrAdmin
                  ? () => _repo.setChoice(AppThemeChoice.cat)
                  : _showProRequired,
            ),
            const SizedBox(height: 12),

            // ── 강아지 테마 카드 ──
            _ThemeCard(
              choice: AppThemeChoice.dog,
              selected: current == AppThemeChoice.dog,
              iconBuilder: (_) => const Icon(Icons.pets_rounded,
                  color: Color(0xFFC97B5C), size: 22),
              accent: const Color(0xFFC97B5C),
              title: '강아지 테마',
              subtitle: '따뜻한 갈색 톤 배경색 + 반투명 강아지 모양 패턴',
              showBeta: true,
              showProBadge: true,
              locked: !isProOrAdmin,
              previewBuilder: (_) => const _ThemeColorSwatch(
                color: Color(0xFFC97B5C),
              ),
              onTap: isProOrAdmin
                  ? () => _repo.setChoice(AppThemeChoice.dog)
                  : _showProRequired,
            ),
            const SizedBox(height: 12),

            // ── 기린 테마 카드 ──
            _ThemeCard(
              choice: AppThemeChoice.giraffe,
              selected: current == AppThemeChoice.giraffe,
              iconBuilder: (_) => const Text('🦒',
                  style: TextStyle(fontSize: 22)),
              accent: const Color(0xFFFF9800),
              title: '기린 테마',
              subtitle: '주황색 톤 배경색 + 반투명 기린 모양 패턴',
              showBeta: true,
              showProBadge: true,
              locked: !isProOrAdmin,
              previewBuilder: (_) => const _ThemeColorSwatch(
                color: Color(0xFFFF9800),
              ),
              onTap: isProOrAdmin
                  ? () => _repo.setChoice(AppThemeChoice.giraffe)
                  : _showProRequired,
            ),
            const SizedBox(height: 12),

            // ── 커피 테마 카드 ──
            _ThemeCard(
              choice: AppThemeChoice.coffee,
              selected: current == AppThemeChoice.coffee,
              iconBuilder: (_) => const Text('☕',
                  style: TextStyle(fontSize: 22)),
              accent: const Color(0xFF8BC34A),
              title: '커피 테마',
              subtitle: '연두색 톤 배경색 + 반투명 커피잔(연기 포함) 패턴',
              showBeta: true,
              showProBadge: true,
              locked: !isProOrAdmin,
              previewBuilder: (_) => const _ThemeColorSwatch(
                color: Color(0xFF8BC34A),
              ),
              onTap: isProOrAdmin
                  ? () => _repo.setChoice(AppThemeChoice.coffee)
                  : _showProRequired,
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                '※ 테마를 바꾸면 즉시 적용됩니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 시스템 테마 라이트/다크 세부 선택기 ─────────────────────────────────

class _DisplayModeSelector extends StatelessWidget {
  const _DisplayModeSelector({
    required this.current,
    required this.onChanged,
  });
  final SystemDisplayMode current;
  final ValueChanged<SystemDisplayMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          _DisplayModeRow(
            mode: SystemDisplayMode.auto,
            current: current,
            icon: Icons.brightness_auto_rounded,
            onChanged: onChanged,
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          _DisplayModeRow(
            mode: SystemDisplayMode.light,
            current: current,
            icon: Icons.light_mode_rounded,
            onChanged: onChanged,
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          _DisplayModeRow(
            mode: SystemDisplayMode.dark,
            current: current,
            icon: Icons.dark_mode_rounded,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _DisplayModeRow extends StatelessWidget {
  const _DisplayModeRow({
    required this.mode,
    required this.current,
    required this.icon,
    required this.onChanged,
  });
  final SystemDisplayMode mode;
  final SystemDisplayMode current;
  final IconData icon;
  final ValueChanged<SystemDisplayMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = current == mode;
    return InkWell(
      onTap: () => onChanged(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
                size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mode.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.normal,
                  color: selected
                      ? scheme.primary
                      : scheme.onSurface,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, color: scheme.primary, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── 테마 카드 ──────────────────────────────────────────────────────────

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.choice,
    required this.selected,
    required this.iconBuilder,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.previewBuilder,
    required this.onTap,
    required this.showBeta,
    this.showNormalBadge = false,
    this.showProBadge = false,
    this.locked = false,
  });

  final AppThemeChoice choice;
  final bool selected;
  final WidgetBuilder iconBuilder;
  final Color accent;
  final String title;
  final String subtitle;
  final WidgetBuilder previewBuilder;
  final VoidCallback onTap;
  final bool showBeta;
  final bool showNormalBadge;
  final bool showProBadge;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: locked ? 0.55 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selected ? accent : scheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: iconBuilder(context)),
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
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              if (showNormalBadge) ...[
                                const SizedBox(width: 6),
                                _SmallBadge(
                                    label: '일반',
                                    color: const Color(0xFF22B6A0)),
                              ],
                              if (showBeta) ...[
                                const SizedBox(width: 6),
                                const BetaBadge(),
                              ],
                              if (showProBadge) ...[
                                const SizedBox(width: 4),
                                _SmallBadge(
                                    label: 'Pro',
                                    color: const Color(0xFF6C5CE7)),
                              ],
                              if (locked) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.lock_rounded,
                                    size: 14,
                                    color: scheme.onSurfaceVariant),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (selected && !locked)
                      Icon(Icons.check_circle_rounded, color: accent),
                  ],
                ),
                const SizedBox(height: 14),
                previewBuilder(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 소형 뱃지 ──────────────────────────────────────────────────────────

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ─── 프리뷰 위젯들 ──────────────────────────────────────────────────────

/// 시스템 테마 미리보기 — 흰색 + 검정 동그라미.
class _SystemColorRing extends StatelessWidget {
  const _SystemColorRing();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: scheme.outlineVariant, width: 1.5),
          ),
        ),
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

/// 테마 대표 색상을 점점 투명해지는 원 6개로 미리보기.
class _ThemeColorSwatch extends StatelessWidget {
  const _ThemeColorSwatch({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    const alphas = [1.0, 0.78, 0.56, 0.36, 0.18, 0.08];
    return Row(
      children: [
        for (final a in alphas) ...[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: a),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}
