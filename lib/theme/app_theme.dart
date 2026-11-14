import 'package:flutter/material.dart';

/// 앱 전체 테마. 둥근 모서리, 부드러운 색감을 기본으로 합니다.
class AppTheme {
  static const seed       = Color(0xFF6C5CE7); // 시스템 기본 (보라)
  static const catSeed    = Color(0xFFFF6B81); // 고양이 (핑크)
  static const dogSeed    = Color(0xFFC97B5C); // 강아지 (따뜻한 갈색)
  static const giraffeSeed = Color(0xFFFF9800); // 기린 (주황)
  static const coffeeSeed  = Color(0xFF8BC34A); // 커피 (연두)

  static ThemeData light() => _fromSeed(seed, Brightness.light,
      scaffoldBg: const Color(0xFFF6F6FB));
  static ThemeData dark() => _fromSeed(seed, Brightness.dark,
      scaffoldBg: const Color(0xFF15151B));

  // 동물/특별 테마: 패턴 배경이 Scaffold 뒤에 보이도록 투명 처리
  static ThemeData catLight() => _fromSeed(catSeed, Brightness.light,
      scaffoldBg: Colors.transparent);
  static ThemeData catDark() => _fromSeed(catSeed, Brightness.dark,
      scaffoldBg: Colors.transparent);

  static ThemeData dogLight() => _fromSeed(dogSeed, Brightness.light,
      scaffoldBg: Colors.transparent);
  static ThemeData dogDark() => _fromSeed(dogSeed, Brightness.dark,
      scaffoldBg: Colors.transparent);

  static ThemeData giraffeLight() => _fromSeed(giraffeSeed, Brightness.light,
      scaffoldBg: Colors.transparent);
  static ThemeData giraffeDark() => _fromSeed(giraffeSeed, Brightness.dark,
      scaffoldBg: Colors.transparent);

  static ThemeData coffeeLight() => _fromSeed(coffeeSeed, Brightness.light,
      scaffoldBg: Colors.transparent);
  static ThemeData coffeeDark() => _fromSeed(coffeeSeed, Brightness.dark,
      scaffoldBg: Colors.transparent);

  static ThemeData _fromSeed(Color seedColor, Brightness brightness,
      {required Color scaffoldBg}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return _build(scheme, scaffoldBg: scaffoldBg);
  }

  static ThemeData _build(ColorScheme scheme, {required Color scaffoldBg}) {
    final isDark = scheme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1F1F27) : Colors.white;
    final outlineColor =
        isDark ? const Color(0xFF2A2A33) : const Color(0xFFE9E9F1);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
        color: cardColor,
        surfaceTintColor: cardColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const StadiumBorder(),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: outlineColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: outlineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: outlineColor,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
