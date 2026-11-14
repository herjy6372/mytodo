import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// ── 일별 예보 모델 ────────────────────────────────────────────────────────────

class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.weatherCode,
    required this.maxTemp,
    required this.minTemp,
    required this.precipitationProbability,
    required this.maxWindspeed,
  });

  final DateTime date;
  final int weatherCode;
  final double maxTemp;
  final double minTemp;
  final int precipitationProbability; // 0 ~ 100 (%)
  final double maxWindspeed; // km/h

  WeatherCondition get condition =>
      WeatherCondition.fromCode(weatherCode, maxWindspeed);

  /// 요일 레이블: 오늘 → '오늘', 내일 → '내일', 이후 → 요일 (월·화·수…)
  String dayLabel(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(date.year, date.month, date.day);
    final diff  = d.difference(today).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '내일';
    return DateFormat('M/d').format(date); // 5/22, 5/23…
  }
}

// ── 현재 날씨 모델 ────────────────────────────────────────────────────────────

/// Open-Meteo + Nominatim 역지오코딩 기반 날씨 정보.
class WeatherInfo {
  const WeatherInfo({
    required this.temperature,
    required this.weatherCode,
    required this.windspeed,
    this.locationName = '',
    this.dailyForecast = const [],
  });

  final double temperature;
  final int weatherCode;
  final double windspeed;        // km/h
  final String locationName;     // Nominatim 역지오코딩 결과 (예: "김천시")
  final List<DailyForecast> dailyForecast; // 최대 16일

  WeatherCondition get condition =>
      WeatherCondition.fromCode(weatherCode, windspeed);

  /// 내일 예보 (dailyForecast[1])
  DailyForecast? get tomorrow =>
      dailyForecast.length > 1 ? dailyForecast[1] : null;
}

// ── 날씨 상태 열거형 ─────────────────────────────────────────────────────────

enum WeatherCondition {
  sunny,
  partlyCloudy,
  cloudy,
  windy,
  rainy,
  snow,
  thunderstorm;

  /// WMO 날씨 코드 + 풍속으로 상태 분류.
  static WeatherCondition fromCode(int code, double windspeed) {
    if (code >= 95) return thunderstorm;
    if (code >= 71 && code <= 77) return snow;
    if (code >= 51 && code <= 82) return rainy;
    if (windspeed >= 30) return windy;
    if (code == 0) return sunny;
    if (code <= 2) return partlyCloudy;
    if (code <= 48) return cloudy;
    return cloudy;
  }

  String get emoji {
    switch (this) {
      case sunny:        return '☀️';
      case partlyCloudy: return '🌤️';
      case cloudy:       return '☁️';
      case windy:        return '🌬️';
      case rainy:        return '🌧️';
      case snow:         return '❄️';
      case thunderstorm: return '⛈️';
    }
  }

  String get label {
    switch (this) {
      case sunny:        return '맑음';
      case partlyCloudy: return '구름 조금';
      case cloudy:       return '흐림';
      case windy:        return '강풍';
      case rainy:        return '비';
      case snow:         return '눈';
      case thunderstorm: return '천둥번개';
    }
  }

  List<Color> get gradientColors {
    switch (this) {
      case sunny:
        return [const Color(0xFFFFB347), const Color(0xFFFFD580)];
      case partlyCloudy:
        return [const Color(0xFF74B9FF), const Color(0xFFA29BFE)];
      case cloudy:
        return [const Color(0xFF9EAAB7), const Color(0xFFB2BEC3)];
      case windy:
        return [const Color(0xFF48CAE4), const Color(0xFF90E0EF)];
      case rainy:
        return [const Color(0xFF4F6D7A), const Color(0xFF74B9FF)];
      case snow:
        return [const Color(0xFFADD8E6), const Color(0xFFE0F7FA)];
      case thunderstorm:
        return [const Color(0xFF2D3436), const Color(0xFF636E72)];
    }
  }
}

// ── 서비스 ────────────────────────────────────────────────────────────────────

class WeatherService extends ChangeNotifier {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  WeatherInfo? _weather;
  bool _loading = false;
  String? _error;

  WeatherInfo? get weather => _weather;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final position = await _getPosition();
      final lat = position.latitude;
      final lon = position.longitude;

