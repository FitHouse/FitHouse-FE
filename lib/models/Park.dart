class Park {
  final String parkNm;
  final String rdnmadr;
  final String parkAr;
  final String mvmFclty;
  final String phoneNumber;

  Park({
    required this.parkNm,
    required this.rdnmadr,
    required this.parkAr,
    required this.mvmFclty,
    required this.phoneNumber,
  });

  factory Park.fromJson(Map<String, dynamic> json) {
    return Park(
      parkNm: json['parkNm'] ?? '이름 없음',
      rdnmadr: json['rdnmadr'] ?? '주소 정보 없음',
      parkAr: json['parkAr'] ?? '면적 정보 없음',
      mvmFclty: json['mvmFclty'] ?? '운동시설 정보 없음',
      phoneNumber: json['phoneNumber'] ?? '연락처 정보 없음',
    );
  }
}
