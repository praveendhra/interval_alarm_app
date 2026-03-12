import 'package:audioplayers/audioplayers.dart';
import '../models/alarm_model.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _player = AudioPlayer();
  String? _currentlyPlayingId;

  bool get isPlaying => _currentlyPlayingId != null;
  String? get currentlyPlayingId => _currentlyPlayingId;

  /// Play a tune preview — handles both asset and custom file tunes
  Future<void> playTune(AlarmTune tune) async {
    try {
      // If already playing this tune, stop it (toggle)
      if (_currentlyPlayingId == tune.id) {
        await stop();
        return;
      }

      await stop();
      _currentlyPlayingId = tune.id;

      if (tune.isCustom) {
        // Custom tune: play from file system path
        await _player.setSource(DeviceFileSource(tune.assetPath));
      } else {
        // Preloaded tune: play from assets
        await _player.setSource(
          AssetSource(tune.assetPath.replaceFirst('assets/', '')),
        );
      }

      await _player.setVolume(0.7);
      await _player.resume();

      // Auto-stop after 5 seconds for preview
      Future.delayed(const Duration(seconds: 5), () {
        if (_currentlyPlayingId == tune.id) {
          stop();
        }
      });
    } catch (e) {
      _currentlyPlayingId = null;
    }
  }

  /// Stop playback
  Future<void> stop() async {
    _currentlyPlayingId = null;
    await _player.stop();
  }

  void dispose() {
    _player.dispose();
  }
}
