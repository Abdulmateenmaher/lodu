import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// Centralized service to handle game audio.
class AudioService {
  static void play(String soundName) async {
    final player = AudioPlayer();
    try {
      await player.setAudioContext(
        AudioContextConfig(respectSilence: false).build(),
      );
      await player.play(AssetSource('sounds/$soundName.mp3'));
    } catch (e) {
      debugPrint('Audio play error: $e');
    }
  }
}
