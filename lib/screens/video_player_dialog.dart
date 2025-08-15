import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

// 영상 재생을 담당하는 새로운 팝업(Dialog) 위젯입니다.
class VideoPlayerDialog extends StatefulWidget {
  final String videoUrl; // 이전 화면에서 전달받을 영상 URL

  const VideoPlayerDialog({super.key, required this.videoUrl});

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _initializeVideoPlayerFuture = _controller.initialize().then((_) {
      // 초기화가 끝나면 바로 재생합니다.
      _controller.play();
      setState(() {});
    });
    _controller.setLooping(true); // 영상 반복 재생 설정
  }

  @override
  void dispose() {
    _controller.dispose(); // 위젯이 사라질 때 리소스를 꼭 해제합니다.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(10),
      child: GestureDetector(
        onTap: () {
          // 팝업 바깥쪽을 눌러도 닫히도록 설정
          Navigator.of(context).pop();
        },
        child: Center(
          child: FutureBuilder(
            future: _initializeVideoPlayerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                // 영상 로딩이 완료되면 플레이어를 보여줍니다.
                return AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(_controller),
                      // 재생/일시정지 버튼 오버레이
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_controller.value.isPlaying) {
                              _controller.pause();
                            } else {
                              _controller.play();
                            }
                          });
                        },
                        child: Icon(
                          _controller.value.isPlaying ? null : Icons.play_arrow,
                          color: Colors.white.withOpacity(0.7),
                          size: 80.0,
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                // 영상 로딩 중에는 스피너를 보여줍니다.
                return const CircularProgressIndicator(color: Colors.white);
              }
            },
          ),
        ),
      ),
    );
  }
}
