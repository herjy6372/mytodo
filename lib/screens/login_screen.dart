import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/auth_repository.dart';
import '../l10n/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _privacyUrl =
      'https://www.notion.so/herjy6372/350255869d0a80ad8ed8e72cc2e05cf2?source=copy_link';

  bool _loading = false;

  Future<void> _openPrivacy() async {
    await launchUrl(Uri.parse(_privacyUrl),
        mode: LaunchMode.externalApplication);
  }

  Future<void> _signInGoogle() async {
    setState(() => _loading = true);
    try {
      await AuthRepository.instance.signInWithGoogle();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'cancelled') _snack(_friendlyMessage(e));
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('ApiException: 10') ||
          msg.contains('DEVELOPER_ERROR')) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            title: const Text('Google 로그인 설정 필요'),
            content: const Text(
                '이 빌드의 서명 키 SHA-1 이 Firebase 에 등록되어 있지 않습니다.\n\n'
                '(개발자용 안내) Firebase Console → 프로젝트 설정 → '
                'Android 앱 → 지문 추가 에서 업로드/디버그 키스토어의 '
                'SHA-1 두 개를 모두 등록 후 google-services.json 을 '
                '갱신하면 해결됩니다.'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      } else {
        _snack('Google 로그인 실패: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _skipLogin() {
    Navigator.of(context).pop(false);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _friendlyMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'network-request-failed':
        return '네트워크 연결을 확인해 주세요.';
      default:
        return e.message ?? '오류가 발생했습니다. (${e.code})';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.isKorean ? '로그인' : 'Sign In')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_rounded,
                    size: 44, color: scheme.primary),
              ),
              const SizedBox(height: 18),
              Text(
                l.isKorean ? '환영합니다' : 'Welcome',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                l.isKorean
                    ? '계정으로 로그인하면 여러 기기에서\n할 일이 자동으로 동기화됩니다.'
                    : 'Sign in to automatically sync your tasks\nacross multiple devices.',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              // 구글 로그인 버튼
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _signInGoogle,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.g_mobiledata_rounded, size: 28),
                  label: Text(l.loginWithGoogle),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 로그인 없이 사용 버튼
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _loading ? null : _skipLogin,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(l.loginWithoutLogin),
                ),
              ),
              // 로그인 없이 사용 시 안내
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ℹ️', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.loginNoSyncWarning,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Center(
                child: TextButton(
                  onPressed: _openPrivacy,
                  child: Text(
                    l.isKorean ? '개인정보 처리방침' : 'Privacy Policy',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
