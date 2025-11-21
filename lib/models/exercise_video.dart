// 영상 하나의 상세 정보를 담는 모델 클래스입니다.
class ExerciseVideo {
  final String url;
  final String trngNm;
  final String toolNm;
  final String thumbnailUrl;

  ExerciseVideo({
    required this.url,
    required this.trngNm,
    required this.toolNm,
    required this.thumbnailUrl,
  });

  // 서버에서 받은 JSON 데이터로부터 ExerciseVideo 객체를 만드는 팩토리 생성자입니다.
  // json['key'] ?? '' 는 서버에서 해당 값이 null로 올 경우를 대비한 안전장치입니다.
  factory ExerciseVideo.fromJson(Map<String, dynamic> json) {
    return ExerciseVideo(
      url: json['url'] ?? '',
      trngNm: json['trngNm'] ?? '제목 없음',
      toolNm: json['toolNm'] ?? '',
      thumbnailUrl: json['thumbnailUrl'] ?? '',
    );
  }
}