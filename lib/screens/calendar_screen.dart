import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../data/language_repository.dart';
import '../l10n/app_localizations.dart';
import '../data/profile_repository.dart';
import '../data/todo_repository.dart';
import '../models/todo.dart';
import '../services/japanese_holiday_service.dart';
import '../services/korean_holiday_service.dart';
import '../widgets/rounded_todo_tile.dart';
import 'todo_edit_screen.dart';

/// 날짜형 (캘린더) 화면.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _repo = TodoRepository.instance;
  final _krHolidaySvc = KoreanHolidayService.instance;
  final _jpHolidaySvc = JapaneseHolidayService.instance;
  CalendarFormat _format = CalendarFormat.month;
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  String? get _countryCode =>
      ProfileRepository.instance.profile?.countryCode;

  bool get _isKrUser => _countryCode == 'KR';
  bool get _isJpUser => _countryCode == 'JP';

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onChange);
    _krHolidaySvc.addListener(_onChange);
    LanguageRepository.instance.addListener(_onChange);
    // 한국 사용자: 현재 월 + 다음 달 공휴일 미리 로드
    _krHolidaySvc.prefetch(_focused);
  }

  @override
  void dispose() {
    _repo.removeListener(_onChange);
    _krHolidaySvc.removeListener(_onChange);
    LanguageRepository.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  List<Todo> _eventsForDay(DateTime day) => _repo.forDate(day);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dayTodos = _eventsForDay(_selected);
    final isKr = _isKrUser;
    final isJp = _isJpUser;

    // 공휴일 이름: KR → API, JP → 오프라인 패키지
    final String? holidayName;
    if (isKr) {
      holidayName = _krHolidaySvc.holidayName(_selected);
    } else if (isJp) {
      holidayName = _jpHolidaySvc.holidayName(_selected);
    } else {
      holidayName = null;
    }

    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.calendarTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: TableCalendar<Todo>(
                locale: LanguageRepository.instance.language.calendarLocale,
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2100, 12, 31),
                focusedDay: _focused,
                selectedDayPredicate: (d) => isSameDay(d, _selected),
                calendarFormat: _format,
                availableCalendarFormats: {
                  CalendarFormat.month: l.calendarFormatMonth,
                  CalendarFormat.twoWeeks: l.calendarFormatTwoWeeks,
                  CalendarFormat.week: l.calendarFormatWeek,
                },
                onFormatChanged: (f) => setState(() => _format = f),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selected = selected;
                    _focused = focused;
                  });
                },
                onPageChanged: (focused) {
                  // ── BUG ③  수정 ──────────────────────────────────────────
                  // setState 없이 _focused 만 교체하면 build 클로저의 isKr 값이
                  // 이전 빌드 기준으로 고정되어 prefetch 조건이 잘못 평가될 수 있음.
                  // → setState 로 감싸 항상 최신 _focused 와 _isKrUser 를 사용.
                  setState(() => _focused = focused);
                  // JP 는 오프라인이므로 prefetch 불필요
                  if (_isKrUser) _krHolidaySvc.prefetch(focused);
                },
                eventLoader: _eventsForDay,
                // ── 공휴일 판별 (KR·JP 사용자만) ──────────────────────────
                holidayPredicate: isKr
                    ? (day) => _krHolidaySvc.isHoliday(day)
                    : isJp
                        ? (day) => _jpHolidaySvc.isHoliday(day)
                        : null,
                headerStyle: HeaderStyle(
                  formatButtonShowsNext: false,
                  titleCentered: true,
                  formatButtonDecoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  formatButtonTextStyle: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                  titleTextStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  markersAlignment: Alignment.bottomCenter,
                  markerMargin: const EdgeInsets.only(top: 4),
                  weekendTextStyle:
                      const TextStyle(color: Color(0xFFFF6B81)),
                  outsideDaysVisible: false,
                  // 공휴일 스타일: 빨간색 굵은 텍스트
                  holidayTextStyle: const TextStyle(
                    color: Color(0xFFE53935),
                    fontWeight: FontWeight.w700,
                  ),
                  holidayDecoration:
                      const BoxDecoration(shape: BoxShape.circle),
                ),
                // ── 공휴일 셀 빌더 (오늘이 공휴일일 때 빨간 텍스트 유지) ──
                calendarBuilders: CalendarBuilders<Todo>(
                  todayBuilder: (context, day, focusedDay) {
                    final isHol = (isKr && _krHolidaySvc.isHoliday(day)) ||
                        (isJp && _jpHolidaySvc.isHoliday(day));
                    return Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            color: isHol
                                ? const Color(0xFFE53935)
                                : scheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // ── 선택된 날짜 헤더 ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Text(
                    DateFormat(l.calendarDateFormat, l.calendarDateLocale).format(_selected),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      l.calendarTaskCount(dayTodos.length),
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // 공휴일 이름 배지
                  if (holidayName != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFFE53935).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              const Color(0xFFE53935).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        holidayName,
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: dayTodos.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l.calendarEmpty,
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                      itemCount: dayTodos.length,
                      separatorBuilder: (_, i) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final t = dayTodos[i];
                        return RoundedTodoTile(
                          todo: t,
                          onToggle: () => _repo.toggleDone(t.id),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TodoEditScreen(todo: t),
                            ),
                          ),
                          onDelete: () => _repo.remove(t.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TodoEditScreen(initialDate: _selected),
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(l.calendarAddFab),
      ),
    );
  }
}
