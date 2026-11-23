import 'package:flutter/material.dart';

import '../data/home_menu_repository.dart';
import '../widgets/home_menu_items.dart';

/// 홈 화면 메뉴 켜고 끄기 · 순서 바꾸기.
class HomeMenuSettingsScreen extends StatefulWidget {
  const HomeMenuSettingsScreen({super.key});

  @override
  State<HomeMenuSettingsScreen> createState() => _HomeMenuSettingsScreenState();
}

class _HomeMenuSettingsScreenState extends State<HomeMenuSettingsScreen> {
  final _repo = HomeMenuRepository.instance;

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
    final order = _repo.order;
    return Scaffold(
      appBar: AppBar(
        title: const Text('홈 화면 메뉴'),
        actions: [
          TextButton(onPressed: _repo.reset, child: const Text('처음대로')),
        ],
      ),
      body: SafeArea(
        child: ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          header: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '자주 쓰는 메뉴만 켜 두고, 오른쪽 손잡이를 끌어서 순서를 바꿀 수 있어요. '
              '꺼 둔 메뉴는 홈 화면에서만 숨겨지고 기록은 그대로 남아요.',
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: 13, height: 1.5),
            ),
          ),
          itemCount: order.length,
          onReorderItem: _repo.move,
          itemBuilder: (context, i) {
            final m = order[i];
            final info = homeMenuInfo(m);
            final hidden = _repo.isHidden(m);
            return Padding(
              key: ValueKey(m),
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: info.color.withValues(alpha: 0.15),
                      child: Icon(info.icon, color: info.color, size: 20),
                    ),
                    title: Text(info.label(context),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: !hidden,
                          onChanged: (on) => _repo.setHidden(m, !on),
                        ),
                        ReorderableDragStartListener(
                          index: i,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.drag_handle_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
