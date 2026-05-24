import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// Centralized service to handle game audio with proper preloading and mobile support.
class AudioService {
  static final Map<String, AudioPlayer> _players = {};
  static bool _isInitialized = false;
  static final Map<String, bool> _isPlaying = {}; // Track playing state per sound
  static bool _isOffline = false;

  static const List<String> _soundFiles = [
    'start_game',
    'rolling',
    'six_four',
    'extra_turn',
    'no_move_chance',
    'moving_piece',
    'reach_goal',
    'block_border',
    'hit_piece',
    'wining',
  ];

  /// Initialize audio service with preloaded sounds
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check network status
      _isOffline = !(await _checkNetworkStatus());

      // Configure audio context based on platform
      final audioContext = AudioContextConfig(
        respectSilence: false,
        stayAwake: true,
      ).build();

      // Create and preload players for each sound
      for (final soundName in _soundFiles) {
        final player = AudioPlayer();
        await player.setAudioContext(audioContext);

        // Set release mode to stop for better memory management
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setVolume(1.0);

        // Preload the audio asset with proper source
        try {
          await player.setSource(AssetSource('sounds/$soundName.mp3'));
          _players[soundName] = player;
        } catch (e) {
          debugPrint('Failed to load sound $soundName: $e');
          // Still add player even if load fails - will handle gracefully at play time
          _players[soundName] = player;
        }
      }

      _isInitialized = true;
      debugPrint('AudioService initialized with ${_players.length} preloaded sounds (offline: $_isOffline)');
    } catch (e) {
      debugPrint('AudioService initialization error: $e');
      _isInitialized = true; // Still mark as initialized to allow graceful degradation
    }
  }

  /// Check network connectivity status
  static Future<bool> _checkNetworkStatus() async {
    try {
      // On web, assume online and let service worker handle caching
      // Audio will work from cache even when offline
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Play a sound by name
  static Future<void> play(String soundName) async {
    if (!_isInitialized) {
      await initialize();
    }

    final player = _players[soundName];
    if (player == null) {
      debugPrint('Audio file not found: $soundName');
      return;
    }

    // Prevent overlapping play calls for the same sound
    if (_isPlaying[soundName] == true) {
      return;
    }

    try {
      _isPlaying[soundName] = true;
      await player.stop();
      await player.seek(Duration.zero);
      await player.resume();
    } catch (e) {
      debugPrint('Audio play error for $soundName: $e');
      // Try to reinitialize on error only if we were online (indicating a transient issue)
      if (!_isOffline) {
        // Only attempt reinitialization if we were online
        initialize();
      }
    } finally {
      _isPlaying[soundName] = false;
    }
  }

  /// Stop all currently playing sounds
  static Future<void> stopAll() async {
    for (final player in _players.values) {
      await player.stop();
    }
    _isPlaying.clear();
  }

  /// Dispose all audio players
  static Future<void> dispose() async {
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
    _isInitialized = false;
  }
}
