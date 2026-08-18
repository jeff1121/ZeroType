import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:zero_type/core/constants/app_constants.dart';

/// 系統音效清單（路徑 → 顯示名稱）
const Map<String, String> kSystemSoundLabels = {
  '/System/Library/PrivateFrameworks/SpeechObjects.framework/Versions/A/Frameworks/DictationServices.framework/Versions/A/Resources/DefaultRecognitionSound.aiff':
      '語音輸入',
  '/System/Library/Sounds/Basso.aiff': 'Basso',
  '/System/Library/Sounds/Blow.aiff': 'Blow',
  '/System/Library/Sounds/Bottle.aiff': 'Bottle',
  '/System/Library/Sounds/Frog.aiff': 'Frog',
  '/System/Library/Sounds/Funk.aiff': 'Funk',
  '/System/Library/Sounds/Glass.aiff': 'Glass',
  '/System/Library/Sounds/Hero.aiff': 'Hero',
  '/System/Library/Sounds/Morse.aiff': 'Morse',
  '/System/Library/Sounds/Ping.aiff': 'Ping',
  '/System/Library/Sounds/Pop.aiff': 'Pop',
  '/System/Library/Sounds/Purr.aiff': 'Purr',
  '/System/Library/Sounds/Sosumi.aiff': 'Sosumi',
  '/System/Library/Sounds/Submarine.aiff': 'Submarine',
  '/System/Library/Sounds/Tink.aiff': 'Tink',
};

const String kDefaultStartSound = '/System/Library/Sounds/Ping.aiff';
const String kDefaultStopSound = '/System/Library/Sounds/Submarine.aiff';
const String kDefaultCancelSound = '/System/Library/Sounds/Basso.aiff';

class SoundService {
  final SharedPreferences _prefs;

  SoundService({required SharedPreferences prefs}) : _prefs = prefs;

  bool get soundEnabled => _prefs.getBool(AppConstants.soundEnabledKey) ?? true;

  String get startSoundPath =>
      _prefs.getString(AppConstants.startSoundKey) ?? kDefaultStartSound;

  String get stopSoundPath =>
      _prefs.getString(AppConstants.stopSoundKey) ?? kDefaultStopSound;

  Future<void> playStartSound() async {
    if (!soundEnabled) return;
    await _play(startSoundPath);
  }

  Future<void> playStopSound() async {
    if (!soundEnabled) return;
    await _play(stopSoundPath);
  }

  Future<void> playCancelSound() async {
    if (!soundEnabled) return;
    await _play(kDefaultCancelSound);
  }

  /// 播放任意路徑的音效（供設定頁預覽使用）
  Future<void> playPreview(String path) async {
    await _play(path);
  }

  /// 暫停背景音樂 (Apple Music & Spotify)
  Future<void> pauseMusic() async {
    if (!Platform.isMacOS) return;
    const script = '''
      tell application "Music"
        if it is running then pause
      end tell
      tell application "Spotify"
        if it is running then pause
      end tell
    ''';
    await Process.run('osascript', ['-e', script]);
  }

  /// 恢復背景音樂 (Apple Music & Spotify)
  Future<void> resumeMusic() async {
    if (!Platform.isMacOS) return;
    const script = '''
      tell application "Music"
        if it is running then play
      end tell
      tell application "Spotify"
        if it is running then play
      end tell
    ''';
    await Process.run('osascript', ['-e', script]);
  }

  static Future<void> _play(String path) async {
    if (!Platform.isMacOS) return;
    try {
      await Process.run('afplay', [path]);
    } catch (_) {
      // 忽略音效錯誤
    }
  }
}
