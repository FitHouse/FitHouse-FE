import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';

class RegionService {
  Future<
      ({
      List<String> sidoList,
      Map<String, Map<String, List<String>>> regionHierarchy
      })> loadRegionsFromCsv() async {
    // ✅ 1. 읽어올 파일 이름을 'korean_regions.csv'로 변경합니다.
    final rawCsv = await rootBundle.loadString('assets/korean_regions.csv');
    final List<List<dynamic>> csvTable =
    const CsvToListConverter().convert(rawCsv);

    final Map<String, Map<String, Set<String>>> hierarchyMap = {};

    // ✅ 2. 헤더에서 'sido', 'sigungu', 'dong' 컬럼의 위치를 각각 찾습니다.
    final headers = csvTable.first;
    final sidoIndex = headers.indexOf('sido');
    final sigunguIndex = headers.indexOf('sigungu');
    final dongIndex = headers.indexOf('dong');

    // 컬럼 중 하나라도 없으면 빈 데이터를 반환합니다.
    if (sidoIndex == -1 || sigunguIndex == -1 || dongIndex == -1) {
      print("오류: CSV 파일에 'sido', 'sigungu', 'dong' 컬럼이 필요합니다.");
      return (sidoList: <String>[], regionHierarchy: <String, Map<String, List<String>>>{});    }

    // 헤더를 제외한 데이터 처리
    for (var i = 1; i < csvTable.length; i++) {
      final row = csvTable[i];

      // ✅ 3. 주소를 분리(split)하는 대신, 각 컬럼에서 값을 직접 읽어옵니다.
      final sido = row[sidoIndex].toString();
      final sigungu = row[sigunguIndex].toString();
      final dong = row[dongIndex].toString();

      // 비어있는 데이터가 있는지 확인
      if (sido.isEmpty || sigungu.isEmpty || dong.isEmpty) {
        continue;
      }

      hierarchyMap
          .putIfAbsent(sido, () => {})
          .putIfAbsent(sigungu, () => {})
          .add(dong);
    }

    // (이하 정렬 및 반환 로직은 이전과 동일)
    final sortedSidoList = hierarchyMap.keys.toList()..sort();
    final sortedRegionHierarchy = <String, Map<String, List<String>>>{};

    for (var sido in sortedSidoList) {
      final sigunguMap = hierarchyMap[sido]!;
      final sortedSigunguMap = <String, List<String>>{};
      final sortedSigunguKeys = sigunguMap.keys.toList()..sort();

      for (var sigungu in sortedSigunguKeys) {
        sortedSigunguMap[sigungu] = sigunguMap[sigungu]!.toList()..sort();
      }
      sortedRegionHierarchy[sido] = sortedSigunguMap;
    }
    return (sidoList: sortedSidoList, regionHierarchy: sortedRegionHierarchy);
  }
}