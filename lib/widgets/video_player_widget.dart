//
// VideoPlayerWidget plays a live youtube video in it's parent widget (Container, SizedBox, FloatingFrame, ...)
// On a web platform it uses youtube_player_iframe and on all other platforms
// the youtube_explode api to get the youtube stream url and media_kit to play the video
//
// we can remove all controls from the web version, but it does not activate the buttons on top of the video...
//
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Video;
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

//
//------------------------------------------------------------------------------------------------------------------------------------------
//'

class VideoPlayerWidget extends StatefulWidget {
  const VideoPlayerWidget({super.key, required this.videoIdList, this.index = 0, this.onClose = _defaultOnClose});

  /// the list of youtube videoId's
  final List<String> videoIdList;

  /// the initial index
  final int index;

  /// the onclose function returns the last index selected by the user
  final Function(int) onClose;

  static void _defaultOnClose(int index) {}

  @override
  State<VideoPlayerWidget> createState() => VideoPlayerWidgetState();
}

class VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late final Player _player;
  late final VideoController _controller;
  late final YoutubePlayerController _webController;
  bool _isLoading = true;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.index.clamp(0, widget.videoIdList.length - 1);

    if (kIsWeb) {
      // 1. Initialize the controller with autoPlay and mute set to true.
      // 2. Muting is required for browsers to allow autoplay.
      _webController = YoutubePlayerController.fromVideoId(
          videoId: widget.videoIdList[_index],
          params: const YoutubePlayerParams(
              mute: false,
              showControls: false,
              showFullscreenButton: false,
              enableCaption: false,
              showVideoAnnotations: false,
              enableKeyboard: false));

      // On Web, fromVideoId handles the initial load automatically.
      // Do NOT call _getVideoStream here for Web, as it triggers a redundant load.
      Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isLoading = false);
      });
    } else {
      // Non-Web initialization (MediaKit)
      _player = Player();
      _controller = VideoController(_player);

      _player.stream.playing.listen((playing) {
        if (playing && mounted) setState(() => _isLoading = false);
      });

      _player.stream.error.listen((error) {
        debugPrint('MediaKit Error: $error');
      });

      // For non-web, we must manually fetch and open the stream URL.
      _getVideoStream(widget.videoIdList[_index]);
    }
  }

  Future<void> _getVideoStream(String videoId) async {
    if (kIsWeb) {
      // This is called when switching videos via arrows
      _webController.loadVideoById(videoId: videoId);
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      if (mounted) setState(() => _isLoading = true);

      final yt = YoutubeExplode();
      final video = await yt.videos.get(videoId);
      String? streamUrl;

      if (video.isLive) {
        streamUrl = await yt.videos.streamsClient.getHttpLiveStreamUrl(VideoId(videoId));
      } else {
        final manifest = await yt.videos.streamsClient.getManifest(VideoId(videoId));
        streamUrl = manifest.muxed.withHighestBitrate().url.toString();
      }
      yt.close();

      // Headers are often necessary to prevent YouTube from blocking the stream
      await _player.open(
        Media(
          streamUrl,
          httpHeaders: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'https://www.youtube.com/',
          },
        ),
        play: true, // Explicitly start playback
      );
    } catch (e) {
      debugPrint('Error loading video stream: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      _webController.close();
    } else {
      _player.dispose();
    }
    widget.onClose(_index);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
      final double videoHeight = constraints.maxWidth * 9 / 16;
      final double finalHeight = constraints.hasBoundedHeight ? constraints.maxHeight : videoHeight;

      return SizedBox(
          width: constraints.maxWidth,
          height: finalHeight,
          child: Stack(fit: StackFit.expand, children: [
            kIsWeb
                ? YoutubePlayer(controller: _webController, aspectRatio: 16 / 9)
                : Video(
                    controller: _controller,
                    controls: NoVideoControls,
                    fill: Colors.black, // Ensures no flickering during load
                  ),
            if (_isLoading)
              Container(
                color: Colors.black,
                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            if (!kIsWeb)
              // Navigation controls for non-web
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  alignment: Alignment.center,
                  child: Row(
                    children: [
                      if (_index > 0)
                        IconButton(
                            onPressed: () {
                              setState(() {
                                _index--;
                                _isLoading = true;
                              });
                              _getVideoStream(widget.videoIdList[_index]);
                            },
                            icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 24)),
                      const Spacer(),
                      if (_index < widget.videoIdList.length - 1)
                        IconButton(
                            onPressed: () {
                              setState(() {
                                _index++;
                                _isLoading = true;
                              });
                              _getVideoStream(widget.videoIdList[_index]);
                            },
                            icon: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 24))
                    ],
                  ))
          ]));
    });
  }
}
