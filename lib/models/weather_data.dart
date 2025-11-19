// lib/models/weather_data.dart

class WeatherData {
   final int temperature; // 기온 (TMP)
   final String skyStatus; // 하늘 상태 (SKY) - 맑음/구름많음/흐림
   final String ptyStatus; // 강수 형태 (PTY) - 없음/비/눈/소나기
   final String windSpeed; // 풍속 (WSD)

   WeatherData({
    required this.temperature,
    required this.skyStatus,
    required this.ptyStatus,
    required this.windSpeed,
   });
}