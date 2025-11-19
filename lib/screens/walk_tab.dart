// lib/walk_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:math';

import '../data/hardcoded_regions.dart';
import '../models/park.dart';
import '../models/weather_data.dart';
import '../api/weather_api.dart';

class WalkTab extends StatefulWidget {
   const WalkTab({super.key});

   @override
   State<WalkTab> createState() => _WalkTabState();
}

class _WalkTabState extends State<WalkTab> {
   List<String> _sidoList = [];
   Map<String, Map<String, List<String>>> _regionHierarchy = {};
   String? _selectedSido;
   String? _selectedSigungu;
   String? _selectedDong;
   List<String> _sigunguList = [];
   List<String> _dongList = [];

   List<Park> _allParks = [];
   List<Park> _filteredParks = [];
   List<dynamic> _gridData = [];

   WeatherData? _weatherData;
   final WeatherApi _weatherApi = WeatherApi();

   bool _isLoading = true;
   String _message = '공원 데이터를 불러오는 중입니다...';

   @override
   void initState() {
    super.initState();
    _sidoList = hardcodedSidoList;
    _regionHierarchy = hardcodedRegionHierarchy;
    _loadAllData();
   }

   Future<void> _loadAllData() async {
    try {
     final String parkJsonString = await rootBundle.loadString('assets/json/optimized_park_data.json');
     final Map<String, dynamic> parkData = jsonDecode(parkJsonString);
     final List<dynamic> parkItemsList = parkData['records'];
     _allParks = parkItemsList.map((json) => Park.fromJson(json)).toList();

  final String gridJsonString = await rootBundle.loadString('assets/json/korea_with_grid.json');
  _gridData = jsonDecode(gridJsonString);

     _filteredParks = [];

     setState(() {
      _isLoading = false;
      _message = '지역을 선택하고 검색 버튼을 눌러주세요.';
     });

    } catch (e) {
     setState(() {
      _isLoading = false;
      _message = '데이터 로드 실패. assets 폴더를 확인해주세요.';
      print('JSON 로딩 오류: $e');
     });
    }
   }

   void _filterParks() {
    if (_selectedSido == null || _selectedSigungu == null) {
     setState(() {
      _message = '시/도와 시/군/구를 모두 선택해주세요.';
     });
     return;
    }

    setState(() => _isLoading = true);

  // 1. 날씨 좌표 찾기
  final selectedRegionName = _selectedDong != null && _selectedDong!.isNotEmpty
  ? '$_selectedSido $_selectedSigungu $_selectedDong'
      : '$_selectedSido $_selectedSigungu';

  final regionGrid = _gridData.firstWhere(
  (item) => item['bjd_nm'] == selectedRegionName,
  orElse: () => null,
  );

  int? nx, ny;
  if (regionGrid != null) {
  nx = regionGrid['nx'] as int?;
  ny = regionGrid['ny'] as int?;
  }

  // 2. 날씨 API 호출 (실패해도 공원은 보여줘야 하므로 별도 처리)
  Future<List<WeatherData>?> weatherFuture = Future.value(null);
  if (nx != null && ny != null) {
  weatherFuture = _weatherApi.fetchWeather(nx, ny);
  }

  // 3. 공원 필터링
  Future<List<Park>> parkFilteringFuture = Future(() {
  final String normalizedSearchSigungu = '$_selectedSido$_selectedSigungu'.replaceAll(' ', '');

  return _allParks.where((park) {
  final fullAddress = (park.lnmadr ?? '') + (park.rdnmadr ?? '');
  final normalizedFullAddress = fullAddress.replaceAll(' ', '');

  if (!normalizedFullAddress.contains(normalizedSearchSigungu)) return false;

  if (_selectedDong != null && _selectedDong!.isNotEmpty) {
  final normalizedDong = _selectedDong!.replaceAll(' ', '');
  return normalizedFullAddress.contains(normalizedDong);
  }
  return true;
  }).toList();
  });

  Future.wait([parkFilteringFuture, weatherFuture]).then((results) {
  final List<Park> parkResults = results[0] as List<Park>;
  final List<WeatherData>? fetchedWeatherList = results[1] as List<WeatherData>?;

  setState(() {
  _filteredParks = parkResults;
  _weatherData = fetchedWeatherList?.isNotEmpty == true ? fetchedWeatherList!.first : null;

  if (_filteredParks.isEmpty) {
  _message = '해당 지역에 공원 정보가 없습니다.';
  }
  _isLoading = false;
  });
  });
   }

