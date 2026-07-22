import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';

class VoiceNotePlayerBubble extends StatefulWidget {
  final String audioUrl;
  final int durationSeconds;
  final bool isMe;

  const VoiceNotePlayerBubble({
    super.key,
    required this.audioUrl,
    required this.durationSeconds,
    required this.isMe,
  });

  @override
  State<VoiceNotePlayerBubble> createState() => _VoiceNotePlayerBubbleState();
}

class _VoiceNotePlayerBubbleState extends State<VoiceNotePlayerBubble> {
  late final AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _duration = Duration(seconds: widget.durationSeconds);

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          _isLoading = false;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted && d.inSeconds > 0) {
        setState(() {
          _duration = d;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) {
        setState(() {
          _position = p;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      setState(() => _isLoading = true);
      try {
        await _audioPlayer.play(UrlSource(widget.audioUrl));
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to play voice note: $e')),
          );
        }
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.isMe ? Colors.white : AppTheme.primaryColor;
    final secondaryColor = widget.isMe ? Colors.white70 : Colors.grey[600]!;

    final maxVal = _duration.inMilliseconds.toDouble() > 0
        ? _duration.inMilliseconds.toDouble()
        : (widget.durationSeconds * 1000).toDouble();

    final currentVal = _position.inMilliseconds.toDouble().clamp(0.0, maxVal > 0 ? maxVal : 1000.0);

    return Container(
      width: 220.w,
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _isLoading ? null : _togglePlay,
                icon: _isLoading
                    ? SizedBox(
                        width: 24.w,
                        height: 24.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primaryColor,
                        ),
                      )
                    : Icon(
                        _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                        size: 34.w,
                        color: primaryColor,
                      ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.r),
                        trackHeight: 4.h,
                        activeTrackColor: primaryColor,
                        inactiveTrackColor: primaryColor.withOpacity(0.3),
                        thumbColor: primaryColor,
                        overlayShape: SliderComponentShape.noOverlay,
                      ),
                      child: Slider(
                        value: currentVal,
                        max: maxVal > 0 ? maxVal : 1000.0,
                        onChanged: (val) async {
                          final newPos = Duration(milliseconds: val.toInt());
                          await _audioPlayer.seek(newPos);
                        },
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: secondaryColor,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.graphic_eq, size: 12.w, color: secondaryColor),
                            SizedBox(width: 2.w),
                            Text(
                              _formatDuration(_duration),
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: secondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
