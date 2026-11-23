import 'package:flutter/material.dart';

import '../data/theme_repository.dart';

/// 글자 크기 설정 (큰 글씨 모드).
class DisplaySettingsScreen extends StatefulWidget {
  const DisplaySettingsScreen({super.key});

  @override
  State<DisplaySettingsScreen> createState() => _DisplaySettingsScreenState();
}

class _DisplaySettingsScreenState extends State<DisplaySettingsScreen> {
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
    final current = _repo.textSize;
    return Scaffold(
      appBar: AppBar(title: const Text('글자 크기')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Text(
              '글자가 작게 느껴지면 크게 바꿔 보세요. 크게 이상을 고르면 '
              '버튼과 카드 테두리도 더 진하게 보여서 누를 곳을 찾기 쉬워요.',
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            for (final o in TextSizeOption.values) ...[
              _SizeCard(
                option: o,
                selected: o == current,
                onTap: () => _repo.setTextSize(o),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            Text(
              '※ 휴대폰 설정의 글꼴 크기와 함께 적용돼요.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeCard extends StatelessWidget {
  const _SizeCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final TextSizeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    // 미리보기: 이 크기로 보이는 모습
                    MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                          textScaler: TextScaler.linear(
                              _baseScale(context) * option.scale)),
                      child: const Text('오늘 할 일 3개 · 오후 2:00 팀 회의',
                          style: TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  /// 휴대폰 자체 글꼴 배율 (앱 배율을 빼고 계산).
  double _baseScale(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1) /
      ThemeRepository.instance.textSize.scale;
}
