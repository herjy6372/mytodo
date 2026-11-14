import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

enum _TimerState { idle, running, paused, finished }

class _TimerScreenState extends State<TimerScreen> {
  // 설정값(초기 입력)
  int _setHours = 0;
  int _setMinutes = 5;
  int _setSeconds = 0;

  // 남은 시간(초)
  int _remaining = 5 * 60;

  Timer? _ticker;
  _TimerState _state = _TimerState.idle;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int get _totalSetSeconds =>
      _setHours * 3600 + _setMinutes * 60 + _setSeconds;

  String _format(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  void _start() {
    if (_state == _TimerState.idle) {
      if (_totalSetSeconds <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('시간을 1초 이상 설정해 주세요.')),
        );
        return;
      }
      _remaining = _totalSetSeconds;
    }
    _ticker?.cancel();
    setState(() => _state = _TimerState.running);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remaining > 0) {
          _remaining -= 1;
          if (_remaining == 0) _onFinished();
        }
      });
    });
  }

  void _pause() {
    _ticker?.cancel();
    setState(() => _state = _TimerState.paused);
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      _state = _TimerState.idle;
      _remaining = _totalSetSeconds;
    });
  }

  Future<void> _onFinished() async {
    _ticker?.cancel();
    setState(() => _state = _TimerState.finished);
    // 진동 + 사운드
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    // 짧은 진동 패턴
    for (int i = 0; i < 3; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      HapticFeedback.heavyImpact();
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('⏰ 타이머 종료'),
        content: const Text('설정한 시간이 모두 지났어요.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() {
      _state = _TimerState.idle;
      _remaining = _totalSetSeconds;
    });
  }

  Future<void> _editTime() async {
    final result = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _TimePickerSheet(
        initialH: _setHours,
        initialM: _setMinutes,
        initialS: _setSeconds,
      ),
    );
    if (result == null) return;
    setState(() {
      _setHours = result[0];
      _setMinutes = result[1];
      _setSeconds = result[2];
      _remaining = _totalSetSeconds;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canEdit = _state == _TimerState.idle;

    return Scaffold(
      appBar: AppBar(title: const Text('타이머')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: canEdit ? _editTime : null,
                  borderRadius: BorderRadius.circular(40),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _format(_remaining),
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          canEdit
                              ? '시간을 누르면 설정할 수 있어요 (00:00:00 ~ 99:59:59)'
                              : '진행 중',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_state == _TimerState.running)
                      _ActionBtn(
                        icon: Icons.pause_rounded,
                        label: '일시정지',
                        onPressed: _pause,
                      )
                    else
                      _ActionBtn(
                        icon: Icons.play_arrow_rounded,
                        label: _state == _TimerState.paused
                            ? '계속'
                            : '시작',
                        primary: true,
                        onPressed: _start,
                      ),
                    const SizedBox(width: 12),
                    _ActionBtn(
                      icon: Icons.replay_rounded,
                      label: '리셋',
                      onPressed: _state == _TimerState.idle &&
                              _remaining == _totalSetSeconds
                          ? null
                          : _reset,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final btn = primary
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          );
    return SizedBox(width: 140, child: btn);
  }
}

/// 시/분/초 휠 입력 시트.
class _TimePickerSheet extends StatefulWidget {
  const _TimePickerSheet({
    required this.initialH,
    required this.initialM,
    required this.initialS,
  });
  final int initialH;
  final int initialM;
  final int initialS;

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late int _h;
  late int _m;
  late int _s;
  late final FixedExtentScrollController _hCtrl;
  late final FixedExtentScrollController _mCtrl;
  late final FixedExtentScrollController _sCtrl;

  @override
  void initState() {
    super.initState();
    _h = widget.initialH.clamp(0, 99);
    _m = widget.initialM.clamp(0, 59);
    _s = widget.initialS.clamp(0, 59);
    _hCtrl = FixedExtentScrollController(initialItem: _h);
    _mCtrl = FixedExtentScrollController(initialItem: _m);
    _sCtrl = FixedExtentScrollController(initialItem: _s);
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    _mCtrl.dispose();
    _sCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text('타이머 시간 설정',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  _wheel('시', 100, _hCtrl, (v) => _h = v),
                  _wheel('분', 60, _mCtrl, (v) => _m = v),
                  _wheel('초', 60, _sCtrl, (v) => _s = v),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, [_h, _m, _s]),
                    child: const Text('확인'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _wheel(String label, int count,
      FixedExtentScrollController ctrl, ValueChanged<int> onChanged) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(
            child: ListWheelScrollView.useDelegate(
              controller: ctrl,
              itemExtent: 40,
              physics: const FixedExtentScrollPhysics(),
              perspective: 0.005,
              onSelectedItemChanged: onChanged,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: count,
                builder: (_, i) => Center(
                  child: Text(
                    i.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
