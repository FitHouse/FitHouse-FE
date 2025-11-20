import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'fullscreen_video_page.dart';

class VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerDialog({super.key, required this.videoUrl});

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  late VideoPlayerController _controller;
  late Future<void> _initializeFuture;

  bool _controlsVisible = true;
  DateTime _lastTouch = DateTime.now();

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _initializeFuture = _controller.initialize().then((_) {
      _controller.play();
      setState(() {});
      _autoHideControls();
    });
    _controller.setLooping(true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _autoHideControls() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 3));
      if (!_controller.value.isPlaying) continue;

      if (DateTime.now().difference(_lastTouch).inSeconds >= 3) {
        setState(() => _controlsVisible = false);
      }
    }
  }

  void _touch() {
    setState(() {
      _controlsVisible = true;
      _lastTouch = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(10),
      child: GestureDetector(
        onTap: _touch,
        child: Center(
          child: FutureBuilder(
            future: _initializeFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const CircularProgressIndicator(color: Colors.white);
              }

              return AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  children: [
                    VideoPlayer(_controller),

                    if (!_controller.value.isPlaying || _controlsVisible)
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_controller.value.isPlaying) {
                                _controller.pause();
                              } else {
                                _controller.play();
                                _controlsVisible = false;
                              }
                            });
                          },
                          child: Icon(
                            _controller.value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            size: 70,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ),

                    if (_controlsVisible)
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: IconButton(
                          icon: const Icon(Icons.fullscreen,
                              color: Colors.white, size: 32),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FullScreenVideoPage(
                                  controller: _controller,
                                ),
                              ),
                            );

                            setState(() {
                              _controlsVisible = true;
                              _lastTouch = DateTime.now();
                            });
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
