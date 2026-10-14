import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Sfx { correct, wrong, tick, starPop, coin, tap, levelUp }

/// Fire-and-forget sound effects. Every call is safe: if audio is muted,
/// not initialised, or the platform player fails, the app just stays silent.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const _prefKey = 'sound_enabled';
  static const _files = <Sfx, String>{
    Sfx.correct: 'sfx/correct.wav',
    Sfx.wrong: 'sfx/wrong.wav',
    Sfx.tick: 'sfx/tick.wav',
    Sfx.starPop: 'sfx/star_pop.wav',
    Sfx.coin: 'sfx/coin.wav',
    Sfx.tap: 'sfx/tap.wav',
    Sfx.levelUp: 'sfx/level_up.wav',
  };

  final Map<Sfx, AudioPlayer> _players = {};
  final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);
  bool _ready = false;

  /// Call once at startup (main.dart). Never throws.
  Future<void> init() async {
    if (_ready) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled.value = prefs.getBool(_prefKey) ?? true;
      for (final entry in _files.entries) {
        final p = AudioPlayer();
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setSource(AssetSource(entry.value));
        _players[entry.key] = p;
      }
      _ready = true;
    } catch (e) {
      debugPrint('SoundService init failed: $e');
    }
  }

  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (_) {}
  }

  void play(Sfx sfx) {
    if (!enabled.value || !_ready) return;
    final p = _players[sfx];
    if (p == null) return;
    () async {
      try {
        await p.stop();
        await p.resume();
      } catch (e) {
        debugPrint('SoundService play($sfx) failed: $e');
      }
    }();
  }
}
