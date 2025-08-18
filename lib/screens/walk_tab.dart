import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../data/hardcoded_regions.dart';
import '../models/park.dart';

// ✅ 정의된 기본 URL
// const String kBaseUrl = 'http://10.0.2.2:8080'; // 안드로이드 에뮬레이터용
const String kBaseUrl = 'http://localhost:8080'; // 데스크탑

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

  List<Park> _parkList = [];
  bool _isParksLoading = false;
  String _message = '지역을 선택하고 검색 버튼을 눌러주세요.';

  @override
  void initState() {
    super.initState();
    _sidoList = hardcodedSidoList;
    _regionHierarchy = hardcodedRegionHierarchy;
  }

  Future<void> _fetchParks() async {
    if (_selectedSido == null || _selectedSigungu == null || _selectedDong == null) return;

    setState(() {
      _isParksLoading = true;
      _message = '공원 정보를 불러오는 중입니다...';
      _parkList = [];
    });

    final searchAddress = '$_selectedSido $_selectedSigungu $_selectedDong';

    try {
      // ✅ 수정된 부분: 하드코딩된 IP 대신 kBaseUrl 상수를 사용합니다.
      final url = Uri.parse('$kBaseUrl/api/parks?address=${Uri.encodeComponent(searchAddress)}');

      print('Requesting to: $url'); // 디버깅을 위해 호출되는 URL을 출력합니다.

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _parkList = data.map((json) => Park.fromJson(json)).toList();
          if (_parkList.isEmpty) _message = '해당 지역에 공원 정보가 없습니다.';
        });
      } else {
        setState(() => _message = '서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _message = '네트워크 오류. 서버 주소 또는 인터넷 연결을 확인해주세요.');
    } finally {
      setState(() => _isParksLoading = false);
    }
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
          hint: '읍/면/동 선택',
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
      onPressed: (_selectedSido != null && _selectedSigungu != null && _selectedDong != null)
          ? _fetchParks
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

  Widget _buildResultsView() {
    if (_isParksLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.green));
    }
    if (_parkList.isEmpty) {
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
      itemCount: _parkList.length,
      itemBuilder: (context, index) {
        final park = _parkList[index];
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
                  Expanded(child: Text(park.parkNm, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                ]),
                const Divider(height: 24),
                Text(park.rdnmadr.isNotEmpty ? park.rdnmadr : park.lnmadr, style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 8),
                Text('면적: ${park.parkAr}㎡', style: TextStyle(color: Colors.grey[600])),
                if (park.mvmFclty.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('운동시설: ${park.mvmFclty}', style: TextStyle(color: Colors.grey[600])),
                ]
              ],
            ),
          ),
        );
      },
    );
  }
}