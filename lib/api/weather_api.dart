// lib/api/weather_api.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/weather_data.dart';

class WeatherApi {
  // 서비스 키 (URL 인코딩 문제 해결을 위해 디코딩된 상태로 사용)
  static const String SERVICE_KEY = 'S+7zSRvCnsne4FGNa9yGGQo3VWzoncxKCq4rLOK2EOCQPoLXkZrCd72Xp+2rbDbwwwHPlcIH1DvOcVTqKzatgw==';
  static const String API_URL = '/1360000/VilageFcstInfoService_2.0/getVilageFcst'; // 단기예보조회

  // 단기예보 발표 시각 리스트
  static const List<String> BASE_TIMES = [
    '0200', '0500', '0800', '1100', '1400', '1700', '2000', '2300'
  ];

  // 현재 시각 기준 가장 가까운 과거 base_date와 base_time을 계산하는 함수
  Map<String, String> getBaseTime() {
    final now = DateTime.now();
    DateTime baseDateTime = now;
    String baseDate = DateFormat('yyyyMMdd').format(now);
    String baseTime = '2300';

    final currentHourMinute = int.parse(DateFormat('HHmm').format(now));

    for (final time in BASE_TIMES) {
      final apiReadyTime = int.parse(time) + 10; // API 제공 시작 시각 (발표 후 10분)

      if (currentHourMinute >= apiReadyTime) {
        baseTime = time;
      } else {
        break;
      }
    }

    if (baseTime == '2300' && currentHourMinute < int.parse(BASE_TIMES[0]) + 10) {
      baseDateTime = now.subtract(const Duration(days: 1));
      baseDate = DateFormat('yyyyMMdd').format(baseDateTime);
    }

    return {'base_date': baseDate, 'base_time': baseTime};
  }

  Future<List<WeatherData>?> fetchWeather(int nx, int ny) async {
    if (SERVICE_KEY.contains('YOUR_API_SERVICE_KEY_HERE')) {
      print('날씨 API 키를 설정해주세요!');
      return null;
    }

    final timeInfo = getBaseTime();

    final authority = 'apis.data.go.kr';
    final path = API_URL;

    final queryParameters = {
      'serviceKey': SERVICE_KEY,
      'dataType': 'JSON',
      'base_date': timeInfo['base_date']!,
      'base_time': timeInfo['base_time']!,
      'nx': nx.toString(),
      'ny': ny.toString(),
      'numOfRows': '60',
      'pageNo': '1',
    };

    final uri = Uri.http(authority, path, queryParameters);

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        final header = jsonResponse['response']['header'];
        final resultCode = header['resultCode'];

        if (resultCode != '00') {
          print('날씨 API 오류 응답: $resultCode - ${header['resultMsg']}');
          return null;
        }

        final items = jsonResponse['response']['body']?['items']?['item'] as List<dynamic>?;

        if (items == null || items.isEmpty) {
          print('날씨 API 응답 항목 없음.');
          return null;
        }

        // 예보 시간 매칭 로직
        final nowHour = DateFormat('HH').format(DateTime.now());
        final nowTimeFcst = '${nowHour}00';
        final nowTimeInt = int.parse(nowTimeFcst);

        items.sort((a, b) => (a['fcstTime'] as String).compareTo(b['fcstTime'] as String));

        String? targetFcstTime;
        for (var item in items) {
          final fcstTimeInt = int.tryParse(item['fcstTime']?.toString() ?? '9999') ?? 9999;
          if (fcstTimeInt >= nowTimeInt) {
            targetFcstTime = item['fcstTime'];
            break;
          }
        }

        if (targetFcstTime == null) {
          targetFcstTime = items.last['fcstTime'];
        }

        final targetItems = items.where((item) => item['fcstTime'] == targetFcstTime).toList();

        int? temperature;
        String? skyStatus;
        String? ptyStatus;
        String? windSpeed;

        for (var item in targetItems) {
          switch (item['category']) {
            case 'TMP':
              temperature = int.tryParse(item['fcstValue']?.toString() ?? '0') ?? 0;
              break;
            case 'SKY':
              skyStatus = _convertSkyCode(item['fcstValue']?.toString() ?? '1');
              break;
            case 'PTY':
              ptyStatus = _convertPtyCode(item['fcstValue']?.toString() ?? '0');
              break;
            case 'WSD':
              windSpeed = item['fcstValue']?.toString() ?? '0';
              break;
          }
        }

        if (temperature != null) {
          return [WeatherData(
            temperature: temperature,
            skyStatus: skyStatus ?? '맑음',
            ptyStatus: ptyStatus ?? '없음',
            windSpeed: windSpeed ?? '0',
          )];
        }
      }
      print('날씨 API 호출 실패 (Status: ${response.statusCode})');
      return null;
    } catch (e) {
      print('날씨 API 통신 오류: $e');
      // 타임아웃 발생 시 인터넷 연결 확인 메시지를 로그에 남깁니다.
      if (e.toString().contains('TimeoutException')) {
        print('💡 팁: 에뮬레이터 인터넷 연결을 확인하거나 "Cold Boot"를 시도해보세요.');
      }
      return null;
    }
  }

  String _convertSkyCode(String code) {
    switch (code) {
      case '1': return '맑음';
      case '3': return '구름 많음';
      case '4': return '흐림';
      default: return '알 수 없음';
    }
  }

  String _convertPtyCode(String code) {
    switch (code) {
      case '0': return '없음';
      case '1': return '비';
      case '2': return '비 또는 눈';
      case '3': return '눈';
      case '4': return '소나기';
      default: return '없음';
    }
  }
}