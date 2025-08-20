import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

import '../data/hardcoded_regions.dart';
import '../models/park.dart';

class WalkTab extends StatefulWidget {
  const WalkTab({super.key});

  @override
  State<WalkTab> createState() => _WalkTabState();
}

class _WalkTabState extends State<WalkTab> {
  // ... (상단 상태 변수 및 initState, _loadParkData, _filterParks 로직은 이전과 동일)
  List<String> _sidoList = [];
  Map<String, Map<String, List<String>>> _regionHierarchy = {};
  String? _selectedSido;
  String? _selectedSigungu;
  String? _selectedDong;
  List<String> _sigunguList = [];
  List<String> _dongList = [];
  List<Park> _allParks = [];
  List<Park> _filteredParks = [];
  bool _isLoading = true;
  String _message = '공원 데이터를 불러오는 중입니다...';

  @override
  void initState() {
    super.initState();
    _sidoList = hardcodedSidoList;
    _regionHierarchy = hardcodedRegionHierarchy;
    _loadParkData();
  }

  Future<void> _loadParkData() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/json/allparkdata.json');
      final Map<String, dynamic> data = jsonDecode(jsonString);
      final List<dynamic> itemsList = data['records'];

      _allParks = itemsList.map((json) => Park.fromJson(json)).toList();
      _filteredParks = [];

      setState(() {
        _isLoading = false;
        _message = '지역을 선택하고 검색 버튼을 눌러주세요.';
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = '공원 데이터를 불러오는 데 실패했습니다.';
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

    Future.delayed(const Duration(milliseconds: 100), () {
      List<Park> results = _allParks.where((park) {
        final fullAddress = (park.lnmadr ?? '') + (park.rdnmadr ?? '');
        final searchSigungu = '$_selectedSido $_selectedSigungu';

        if (!fullAddress.contains(searchSigungu)) {
          return false;
        }
        if (_selectedDong != null) {
          return fullAddress.contains(_selectedDong!);
        }
        return true;
      }).toList();

      setState(() {
        _filteredParks = results;
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
          _buildRegionSelectors(),
          const SizedBox(height: 16),
          _buildSearchButton(),
          const SizedBox(height: 24),
          Expanded(child: _buildResultsView()),
        ],
      ),
    );
  }

  // ... (Dropdown 관련 위젯은 이전과 동일)
  Widget _buildRegionSelectors() {
    return Column(
      children: [
        Row(children: [
          Expanded(child: _buildDropdown(
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
          )),
          const SizedBox(width: 16),
          Expanded(child: _buildDropdown(
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
          )),
        ]),
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
      onPressed: (_selectedSido != null && _selectedSigungu != null)
          ? _filterParks
          : null,
      label: const Text('산책로 검색', style: TextStyle(fontSize: 16, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 2,
      ),
    );
  }

  // ▼▼▼ 여기가 UI 표시를 담당하는 핵심 수정 부분입니다 ▼▼▼
  Widget _buildResultsView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.green));
    }
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

        // 1. 공원 이름 뒤에 '공원' 붙이기
        String displayName = park.parkNm ?? '이름 없음';
        if (!displayName.endsWith('공원')) {
          displayName += '공원';
        }

        // 2. 표시할 주소 선택 (도로명 > 지번)
        String displayAddress = (park.rdnmadr != null && park.rdnmadr!.isNotEmpty)
            ? park.rdnmadr!
            : park.lnmadr ?? '주소 정보 없음';

        // 3. 시설 정보가 있을 때만 위젯 리스트에 추가
        List<Widget> facilityWidgets = [];
        _addFacilityInfo(facilityWidgets, '운동시설', park.mvmFclty);
        _addFacilityInfo(facilityWidgets, '유희시설', park.amsmtFclty);
        _addFacilityInfo(facilityWidgets, '편익시설', park.cnvnncFclty);
        _addFacilityInfo(facilityWidgets, '교양시설', park.cltrFclty);
        _addFacilityInfo(facilityWidgets, '기타시설', park.etcFclty);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                // 4. 위치 정보 표시 (면적 대신)
                _buildInfoRow(Icons.location_on_outlined, '위치', displayAddress),
                // 5. 시설 정보 목록 표시
                ...facilityWidgets,
              ],
            ),
          ),
        );
      },
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
        Text('$label: ', style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold)),
        Expanded(child: Text(text, style: TextStyle(color: Colors.grey[700]))),
      ],
    );
  }
}