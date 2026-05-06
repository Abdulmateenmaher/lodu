import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// Centralized service to handle game audio with proper preloading and mobile support.
class AudioService {
  static final Map<String, AudioPlayer> _players = {};
  static bool _isInitialized = false;

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
      // Configure audio context based on platform
      final audioContext = AudioContextConfig(
        respectSilence: false,
        stayAwake: true,
      ).build();

      // Create and preload players for each sound
      for (final soundName in _soundFiles) {
        final player = AudioPlayer();
        await player.setAudioContext(audioContext);

        // Preload the audio asset
        await player.setSource(AssetSource('sounds/$soundName.mp3'));
        await player.setVolume(1.0);
        await player.setReleaseMode(ReleaseMode.stop);

        _players[soundName] = player;
      }

      _isInitialized = true;
      debugPrint('AudioService initialized with ${_players.length} preloaded sounds');
    } catch (e) {
      debugPrint('AudioService initialization error: $e');
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

    try {
      // Stop any current playback and restart
      await player.stop();
      await player.resume();
    } catch (e) {
      debugPrint('Audio play error for $soundName: $e');
    }
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