      // 현재 날씨 + 16일 예보 + 역지오코딩 병렬 요청
      final results = await Future.wait([
        _fetchWeather(lat, lon),
        _fetchLocationName(lat, lon),
      ]);

      final info         = results[0] as WeatherInfo;
      final locationName = results[1] as String;

      _weather = WeatherInfo(
        temperature: info.temperature,
        weatherCode: info.weatherCode,
        windspeed:   info.windspeed,
        locationName: locationName,
        dailyForecast: info.dailyForecast,
      );
    } catch (e) {
      _error = e.toString();
      debugPrint('[WeatherService] error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── 위치 권한 + 좌표 취득 ────────────────────────────────────────────────────

  Future<Position> _getPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('위치 서비스가 꺼져 있습니다.');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('위치 권한이 거부되었습니다.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('위치 권한이 영구 거부되었습니다.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  // ── Open-Meteo API — 현재 날씨 + 16일 daily 예보 ───────────────────────────

  Future<WeatherInfo> _fetchWeather(double lat, double lon) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lon'
      '&current_weather=true'
      '&daily=weathercode,temperature_2m_max,temperature_2m_min'
      ',precipitation_probability_max,windspeed_10m_max'
      '&forecast_days=16'
      '&timezone=auto'
      '&temperature_unit=celsius'
      '&windspeed_unit=kmh',
    );

    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('날씨 API 오류: ${res.statusCode}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;

    // 현재 날씨
    final cw = json['current_weather'] as Map<String, dynamic>;
    final temperature = (cw['temperature'] as num).toDouble();
    final weatherCode = (cw['weathercode'] as num).toInt();
    final windspeed   = (cw['windspeed'] as num).toDouble();

    // 16일 일별 예보
    final daily     = json['daily'] as Map<String, dynamic>? ?? {};
    final dates     = (daily['time'] as List?)?.cast<String>() ?? [];
    final codes     = (daily['weathercode'] as List?)?.cast<num>() ?? [];
    final maxTemps  = (daily['temperature_2m_max'] as List?)?.cast<num>() ?? [];
    final minTemps  = (daily['temperature_2m_min'] as List?)?.cast<num>() ?? [];
    final precips   = (daily['precipitation_probability_max'] as List?)?.cast<num?>() ?? [];
    final winds     = (daily['windspeed_10m_max'] as List?)?.cast<num?>() ?? [];

    final forecasts = <DailyForecast>[];
    for (int i = 0; i < dates.length; i++) {
      forecasts.add(DailyForecast(
        date: DateTime.parse(dates[i]),
        weatherCode: codes.length > i ? codes[i].toInt() : 0,
        maxTemp: maxTemps.length > i ? maxTemps[i].toDouble() : 0,
        minTemp: minTemps.length > i ? minTemps[i].toDouble() : 0,
        precipitationProbability:
            precips.length > i ? (precips[i] ?? 0).toInt() : 0,
        maxWindspeed: winds.length > i ? (winds[i] ?? 0).toDouble() : 0,
      ));
    }

    return WeatherInfo(
      temperature: temperature,
      weatherCode: weatherCode,
      windspeed: windspeed,
      dailyForecast: forecasts,
    );
  }

  // ── Nominatim 역지오코딩 — 도시/구 이름 반환 ────────────────────────────────

  Future<String> _fetchLocationName(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lon&format=json&accept-language=ko',
      );
      final res = await http
          .get(uri, headers: {'User-Agent': 'mytodo-flutter-app'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return '';

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final addr = json['address'] as Map<String, dynamic>? ?? {};

      // 한국 주소: city → county → town → village 우선
      final city = addr['city'] as String?
          ?? addr['county'] as String?
          ?? addr['town'] as String?
          ?? addr['village'] as String?
          ?? '';
      final district = addr['city_district'] as String?
          ?? addr['suburb'] as String?
          ?? addr['quarter'] as String?
          ?? '';

      if (city.isNotEmpty && district.isNotEmpty) return '$city $district';
      if (city.isNotEmpty) return city;
      return addr['state'] as String? ?? '';
    } catch (_) {
      return '';
    }
  }
}
