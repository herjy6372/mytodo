import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/auth_repository.dart';
import 'data/language_repository.dart';
import 'data/ledger_repository.dart';
import 'data/alarm_repository.dart';
import 'data/memo_repository.dart';
import 'data/mood_repository.dart';
import 'data/profile_repository.dart';
import 'data/theme_repository.dart';
import 'data/todo_repository.dart';
import 'data/world_clock_repository.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/graph_screen.dart';
import 'screens/ledger_screen.dart';
import 'screens/memo_screen.dart';
import 'screens/mood_screen.dart';
import 'screens/timer_screen.dart';
import 'screens/todo_list_screen.dart';
import 'screens/weekly_summary_screen.dart';
import 'screens/world_clock_screen.dart';
import 'services/daily_notification_service.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';
import 'services/widget_service.dart';
import 'theme/app_theme.dart';
import 'widgets/paw_background.dart';

/// 알림 탭 → 화면 이동에 사용하는 전역 네비게이터 키.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR');
  await initializeDateFormatting('en_US');
  await initializeDateFormatting('ja_JP');
  await initializeDateFormatting('vi_VN');
  // Filipino(fil)은 intl 미지원 → en_US 포맷 공용

  // Firebase 초기화 — `flutterfire configure` 로 firebase_options.dart 가
  // 생성되어야 합니다. 자세한 절차는 docs/firebase_setup_steps.md 참고.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    SyncService.instance.backend =
        FirebaseSyncBackend(FirebaseFirestore.instance);
  } catch (e, st) {
    debugPrint('Firebase 초기화 실패: $e\n$st');
  }

  await NotificationService.instance.init();
  await DailyNotificationService.instance.load();
  await DailyNotificationService.instance.requestPermission();
  await TodoRepository.instance.load();
  await MoodRepository.instance.load();
  await MemoRepository.instance.load();
  await AlarmRepository.instance.load();
  await LedgerRepository.instance.load();
  await WorldClockRepository.instance.load();
  await AuthRepository.instance.load();
  await ProfileRepository.instance.init();
  await SyncService.instance.load();
  await ThemeRepository.instance.load();
  await LanguageRepository.instance.load();

  // 할 일·기분·가계부 데이터 변경 시 일일 알림 재예약
  void rescheduleDaily() {
    DailyNotificationService.instance.scheduleDailyNotifications();
  }
  TodoRepository.instance.addListener(rescheduleDaily);
  MoodRepository.instance.addListener(rescheduleDaily);
  LedgerRepository.instance.addListener(rescheduleDaily);

  // 정기 알림 예약 (앱 시작 시 매번 최신 데이터로 재예약)
  await DailyNotificationService.instance.scheduleDailyNotifications();

  runApp(MyTodoApp(navigatorKey: navigatorKey));

  // 홈 화면 위젯 연결 (Android). 위젯을 누르면 해당 화면으로 이동.
  await WidgetService.init(navigatorKey, (screen) {
    final loggedIn = AuthRepository.instance.isLoggedIn;
    final pro = loggedIn && ProfileRepository.instance.role.canUsePro;
    final Widget? page = switch (screen) {
      'todo' when loggedIn => const TodoListScreen(),
      'calendar' when loggedIn => const CalendarScreen(),
      'graph' when loggedIn => const GraphScreen(),
      'mood' when pro => const MoodScreen(),
      'ledger' when pro => const LedgerScreen(),
      'memo' => const MemoScreen(),
      'memo_new' => const MemoEditScreen(),
      'timer' => const TimerScreen(),
      'worldclock' => const WorldClockScreen(),
      _ => null, // 권한이 없으면 홈 화면에 머무름
    };
    if (page != null) {
      navigatorKey.currentState
          ?.push(MaterialPageRoute(builder: (_) => page));
    }
  });

  // 알림 탭 핸들러: 주간 요약 알림 → WeeklySummaryScreen 이동
  DailyNotificationService.onNotificationTap = (payload) {
    if (payload == 'weekly_summary') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const WeeklySummaryScreen()),
      );
    }
  };
}

class MyTodoApp extends StatefulWidget {
  const MyTodoApp({super.key, required this.navigatorKey});
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<MyTodoApp> createState() => _MyTodoAppState();
}

class _MyTodoAppState extends State<MyTodoApp> with WidgetsBindingObserver {
  final _theme = ThemeRepository.instance;
  final _lang = LanguageRepository.instance;
  final _auth = AuthRepository.instance;
  final _profile = ProfileRepository.instance;

  @override
  void initState() {
    super.initState();
    _theme.addListener(_onChange);
    _lang.addListener(_onChange);
    _auth.addListener(_onChange);
    _profile.addListener(_onChange);
    WidgetsBinding.instance.addObserver(this);
  }

  /// 앱으로 돌아올 때: 홈 위젯에서 체크한 할 일을 반영하고 위젯을 최신화.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      TodoRepository.instance.reload();
      WidgetService.publishAll();
    }
  }

  @override
  void dispose() {
    _theme.removeListener(_onChange);
    _lang.removeListener(_onChange);
    _auth.removeListener(_onChange);
    _profile.removeListener(_onChange);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final canUseCustomTheme =
        _auth.isLoggedIn && _profile.role.canUseAnimalTheme;
    final choice = canUseCustomTheme ? _theme.choice : AppThemeChoice.system;
    final effectiveThemeMode =
        canUseCustomTheme ? _theme.themeMode : _theme.displayMode.themeMode;
    final ThemeData light;
    final ThemeData dark;
    switch (choice) {
      case AppThemeChoice.cat:
        light = AppTheme.catLight();
        dark = AppTheme.catDark();
      case AppThemeChoice.dog:
        light = AppTheme.dogLight();
        dark = AppTheme.dogDark();
      case AppThemeChoice.giraffe:
        light = AppTheme.giraffeLight();
        dark = AppTheme.giraffeDark();
      case AppThemeChoice.coffee:
        light = AppTheme.coffeeLight();
        dark = AppTheme.coffeeDark();
      case AppThemeChoice.system:
        light = AppTheme.light();
        dark = AppTheme.dark();
    }
    return MaterialApp(
      navigatorKey: widget.navigatorKey,
      title: '나의 할 일(Beta)',
      debugShowCheckedModeBanner: false,
      theme: light,
      darkTheme: dark,
      themeMode: effectiveThemeMode,
      locale: _lang.locale,
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
        Locale('ja', 'JP'),
        Locale('fil', 'PH'),
        Locale('vi', 'VN'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // 동물·커피 테마일 때 패턴 배경 적용
      builder: choice.isCustomTheme
          ? (ctx, child) {
              final isDark = Theme.of(ctx).brightness == Brightness.dark;
              return PawBackground(
                choice: choice,
                isDark: isDark,
                child: child!,
              );
            }
          : null,
      home: const HomeScreen(),
    );
  }
}
