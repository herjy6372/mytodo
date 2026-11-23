import 'package:flutter/material.dart';

import '../data/home_menu_repository.dart';
import '../l10n/app_localizations.dart';

/// 홈 화면 메뉴의 아이콘·색·이름.
class HomeMenuInfo {
  const HomeMenuInfo(this.icon, this.color, this.label);
  final IconData icon;
  final Color color;
  final String Function(BuildContext) label;
}

HomeMenuInfo homeMenuInfo(HomeMenu m) => switch (m) {
      HomeMenu.todos => HomeMenuInfo(Icons.checklist_rounded,
          const Color(0xFF6C5CE7), (c) => AppLocalizations.of(c).menuTodos),
      HomeMenu.calendar => HomeMenuInfo(Icons.calendar_month_rounded,
          const Color(0xFF22B6A0), (c) => AppLocalizations.of(c).menuCalendar),
      HomeMenu.graph => HomeMenuInfo(Icons.bar_chart_rounded,
          const Color(0xFFFFA94D), (c) => AppLocalizations.of(c).menuGraph),
      HomeMenu.mood => HomeMenuInfo(Icons.edit_note_rounded,
          const Color(0xFFFF8FA3), (c) => AppLocalizations.of(c).menuMood),
      HomeMenu.ledger => HomeMenuInfo(Icons.account_balance_wallet_rounded,
          const Color(0xFF2EC4B6), (c) => AppLocalizations.of(c).menuLedger),
      HomeMenu.timer => HomeMenuInfo(Icons.timer_rounded,
          const Color(0xFFFFB74D), (c) => AppLocalizations.of(c).menuTimer),
      HomeMenu.worldClock => HomeMenuInfo(Icons.public_rounded,
          const Color(0xFF7B83EB), (c) => AppLocalizations.of(c).menuWorldClock),
      HomeMenu.memo => HomeMenuInfo(Icons.sticky_note_2_rounded,
          const Color(0xFFF4B400), (_) => '메모'),
      HomeMenu.support => HomeMenuInfo(Icons.support_agent_rounded,
          const Color(0xFF4F8DFF), (_) => '고객지원'),
    };
