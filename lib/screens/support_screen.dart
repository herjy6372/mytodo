import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/private_config.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static const _adminEmail = PrivateConfig.adminEmail;

  Future<void> _copyEmail(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _adminEmail));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('이메일 주소를 복사했어요.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('고객지원')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 이메일 안내 카드
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.support_agent_rounded,
                            color: scheme.primary),
                        const SizedBox(width: 10),
                        const Text(
                          '문의 메일 주소',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 개발자 정보
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'TeraBlack',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '앱 개발자',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _adminEmail,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _copyEmail(context),
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('이메일 주소 복사'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 안내 카테고리 (정적)
              const _CategoryCard(
                color: Color(0xFFFF6B81),
                icon: Icons.bug_report_outlined,
                title: '앱 오류 신고',
                description:
                    '버그가 발생했다면 다음 정보를 함께 보내주시면 빠르게 도와드릴 수 있어요.\n'
                    '• 사용 중인 기기/OS 버전\n'
                    '• 어떤 화면에서 어떤 동작을 했는지\n'
                    '• 가능하면 스크린샷 또는 화면 녹화',
              ),
              const SizedBox(height: 10),
              const _CategoryCard(
                color: Color(0xFFFFA94D),
                icon: Icons.lightbulb_outline_rounded,
                title: '신기능 제안',
                description:
                    '있었으면 하는 기능을 자유롭게 적어 주세요.\n'
                    '왜 필요한지(어떤 상황에서 쓰고 싶은지) 알려주시면 의도를 잘 살려 반영할 수 있어요.',
              ),
              const SizedBox(height: 10),
              const _CategoryCard(
                color: Color(0xFF6C5CE7),
                icon: Icons.chat_bubble_outline_rounded,
                title: '기타 문의',
                description:
                    '계정/결제/데이터 등 그 외 문의도 환영합니다.\n'
                    '회신은 평일 24~48시간 내에 드립니다.',
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.description,
  });

  final Color color;
  final IconData icon;
  final String title;
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12.5,
                    height: 1.5,
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
