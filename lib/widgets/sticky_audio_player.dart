import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sticky audio player widget for Story detail view
/// 
/// Displays audio playback controls (play/pause, scrubber, duration, playback speed)
/// and remains visible when scrolling. Currently shows placeholder since audio fields
/// are not yet available in the moments table.
class StickyAudioPlayer extends ConsumerStatefulWidget {
  /// Audio URL from Supabase Storage (nullable until audio fields are added)
  final String? audioUrl;
  
  /// Audio duration in seconds (nullable until audio fields are added)
  final double? duration;
  
  /// Story ID for audio caching
  final String storyId;

  const StickyAudioPlayer({
    super.key,
    this.audioUrl,
    this.duration,
    required this.storyId,
  });

  @override
  ConsumerState<StickyAudioPlayer> createState() => _StickyAudioPlayerState();
}

class _StickyAudioPlayerState extends ConsumerState<StickyAudioPlayer> {
  bool _isPlaying = false;
  double _currentPosition = 0.0;
  double _playbackSpeed = 1.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // If audio URL is not available, show placeholder
    if (widget.audioUrl == null || widget.duration == null) {
      return Semantics(
        label: 'Audio player placeholder - audio playback will be available soon',
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Semantics(
                label: 'Audio file icon',
                excludeSemantics: true,
                child: Icon(
                  Icons.audio_file_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Audio playback will be available soon',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Semantics(
      label: 'Audio player for story',
      hint: 'Use play/pause button to control playback, use slider to seek',
      child: Focus(
        autofocus: false,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Play/pause button and time display row
              Row(
                children: [
                  // Play/pause button - 48x48px meets accessibility requirements
                  Semantics(
                    label: _isPlaying ? 'Pause audio playback' : 'Play audio playback',
                    hint: _isPlaying ? 'Double tap to pause' : 'Double tap to play',
                    button: true,
                    child: Material(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: _togglePlayPause,
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          child: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: theme.colorScheme.onPrimary,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
              const SizedBox(width: 16),
              // Time display and scrubber
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current position / Duration
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_currentPosition),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          _formatDuration(widget.duration!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Progress slider - accessible for screen readers
                    Semantics(
                      label: 'Audio progress',
                      value: '${_formatDuration(_currentPosition)} of ${_formatDuration(widget.duration!)}',
                      child: Slider(
                        value: _currentPosition.clamp(0.0, widget.duration!),
                        max: widget.duration!,
                        onChanged: (value) {
                          setState(() {
                            _currentPosition = value;
                          });
                          // TODO: Seek to position when audio engine is integrated
                        },
                        activeColor: theme.colorScheme.primary,
                        inactiveColor: theme.colorScheme.surfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Playback speed button - accessible with proper labels
              Semantics(
                label: 'Playback speed: ${_playbackSpeed}x',
                hint: 'Double tap to change playback speed',
                button: true,
                child: PopupMenuButton<double>(
                  tooltip: 'Change playback speed',
                  icon: Text(
                    '${_playbackSpeed}x',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onSelected: (speed) {
                    setState(() {
                      _playbackSpeed = speed;
                    });
                    // TODO: Update playback speed when audio engine is integrated
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 0.5,
                      child: Semantics(label: 'Playback speed 0.5x', child: const Text('0.5x')),
                    ),
                    PopupMenuItem(
                      value: 0.75,
                      child: Semantics(label: 'Playback speed 0.75x', child: const Text('0.75x')),
                    ),
                    PopupMenuItem(
                      value: 1.0,
                      child: Semantics(label: 'Playback speed 1x', child: const Text('1x')),
                    ),
                    PopupMenuItem(
                      value: 1.25,
                      child: Semantics(label: 'Playback speed 1.25x', child: const Text('1.25x')),
                    ),
                    PopupMenuItem(
                      value: 1.5,
                      child: Semantics(label: 'Playback speed 1.5x', child: const Text('1.5x')),
                    ),
                    PopupMenuItem(
                      value: 2.0,
                      child: Semantics(label: 'Playback speed 2x', child: const Text('2x')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
        ),
      ),
    );
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    // TODO: Integrate with audio engine when audio fields are available
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final minutes = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

