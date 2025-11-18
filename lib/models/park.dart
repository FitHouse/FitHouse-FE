// lib/models/park.dart

import 'package:json_annotation/json_annotation.dart';

part 'park.g.dart'; // 실행 후 자동 생성될 파일

@JsonSerializable()
class Park {
  // 1. 기본 공원 정보 필드
  @JsonKey(name: '공원명')
  final String? parkNm;

  @JsonKey(name: '소재지도로명주소')
  final String? rdnmadr;

  @JsonKey(name: '소재지지번주소')
  final String? lnmadr;

  @JsonKey(name: '위도')
  final String? latitude; // JSON에서는 String이지만 Dart 코드에서 필요 시 double로 파싱

  @JsonKey(name: '경도')
  final String? longitude; // JSON에서는 String이지만 Dart 코드에서 필요 시 double로 파싱

  @JsonKey(name: '공원면적')
  final String? parkArea;

  // 2. 공원 보유 시설 필드 (이름은 기존 JSON 파일의 키와 일치해야 합니다)
  @JsonKey(name: '공원보유시설(운동시설)')
  final String? mvmFclty; // 운동 시설

  @JsonKey(name: '공원보유시설(유희시설)')
  final String? amsmtFclty; // 유희 시설

  @JsonKey(name: '공원보유시설(편익시설)')
  final String? cnvnncFclty; // 편익 시설

  @JsonKey(name: '공원보유시설(교양시설)')
  final String? cltrFclty; // 교양 시설

  @JsonKey(name: '공원보유시설(기타시설)')
  final String? etcFclty; // 기타 시설

  // 3. ✨ 파이썬 전처리로 추가된 근접 시설 정보 필드 (키 이름은 파이썬 스크립트와 일치해야 합니다)
  @JsonKey(name: 'nearestFacilityNm')
  final String? nearestFacilityNm; // 가장 가까운 체육시설 이름

  @JsonKey(name: 'nearestStopNm')
  final String? nearestStopNm; // 가장 가까운 정류장 이름

  @JsonKey(name: 'walkingTimeMin')
  final double? walkingTimeMin;

  @JsonKey(name: 'walkingDistKm')
  final double? walkingDistKm; // 도보 거리 (Km 단위, 실수)

  Park({
    this.parkNm,
    this.rdnmadr,
    this.lnmadr,
    this.latitude,
    this.longitude,
    this.parkArea,
    this.mvmFclty,
    this.amsmtFclty,
    this.cnvnncFclty,
    this.cltrFclty,
    this.etcFclty,
    this.nearestFacilityNm,
    this.nearestStopNm,
    this.walkingTimeMin,
    this.walkingDistKm,
  });

  factory Park.fromJson(Map<String, dynamic> json) => _$ParkFromJson(json);
  Map<String, dynamic> toJson() => _$ParkToJson(this);
}