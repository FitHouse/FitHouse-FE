class ExerciseVideo {
  final String url;
  final String trngNm;
  final String toolNm;
  final String thumbnailUrl;

  final String aggrpNm;      // 연령대명
  final String ftnsFctrNm;   // 체력요인명
  final String ftnsLvlNm;    // 체력수준명
  final String bodyPartNm;   // 운동부위명
  final String videoDesc;    // 영상 설명
  final String trngPlacNm;   // 운동 장소명

  ExerciseVideo({
    required this.url,
    required this.trngNm,
    required this.toolNm,
    required this.thumbnailUrl,
    required this.aggrpNm,
    required this.ftnsFctrNm,
    required this.ftnsLvlNm,
    required this.bodyPartNm,
    required this.videoDesc,
    required this.trngPlacNm,
  });

  factory ExerciseVideo.fromJson(Map<String, dynamic> json) {
    final existingUrl = json['url'];
    final existingName = json['trngNm'];
    final existingTool = json['toolNm'];
    final existingThumb = json['thumbnailUrl'];

    final apiUrl = json['file_url'] != null && json['file_nm'] != null
        ? json['file_url'] + json['file_nm']
        : null;

    final apiThumb = json['img_file_url'] != null && json['img_file_nm'] != null
        ? json['img_file_url'] + json['img_file_nm']
        : null;

    return ExerciseVideo(
      url: existingUrl ?? apiUrl ?? '',
      trngNm: existingName ?? json['trng_nm'] ?? json['vdo_ttl_nm'] ?? '제목 없음',
      toolNm: existingTool ?? json['tool_nm'] ?? '',
      thumbnailUrl: existingThumb ?? apiThumb ?? '',

      aggrpNm: json['aggrp_nm'] ?? '',
      ftnsFctrNm: json['ftns_fctr_nm'] ?? '',
      ftnsLvlNm: json['ftns_lvl_nm'] ?? '',
      bodyPartNm: json['trng_mscl_part'] ?? '',
      videoDesc: json['vdo_desc'] ?? '',
      trngPlacNm: json['trng_plc_nm'] ?? '',
    );
  }
}
