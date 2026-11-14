import 'package:flutter/material.dart';

/// 메뉴 항목에 표시할 등급 배지 종류.
enum MenuBadge { none, pro, beta }

/// 캡슐 바 안에 들어가는 단일 메뉴 항목.
class MenuPill extends StatelessWidget {
  const MenuPill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.onDisabledTap,
    this.disabled = false,
    this.badge = MenuBadge.none,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onDisabledTap;
  final bool disabled;
  final MenuBadge badge;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = disabled ? color.withValues(alpha: 0.3) : color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? onDisabledTap : onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: effectiveColor, size: 24),
                  if (badge != MenuBadge.none)
                    Positioned(
                      top: -4,
                      right: -8,
                      child: _BadgeChip(badge: badge, dim: disabled),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: effectiveColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge, required this.dim});
  final MenuBadge badge;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final isPro = badge == MenuBadge.pro;
    final bg = isPro
        ? const Color(0xFF6C5CE7)
        : const Color(0xFFFF8C42); // Beta = 오렌지
    final label = isPro ? 'Pro' : 'Beta';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: dim ? 0.3 : 1.0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 7,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
          height: 1.2,
        ),
      ),
    );
  }
}

/// 둥근 캡슐 형태의 메뉴 바.
class RoundedMenuBar extends StatelessWidget {
  const RoundedMenuBar({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: isDark ? 0.7 : 0.55),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          for (final c in children) Expanded(child: c),
        ],
      ),
    );
  }
}
