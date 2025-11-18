import 'dart:async';
import 'package:flutter_dictation/flutter_dictation.dart';

/// Dictation status enum
enum DictationStatus {
  idle,
  starting,
  listening,
  stopping,
  stopped,
  cancelled,
  error,
}

/// Result from stopping dictation
class DictationStopResult {
  final String transcript;
  final String? audioFilePath;
  final Map<String, dynamic>? metadata;

  const DictationStopResult({
    required this.transcript,
    this.audioFilePath,
    this.metadata,
  });
}

/// Service for handling voice dictation
/// 
/// Wraps the NativeDictationService from the flutter_dictation plugin
/// and provides a stream-based interface for Riverpod state management.
/// 
/// Provides:
/// - Start/stop dictation with initialization
/// - Stream of transcript updates (result stream)
/// - Status stream (idle, starting, listening, stopping, stopped, error)
/// - Audio level stream (for waveform visualization)
/// - Audio file reference when recording stops (when preserveAudio is enabled)
/// - Permission error handling
class DictationService {
  /// Native dictation service instance
  final NativeDictationService _nativeService = NativeDictationService();
  
  /// Stream controller for transcript updates (result stream)
  final _transcriptController = StreamController<String>.broadcast();
  
  /// Stream controller for status updates
  final _statusController = StreamController<DictationStatus>.broadcast();
  
  /// Stream controller for audio level updates (for waveform)
  final _audioLevelController = StreamController<double>.broadcast();
  
  /// Stream controller for errors
  final _errorController = StreamController<String>.broadcast();
  
  /// Current transcript (accumulated from partial + final results)
  String _currentTranscript = '';
  
  /// Current status
  DictationStatus _status = DictationStatus.idle;
  
  /// Whether dictation is currently active
  bool _isActive = false;
  
  /// Current audio level (0.0 to 1.0)
  double _audioLevel = 0.0;
  
  /// Current error message, if any
  String? _errorMessage;
  
  /// Whether the service has been initialized
  bool _isInitialized = false;
  
  /// Whether to use new plugin behavior (gated by feature flag)
  /// When true, enables audio preservation
  final bool useNewPlugin;
  
  /// Completer for waiting on audio file when stopping
  Completer<DictationAudioFile?>? _audioFileCompleter;

  DictationService({this.useNewPlugin = false});

  /// Stream of transcript updates (result stream)
  Stream<String> get transcriptStream => _transcriptController.stream;

  /// Stream of status updates
  Stream<DictationStatus> get statusStream => _statusController.stream;

  /// Stream of audio level updates (0.0 to 1.0)
  Stream<double> get audioLevelStream => _audioLevelController.stream;

  /// Stream of error messages
  Stream<String> get errorStream => _errorController.stream;

  /// Current transcript text
  String get currentTranscript => _currentTranscript;

  /// Current status
  DictationStatus get status => _status;

  /// Whether dictation is currently active
  bool get isActive => _isActive;

  /// Current audio level (0.0 to 1.0)
  double get audioLevel => _audioLevel;

  /// Current error message, if any
  String? get errorMessage => _errorMessage;

  /// Initialize the native dictation service
  /// Should be called before starting to listen
  Future<void> _ensureInitialized() async {
    if (_isInitialized) {
      return;
    }

    try {
      await _nativeService.initialize();
      _isInitialized = true;
    } catch (e) {
      _setError('Failed to initialize dictation: $e');
      rethrow;
    }
  }

  /// Map plugin status string to DictationStatus enum
  DictationStatus _mapStatus(String pluginStatus) {
    switch (pluginStatus.toLowerCase()) {
      case 'ready':
        return DictationStatus.idle;
      case 'listening':
        return DictationStatus.listening;
      case 'stopped':
        return DictationStatus.stopped;
      case 'cancelled':
        return DictationStatus.cancelled;
      case 'error':
      default:
        if (pluginStatus.startsWith('error:')) {
          return DictationStatus.error;
        }
        return DictationStatus.error;
    }
  }

