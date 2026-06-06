import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

/// Centralized service to handle game audio with proper preloading and mobile
/// support. All original logic is preserved — this update only adds:
///   * a per-sound `setMuted` toggle persisted in SharedPreferences
///   * a `Haptics` helper that fires the system vibration on key events
///   * safe-guards so muted/initialised checks don't break the original flow
class AudioService {
  static final Map<String, AudioPlayer> _players = {};
  static bool _isInitialized = false;
  static final Map<String, bool> _isPlaying = {}; // Track playing state per sound
  static bool _isOffline = false;

  // ── New: muted toggle ──────────────────────────────────────────────────
  static const String _kMutedKey = 'audio_muted';
  static bool _isMuted = false;
  static bool get isMuted => _isMuted;
  static ValueNotifier<bool> mutedNotifier = ValueNotifier<bool>(false);

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

      // Restore muted state from prefs (best-effort, never throws)
      try {
        final prefs = await SharedPreferences.getInstance();
        _isMuted = prefs.getBool(_kMutedKey) ?? false;
        mutedNotifier.value = _isMuted;
      } catch (_) {}

      _isInitialized = true;
      debugPrint('AudioService initialized with ${_players.length} preloaded sounds (offline: $_isOffline, muted: $_isMuted)');
    } catch (e) {
      debugPrint('AudioService initialization error: $e');
      _isInitialized = true; // Still mark as initialized to allow graceful degradation
    }
  }

  /// Persisted mute toggle. When muted, `play` is a no-op for audio.
  static Future<void> setMuted(bool value) async {
    _isMuted = value;
    mutedNotifier.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kMutedKey, value);
    } catch (_) {}
    if (value) {
      // Stop any in-flight sounds immediately
      await stopAll();
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

  /// Play a sound by name (with mute check)
  static Future<void> play(String soundName) async {
    if (_isMuted) return; // New: respect mute
    if (!_isInitialized) {
      await initialize();
    }
    if (_isMuted) return; // recheck in case init flipped it

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

/// Lightweight wrapper around `HapticFeedback` so the rest of the app can
/// trigger device haptics without importing `flutter/services` everywhere.
class Haptics {
  Haptics._();

  /// Light tap — used for selectable piece highlights, die selection, etc.
  static Future<void> light() => _safe(HapticFeedback.lightImpact);
  static Future<void> medium() => _safe(HapticFeedback.mediumImpact);
  static Future<void> heavy() => _safe(HapticFeedback.heavyImpact);
  static Future<void> selection() => _safe(HapticFeedback.selectionClick);

  static Future<void> _safe(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (_) {
      // Some platforms (web) may not support haptics; never crash.
    }
  }
}
