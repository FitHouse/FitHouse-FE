// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'park.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Park _$ParkFromJson(Map<String, dynamic> json) => Park(
  parkNm: json['공원명'] as String?,
  rdnmadr: json['소재지도로명주소'] as String?,
  lnmadr: json['소재지지번주소'] as String?,
  latitude: json['위도'] as String?,
  longitude: json['경도'] as String?,
  parkArea: json['공원면적'] as String?,
  mvmFclty: json['공원보유시설(운동시설)'] as String?,
  amsmtFclty: json['공원보유시설(유희시설)'] as String?,
  cnvnncFclty: json['공원보유시설(편익시설)'] as String?,
  cltrFclty: json['공원보유시설(교양시설)'] as String?,
  etcFclty: json['공원보유시설(기타시설)'] as String?,
  nearestFacilityNm: json['nearestFacilityNm'] as String?,
  nearestStopNm: json['nearestStopNm'] as String?,
  walkingTimeMin: (json['walkingTimeMin'] as num?)?.toDouble(),
  walkingDistKm: (json['walkingDistKm'] as num?)?.toDouble(),
);

Map<String, dynamic> _$ParkToJson(Park instance) => <String, dynamic>{
  '공원명': instance.parkNm,
  '소재지도로명주소': instance.rdnmadr,
  '소재지지번주소': instance.lnmadr,
  '위도': instance.latitude,
  '경도': instance.longitude,
  '공원면적': instance.parkArea,
  '공원보유시설(운동시설)': instance.mvmFclty,
  '공원보유시설(유희시설)': instance.amsmtFclty,
  '공원보유시설(편익시설)': instance.cnvnncFclty,
  '공원보유시설(교양시설)': instance.cltrFclty,
  '공원보유시설(기타시설)': instance.etcFclty,
  'nearestFacilityNm': instance.nearestFacilityNm,
  'nearestStopNm': instance.nearestStopNm,
  'walkingTimeMin': instance.walkingTimeMin,
  'walkingDistKm': instance.walkingDistKm,
};
