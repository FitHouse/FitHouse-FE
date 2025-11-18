import 'package:json_annotation/json_annotation.dart';
import 'package:fithouse/models/sports_facility.dart';

part 'park.g.dart';

@JsonSerializable()
class Park {
  @JsonKey(name: '공원명')
  final String? parkNm;

  @JsonKey(name: '소재지도로명주소')
  final String? rdnmadr;

  @JsonKey(name: '소재지지번주소')
  final String? lnmadr;

  @JsonKey(name: '위도')
  final String? latitude;

  @JsonKey(name: '경도')
  final String? longitude;

  @JsonKey(name: '공원면적')
  final String? parkAr;

  @JsonKey(name: '공원보유시설(운동시설)')
  final String? mvmFclty;

  @JsonKey(name: '공원보유시설(유희시설)')
  final String? amsmtFclty;

  @JsonKey(name: '공원보유시설(편익시설)')
  final String? cnvnncFclty;

  @JsonKey(name: '공원보유시설(교양시설)')
  final String? cltrFclty;

  @JsonKey(name: '공원보유시설(기타시설)')
  final String? etcFclty;

  @JsonKey(ignore: true)
  SportsFacility? nearestFacility;

  Park({
    this.parkNm,
    this.rdnmadr,
    this.lnmadr,
    this.latitude,
    this.longitude,
    this.parkAr,
    this.mvmFclty,
    this.amsmtFclty,
    this.cnvnncFclty,
    this.cltrFclty,
    this.etcFclty,
  });

  factory Park.fromJson(Map<String, dynamic> json) => _$ParkFromJson(json);

  Map<String, dynamic> toJson() => _$ParkToJson(this);
}