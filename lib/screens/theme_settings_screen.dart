import 'package:flutter/material.dart';

import '../data/theme_repository.dart';


class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  final _repo = ThemeRepository.instance;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onChange);
  }

  @override
  void dispose() {
    _repo.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = _repo.choice;
    final displayMode = _repo.displayMode;

    return Scaffold(
      appBar: AppBar(title: const Text('테마')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Text(
              '시스템·고양이·강아지·기린·커피 중에서 선택할 수 있어요.',
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
              subtitle: '기기 설정에 따라 라이트/다크 전환.',
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
              previewBuilder: (_) => const _ThemeColorSwatch(
                color: Color(0xFFFF6B81),
              ),
              onTap: () => _repo.setChoice(AppThemeChoice.cat),
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
              previewBuilder: (_) => const _ThemeColorSwatch(
                color: Color(0xFFC97B5C),
              ),
              onTap: () => _repo.setChoice(AppThemeChoice.dog),
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
              previewBuilder: (_) => const _ThemeColorSwatch(
                color: Color(0xFFFF9800),
              ),
              onTap: () => _repo.setChoice(AppThemeChoice.giraffe),
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
              previewBuilder: (_) => const _ThemeColorSwatch(
                color: Color(0xFF8BC34A),
              ),
              onTap: () => _repo.setChoice(AppThemeChoice.coffee),
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
  });

  final AppThemeChoice choice;
  final bool selected;
  final WidgetBuilder iconBuilder;
  final Color accent;
  final String title;
  final String subtitle;
  final WidgetBuilder previewBuilder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
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
                    if (selected)
                      Icon(Icons.check_circle_rounded, color: accent),
                  ],
                ),
                const SizedBox(height: 14),
                previewBuilder(context),
              ],
            ),
          ),
        ),
    );
  }
}

// ─── 소형 뱃지 ──────────────────────────────────────────────────────────

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
