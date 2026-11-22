import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/alarm_ring_service.dart';
import '../services/notification_service.dart';

/// 알람이 울릴 때 뜨는 전체 화면.
/// [firedAt] 부터 1분 동안 알람음을 내고, 중지하거나 N분 뒤로 미룰 수 있습니다.
/// 닫힐 때 미룬 분(int)을 돌려주거나, 중지하면 null 을 돌려줍니다.
class AlarmRingScreen extends StatefulWidget {
  const AlarmRingScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.firedAt,
  });

  final String title;
  final String subtitle;
  final DateTime firedAt;

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen>
    with SingleTickerProviderStateMixin {
  Timer? _stopTimer;
  Timer? _clock;
  bool _ringing = false;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    final remaining = NotificationService.ringDuration -
        DateTime.now().difference(widget.firedAt);
    if (remaining > Duration.zero) {
      _ringing = true;
      AlarmRingService.instance.startSound();
      _stopTimer = Timer(remaining, _timeUp);
    } else {
      _pulse.stop();
    }
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _timeUp() {
    AlarmRingService.instance.stopSound();
    _pulse.stop();
    if (mounted) setState(() => _ringing = false);
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    _clock?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    return PopScope(
      // 뒤로 가기도 "중지"로 처리
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              children: [
                const Spacer(),
                ScaleTransition(
                  scale: Tween(begin: 0.92, end: 1.08).animate(
                      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.alarm_rounded,
                        size: 64, color: scheme.primary),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  DateFormat('a h:mm', 'ko_KR').format(now),
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                if (widget.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                        fontSize: 14, color: scheme.onSurfaceVariant),
                  ),
                ],
                if (!_ringing) ...[
                  const SizedBox(height: 10),
                  Text(
                    '1분이 지나 소리가 멈췄어요',
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant),
                  ),
                ],
                const Spacer(),
                Text(
                  '다시 울림',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final m in AlarmRingService.snoozeChoices) ...[
                      if (m != AlarmRingService.snoozeChoices.first)
                        const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () => Navigator.of(context).pop(m),
                          child: Text('$m분 뒤',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      '알람 중지',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
