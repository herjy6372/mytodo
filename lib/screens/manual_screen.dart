import 'package:flutter/material.dart';

/// 사용설명서 화면.
/// 등급 설명 + 주요 기능 안내.
class ManualScreen extends StatelessWidget {
  const ManualScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사용설명서')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // ── 계정 등급 안내 ──────────────────────────────
          _SectionHeader(
            icon: Icons.workspace_premium_rounded,
            color: const Color(0xFF6C5CE7),
            title: '계정 등급',
          ),
          const SizedBox(height: 10),
          _GradeCard(
            grade: '일반',
            badgeColor: const Color(0xFF22B6A0),
            icon: Icons.person_rounded,
            description: '기본 등급으로 누구나 사용할 수 있습니다. '
                '할 일 목록, 날짜형 목록, 그래프형 목록, 언어 설정 등 '
                '앱의 기본 기능을 이용할 수 있습니다.\n\n'
                '테마는 시스템 테마(라이트 고정·다크 고정·시스템 따름)만 사용 가능합니다.',
          ),
          const SizedBox(height: 10),
          _GradeCard(
            grade: 'Pro',
            badgeColor: const Color(0xFF6C5CE7),
            icon: Icons.star_rounded,
            description: '일반 등급의 모든 기능에 더해 기분 한 줄, 가계부, '
                '고양이·강아지 테마를 추가로 사용할 수 있습니다.\n\n'
                '설정 화면에서 "Pro 등급 신청" 버튼을 통해 관리자에게 신청할 수 있으며, '
                '관리자 검토 후 승인이 완료되면 Pro 등급으로 전환됩니다.',
          ),
          const SizedBox(height: 10),
          _GradeCard(
            grade: 'Beta',
            badgeColor: const Color(0xFFFF8C42),
            icon: Icons.science_rounded,
            description: 'Pro 등급의 모든 기능에 더해 클라우드 동기화를 추가로 사용할 수 있습니다.\n\n'
                'Beta 등급은 관리자가 직접 부여하며, 새로운 기능이 출시될 때마다 '
                'Beta 뱃지가 달린 기능을 가장 먼저 체험할 수 있습니다.\n'
                '만 14세 미만(학생 등급)은 Beta 등급을 부여받을 수 없습니다.',
          ),
          const SizedBox(height: 24),

          // ── 주요 기능 안내 ──────────────────────────────
          _SectionHeader(
            icon: Icons.auto_stories_rounded,
            color: const Color(0xFF4F8DFF),
            title: '주요 기능',
          ),
          const SizedBox(height: 10),
          _FeatureCard(
            icon: Icons.checklist_rounded,
            color: const Color(0xFF6C5CE7),
            title: '할 일 목록',
            description: '할 일을 카테고리·마감일·장소와 함께 등록하고 관리합니다. '
                '완료된 할 일은 별도로 확인할 수 있으며, 마감 시간에 맞춰 알림을 받을 수 있습니다.',
          ),
          _FeatureCard(
            icon: Icons.calendar_month_rounded,
            color: const Color(0xFF22B6A0),
            title: '날짜형 목록',
            description: '달력 형태로 할 일을 날짜별로 확인합니다. '
                '특정 날짜를 탭하면 해당 날의 일정을 한눈에 볼 수 있습니다.',
          ),
          _FeatureCard(
            icon: Icons.bar_chart_rounded,
            color: const Color(0xFFFFA94D),
            title: '그래프형 목록',
            description: '기간별 할 일 완료율을 그래프로 시각화합니다. '
                '주간·월간 통계를 통해 나의 생산성 패턴을 파악할 수 있습니다.',
          ),
          _FeatureCard(
            icon: Icons.edit_note_rounded,
            color: const Color(0xFFFF8FA3),
            title: '기분 한 줄 (Pro 이상)',
            description: '하루의 기분을 한 줄로 기록합니다. '
                '이모지와 함께 짧은 메모를 남겨 감정 일기로 활용할 수 있습니다.',
          ),
          _FeatureCard(
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFF2EC4B6),
            title: '가계부 (Pro 이상)',
            description: '수입과 지출을 카테고리별로 기록하고 월별 지출 패턴을 확인합니다.',
          ),
          _FeatureCard(
            icon: Icons.timer_rounded,
            color: const Color(0xFFFFB74D),
            title: '타이머',
            description: '시간 설정 후 시작버튼을 누르면 설정하신만큼 줄어듭니다.',
          ),
          _FeatureCard(
            icon: Icons.public_rounded,
            color: const Color(0xFF7B83EB),
            title: '세계 시각',
            description: '전 세계 주요 도시의 현재 시각을 확인합니다. '
                '해외 팀·지인과 일정을 조율할 때 편리하게 활용하세요.',
          ),
          _FeatureCard(
            icon: Icons.cloud_sync_rounded,
            color: const Color(0xFF6C5CE7),
            title: '클라우드 동기화 (Beta 이상)',
            description: 'Beta 등급 이상에서 이용 가능한 베타 기능입니다. '
                '여러 기기에서 할 일 데이터를 자동으로 동기화하며, '
                '수동 백업·복원 기능도 지원합니다. 베타 기간에는 일부 오류가 있을 수 있습니다.',
          ),
          // ── 기타 안내 ────────────────────────────
          _SectionHeader(
            icon: Icons.info_outline_rounded,
            color: const Color(0xFFFFA94D),
            title: '기타 안내',
          ),
          const SizedBox(height: 10),
          _FeatureCard(
            icon: Icons.notifications_active_outlined,
            color: const Color(0xFFFF6B81),
            title: '할 일 알림',
            description: '마감일이 설정된 할 일은 해당 시간에 알림을 받을 수 있습니다. '
                '설정 → 푸시 알림에서 알림 권한을 확인하거나 요청할 수 있습니다.',
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.title,
  });
  final IconData icon;
  final Color color;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _GradeCard extends StatelessWidget {
  const _GradeCard({
    required this.grade,
    required this.badgeColor,
    required this.icon,
    required this.description,
  });
  final String grade;
  final Color badgeColor;
  final IconData icon;
  final String description;

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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: badgeColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      grade,
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