   @override
   Widget build(BuildContext context) {
    return Padding(
     padding: const EdgeInsets.all(16.0),
     child: Column(
      children: [
  if (_weatherData != null) _buildWeatherCard(),
  if (_weatherData != null) const SizedBox(height: 16),
       _buildRegionSelectors(),
       const SizedBox(height: 16),
       _buildSearchButton(),
       const SizedBox(height: 24),
       Expanded(child: _buildResultsView()),
      ],
     ),
    );
   }

   Widget _buildRegionSelectors() {
    return Column(
     children: [
      Row(
       children: [
        Expanded(
         child: _buildDropdown(
          hint: '시/도 선택',
          value: _selectedSido,
          items: _sidoList,
          onChanged: (value) {
           setState(() {
            _selectedSido = value;
            _sigunguList = _regionHierarchy[value]?.keys.toList() ?? [];
            _selectedSigungu = null;
            _dongList = [];
            _selectedDong = null;
  _weatherData = null;
           });
          },
         ),
        ),
        const SizedBox(width: 16),
        Expanded(
         child: _buildDropdown(
          hint: '시/군/구 선택',
          value: _selectedSigungu,
          items: _sigunguList,
          onChanged: (value) {
           setState(() {
            _selectedSigungu = value;
            _dongList = _regionHierarchy[_selectedSido]?[value] ?? [];
            _selectedDong = null;
  _weatherData = null;
           });
          },
         ),
        ),
       ],
      ),
      const SizedBox(height: 10),
      _buildDropdown(
       hint: '읍/면/동 선택 (선택)',
       value: _selectedDong,
       items: _dongList,
       onChanged: (value) => setState(() {
  _selectedDong = value;
  _weatherData = null;
  }),
      ),
     ],
    );
   }

   Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
   }) {
  return Container(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  decoration: BoxDecoration(
  color: Colors.grey[100],
  borderRadius: BorderRadius.circular(30),
  border: Border.all(color: Colors.grey[300]!, width: 1.5),
  ),
  child: DropdownButtonHideUnderline(
  child: DropdownButton<String>(
  isExpanded: true,
  hint: Text(hint),
  value: value,
  icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.green),
  items: items
      .map((item) => DropdownMenuItem<String>(
  value: item,
  child: Text(item, style: const TextStyle(fontSize: 14)),
  ))
      .toList(),
  onChanged: onChanged,
  ),
  ),
  );
  }

  Widget _buildSearchButton() {
  return ElevatedButton.icon(
  icon: const Icon(Icons.search, color: Colors.white),
  onPressed: (_selectedSido != null && _selectedSigungu != null) ? _filterParks : null,
  label: const Text('산책로 검색', style: TextStyle(fontSize: 16, color: Colors.white)),
  style: ElevatedButton.styleFrom(
  backgroundColor: Colors.green,
  minimumSize: const Size(double.infinity, 52),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
  elevation: 2,
  ),
  );
  }

  Widget _buildWeatherCard() {
  if (_weatherData == null) return const SizedBox.shrink();

  IconData weatherIcon;
  String statusText;

  if (_weatherData!.ptyStatus != '없음') {
  weatherIcon = _weatherData!.ptyStatus.contains('눈') ? Icons.ac_unit : Icons.umbrella;
  statusText = _weatherData!.ptyStatus;
  } else if (_weatherData!.skyStatus == '맑음') {
  weatherIcon = Icons.wb_sunny;
  statusText = '맑음';
  } else if (_weatherData!.skyStatus == '구름 많음') {
  weatherIcon = Icons.cloud;
  statusText = '구름 많음';
  } else {
  weatherIcon = Icons.filter_drama;
  statusText = '흐림';
  }

  return Container(
  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
  decoration: BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: Colors.green[100]!, width: 1),
  boxShadow: [
  BoxShadow(
  color: Colors.green.withOpacity(0.1),
  spreadRadius: 1,
  blurRadius: 5,
  offset: const Offset(0, 3),
  ),
  ],
  ),
  child: Row(
  children: [
  Icon(weatherIcon, color: Colors.green[700], size: 40),
  const SizedBox(width: 12),
  Expanded(
  child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
  Text(
  '현재 날씨 (단기예보) - ${_selectedSigungu ?? _selectedSido}',
  style: TextStyle(fontSize: 12, color: Colors.green[700], fontWeight: FontWeight.bold),
  ),
  Text(
  '${_weatherData!.temperature}°C | $statusText',
  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
  ),
  ],
  ),
  ),
  Text(
  '풍속: ${_weatherData!.windSpeed} m/s',
  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
  ),
  ],
  ),
  );
  }

   Widget _buildResultsView() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.green));
    if (_filteredParks.isEmpty) {
     return Center(
      child: Column(
       mainAxisAlignment: MainAxisAlignment.center,
       children: [
        Icon(Icons.info_outline, color: Colors.grey[400], size: 48),
        const SizedBox(height: 16),
        Text(_message, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
       ],
      ),
     );
    }

    return ListView.builder(
      itemCount: _filteredParks.length,
      itemBuilder: (context, index) {
       final park = _filteredParks[index];

       // 1. 공원 이름 및 주소
       String displayName = park.parkNm ?? '이름 없음';
       if (!displayName.endsWith('공원')) displayName += '공원';
       String displayAddress = (park.rdnmadr?.isNotEmpty == true) ? park.rdnmadr! : (park.lnmadr ?? '주소 정보 없음');

       // 2. 공원 자체 시설 정보
       List<Widget> facilityWidgets = [];
       _addFacilityInfo(facilityWidgets, '운동시설', park.mvmFclty);
       _addFacilityInfo(facilityWidgets, '유희시설', park.amsmtFclty);
       _addFacilityInfo(facilityWidgets, '편익시설', park.cnvnncFclty);
       _addFacilityInfo(facilityWidgets, '교양시설', park.cltrFclty);
       _addFacilityInfo(facilityWidgets, '기타시설', park.etcFclty);

       // 3. 가까운 체육시설 및 대중교통 정보 추가 (Park 모델의 필드값 사용)
       if (park.nearestFacilityNm != null && park.nearestFacilityNm!.isNotEmpty) {
        facilityWidgets.add(const SizedBox(height: 8));
        facilityWidgets.add(Text('🎯 근접 시설 정보', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey[700])));
        facilityWidgets.add(const SizedBox(height: 8));
        facilityWidgets.add(_buildInfoRow(Icons.sports_soccer, '체육시설', park.nearestFacilityNm!));

        if (park.nearestStopNm != null && park.nearestStopNm!.isNotEmpty) {
  num min = park.walkingTimeMin ?? 0;
  if(min == 0) min = 1; // 0분일 경우 1분
         facilityWidgets.add(const SizedBox(height: 8));
         facilityWidgets.add(_buildInfoRow(Icons.bus_alert, '가까운 정류장', park.nearestStopNm!));
         facilityWidgets.add(const SizedBox(height: 8));
         facilityWidgets.add(_buildInfoRow(Icons.directions_walk, '도보 정보', '약 ${min}분 (거리: ${(park.walkingDistKm ?? 0).toStringAsFixed(2)}km)'));
        } else {
         facilityWidgets.add(const SizedBox(height: 8));
         facilityWidgets.add(_buildInfoRow(Icons.warning_amber, '대중교통', '가까운 대중교통 시설 또는 도보 경로 정보 없음'));
        }
       }

       return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(16),
         boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), spreadRadius: 1, blurRadius: 5, offset: const Offset(0, 3))],
         border: Border.all(color: Colors.grey.withOpacity(0.5), width: 0.8),
        ),
        child: Card(
         elevation: 0,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide.none),
         margin: EdgeInsets.zero,
         child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
            Row(children: [
             const Icon(Icons.park, color: Colors.green, size: 28),
             const SizedBox(width: 12),
             Expanded(child: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            ]),
            const Divider(height: 24),
            _buildInfoRow(Icons.location_on_outlined, '위치', displayAddress),
            ...facilityWidgets,
           ],
          ),
         ),
        ),
       );
      }
    );
   }

   void _addFacilityInfo(List<Widget> widgets, String label, String? data) {
    if (data != null && data.isNotEmpty) {
     widgets.add(const SizedBox(height: 8));
     widgets.add(_buildInfoRow(Icons.check_circle_outline, label, data));
    }
   }

   Widget _buildInfoRow(IconData icon, String label, String text) {
    return Row(
     crossAxisAlignment: CrossAxisAlignment.start,
     children: [
      Icon(icon, color: Colors.grey[600], size: 18),
      const SizedBox(width: 8),
      Text('$label: ', style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold)),
      Expanded(child: Text(text, style: TextStyle(color: Colors.grey[700]))),
     ],
    );
   }
}