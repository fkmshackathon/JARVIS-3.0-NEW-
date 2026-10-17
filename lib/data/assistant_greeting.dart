import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Plays the short greeting voice when the SYNCHRO Assistant is opened.
///
/// Playback is deliberately best-effort: widget tests run without the audio
/// plugins and a device can always fail to play sound, but neither case may
/// stop the assistant panel from opening.
class AssistantGreeting {
  static const String _assetPath = 'sounds/assistant_greeting.mp3';

  AudioPlayer? _player;

  /// Restarts the greeting from the beginning, replacing earlier playback.
  Future<void> play() async {
    try {
      final player = _player ??= AudioPlayer();
      await player.stop();
      await player.play(AssetSource(_assetPath));
    } catch (_) {
      // Audio is decorative here; ignore missing plugins and playback errors.
    }
  }

  void dispose() {
    final player = _player;
    _player = null;
    if (player != null) {
      unawaited(player.dispose().catchError((Object _) {}));
    }
  }
}
