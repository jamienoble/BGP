import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:walkies/constants/app_colors.dart';
import 'package:walkies/models/content.dart';
import 'package:walkies/services/content_service.dart';
import 'package:walkies/widgets/simple_markdown.dart';

class VideoScreen extends StatefulWidget {
  final Video video;
  final int startAt; // seconds

  const VideoScreen({super.key, required this.video, this.startAt = 0});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  final _contentService = ContentService();
  late final VideoPlayerController _videoController;
  ChewieController? _chewieController;
  Timer? _progressTimer;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.video.playbackUrl),
    );
    _initialise();
  }

  Future<void> _initialise() async {
    try {
      await _videoController.initialize();
      final duration = _videoController.value.duration;
      // Resume where the viewer left off, unless they had nearly finished
      final resumeAt = Duration(seconds: widget.startAt);
      final startAt =
          resumeAt < duration - const Duration(seconds: 10) ? resumeAt : null;
      if (!mounted) return;
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _videoController,
          autoPlay: true,
          startAt: startAt,
          allowedScreenSleep: false,
          materialProgressColors: ChewieProgressColors(
            playedColor: AppColors.accent,
            handleColor: AppColors.accent,
          ),
        );
      });
      _progressTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _saveProgress(),
      );
    } catch (e) {
      debugPrint('Video failed to load: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  Future<void> _saveProgress() async {
    final value = _videoController.value;
    if (!value.isInitialized) return;
    final position = value.position;
    final completed =
        position >= value.duration - const Duration(seconds: 10);
    try {
      await _contentService.saveProgress(
        contentType: 'video',
        contentId: widget.video.id,
        progressSeconds: position.inSeconds,
        completed: completed,
      );
    } catch (e) {
      debugPrint('Could not save video progress: $e');
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _saveProgress();
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    return Scaffold(
      appBar: AppBar(title: const Text('Video')),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: _hasError
                  ? const Center(
                      child: Text(
                        'This video could not be played.',
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  : _chewieController == null
                      ? const Center(child: CircularProgressIndicator())
                      : Chewie(controller: _chewieController!),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
                if (video.presenterName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'With ${video.presenterName}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
                if (video.summary != null) ...[
                  const SizedBox(height: 16),
                  SimpleMarkdown(video.summary!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
