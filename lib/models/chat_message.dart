import 'exercise_video.dart';

// 채팅 메시지 하나를 나타내는 모델 클래스입니다.
class ChatMessage {
  final String text; // 메시지 텍스트
  final bool isUser; // 사용자가 보낸 메시지인지 여부
  final List<ExerciseVideo> videos; // 추천 영상 목록

  ChatMessage({
    required this.text,
    required this.isUser,
    this.videos = const [], // 영상 목록의 기본값은 빈 리스트입니다.
  });
}
