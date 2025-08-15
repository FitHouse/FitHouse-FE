import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/park.dart';
import '../lib/korean_regions.dart';

class WalkTab extends StatefulWidget {
  const WalkTab({super.key});

  @override
  State<WalkTab> createState() => _WalkTabState();
}

class _WalkTabState extends State<WalkTab> {
  // 상태 변수들
  String? _selectedSido; // 선택된 시/도
  String? _selectedSigungu; // 선택된 시/군/구
  List<String> _sigunguList = []; // 시/도에 따라 동적으로 변경될 시/군/구 목록

  List<Park> _parkList = []; // API로부터 받아온 공원 목록
  bool _isLoading = false; // 데이터 로딩 중인지 여부
  String _message = '지역을 선택하고 검색 버튼을 눌러주세요.'; // 사용자에게 보여줄 메시지

  // 공원 데이터를 서버에 요청하는 함수
  Future<void> _fetchParks() async {
    if (_selectedSido == null || _selectedSigungu == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '공원 정보를 불러오는 중입니다...';
      _parkList = [];
    });

    try {
      final url = Uri.parse('http://localhost:8080/api/parks?sido=$_selectedSido&sigungu=$_selectedSigungu');
      // final url = Uri.parse('http://10.0.2.2:8080/api/parks?sido=$_selectedSido&sigungu=$_selectedSigungu'); // 안드로이드 에뮬레이터

      final response = await http.get(url, headers: {"Content-Type": "application/json"});

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _parkList = data.map((json) => Park.fromJson(json)).toList();
          if (_parkList.isEmpty) {
            _message = '해당 지역에 공원 정보가 없습니다.';
          }
        });
      } else {
        setState(() {
          _message = '오류가 발생했습니다: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _message = '네트워크 오류가 발생했습니다.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 1. 지역 선택 UI
          Row(
            children: [
              // 시/도 드롭다운
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('시/도 선택'),
                  value: _selectedSido,
                  items: koreanRegions.keys.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedSido = newValue;
                      _selectedSigungu = null; // 시/군/구 선택 초기화
                      _sigunguList = koreanRegions[newValue!] ?? [];
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              // 시/군/구 드롭다운
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('시/군/구 선택'),
                  value: _selectedSigungu,
                  items: _sigunguList.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedSigungu = newValue;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. 검색 버튼
          ElevatedButton(
            onPressed: _fetchParks,
            child: const Text('산책로 검색'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 16),

          // 3. 공원 목록 또는 메시지 표시
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _parkList.isEmpty
                ? Center(child: Text(_message))
                : ListView.builder(
              itemCount: _parkList.length,
              itemBuilder: (context, index) {
                final park = _parkList[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.park, color: Colors.green),
                    title: Text(park.parkNm, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(park.rdnmadr),
                        const SizedBox(height: 4),
                        Text('면적: ${park.parkAr}㎡'),
                        if (park.mvmFclty.isNotEmpty) Text('운동시설: ${park.mvmFclty}'),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
