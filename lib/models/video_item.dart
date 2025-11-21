class VideoItem {
  final String trngNm;
  final String aggrpNm;
  final String ftnsFctrNm;
  final String ftnsLvlNm;
  final String toolNm;
  final String thumbnailUrl;
  final String videoUrl;

  VideoItem({
    required this.trngNm,
    required this.aggrpNm,
    required this.ftnsFctrNm,
    required this.ftnsLvlNm,
    required this.toolNm,
    required this.thumbnailUrl,
    required this.videoUrl,
  });

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    return VideoItem(
      trngNm: json["trngNm"] ?? "",
      aggrpNm: json["aggrpNm"] ?? "",
      ftnsFctrNm: json["ftnsFctrNm"] ?? "",
      ftnsLvlNm: json["ftnsLvlNm"] ?? "",
      toolNm: json["toolNm"] ?? "",
      thumbnailUrl: json["thumbnailUrl"] ?? "",
      videoUrl: json["videoUrl"] ?? "",
    );
  }
}
