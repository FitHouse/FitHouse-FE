class Park {
  final String parkNm;
  final String rdnmadr;
  final String lnmadr;
  final String latitude;
  final String longitude;
  final String parkAr;
  final String mvmFclty;
  final String amsmtFclty;
  final String cnvnncFclty;
  final String phoneNumber;

  Park({
    required this.parkNm,
    required this.rdnmadr,
    required this.lnmadr,
    required this.latitude,
    required this.longitude,
    required this.parkAr,
    required this.mvmFclty,
    required this.amsmtFclty,
    required this.cnvnncFclty,
    required this.phoneNumber,
  });

  factory Park.fromJson(Map<String, dynamic> json) {
    return Park(
      parkNm: json['parkNm'] ?? '',
      rdnmadr: json['rdnmadr'] ?? '',
      lnmadr: json['lnmadr'] ?? '',
      latitude: json['latitude'] ?? '',
      longitude: json['longitude'] ?? '',
      parkAr: json['parkAr'] ?? '',
      mvmFclty: json['mvmFclty'] ?? '',
      amsmtFclty: json['amsmtFclty'] ?? '',
      cnvnncFclty: json['cnvnncFclty'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
    );
  }
}