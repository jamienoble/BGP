import 'dart:async';

import 'package:walkies/services/error_reporter.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:walkies/config/app_config.dart';
import 'package:walkies/models/content.dart';
import 'package:walkies/screens/education/article_screen.dart' show HealthDisclaimer;
import 'package:walkies/screens/education_screen.dart' show contentLength;
import 'package:walkies/services/content_service.dart';
import 'package:walkies/theme/app_theme.dart';
import 'package:walkies/widgets/simple_markdown.dart';
import 'package:walkies/widgets/ui.dart';

/// Shows a poster until the viewer presses play (no autoplay, so nothing
/// streams on mobile data until asked), then plays inline and saves
/// progress every 15 seconds and on leaving.
class VideoScreen extends StatefulWidget {
  final Video video;
  final int startAt; // seconds

  const VideoScreen({super.key, required this.video, this.startAt = 0});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  final _contentService = ContentService();
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  Timer? _progressTimer;
  bool _isStarting = false;
  bool _hasError = false;

  Future<void> _play() async {
    setState(() {
      _isStarting = true;
      _hasError = false;
    });
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.video.playbackUrl),
    );
    _videoController = controller;
    try {
      await controller.initialize();
      final duration = controller.value.duration;
      // Resume where the viewer left off, unless they had nearly finished
      final resumeAt = Duration(seconds: widget.startAt);
      final startAt =
          resumeAt < duration - const Duration(seconds: 10) ? resumeAt : null;
      if (!mounted) return;
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: controller,
          autoPlay: true,
          startAt: startAt,
          allowedScreenSleep: false,
          materialProgressColors: ChewieProgressColors(
            playedColor: AppPalette.terracotta,
            handleColor: AppPalette.terracotta,
            bufferedColor: Colors.white38,
            backgroundColor: Colors.white24,
          ),
        );
        _isStarting = false;
      });
      _progressTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _saveProgress(),
      );
    } catch (e, stack) {
      ErrorReporter.report(e, stack, context: 'Video failed to load');
      if (mounted) {
        setState(() {
          _isStarting = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _saveProgress() async {
    final value = _videoController?.value;
    if (value == null || !value.isInitialized) return;
    final position = value.position;
    final completed = position >= value.duration - const Duration(seconds: 10);
    try {
      await _contentService.saveProgress(
        contentType: 'video',
        contentId: widget.video.id,
        progressSeconds: position.inSeconds,
        completed: completed,
      );
    } catch (e, stack) {
      ErrorReporter.report(e, stack, context: 'Could not save video progress');
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _saveProgress();
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final text = Theme.of(context).textTheme;
    final resumeLabel = widget.startAt > 30
        ? 'Resume from ${widget.startAt ~/ 60}:${(widget.startAt % 60).toString().padLeft(2, '0')}'
        : 'Play video';

    return Scaffold(
      appBar: AppBar(title: const Text('Video')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radius),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _chewieController != null
                  ? ColoredBox(
                      color: Colors.black,
                      child: Chewie(controller: _chewieController!),
                    )
                  : _Poster(
                      video: video,
                      label: _hasError ? 'Couldn\'t play. Try again' : resumeLabel,
                      isStarting: _isStarting,
                      onPlay: _play,
                    ),
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 8,
            children: [
              Pill(contentLength(video), icon: Icons.play_circle_outline_rounded),
            ],
          ),
          const SizedBox(height: 14),
          Text(video.title, style: text.headlineMedium),
          if (video.presenterName != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                InitialAvatar(video.presenterName!, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(video.presenterName!, style: text.bodySmall),
                ),
              ],
            ),
          ],
          if (video.summary != null) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),
            SimpleMarkdown(video.summary!),
          ],
          const SizedBox(height: 24),
          const HealthDisclaimer(),
        ],
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  final Video video;
  final String label;
  final bool isStarting;
  final VoidCallback onPlay;

  const _Poster({
    required this.video,
    required this.label,
    required this.isStarting,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = AppConfig.imageUrl(video.thumbnailImage, width: 1200);
    final artwork = ArtworkPlaceholder(
      seed: video.categoryId ?? video.id,
      icon: Icons.play_lesson_outlined,
      iconSize: 0,
    );
    return Material(
      color: Colors.black,
      child: InkWell(
        onTap: isStarting ? null : onPlay,
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageUrl != null
                ? Image.network(imageUrl, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => artwork)
                : artwork,
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x66000000)],
                ),
              ),
            ),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 20)],
                ),
                child: isStarting
                    ? const Padding(
                        padding: EdgeInsets.all(22),
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : const Icon(Icons.play_arrow_rounded,
                        size: 44, color: AppPalette.forest),
              ),
            ),
            Positioned(
              left: 14,
              bottom: 12,
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
