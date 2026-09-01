import 'package:audioplayers/audioplayers.dart';

enum RingtoneKind { incoming, outgoing }

/// Loops a ringback/ringtone sound while a call is ringing, and stops the
/// moment it stops (answered, declined, or ended).
class RingtonePlayer {
  RingtonePlayer() : _player = AudioPlayer() {
    _player.setReleaseMode(ReleaseMode.loop);
  }

  final AudioPlayer _player;
  RingtoneKind? _current;

  Future<void> play(RingtoneKind kind) async {
    if (_current == kind) return;
    _current = kind;
    final asset = switch (kind) {
      RingtoneKind.incoming => 'sounds/incoming_ringtone.mp3',
      RingtoneKind.outgoing => 'sounds/outgoing_ringback.mp3',
    };
    await _player.stop();
    await _player.play(AssetSource(asset));
  }

  Future<void> stop() async {
    if (_current == null) return;
    _current = null;
    await _player.stop();
  }

  Future<void> dispose() => _player.dispose();
}
