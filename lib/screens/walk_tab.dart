import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:math';

import '../data/hardcoded_regions.dart'; // 지역 데이터 경로
import '../models/park.dart'; // Park 모델 경로

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

  // 최적화된 공원 데이터만 로드합니다.
  List<Park> _allParks = [];
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

  // --- 1. 데이터 로드 및 파싱 (최적화) ---
  Future<void> _loadAllData() async {
    try {
      // 최적화된 파일 경로 사용: optimized_park_data.json
      final String parkJsonString = await rootBundle.loadString('assets/json/optimized_park_data.json');
      final Map<String, dynamic> parkData = jsonDecode(parkJsonString);
      final List<dynamic> parkItemsList = parkData['records'];

      // O(N*M) 계산을 위한 allFacilities 로직은 완전히 제거되었습니다.

      _allParks = parkItemsList.map((json) => Park.fromJson(json)).toList();
      _filteredParks = [];

      setState(() {
        _isLoading = false;
        _message = '지역을 선택하고 검색 버튼을 눌러주세요.';
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = '데이터 로드 실패. 파일명(optimized_park_data.json)과 경로를 확인해주세요.';
        print('JSON 로딩 오류: $e');
      });
    }
  }

  // --- 2. 거리 계산 헬퍼 함수 (더 이상 사용되지 않으므로 제거) ---
  // 이 함수는 O(N*M) 계산 로직 제거와 함께 삭제되었습니다.


  // --- 3. 공원 및 근접 시설 필터링 로직 (O(N*M) 계산 제거) ---
  void _filterParks() {
    if (_selectedSido == null || _selectedSigungu == null) {
      setState(() {
        _message = '시/도와 시/군/구를 모두 선택해주세요.';
      });
      return;
    }

    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 100), () {
      // 1. 공원 지역 필터링 (주소 공백 제거 로직 유지)
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

      // 2. O(N*M) 계산 로직 제거: 공원 객체는 이미 전처리된 정보를 가지고 있습니다.

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

  // --- 5. 검색 결과 UI (전처리된 데이터 사용) ---
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

          // 전처리된 데이터에서 바로 정보를 가져옵니다.
          final nearestFacilityNm = park.nearestFacilityNm;
          final nearestStopNm = park.nearestStopNm;
          final walkingTimeMin = park.walkingTimeMin; // 이미 분 단위
          final walkingDistKm = park.walkingDistKm; // 이미 KM 단위

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

          // 3. 가까운 체육시설 및 대중교통 정보 추가 (전처리된 필드 사용)
          if (nearestFacilityNm != null) {

            // 도보 정보가 유효한지 확인 (널이 아니거나 0보다 크거나 같음)
            final hasWalkingInfo = walkingTimeMin != null && walkingDistKm != null;

            // 근접 시설 정보 제목 (요청하신 대로 여백 조정)
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

            // 제목과 체육시설 사이 여백 추가
            facilityWidgets.add(const SizedBox(height: 8));

            // 가까운 체육시설 이름
            facilityWidgets.add(
              _buildInfoRow(
                Icons.sports_soccer,
                '체육시설',
                nearestFacilityNm,
              ),
            );

            // 대중교통 시설 및 도보 이동 시간
            if (hasWalkingInfo) {
              // 시간과 거리는 이미 전처리 과정에서 분(Min)과 KM로 계산되었습니다.

              facilityWidgets.add(const SizedBox(height: 8));
              facilityWidgets.add(
                _buildInfoRow(
                  Icons.bus_alert,
                  '가까운 정류장',
                  nearestStopNm ?? '정보 없음',
                ),
              );
              facilityWidgets.add(const SizedBox(height: 8));
              facilityWidgets.add(
                _buildInfoRow(
                  Icons.directions_walk,
                  '도보 정보',
                  '약 ${walkingTimeMin}분 (거리: ${walkingDistKm}km)',
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

          // --- UI 스타일 (Container와 Card를 사용한 4면 그림자/선) ---
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(
                color: Colors.grey.withOpacity(0.5),
                width: 0.8,
              ),
            ),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide.none,
              ),
              margin: EdgeInsets.zero,
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