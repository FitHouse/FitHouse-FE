import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

// GPS 및 주소 변환을 위한 패키지
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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
      // 1. 공원 데이터 로드
      final String parkJsonString = await rootBundle.loadString('assets/json/optimized_park_data.json');
      final Map<String, dynamic> parkData = jsonDecode(parkJsonString);
      final List<dynamic> parkItemsList = parkData['records'];
      _allParks = parkItemsList.map((json) => Park.fromJson(json)).toList();

      // 2. 날씨 격자 데이터 로드
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

  // 🔍 기존 검색 로직 (날씨 API + 공원 필터링)
  void _filterParks() {
    if (_selectedSido == null || _selectedSigungu == null) {
      setState(() {
        _message = '시/도와 시/군/구를 모두 선택해주세요.';
        // 로딩 상태 해제 (중요)
        _isLoading = false;
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

    // 2. 날씨 API 호출
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

// 📍 [최종 수정] 내 위치(GPS)를 받아서 드롭다운을 자동 설정하는 함수
  Future<void> _searchByCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _message = 'GPS 정보를 확인 중입니다...';
    });

    // 1. 권한 및 서비스 확인
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _isLoading = false;
        _message = 'GPS 기능을 켜주세요.';
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _isLoading = false;
          _message = '위치 권한이 필요합니다.';
        });
        return;
      }
    }

    try {
      // 2. 현재 좌표 가져오기
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() => _message = '주소를 변환 중입니다...');

      // 3. 좌표 -> 주소 변환
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;

        // 🔥 [디버깅] GPS가 주는 모든 정보를 다 찍어봅니다.
        print("📦 GPS 원본 데이터(Placemark): $place");

        // 1. 시/도 찾기
        // administrativeArea가 비어있으면 전체 주소에서 시도 이름을 찾습니다.
        String fullAddress = place.toString(); // 전체 주소 텍스트
        String? matchedSido;

        try {
          matchedSido = _sidoList.firstWhere(
                (sido) =>
            (place.administrativeArea ?? '').contains(sido) ||
                sido.contains(place.administrativeArea ?? '') ||
                fullAddress.contains(sido), // 전체 텍스트에서도 검색
          );
        } catch (e) { /* 매칭 실패 */ }

        if (matchedSido != null) {
          // 2. 시/군/구 찾기 (강력한 탐색!)
          // GPS 변수(locality 등)를 믿지 않고, 우리 리스트에 있는 '구' 이름이 GPS 정보 어디라도 포함되어 있는지 확인합니다.
          List<String> validSigunguList = _regionHierarchy[matchedSido]?.keys.toList() ?? [];
          String? matchedSigungu;

          try {
            matchedSigungu = validSigunguList.firstWhere((validSigungu) {
              // GPS 정보의 구석구석을 다 뒤져서 '강서구' 같은 단어가 있는지 확인
              return (place.locality ?? '').contains(validSigungu) ||
                  (place.subLocality ?? '').contains(validSigungu) ||
                  (place.subAdministrativeArea ?? '').contains(validSigungu) ||
                  fullAddress.contains(validSigungu);
            });
          } catch (e) {}

          // 3. 읍/면/동 찾기 (강력한 탐색!)
          List<String> newDongList = [];
          String? matchedDong;

          if (matchedSigungu != null) {
            newDongList = _regionHierarchy[matchedSido]?[matchedSigungu] ?? [];
            try {
              matchedDong = newDongList.firstWhere((validDong) {
                return (place.thoroughfare ?? '').contains(validDong) ||
                    (place.subLocality ?? '').contains(validDong) ||
                    fullAddress.contains(validDong);
              });
            } catch (e) {}
          } else {
            // 구를 못 찾았는데 동 정보는 있는 경우 역추적 (마지막 보루)
            String gpsDong = place.thoroughfare ?? place.subLocality ?? '';
            if (gpsDong.isNotEmpty) {
              try {
                matchedSigungu = validSigunguList.firstWhere((sigunguKey) {
                  List<String> dongsInGu = _regionHierarchy[matchedSido]?[sigunguKey] ?? [];
                  return dongsInGu.any((validDong) => gpsDong.contains(validDong));
                });
                if (matchedSigungu != null) {
                  newDongList = _regionHierarchy[matchedSido]?[matchedSigungu] ?? [];
                  // 구를 찾았으니 동도 다시 매칭 시도
                  try {
                    matchedDong = newDongList.firstWhere((d) => gpsDong.contains(d));
                  } catch (e) {}
                }
              } catch (e) {}
            }
          }

          // 4. 상태 업데이트 및 검색
          setState(() {
            _selectedSido = matchedSido;
            _sigunguList = validSigunguList;

            _selectedSigungu = matchedSigungu;
            _dongList = newDongList;

            _selectedDong = matchedDong;

            if (matchedSigungu == null) {
              _message = '상세 지역(구/군)을 자동으로 찾지 못했습니다. 직접 선택해주세요.';
            } else {
              _message = '위치 설정 완료! 검색을 시작합니다.';
            }
          });

          // 구 정보가 있으면 검색 실행, 없으면 사용자 선택 유도
          if (matchedSigungu != null) {
            _filterParks();
          } else {
            // 구를 못 찾았으면 로딩 끄기
            setState(() => _isLoading = false);
          }

        } else {
          setState(() {
            _isLoading = false;
            _message = '현재 위치의 시/도 정보를 찾을 수 없습니다.';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _message = '주소 정보를 받아올 수 없습니다.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = '위치 정보를 가져오는 중 오류가 발생했습니다.';
      });
      print('GPS Error: $e');
    }
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
          const SizedBox(height: 12),
          _buildGpsButton(), // 내 위치 검색 버튼
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
          items: items.map((item) => DropdownMenuItem<String>(
            value: item,
            child: Text(item, style: const TextStyle(fontSize: 14)),
          )).toList(),
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

  Widget _buildGpsButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.my_location, color: Colors.green),
      onPressed: _isLoading ? null : _searchByCurrentLocation,
      label: const Text('내 위치로 검색', style: TextStyle(fontSize: 16, color: Colors.green)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        side: const BorderSide(color: Colors.green, width: 1.5),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 0,
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

        String displayName = park.parkNm ?? '이름 없음';
        if (!displayName.endsWith('공원')) displayName += '공원';
        String displayAddress = (park.rdnmadr?.isNotEmpty == true) ? park.rdnmadr! : (park.lnmadr ?? '주소 정보 없음');

        List<Widget> facilityWidgets = [];
        _addFacilityInfo(facilityWidgets, '운동시설', park.mvmFclty);
        _addFacilityInfo(facilityWidgets, '유희시설', park.amsmtFclty);
        _addFacilityInfo(facilityWidgets, '편익시설', park.cnvnncFclty);
        _addFacilityInfo(facilityWidgets, '교양시설', park.cltrFclty);
        _addFacilityInfo(facilityWidgets, '기타시설', park.etcFclty);

        // 근접 시설 정보 표시
        if (park.nearestFacilityNm != null && park.nearestFacilityNm!.isNotEmpty) {
          facilityWidgets.add(const SizedBox(height: 8));
          facilityWidgets.add(Text('🎯 근접 시설 정보', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey[700])));
          facilityWidgets.add(const SizedBox(height: 8));

          facilityWidgets.add(_buildInfoRow(Icons.sports_soccer, '체육시설', park.nearestFacilityNm!));

          if (park.nearestStopNm != null && park.nearestStopNm!.isNotEmpty) {
            num min = park.walkingTimeMin ?? 0;
            if(min == 0) min = 1;

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
      },
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