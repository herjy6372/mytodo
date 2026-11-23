import 'package:flutter/material.dart';

/// 사용설명서 화면.
/// 주요 기능 안내.
class ManualScreen extends StatelessWidget {
  const ManualScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사용설명서')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
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
            title: '기분 한 줄',
            description: '하루의 기분을 한 줄로 기록합니다. '
                '이모지와 함께 짧은 메모를 남겨 감정 일기로 활용할 수 있습니다.',
          ),
          _FeatureCard(
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFF2EC4B6),
            title: '가계부',
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
            icon: Icons.alarm_rounded,
            color: const Color(0xFFFFA94D),
            title: '알람',
            description: '메인 화면 오른쪽 위 알람 버튼에서 아침 깨우기, 잘 때 알람, 일반 알람을 '
                '시간과 반복 요일로 설정할 수 있습니다. 할 일 추가 화면에서 "알람으로 알리기"를 켜면 '
                '그 할 일 시간에 알람음이 울립니다.\n\n'
                '알람이 울리면 알람 화면이 열리고 1분 동안 소리가 납니다. '
                '"알람 중지"로 끄거나 1·5·10·30분 뒤 다시 울리도록 미룰 수 있어요. '
                '무음 모드에서는 소리가 제한될 수 있어요.',
          ),
          _FeatureCard(
            icon: Icons.palette_rounded,
            color: const Color(0xFFC97B5C),
            title: '테마',
            description: '설정 → 테마에서 시스템 테마(라이트·다크·시스템 따름)와 '
                '고양이·강아지·기린·커피 테마 중 원하는 테마를 고를 수 있습니다.',
          ),
          _FeatureCard(
            icon: Icons.sticky_note_2_rounded,
            color: const Color(0xFFF4B400),
            title: '메모',
            description: '메인 화면의 메모 버튼에서 떠오르는 생각을 글이나 그림으로 기록합니다. '
                '[글]에서는 글자 크기·굵게·기울임·밑줄·글자색·정렬·목록·체크리스트를 쓸 수 있고, '
                '[그림]에서는 손가락이나 펜으로 그리고 형광펜·지우개·글상자를 쓸 수 있습니다 '
                '(두 손가락으로 위아래로 움직임). '
                '상단의 팔레트 버튼으로 색상을 고르고, 메모를 길게 누르거나 핀 버튼을 누르면 맨 위에 고정됩니다. '
                '작성 화면을 나가면 자동으로 저장됩니다.',
          ),
          _FeatureCard(
            icon: Icons.cloud_sync_rounded,
            color: const Color(0xFF6C5CE7),
            title: '클라우드 동기화 (베타)',
            description: '여러 기기에서 할 일 데이터를 자동으로 동기화하며, '
                '수동 백업·복원 기능도 지원합니다. 현재 테스트 중인 기능이라 '
                '일부 사용자에게만 제공되며, 오류가 있을 수 있습니다.',
          ),
          _FeatureCard(
            icon: Icons.format_size_rounded,
            color: const Color(0xFF22B6A0),
            title: '글자 크기 (큰 글씨 모드)',
            description: '설정 → 글자 크기에서 기본·크게·아주 크게 중에 고를 수 있어요. '
                '크게 이상을 고르면 버튼과 카드 테두리도 진하게 보여 누를 곳을 찾기 쉬워요.',
          ),
          _FeatureCard(
            icon: Icons.dashboard_customize_rounded,
            color: const Color(0xFFFFA94D),
            title: '홈 화면 메뉴 정리',
            description: '설정 → 홈 화면 메뉴에서 자주 쓰는 메뉴만 켜 두고, '
                '손잡이를 끌어 순서를 바꿀 수 있어요. 꺼 둔 메뉴의 기록은 그대로 남아요.',
          ),
          _FeatureCard(
            icon: Icons.undo_rounded,
            color: const Color(0xFF4F8DFF),
            title: '삭제 되돌리기',
            description: '할 일·메모·가계부·기분 기록을 지우면 화면 아래에 "되돌리기" 버튼이 '
                '잠시 나타나요. 실수로 지웠다면 바로 눌러 되살릴 수 있어요.',
          ),
          _FeatureCard(
            icon: Icons.save_alt_rounded,
            color: const Color(0xFF6C5CE7),
            title: '기록 백업 (파일)',
            description: '설정 → 기록 백업에서 할 일·메모·가계부·기분·알람을 파일 하나로 내보내고, '
                '새 휴대폰이나 다시 설치한 앱에서 불러올 수 있어요. 로그인하지 않아도 쓸 수 있어요.',
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