  /// Start dictation
  /// 
  /// Returns true if started successfully, false otherwise
  Future<bool> start() async {
    if (_isActive) {
      return true;
    }

    try {
      _setStatus(DictationStatus.starting);
      _clearError();
      _resetWaveform();
      
      // Ensure service is initialized
      await _ensureInitialized();
      
      // Reset transcript and audio file state
      _currentTranscript = '';
      _audioFileCompleter = Completer<DictationAudioFile?>();
      
      // Configure audio preservation if new plugin is enabled
      final options = useNewPlugin
          ? const DictationSessionOptions(
              preserveAudio: true,
              deleteAudioIfCancelled: false,
            )
          : null;

      // Start listening with callbacks
      await _nativeService.startListening(
        onResult: (text, isFinal) {
          if (isFinal) {
            // Final result: append to transcript
            _currentTranscript = '$_currentTranscript$text '.trim();
          } else {
            // Partial result: update current transcript (replace, don't append)
            // The plugin sends incremental updates
            _currentTranscript = text;
          }
          _transcriptController.add(_currentTranscript);
        },
        onStatus: (status) {
          final mappedStatus = _mapStatus(status);
          _setStatus(mappedStatus);
        },
        onAudioLevel: (level) {
          _audioLevel = level.clamp(0.0, 1.0);
          _audioLevelController.add(_audioLevel);
        },
        onError: (error) {
          _setError(error);
        },
        onAudioFile: (file) {
          // Audio file callback (fires after stopListening completes)
          if (_audioFileCompleter != null && !_audioFileCompleter!.isCompleted) {
            _audioFileCompleter!.complete(file);
          }
        },
        options: options,
      );

      return true;
    } catch (e) {
      _isActive = false;
      _setStatus(DictationStatus.error);
      _setError('Failed to start dictation: $e');
      return false;
    }
  }

  /// Stop dictation
  /// 
  /// Returns a DictationStopResult containing transcript and optionally audio file reference
  Future<DictationStopResult> stop() async {
    if (!_isActive) {
      return DictationStopResult(transcript: _currentTranscript);
    }

    try {
      _setStatus(DictationStatus.stopping);
      
      // Stop listening (this will trigger audioFile callback if preserveAudio was enabled)
      await _nativeService.stopListening();
      
      // Wait for audio file callback if we're preserving audio
      DictationAudioFile? audioFile;
      if (useNewPlugin && _audioFileCompleter != null) {
        try {
          // Wait up to 5 seconds for audio file callback
          audioFile = await _audioFileCompleter!.future.timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          );
        } catch (e) {
          // Timeout or error - continue without audio file
          audioFile = null;
        }
      }
      
      _isActive = false;
      _setStatus(DictationStatus.stopped);
      
      // Build metadata from audio file if available
      Map<String, dynamic>? metadata;
      String? audioFilePath;
      
      if (audioFile != null) {
        audioFilePath = audioFile.path;
        metadata = {
          'duration': audioFile.duration.inMilliseconds / 1000.0, // seconds
          'fileSizeBytes': audioFile.fileSizeBytes,
          'sampleRate': audioFile.sampleRate,
          'channelCount': audioFile.channelCount,
          'wasCancelled': audioFile.wasCancelled,
        };
      }
      
      final result = DictationStopResult(
        transcript: _currentTranscript,
        audioFilePath: audioFilePath,
        metadata: metadata,
      );
      
      // Reset waveform state
      _resetWaveform();
      
      return result;
    } catch (e) {
      _isActive = false;
      _setStatus(DictationStatus.error);
      _setError('Failed to stop dictation: $e');
      return DictationStopResult(transcript: _currentTranscript);
    }
  }

  /// Cancel dictation without getting a result
  Future<void> cancel() async {
    if (!_isActive) {
      return;
    }

    try {
      await _nativeService.cancelListening();
      _isActive = false;
      _setStatus(DictationStatus.cancelled);
      _resetWaveform();
    } catch (e) {
      _isActive = false;
      _setStatus(DictationStatus.error);
      _setError('Failed to cancel dictation: $e');
    }
  }

  /// Clear current transcript
  void clear() {
    _currentTranscript = '';
    _transcriptController.add('');
    _resetWaveform();
  }

  /// Reset waveform state
  void _resetWaveform() {
    _audioLevel = 0.0;
    _audioLevelController.add(0.0);
  }

  /// Set status and emit to stream
  void _setStatus(DictationStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
    
    // Update _isActive based on status
    _isActive = newStatus == DictationStatus.listening || 
                newStatus == DictationStatus.starting;
  }

  /// Set error and emit to stream
  void _setError(String error) {
    _errorMessage = error;
    _errorController.add(error);
    _setStatus(DictationStatus.error);
  }

  /// Clear error
  void _clearError() {
    _errorMessage = null;
  }

  /// Dispose resources
  void dispose() {
    _nativeService.dispose();
    _transcriptController.close();
    _statusController.close();
    _audioLevelController.close();
    _errorController.close();
  }
}
