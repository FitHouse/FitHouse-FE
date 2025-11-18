import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:math';

import '../data/hardcoded_regions.dart'; // 지역 데이터 경로
import '../models/park.dart'; // Park 모델 경로
import '../models/sports_facility.dart'; // SportsFacility 모델 경로


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
   List<SportsFacility> _allFacilities = [];
   List<Park> _filteredParks = [];

   bool _isLoading = true;
   String _message = '공원 데이터를 불러오는 중입니다...';

   @override
   void initState() {
    super.initState();
    _sidoList = hardcodedSidoList;
    _regionHierarchy = hardcodedRegionHierarchy;
    _loadAllData();
   }

  // --- 1. 데이터 로드 및 파싱 ---
   Future<void> _loadAllData() async {
    try {
     // 1. 공원 데이터 로드 (allparkdata.json)
     final String parkJsonString = await rootBundle.loadString('assets/json/allparkdata.json');
     final Map<String, dynamic> parkData = jsonDecode(parkJsonString);
     final List<dynamic> parkItemsList = parkData['records'];

     // 2. 체육시설 데이터 로드 (allfacilitydata.json)
     final String facilityJsonString = await rootBundle.loadString('assets/json/allfacilitydata.json');
     final List<dynamic> facilityItemsList = jsonDecode(facilityJsonString);

     _allParks = parkItemsList.map((json) => Park.fromJson(json)).toList();
     _allFacilities = facilityItemsList.map((json) => SportsFacility.fromJson(json)).toList();

     _filteredParks = [];

     setState(() {
      _isLoading = false;
      _message = '지역을 선택하고 검색 버튼을 눌러주세요.';
     });

    } catch (e) {
     setState(() {
      _isLoading = false;
      _message = '데이터를 불러오는 데 실패했습니다. 파일을 확인해주세요.';
      print('JSON 로딩 오류: $e');
     });
    }
   }

  // --- 2. 거리 계산 헬퍼 함수 ---
   double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // 지구 반지름 (km)
    final dLat = (lat2 - lat1) * (pi / 180);
    final dLon = (lon2 - lon1) * (pi / 180);
    final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * (pi / 180)) * cos(lat2 * (pi / 180)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c; // 결과는 킬로미터(km)
   }


  // --- 3. 공원 및 근접 시설 필터링 로직 (공백 제거 적용) ---
   void _filterParks() {
    if (_selectedSido == null || _selectedSigungu == null) {
     setState(() {
      _message = '시/도와 시/군/구를 모두 선택해주세요.';
     });
     return;
    }

    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 100), () {
     // 1. 공원 지역 필터링 (주소 공백 제거하여 정확도 개선)
     final String normalizedSearchSigungu =
  '$_selectedSido$_selectedSigungu'.replaceAll(' ', '');

     List<Park> results = _allParks.where((park) {
      final fullAddress = (park.lnmadr ?? '') + (park.rdnmadr ?? '');
      final normalizedFullAddress = fullAddress.replaceAll(' ', '');

      // 공백 제거된 주소로 시/군/구 포함 여부 확인
      if (!normalizedFullAddress.contains(normalizedSearchSigungu)) {
       return false;
      }

      // 읍/면/동 필터링
      if (_selectedDong != null && _selectedDong!.isNotEmpty) {
       final normalizedDong = _selectedDong!.replaceAll(' ', '');
       return normalizedFullAddress.contains(normalizedDong);
      }
      return true;
     }).toList();

     // 2. 필터링된 공원별로 가장 가까운 체육시설 찾기 및 대중교통 정보 연결 (안정성 보강)
     for (var park in results) {
      SportsFacility? nearestFacilityBase;
      double minDistanceKm = double.infinity;

  // 공원 좌표를 안전하게 파싱 (실패 시 0.0)
      final parkLat = double.tryParse(park.latitude ?? '0.0') ?? 0.0;
      final parkLon = double.tryParse(park.longitude ?? '0.0') ?? 0.0;

      if (parkLat != 0.0 && parkLon != 0.0) {
       // A. 공원에 지리적으로 가장 가까운 체육시설 찾기
       final localFacilities = _allFacilities.where(
        (f) => (f.facilityAddr ?? '').contains(_selectedSigungu!),
       );

       for (var facility in localFacilities) {
        final facilityLat = double.tryParse(facility.facilityLat ?? '0.0') ?? 0.0;
        final facilityLon = double.tryParse(facility.facilityLon ?? '0.0') ?? 0.0;

        if (facilityLat != 0.0 && facilityLon != 0.0) {
         final distance = _calculateDistance(
          parkLat, parkLon, facilityLat, facilityLon,
         );

         if (distance < minDistanceKm) {
          minDistanceKm = distance;
          nearestFacilityBase = facility;
         }
        }
       }
      }

      // B. 찾은 체육시설의 레코드들 중 가장 가까운 대중교통 정보 찾기
      if (nearestFacilityBase != null) {
       SportsFacility? bestTransitFacility;
       double minWalkingDist = double.infinity;

       // 같은 체육시설 이름을 가진 레코드 중에서, 도보 거리가 가장 짧은 레코드를 찾습니다.
       final relatedFacilities = _allFacilities.where(
        (f) => f.facilityNm == nearestFacilityBase!.facilityNm,
       );

       for (var related in relatedFacilities) {
        final walkingDist =
          double.tryParse(related.walkingDist ?? '0') ?? double.infinity;

        if (walkingDist < minWalkingDist) {
         minWalkingDist = walkingDist;
         bestTransitFacility = related;
        }
       }

       park.nearestFacility = bestTransitFacility;
      } else {
       park.nearestFacility = null;
      }
     }

     setState(() {
      _filteredParks = results;

      if (_filteredParks.isEmpty) {
       _message = '해당 지역에 공원 정보가 없습니다.';
      }

      _isLoading = false;
     });
    });
   }

  // --- 4. 빌드 및 UI 위젯 (기존 코드 유지) ---
   @override
   Widget build(BuildContext context) {
    return Padding(
     padding: const EdgeInsets.all(16.0),
     child: Column(
      children: [
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
       onChanged: (value) => setState(() => _selectedDong = value),
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
         .map(
          (item) => DropdownMenuItem<String>(
           value: item,
           child: Text(item, style: const TextStyle(fontSize: 14)),
          ),
         )
         .toList(),
       onChanged: onChanged,
      ),
     ),
    );
   }

   Widget _buildSearchButton() {
    return ElevatedButton.icon(
     icon: const Icon(Icons.search, color: Colors.white),
     onPressed: (_selectedSido != null && _selectedSigungu != null)
       ? _filterParks
       : null,
     label: const Text(
      '산책로 검색',
      style: TextStyle(fontSize: 16, color: Colors.white),
     ),
     style: ElevatedButton.styleFrom(
      backgroundColor: Colors.green,
      minimumSize: const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      elevation: 2,
     ),
    );
   }

  // --- 5. 검색 결과 UI (통합) ---
   Widget _buildResultsView() {
    if (_isLoading) {
     return const Center(
      child: CircularProgressIndicator(color: Colors.green),
     );
    }

    if (_filteredParks.isEmpty) {
     return Center(
      child: Column(
       mainAxisAlignment: MainAxisAlignment.center,
       children: [
        Icon(Icons.info_outline, color: Colors.grey[400], size: 48),
        const SizedBox(height: 16),
        Text(
         _message,
         style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
       ],
      ),
     );
    }

    return ListView.builder(
     itemCount: _filteredParks.length,
     itemBuilder: (context, index) {
       final park = _filteredParks[index];
       final nearestFacility = park.nearestFacility;

       // 1. 공원 이름 및 주소
       String displayName = park.parkNm ?? '이름 없음';
       if (!displayName.endsWith('공원')) {
         displayName += '공원';
       }
       String displayAddress =
       (park.rdnmadr != null && park.rdnmadr!.isNotEmpty)
           ? park.rdnmadr!
           : park.lnmadr ?? '주소 정보 없음';

       // 2. 공원 자체 시설 정보
       List<Widget> facilityWidgets = [];
       _addFacilityInfo(facilityWidgets, '운동시설', park.mvmFclty);
       _addFacilityInfo(facilityWidgets, '유희시설', park.amsmtFclty);
       _addFacilityInfo(facilityWidgets, '편익시설', park.cnvnncFclty);
       _addFacilityInfo(facilityWidgets, '교양시설', park.cltrFclty);
       _addFacilityInfo(facilityWidgets, '기타시설', park.etcFclty);

       // 3. 가까운 체육시설 및 대중교통 정보 추가
       if (nearestFacility != null) {
         final timeInSeconds =
             double.tryParse(nearestFacility.walkingTime ?? '0') ?? 0;
         final distanceInMeters =
             double.tryParse(nearestFacility.walkingDist ?? '0') ?? 0;

         // 도보 정보가 유효한지 확인 (시간 > 0, 거리 > 0, 정류장 이름 있음)
         final hasWalkingInfo =
             timeInSeconds > 0 &&
                 distanceInMeters > 0 &&
                 (nearestFacility.stopNm?.isNotEmpty ?? false);

         // 구분선
         facilityWidgets.add(const SizedBox(height: 8));
         facilityWidgets.add(
           Text(
             '🎯 근접 시설 정보',
             style: TextStyle(
               fontWeight: FontWeight.bold,
               fontSize: 16,
               color: Colors.blueGrey[700],
             ),
           ),
         );

         facilityWidgets.add(const SizedBox(height: 8));

         // 가까운 체육시설 이름
         facilityWidgets.add(
           _buildInfoRow(
             Icons.sports_soccer,
             '체육시설',
             nearestFacility.facilityNm ?? '정보 없음',
           ),
         );

         // 대중교통 시설 및 도보 이동 시간
         if (hasWalkingInfo) {
           // 초 -> 분 변환
           final timeInSeconds = double.tryParse(
               nearestFacility.walkingTime ?? '0') ?? 0;
           int timeInMinutes = (timeInSeconds / 60).round();

           // 수정된 부분: 0분일 경우 1분으로 설정
           if (timeInMinutes == 0) {
             timeInMinutes = 1;
           }
           final distanceInMeters = double.tryParse(
               nearestFacility.walkingDist ?? '0') ?? 0;

           facilityWidgets.add(const SizedBox(height: 8));
           facilityWidgets.add(
             _buildInfoRow(
               Icons.bus_alert,
               '가까운 정류장',
               nearestFacility.stopNm ?? '정보 없음',
             ),
           );
           facilityWidgets.add(const SizedBox(height: 8));
           facilityWidgets.add(
             _buildInfoRow(
               Icons.directions_walk,
               '도보 정보',
               '약 ${timeInMinutes}분 (거리: ${distanceInMeters}m)',
             ),
           );
         } else {
           facilityWidgets.add(const SizedBox(height: 8));
           facilityWidgets.add(
             _buildInfoRow(
               Icons.warning_amber,
               '대중교통',
               '가까운 대중교통 시설 또는 도보 경로 정보 없음',
             ),
           );
         }
       }

// lib/walk_tab.dart - _buildResultsView 함수 내부 (return Card 부분)

// return Card( ... ); 대신 아래와 같이 Container로 감쌉니다.
       return Container( // 👈 Container로 Card를 감싸서 테두리 효과를 줍니다.
         margin: const EdgeInsets.symmetric(vertical: 8),
         // Card의 margin은 Container로 옮깁니다.
         decoration: BoxDecoration(
           color: Colors.white, // Card의 배경색을 여기에 맞춰줄 수 있습니다.
           borderRadius: BorderRadius.circular(16),
           boxShadow: [
             BoxShadow(
               color: Colors.grey.withOpacity(0.3), // 그림자 색상 및 투명도
               spreadRadius: 1, // 그림자가 얼마나 퍼질지
               blurRadius: 5, // 그림자 블러 강도
               offset: const Offset(0, 3), // 그림자 위치 (x, y)
             ),
           ],
           border: Border.all(
             color: Colors.grey.withOpacity(0.5), // 얇은 테두리 색상
             width: 0.8, // 테두리 두께
           ),
         ),
         child: Card(
           // Card의 elevation과 shape는 그대로 유지하여 추가 그림자 효과를 줍니다.
           elevation: 0,
           // 👈 Card 자체의 elevation은 0으로 설정하여 Container의 boxShadow와 겹치지 않게 합니다.
           shape: RoundedRectangleBorder(
             borderRadius: BorderRadius.circular(16),
             side: BorderSide.none, // 👈 Card 자체의 테두리는 없앱니다.
           ),
           margin: EdgeInsets.zero,
           // 👈 Card의 margin은 0으로 설정합니다.
           child: Padding(
             padding: const EdgeInsets.all(16.0),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   children: [
                     const Icon(Icons.park, color: Colors.green, size: 28),
                     const SizedBox(width: 12),
                     Expanded(
                         child: Text(displayName,
                             style: const TextStyle(
                                 fontWeight: FontWeight.bold, fontSize: 18))),
                   ],
                 ),
                 const Divider(height: 24),
                 _buildInfoRow(
                     Icons.location_on_outlined, '위치', displayAddress),
                 ...facilityWidgets,
               ],
             ),
           ),
         ),
       );
     }
    );
   }

   // 시설 정보가 있을 때만 리스트에 추가하는 헬퍼 함수
   void _addFacilityInfo(List<Widget> widgets, String label, String? data) {
    if (data != null && data.isNotEmpty) {
     widgets.add(const SizedBox(height: 8));
     widgets.add(_buildInfoRow(Icons.check_circle_outline, label, data));
    }
   }

   // 아이콘, 라벨, 텍스트를 보여주는 공통 UI 위젯
   Widget _buildInfoRow(IconData icon, String label, String text) {
    return Row(
     crossAxisAlignment: CrossAxisAlignment.start,
     children: [
      Icon(icon, color: Colors.grey[600], size: 18),
      const SizedBox(width: 8),
      Text(
       '$label: ',
       style: TextStyle(
        color: Colors.grey[800],
        fontWeight: FontWeight.bold,
       ),
      ),
      Expanded(
       child: Text(text, style: TextStyle(color: Colors.grey[700])),
      ),
     ],
    );
   }
}