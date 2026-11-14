import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/auth_repository.dart';
import '../data/profile_repository.dart';
import '../l10n/app_localizations.dart';
import '../widgets/user_avatar.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  static const _privacyUrl =
      'https://www.notion.so/herjy6372/350255869d0a80ad8ed8e72cc2e05cf2?source=copy_link';

  late final TextEditingController _nicknameCtrl;
  late final TextEditingController _countryCodeCtrl;
  late final TextEditingController _phoneCtrl;
  DateTime? _birthDate;
  bool _ageVerified = false;
  bool _privacyAgreed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final p = ProfileRepository.instance.profile;
    _nicknameCtrl = TextEditingController(text: p?.nickname ?? '');
    _countryCodeCtrl = TextEditingController(
        text: p?.phoneCountryCode?.replaceAll('+', '') ?? '82');
    _phoneCtrl = TextEditingController(text: p?.phoneNumber ?? '');
    _birthDate = p?.birthDate;
    _ageVerified = p?.ageVerified ?? false;
    _privacyAgreed = p?.privacyAgreed ?? false;
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _countryCodeCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final l = AppLocalizations.of(context);
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(today.year - 20, 1, 1),
      firstDate: DateTime(1900, 1, 1),
      lastDate: today,
      locale: Locale(l.profileLocale),
      helpText: l.profileBirthdayPick,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _openPhotoPicker() async {
    // context 참조는 async gap 이전에 캡처
    final l = AppLocalizations.of(context);
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scaffoldBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _AvatarPickerSheet(),
    );
    if (result == null) return;
    setState(() => _busy = true);
    try {
      if (result == 'gallery') {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );
        if (picked != null) {
          await ProfileRepository.instance.uploadPhoto(File(picked.path));
          _snack(l.profilePhotoChanged);
        }
      } else if (result.startsWith('asset:')) {
        await ProfileRepository.instance.updateProfile(photoUrl: result);
        _snack(l.profileAvatarApplied);
      } else if (result == 'remove') {
        // 로컬 사진 + Firestore photoUrl 모두 제거
        await ProfileRepository.instance.removeLocalPhoto();
        await ProfileRepository.instance.updateProfile(photoUrl: '');
        _snack(l.profilePhotoRemoved);
      }
    } catch (e) {
      _snack(l.profilePhotoChangeFail('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final nick = _nicknameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final cc = _countryCodeCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    setState(() => _busy = true);
    try {
      // 휴대폰 번호가 입력된 경우 중복 확인 후 저장
      if (phone.isNotEmpty) {
        try {
          await ProfileRepository.instance.updatePhone(
            countryCode: '+$cc',
            phoneNumber: phone,
          );
        } on Exception catch (e) {
          if (e.toString().contains('phone_duplicate')) {
            _snack(l.profilePhoneDuplicate);
            return;
          }
          rethrow;
        }
      }

      await ProfileRepository.instance.updateProfile(
        nickname: nick,
        birthDate: _birthDate,
        clearBirthDate: false,
        ageVerified: _ageVerified,
        privacyAgreed: _privacyAgreed,
      );
      if (!mounted) return;
      _snack(l.profileSaved);
      Navigator.of(context).pop();
    } catch (e) {
      _snack(l.profileSaveFail('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dl = AppLocalizations.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          title: Text(dl.profileDeleteTitle),
          content: Text(dl.profileDeleteConfirm),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(dl.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(dl.profileDeleteBtn),
            ),
          ],
        );
      },
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await ProfileRepository.instance.deleteAccount();
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _snack(l.profileReLoginRequired);
        await AuthRepository.instance.signOut();
        if (!mounted) return;
        Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        _snack(l.profileDeleteFail(e.message ?? e.code));
      }
    } catch (e) {
      _snack(l.profileDeleteFail('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPrivacy() async {
    final failMsg = AppLocalizations.of(context).profileBrowserFail;
    final ok = await launchUrl(Uri.parse(_privacyUrl),
        mode: LaunchMode.externalApplication);
    if (!ok) _snack(failMsg);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final p = ProfileRepository.instance.profile;
    return Scaffold(
      appBar: AppBar(title: Text(l.profileTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  children: [
                    UserAvatar(
                      photoUrl: ProfileRepository.instance.displayPhotoUrl,
                      radius: 48,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Material(
                        color: scheme.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _busy ? null : _openPhotoPicker,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.edit_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  p?.email ?? '',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${l.profileGradePrefix}${p?.role.label ?? '-'}',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _Label(l.profileNickname),
              TextField(
                controller: _nicknameCtrl,
                maxLength: 20,
                decoration: InputDecoration(
                  hintText: l.profileNicknameHint,
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),
              _Label(l.profileBirthday),
              // 프로필에 생일이 이미 저장된 경우 읽기 전용으로 표시
              if (p?.birthDate != null)
                InputDecorator(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          DateFormat('yyyy-MM-dd').format(p!.birthDate!),
                        ),
                      ),
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                )
              else
                InkWell(
                  onTap: _pickBirthDate,
                  borderRadius: BorderRadius.circular(20),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.cake_outlined),
                      hintText: l.profileBirthdayHint,
                    ),
                    child: Text(
                      _birthDate == null
                          ? l.profileBirthdayHint
                          : DateFormat('yyyy-MM-dd').format(_birthDate!),
                      style: TextStyle(
                        color: _birthDate == null
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                  ),
                ),
              _Label(l.profilePhone),
              Row(
                children: [
                  // 국가 코드
                  SizedBox(
                    width: 72,
                    child: TextField(
                      controller: _countryCodeCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: const InputDecoration(
                        prefixText: '+',
                        hintText: '82',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 전화번호
                  Expanded(
                    child: TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 15,
                      decoration: InputDecoration(
                        hintText: l.profilePhoneHint,
                        prefixIcon: const Icon(Icons.phone_outlined),
                        counterText: '',
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Text(
                  l.profilePhoneNote,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _ageVerified,
                // 이미 체크된 경우 변경 불가
                onChanged: (p?.ageVerified == true)
                    ? null
                    : (v) => setState(() => _ageVerified = v ?? false),
                title: Text(l.profileAgeVerified),
                subtitle: Text(l.profileAgeVerifiedSub),
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: _privacyAgreed,
                // 이미 동의한 경우 변경 불가
                onChanged: (p?.privacyAgreed == true)
                    ? null
                    : (v) => setState(() => _privacyAgreed = v ?? false),
                title: GestureDetector(
                  onTap: _openPrivacy,
                  child: Text.rich(
                    TextSpan(text: l.profilePrivacyAgreed, children: [
                      TextSpan(
                        text: l.profilePrivacyView,
                        style: const TextStyle(
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ]),
                  ),
                ),
                subtitle: Text(l.profilePrivacyAgreedSub),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(l.save),
              ),
              const SizedBox(height: 24),
              Divider(color: scheme.outlineVariant),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.error,
                  side: BorderSide(color: scheme.error.withValues(alpha: 0.6)),
                ),
                onPressed: _busy ? null : _confirmDelete,
                icon: const Icon(Icons.delete_forever_rounded),
                label: Text(l.profileDeleteTitle),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  l.profileDeleteWarning,
                  style: TextStyle(
                      fontSize: 11.5, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}


class _AvatarPickerSheet extends StatelessWidget {
  const _AvatarPickerSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context).profilePhotoTitle,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    scheme.primary.withValues(alpha: 0.12),
                child: Icon(Icons.photo_library_rounded,
                    color: scheme.primary),
              ),
              title: Text(AppLocalizations.of(context).profilePhotoGallery),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.error.withValues(alpha: 0.12),
                child: Icon(Icons.person_off_rounded, color: scheme.error),
              ),
              title: Text(AppLocalizations.of(context).profilePhotoRemove),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
          ],
        ),
      ),
    );
  }
}

