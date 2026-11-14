import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/parent_consent_repository.dart';
import '../data/profile_repository.dart';

/// 앱 최초 가입 시 표시되는 필수 온보딩 화면.
/// Step 0: 생년월일 + 개인정보 동의
/// Step 1: 거주 국가 선택 (KR / US)
/// Step 2: 보호자 정보 입력 (만 14세 미만)
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.initialStep = 0});
  final int initialStep;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _privacyUrl =
      'https://www.notion.so/herjy6372/350255869d0a80ad8ed8e72cc2e05cf2?source=copy_link';

  // step: 0 = 생일+동의, 1 = 국가선택, 2 = 보호자 정보 (만 14세 미만)
  late int _step = widget.initialStep;

  DateTime? _birthDate;
  bool _privacyAgreed = false;
  String? _countryCode; // 'KR' | 'US'
  bool _busy = false;

  // 보호자 정보 컨트롤러
  final _parentNameCtrl = TextEditingController();
  final _parentAgeCtrl = TextEditingController();
  final _parentPhoneCtrl = TextEditingController();

  @override
  void dispose() {
    _parentNameCtrl.dispose();
    _parentAgeCtrl.dispose();
    _parentPhoneCtrl.dispose();
    super.dispose();
  }

  bool get _isUnder14 {
    final b = _birthDate;
    if (b == null) return false;
    final now = DateTime.now();
    var age = now.year - b.year;
    final hadBirthday =
        (now.month > b.month) || (now.month == b.month && now.day >= b.day);
    if (!hadBirthday) age--;
    return age < 14;
  }

  Future<void> _pickBirthDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(today.year - 15, 1, 1),
      firstDate: DateTime(1900, 1, 1),
      lastDate: today,
      helpText: '생년월일 선택',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _openPrivacy() async {
    await launchUrl(Uri.parse(_privacyUrl),
        mode: LaunchMode.externalApplication);
  }

  /// Step 0 완료: 생일 + 동의 저장 → Step 1(국가 선택)으로 이동
  Future<void> _nextStep() async {
    if (_birthDate == null) {
      _snack('생년월일을 입력해 주세요.');
      return;
    }
    if (!_privacyAgreed) {
      _snack('개인정보 처리방침에 동의해야 이용할 수 있습니다.');
      return;
    }

    setState(() => _busy = true);
    try {
      await ProfileRepository.instance.updateProfile(
        birthDate: _birthDate,
        privacyAgreed: true,
        ageVerified: !_isUnder14,
      );
    } catch (e) {
      _snack('저장 실패: $e');
      if (mounted) setState(() => _busy = false);
      return;
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _step = 1; // 국가 선택으로
    });
  }

  /// Step 1 완료: 국가 코드 저장 후 분기
  Future<void> _nextCountryStep() async {
    if (_countryCode == null) {
      _snack('거주 국가를 선택해 주세요.');
      return;
    }

    setState(() => _busy = true);
    try {
      await ProfileRepository.instance.updateCountryCode(_countryCode!);
    } catch (e) {
      _snack('저장 실패: $e');
      if (mounted) setState(() => _busy = false);
      return;
    }

    if (!mounted) return;
    setState(() => _busy = false);

    if (_isUnder14) {
      setState(() => _step = 2); // 보호자 정보 입력
    } else {
      Navigator.of(context).pop(); // 온보딩 완료
    }
  }

  /// Step 2: 보호자 정보 제출
  Future<void> _submitParentInfo() async {
    final name = _parentNameCtrl.text.trim();
    final ageStr = _parentAgeCtrl.text.trim();
    final phone = _parentPhoneCtrl.text.trim();

    if (name.isEmpty || ageStr.isEmpty || phone.isEmpty) {
      _snack('보호자 정보를 모두 입력해 주세요.');
      return;
    }
    final age = int.tryParse(ageStr);
    if (age == null || age < 19 || age > 120) {
      _snack('보호자 나이를 올바르게 입력해 주세요.');
      return;
    }

    setState(() => _busy = true);
    try {
      final profile = ProfileRepository.instance.profile;
      if (profile == null) throw Exception('프로필 정보를 불러올 수 없습니다.');

      await ParentConsentRepository.submit(
        uid: profile.uid,
        childEmail: profile.email,
        parentName: name,
        parentAge: age,
        parentPhone: phone,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // 온보딩 완료 → 홈으로 (대기 상태)
    } catch (e) {
      _snack('제출 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: switch (_step) {
            0 => _buildStep0(),
            1 => _buildStep1Country(),
            _ => _buildStep2Parent(),
          },
        ),
      ),
    );
  }

  // ── Step 0: 생년월일 + 개인정보 동의 ──────────────────────────────────

  Widget _buildStep0() {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 진행 표시: 총 단계 = 국가선택(+1) + 보호자(+1 if under14)
          _StepIndicator(current: 0, total: _isUnder14 ? 3 : 2),
          const SizedBox(height: 32),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cake_rounded, size: 36, color: scheme.primary),
          ),
          const SizedBox(height: 20),
          const Text(
            '기본 정보 입력',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '서비스 이용을 위해 생년월일과\n개인정보 처리방침 동의가 필요합니다.',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),

          // 생년월일
          _Label('생년월일 *'),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickBirthDate,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _birthDate != null
                      ? scheme.primary
                      : scheme.outlineVariant,
                  width: _birthDate != null ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      color: _birthDate != null
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                      size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _birthDate != null
                        ? DateFormat('yyyy년 M월 d일', 'ko_KR')
                            .format(_birthDate!)
                        : '생년월일을 선택하세요',
                    style: TextStyle(
                      fontSize: 15,
                      color: _birthDate != null
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 나이 표시
          if (_birthDate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isUnder14
                        ? const Color(0xFFFFF3CD)
                        : scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isUnder14
                        ? '⚠️ 만 14세 미만 — 보호자 동의 필요'
                        : '✓ 만 ${_computeAge()} 세',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _isUnder14
                          ? const Color(0xFF856404)
                          : scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 28),

          // 개인정보 처리방침
          _Label('개인정보 처리방침 *'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _privacyAgreed
                    ? scheme.primary
                    : scheme.outlineVariant,
                width: _privacyAgreed ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: _openPrivacy,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined,
                            color: scheme.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '개인정보 처리방침 읽기',
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        Icon(Icons.open_in_new_rounded,
                            size: 16, color: scheme.primary),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: scheme.outlineVariant),
                InkWell(
                  onTap: () =>
                      setState(() => _privacyAgreed = !_privacyAgreed),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _privacyAgreed,
                          onChanged: (v) =>
                              setState(() => _privacyAgreed = v ?? false),
                        ),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            '개인정보 처리방침에 동의합니다 (필수)',
                            style: TextStyle(fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 36),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _nextStep,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('다음'),
            ),
          ),

          if (!_privacyAgreed) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Text('⚠️', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '개인정보 처리방침에 동의하지 않으면 앱을 이용할 수 없습니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF856404),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Step 1: 거주 국가 선택 ─────────────────────────────────────────────

  Widget _buildStep1Country() {
    final scheme = Theme.of(context).colorScheme;
    final totalSteps = _isUnder14 ? 3 : 2;

    Widget countryCard({
      required String code,
      required String flag,
      required String label,
      required String subtitle,
    }) {
      final selected = _countryCode == code;
      return GestureDetector(
        onTap: () => setState(() => _countryCode = code),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.10)
                : Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: selected ? scheme.primary : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded,
                    color: scheme.primary, size: 22),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIndicator(current: 1, total: totalSteps),
          const SizedBox(height: 32),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.public_rounded, size: 36, color: scheme.primary),
          ),
          const SizedBox(height: 20),
          const Text(
            '거주 국가 선택',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '거주 국가에 따라 달력에 해당 국가의\n공휴일이 표시됩니다.',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          countryCard(
            code: 'KR',
            flag: '🇰🇷',
            label: '대한민국 / South Korea',
            subtitle: '한국 공휴일(신정·설날·추석 등)이 달력에 표시됩니다.',
          ),
          const SizedBox(height: 10),
          countryCard(
            code: 'US',
            flag: '🇺🇸',
            label: '미국 / United States',
            subtitle: 'Default calendar — no special holidays displayed.',
          ),
          const SizedBox(height: 10),
          countryCard(
            code: 'JP',
            flag: '🇯🇵',
            label: '일본 / Japan',
            subtitle: 'デフォルトカレンダー — 祝日表示は今後対応予定です。',
          ),
          const SizedBox(height: 10),
          countryCard(
            code: 'PH',
            flag: '🇵🇭',
            label: '필리핀 / Philippines',
            subtitle: 'Default calendar — holiday display coming soon.',
          ),
          const SizedBox(height: 10),
          countryCard(
            code: 'VN',
            flag: '🇻🇳',
            label: '베트남 / Vietnam',
            subtitle: 'Lịch mặc định — hiển thị ngày lễ sẽ sớm ra mắt.',
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _nextCountryStep,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isUnder14 ? '다음 → 보호자 정보 입력' : '완료'),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : () => setState(() => _step = 0),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 0),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('이전으로'),
          ),
        ],
      ),
    );
  }

  // ── Step 2: 보호자 정보 입력 ───────────────────────────────────────────

  Widget _buildStep2Parent() {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIndicator(current: 2, total: 3),
          const SizedBox(height: 32),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.family_restroom_rounded,
                size: 36, color: Color(0xFF6C5CE7)),
          ),
          const SizedBox(height: 20),
          const Text(
            '보호자 정보 입력',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '만 14세 미만은 보호자 동의가 필요합니다.\n부모님 중 한 분의 정보를 입력해 주세요.',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '입력하신 정보는 관리자 검토 후 삭제되며 다른 용도로 사용되지 않습니다.',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          _Label('보호자 이름 *'),
          const SizedBox(height: 8),
          TextField(
            controller: _parentNameCtrl,
            decoration: const InputDecoration(
              hintText: '보호자 성함을 입력하세요',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 16),

          _Label('보호자 나이 *'),
          const SizedBox(height: 8),
          TextField(
            controller: _parentAgeCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              hintText: '만 나이를 숫자로 입력하세요',
              prefixIcon: Icon(Icons.cake_outlined),
            ),
          ),
          const SizedBox(height: 16),

          _Label('보호자 휴대폰 번호 *'),
          const SizedBox(height: 8),
          TextField(
            controller: _parentPhoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              hintText: '숫자만 입력하세요 (예: 01012345678)',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 36),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _submitParentInfo,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('보호자 동의 신청하기'),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () {
                    if (widget.initialStep == 2) {
                      Navigator.of(context).pop();
                    } else {
                      setState(() => _step = 1);
                    }
                  },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 0),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('이전으로'),
          ),
        ],
      ),
    );
  }

  int _computeAge() {
    final b = _birthDate;
    if (b == null) return 0;
    final now = DateTime.now();
    var age = now.year - b.year;
    final hadBirthday =
        (now.month > b.month) || (now.month == b.month && now.day >= b.day);
    if (!hadBirthday) age--;
    return age;
  }
}

// ── 헬퍼 위젯 ──────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(total, (i) {
        final active = i <= current;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: active ? scheme.primary : scheme.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
