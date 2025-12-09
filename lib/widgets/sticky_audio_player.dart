import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// Sticky audio player widget for Story detail view
///
/// Displays audio playback controls (play/pause, scrubber, duration, playback speed)
/// and remains visible when scrolling. When audio is not available or still loading,
/// shows a neutral placeholder rather than implying future availability.
class StickyAudioPlayer extends ConsumerStatefulWidget {
  /// Audio URL from Supabase Storage (nullable until audio fields are added)
  final String? audioUrl;

  /// Audio duration in seconds (nullable until audio fields are added)
  final double? duration;

  /// Story ID for audio caching
  final String storyId;
  final bool enablePositionUpdates;
  final ValueChanged<double>? onHeightChanged;

  /// Whether the audio URL is currently being fetched (shows loading state instead of "not available")
  final bool isLoadingUrl;

  const StickyAudioPlayer({
    super.key,
    this.audioUrl,
    this.duration,
    required this.storyId,
    this.enablePositionUpdates = true,
    this.onHeightChanged,
    this.isLoadingUrl = false,
  });

  @override
  ConsumerState<StickyAudioPlayer> createState() => _StickyAudioPlayerState();
}

class _StickyAudioPlayerState extends ConsumerState<StickyAudioPlayer> {
  late final AudioPlayer _audioPlayer;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<double>? _speedSubscription;

  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isBuffering = false;
  double _currentPosition = 0.0;
  double _playbackSpeed = 1.0;
  double? _loadedDuration; // Duration loaded from audio engine (if available)
  String? _errorMessage;
  double? _lastReportedHeight;
  bool _heightReportScheduled = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _attachPlayerListeners();
    _loadAudioSource();
  }

  @override
  void didUpdateWidget(covariant StickyAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.audioUrl != oldWidget.audioUrl) {
      _loadAudioSource();
    }
    if (widget.enablePositionUpdates != oldWidget.enablePositionUpdates) {
      _startPositionSubscription();
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _speedSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _scheduleHeightReport();

    // Use loaded duration if available, otherwise fall back to widget duration
    final effectiveDuration = _loadedDuration ?? widget.duration;

    // If audio URL is not available, show placeholder or loading state
    // Duration can be loaded from audio engine once playback starts
    if (widget.audioUrl == null) {
      // If we're loading the URL, show a loading state instead of "not available"
      if (widget.isLoadingUrl) {
        return Semantics(
          label: 'Loading audio',
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
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Loading audio…',
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

      // Otherwise, show "not available" message
      return Semantics(
        label: 'Audio is not available for this story',
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
                  'Audio is not available for this story',
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
          child: IntrinsicHeight(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AudioErrorBanner(
                      message: _errorMessage!,
                      onRetry: widget.audioUrl != null
                          ? () => _loadAudioSource()
                          : null,
                    ),
                  )
                else if (_isLoading || _isBuffering)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AudioLoadingBanner(isBuffering: _isBuffering),
                  ),
                // Play/pause button and time display row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Play/pause button - 48x48px meets accessibility requirements
                    Semantics(
                      label: _isPlaying
                          ? 'Pause audio playback'
                          : 'Play audio playback',
                      hint: _isPlaying
                          ? 'Double tap to pause'
                          : 'Double tap to play',
                      button: true,
                      child: Material(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(24),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: (_errorMessage == null &&
                                  !_isLoading &&
                                  widget.audioUrl != null)
                              ? _togglePlayPause
                              : null,
                          child: Opacity(
                            opacity: (_errorMessage == null &&
                                    !_isLoading &&
                                    widget.audioUrl != null)
                                ? 1.0
                                : 0.5,
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
                    ),
                    const SizedBox(width: 16),
                    // Time display and scrubber
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Progress slider - accessible for screen readers
                          Semantics(
                            label: 'Audio progress',
                            value: effectiveDuration != null
                                ? '${_formatDuration(_currentPosition)} of ${_formatDuration(effectiveDuration)}'
                                : '${_formatDuration(_currentPosition)}',
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2.0,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6.0,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 14.0,
                                ),
                              ),
                              child: Slider(
                                value: _currentPosition.clamp(
                                    0.0, effectiveDuration ?? 1.0),
                                max: effectiveDuration ?? 1.0,
                                onChanged: effectiveDuration != null
                                    ? (value) {
                                        setState(() {
                                          _currentPosition = value;
                                        });
                                      }
                                    : null, // Disable slider when duration is unknown
                                onChangeEnd: effectiveDuration != null
                                    ? (value) => _seekTo(value)
                                    : null,
                                activeColor: theme.colorScheme.primary,
                                inactiveColor: theme.colorScheme.surfaceVariant,
                              ),
                            ),
                          ),
                          // Current position / Duration
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(_currentPosition),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  effectiveDuration != null
                                      ? _formatDuration(effectiveDuration)
                                      : '?:??',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Playback speed button - accessible with proper labels
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Semantics(
                          label: 'Playback speed: ${_playbackSpeed}x',
                          hint: 'Double tap to change playback speed',
                          button: true,
                          child: PopupMenuButton<double>(
                            tooltip: 'Change playback speed',
                            padding: EdgeInsets.zero,
                            icon: Text(
                              '${_playbackSpeed}x',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onSelected: (speed) => _setPlaybackSpeed(speed),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 0.5,
                                child: Semantics(
                                    label: 'Playback speed 0.5x',
                                    child: const Text('0.5x')),
                              ),
                              PopupMenuItem(
                                value: 0.75,
                                child: Semantics(
                                    label: 'Playback speed 0.75x',
                                    child: const Text('0.75x')),
                              ),
                              PopupMenuItem(
                                value: 1.0,
                                child: Semantics(
                                    label: 'Playback speed 1x',
                                    child: const Text('1x')),
                              ),
                              PopupMenuItem(
                                value: 1.25,
                                child: Semantics(
                                    label: 'Playback speed 1.25x',
                                    child: const Text('1.25x')),
                              ),
                              PopupMenuItem(
                                value: 1.5,
                                child: Semantics(
                                    label: 'Playback speed 1.5x',
                                    child: const Text('1.5x')),
                              ),
                              PopupMenuItem(
                                value: 2.0,
                                child: Semantics(
                                    label: 'Playback speed 2x',
                                    child: const Text('2x')),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _scheduleHeightReport() {
    if (!mounted || widget.onHeightChanged == null || _heightReportScheduled) {
      return;
    }
    _heightReportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _heightReportScheduled = false;
      _reportHeight();
    });
  }

  void _reportHeight() {
    if (!mounted || widget.onHeightChanged == null) {
      return;
    }
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return;
    }
    final height = renderBox.size.height;
    if (!height.isFinite || height <= 0) {
      return;
    }
    if (_lastReportedHeight == null ||
        (height - _lastReportedHeight!).abs() > 0.5) {
      _lastReportedHeight = height;
      widget.onHeightChanged!(height);
    }
  }

  Future<void> _togglePlayPause() async {
    if (widget.audioUrl == null || _isLoading || _errorMessage != null) {
      debugPrint(
          '[StickyAudioPlayer] Play button disabled - audioUrl: ${widget.audioUrl}, isLoading: $_isLoading, error: $_errorMessage');
      return;
    }

    try {
      debugPrint(
          '[StickyAudioPlayer] Toggling playback - currently playing: ${_audioPlayer.playing}');
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
        debugPrint('[StickyAudioPlayer] Paused');
      } else {
        // Ensure audio source is loaded before playing
        if (_loadedDuration == null && widget.duration == null) {
          debugPrint(
              '[StickyAudioPlayer] Audio duration not available, attempting to reload...');
          await _loadAudioSource();
          // Wait a bit for the source to be ready
          await Future.delayed(const Duration(milliseconds: 100));
        }
        await _audioPlayer.play();
        debugPrint('[StickyAudioPlayer] Playing');
      }
    } catch (error, stackTrace) {
      debugPrint('[StickyAudioPlayer] Failed to toggle playback: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Audio playback is unavailable right now.';
      });
    }
  }

  Future<void> _seekTo(double positionSeconds) async {
    try {
      await _audioPlayer.seek(
        Duration(milliseconds: (positionSeconds * 1000).round()),
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to seek audio: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    try {
      await _audioPlayer.setSpeed(speed);
      if (!mounted) return;
      setState(() {
        _playbackSpeed = speed;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to update playback speed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to change playback speed.';
      });
    }
  }

  Future<void> _loadAudioSource() async {
    if (widget.audioUrl == null) {
      // Reset state when audio URL disappears (e.g., offline detail still loading)
      _audioPlayer.stop();
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _currentPosition = 0.0;
        _loadedDuration = null;
        _errorMessage = null;
        _isLoading = false;
        _isBuffering = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('[StickyAudioPlayer] Loading audio from: ${widget.audioUrl}');
      // just_audio's setUrl handles both HTTP URLs and file:// URLs
      final duration = await _audioPlayer.setUrl(widget.audioUrl!);
      if (!mounted) {
        return;
      }
      debugPrint(
          '[StickyAudioPlayer] Audio loaded successfully, duration: $duration');
      setState(() {
        _currentPosition = 0.0;
        _loadedDuration =
            duration != null ? duration.inMilliseconds / 1000.0 : null;
        // Fall back to server-provided duration when audio engine hasn't reported one yet
        _loadedDuration ??= widget.duration;
      });
    } catch (error, stackTrace) {
      debugPrint('[StickyAudioPlayer] Failed to load audio source: $error');
      debugPrint('[StickyAudioPlayer] URL was: ${widget.audioUrl}');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load audio.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _attachPlayerListeners() {
    _startPositionSubscription();

    _durationSubscription =
        _audioPlayer.durationStream.listen((Duration? duration) {
      if (!mounted || duration == null) return;
      setState(() {
        _loadedDuration = duration.inMilliseconds / 1000.0;
      });
    });

    _playerStateSubscription =
        _audioPlayer.playerStateStream.listen((PlayerState state) {
      if (!mounted) return;
      final buffering = state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
      final completed = state.processingState == ProcessingState.completed;

      setState(() {
        _isBuffering = buffering;
        _isPlaying = state.playing && !buffering && !completed;
      });

      if (completed) {
        unawaited(_audioPlayer.seek(Duration.zero));
        unawaited(_audioPlayer.pause());
      }
    });

    _speedSubscription = _audioPlayer.speedStream.listen((double speed) {
      if (!mounted) return;
      setState(() {
        _playbackSpeed = speed;
      });
    });
  }

  void _startPositionSubscription() {
    _positionSubscription?.cancel();
    if (!widget.enablePositionUpdates) {
      _positionSubscription = null;
      return;
    }
    _positionSubscription =
        _audioPlayer.positionStream.listen((Duration position) {
      if (!mounted) return;
      setState(() {
        _currentPosition = position.inMilliseconds / 1000.0;
      });
    });
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final minutes = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

class _AudioLoadingBanner extends StatelessWidget {
  final bool isBuffering;

  const _AudioLoadingBanner({this.isBuffering = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isBuffering ? 'Buffering audio…' : 'Loading audio…',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _AudioErrorBanner extends StatelessWidget {
  final String message;
  final Future<void> Function()? onRetry;

  const _AudioErrorBanner({
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.warning_amber_rounded,
          color: theme.colorScheme.error,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (onRetry != null)
          TextButton(
            onPressed: () => onRetry!(),
            child: const Text('Retry'),
          ),
      ],
    );
  }
}
