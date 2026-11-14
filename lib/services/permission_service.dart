import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/auth_repository.dart';
import '../screens/login_screen.dart';
import 'notification_service.dart';
import 'weather_service.dart';

class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  static const _introShownKey = 'permission_intro_shown';
  bool _loginPromptedThisSession = false;

  /// HomeScreen 첫 프레임 후 호출. 첫 설치 여부에 따라 다른 흐름 실행.
  Future<void> checkAndRequest(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final introShown = prefs.getBool(_introShownKey) ?? false;

    if (!introShown) {
      if (!context.mounted) return;
      await _showIntroAndRequest(context);
      await prefs.setBool(_introShownKey, true);
    } else {
      if (!context.mounted) return;
      await _silentCheck(context);
    }

    // 앱 실행 시 비로그인 상태이면 로그인 화면으로 안내 (세션당 1회)
    if (context.mounted &&
        !AuthRepository.instance.isLoggedIn &&
        !_loginPromptedThisSession) {
      _loginPromptedThisSession = true;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  // ────────────────────────────────────────────────────
  // 첫 설치: 안내 다이얼로그 → 순차 요청
  // ────────────────────────────────────────────────────
  Future<void> _showIntroAndRequest(BuildContext context) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Text('앱 권한 안내', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PermissionRow(
              emoji: '🔔',
              title: '알림 권한',
              description: '할 일 마감 시간이 되면 알림으로 알려드립니다.',
            ),
            SizedBox(height: 16),
            _PermissionRow(
              emoji: '📍',
              title: '위치 권한',
              description: '현재 위치의 날씨 정보를 홈 화면에 표시합니다.',
            ),
            SizedBox(height: 16),
            _PermissionRow(
              emoji: '🖼️',
              title: '갤러리 / 사진 권한',
              description: '프로필 사진을 갤러리에서 선택하여 변경할 때 필요합니다.',
            ),
            SizedBox(height: 12),
            Text(
              '권한은 언제든지 기기 설정에서 변경할 수 있습니다.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('권한 허용하기'),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );

    // 순차적으로 권한 요청
    if (!context.mounted) return;
    await _requestNotification(context);
    if (!context.mounted) return;
    await _requestLocation(context);
  }

  // ────────────────────────────────────────────────────
  // 이후 실행: 미허용 항목만 조용히 재요청
  // ────────────────────────────────────────────────────
  Future<void> _silentCheck(BuildContext context) async {
    // 알림 권한 확인
    final notifGranted = await _isNotificationGranted();
    if (!notifGranted) {
      if (!context.mounted) return;
      await _requestNotification(context);
    }

    // 위치 권한 확인
    final locStatus = await Geolocator.checkPermission();
    if (locStatus == LocationPermission.denied) {
      if (!context.mounted) return;
      await _requestLocation(context);
    } else if (locStatus == LocationPermission.deniedForever) {
      if (!context.mounted) return;
      _showSettingsSnackbar(
          context, '위치 권한이 영구 거부되어 있습니다. 설정에서 허용해 주세요.');
    } else {
      // 이미 허용 → 날씨 로드가 아직 안 됐다면 재시도
      if (WeatherService.instance.weather == null &&
          !WeatherService.instance.loading) {
        WeatherService.instance.load();
      }
    }
  }

  // ────────────────────────────────────────────────────
  // 알림 권한 요청
  // ────────────────────────────────────────────────────
  Future<void> _requestNotification(BuildContext context) async {
    final granted = await NotificationService.instance.requestPermission();
    if (!granted && context.mounted) {
      _showSettingsSnackbar(
          context, '알림 권한이 거부되었습니다. 설정에서 허용해야 할 일 알림을 받을 수 있습니다.');
    }
  }

  // ────────────────────────────────────────────────────
  // 위치 권한 요청
  // ────────────────────────────────────────────────────
  Future<void> _requestLocation(BuildContext context) async {
    final status = await Geolocator.requestPermission();
    if (status == LocationPermission.whileInUse ||
        status == LocationPermission.always) {
      // 허용됨 → 날씨 로드
      WeatherService.instance.load();
    } else if (status == LocationPermission.deniedForever &&
        context.mounted) {
      _showSettingsSnackbar(
          context, '위치 권한이 영구 거부되어 있습니다. 설정에서 허용해 주세요.');
    }
  }

  // ────────────────────────────────────────────────────
  // 알림 권한 허용 여부 확인 (요청 없이)
  // ────────────────────────────────────────────────────
  Future<bool> _isNotificationGranted() async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      if (Platform.isAndroid) {
        final android = plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return await android?.areNotificationsEnabled() ?? true;
      }
      if (Platform.isIOS) {
        final ios = plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final settings = await ios?.checkPermissions();
        return settings?.isEnabled ?? true;
      }
    } catch (_) {}
    return true;
  }

  void _showSettingsSnackbar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '설정 열기',
          onPressed: () => Geolocator.openAppSettings(),
        ),
      ),
    );
  }
}

/// 권한 안내 다이얼로그용 행 위젯
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.emoji,
    required this.title,
    required this.description,
  });
  final String emoji;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                    height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
