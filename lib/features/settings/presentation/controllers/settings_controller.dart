import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zero_type/core/constants/app_constants.dart';
import 'package:zero_type/core/di/injection.dart';
import 'package:zero_type/core/hotkey/global_hotkey_registrar.dart';
import 'package:zero_type/core/hotkey/hotkey_combo.dart';
import 'package:zero_type/core/services/hotkey_service.dart';
import 'package:zero_type/core/services/sound_service.dart';
import 'settings_state.dart';

part 'settings_controller.g.dart';

@riverpod
class SettingsController extends _$SettingsController {
  @override
  Future<SettingsState> build() async {
    debugPrint('[SettingsController] Building state...');

    try {
      debugPrint(
        '[SettingsController] Checking if launch at startup is enabled...',
      );
      final isLaunchEnabled =
          getIt<SharedPreferences>().getBool(AppConstants.launchAtStartupKey) ??
          false;

      debugPrint('[SettingsController] Fetching current hotkey...');
      final HotkeyService hotkeyService = getIt<HotkeyService>();
      await hotkeyService.initialize();
      final HotKey hotkey = hotkeyService.currentHotkey;

      debugPrint('[SettingsController] Fetching permissions...');
      final isAccessibilityAuthorized = await _checkAccessibility();
      final isMicrophoneAuthorized = await _checkMicrophone();

      final prefs = getIt<SharedPreferences>();
      final soundEnabled = prefs.getBool(AppConstants.soundEnabledKey) ?? true;
      final startSound =
          prefs.getString(AppConstants.startSoundKey) ?? kDefaultStartSound;
      final stopSound =
          prefs.getString(AppConstants.stopSoundKey) ?? kDefaultStopSound;
      final historyRetentionDays =
          prefs.getInt(AppConstants.historyRetentionDaysKey) ?? 7;
      final maxRecordingMinutes =
          prefs.getInt(AppConstants.maxRecordingMinutesKey) ?? 1;

      debugPrint('[SettingsController] Build complete.');
      return SettingsState(
        launchAtStartup: isLaunchEnabled,
        hotkey: hotkey,
        isAccessibilityAuthorized: isAccessibilityAuthorized,
        isMicrophoneAuthorized: isMicrophoneAuthorized,
        soundEnabled: soundEnabled,
        startSound: startSound,
        stopSound: stopSound,
        historyRetentionDays: historyRetentionDays,
        maxRecordingMinutes: maxRecordingMinutes,
      );
    } catch (e, st) {
      debugPrint('[SettingsController] Error building settings state: $e\n$st');
      rethrow;
    }
  }

  Future<void> toggleLaunchAtStartup(bool value) async {
    debugPrint('[SettingsController] Toggling launchAtStartup to $value...');
    try {
      if (value) {
        await LaunchAtStartup.instance.enable();
      } else {
        await LaunchAtStartup.instance.disable();
      }
    } on MissingPluginException {
      debugPrint(
        '[SettingsController] toggleLaunchAtStartup failed: plugin missing.',
      );
      return;
    } catch (e) {
      debugPrint('[SettingsController] toggleLaunchAtStartup error: $e');
      return;
    }
    await getIt<SharedPreferences>().setBool(
      AppConstants.launchAtStartupKey,
      value,
    );
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.copyWith(launchAtStartup: value));
    }
  }

  bool _isChangingHotkey = false;

  Future<HotkeyRegistrationResult> startRecordingHotkey() async {
    if (_isChangingHotkey || state.value == null) {
      return const HotkeyRegistrationFailure('設定尚未就緒，請稍後再試。');
    }
    if (state.value!.isRecordingHotkey) {
      return const HotkeyRegistrationSuccess();
    }
    _isChangingHotkey = true;
    try {
      final HotkeyService service = getIt<HotkeyService>();
      final HotkeyRegistrationResult result = await service.pause();
      if (result is HotkeyRegistrationFailure) {
        final HotkeyRegistrationResult restored = await service.resume(
          discardPending: true,
        );
        // 暫停失敗不能讓原本可用的熱鍵永遠停用；恢復也失敗時提供重試入口。
        _finishHotkeyRecording(service);
        if (restored is HotkeyRegistrationFailure) {
          return HotkeyRegistrationFailure(
            '${result.message} 原快捷鍵無法恢復：${restored.message}',
            restored.details,
          );
        }
        return result;
      }
      if (ref.mounted) {
        final SettingsState? current = state.value;
        if (current != null) {
          state = AsyncData(current.copyWith(isRecordingHotkey: true));
        }
      }
      return result;
    } finally {
      _isChangingHotkey = false;
    }
  }

  Future<HotkeyRegistrationResult> stopRecordingHotkey() async {
    if (_isChangingHotkey) {
      return const HotkeyRegistrationFailure('快捷鍵正在儲存，請稍後再試。');
    }
    _isChangingHotkey = true;
    try {
      final HotkeyService service = getIt<HotkeyService>();
      final HotkeyRegistrationResult result = await service.resume(
        discardPending: true,
      );
      _finishHotkeyRecording(service);
      return result;
    } finally {
      _isChangingHotkey = false;
    }
  }

  Future<HotkeyRegistrationResult> saveHotkey(
    List<PhysicalKeyboardKey> keys, [
    TargetPlatform? platform,
  ]) async {
    if (_isChangingHotkey || state.value == null) {
      return const HotkeyRegistrationFailure('快捷鍵正在處理，請稍後再試。');
    }
    _isChangingHotkey = true;
    try {
      final HotkeyService service = getIt<HotkeyService>();
      final HotkeyParseResult parsed = HotkeyCombo.parse(
        keys,
        platform: platform ?? service.platform,
      );
      if (parsed is HotkeyParseFailure) {
        final HotkeyRegistrationResult restored = await service.resume(
          discardPending: true,
        );
        _finishHotkeyRecording(service);
        final String recovery = restored is HotkeyRegistrationFailure
            ? ' 原快捷鍵無法恢復：${restored.message}'
            : '';
        return HotkeyRegistrationFailure(
          '${parsed.message}$recovery',
          parsed.reason,
        );
      }

      HotkeyRegistrationResult result = await service.updateHotkey(
        (parsed as HotkeyParseSuccess).combo,
      );
      if (result.isSuccess) {
        // 錄製期間 update 僅暫存候選組合；確認原生註冊後才算儲存成功。
        result = await service.resume();
      } else if (service.isPaused) {
        final HotkeyRegistrationResult restored = await service.resume(
          discardPending: true,
        );
        if (restored is HotkeyRegistrationFailure) {
          result = HotkeyRegistrationFailure(
            '${(result as HotkeyRegistrationFailure).message} '
            '原快捷鍵無法恢復：${restored.message}',
          );
        }
      }
      _finishHotkeyRecording(service);
      return result;
    } finally {
      _isChangingHotkey = false;
    }
  }

  void _finishHotkeyRecording(HotkeyService service) {
    if (!ref.mounted) return;
    final SettingsState? current = state.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          isRecordingHotkey: service.isPaused,
          hotkey: service.currentHotkey,
        ),
      );
    }
  }

  Future<void> toggleSound(bool value) async {
    await getIt<SharedPreferences>().setBool(
      AppConstants.soundEnabledKey,
      value,
    );
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.copyWith(soundEnabled: value));
    }
  }

  Future<void> setStartSound(String path) async {
    await getIt<SharedPreferences>().setString(
      AppConstants.startSoundKey,
      path,
    );
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.copyWith(startSound: path));
    }
  }

  Future<void> setStopSound(String path) async {
    await getIt<SharedPreferences>().setString(AppConstants.stopSoundKey, path);
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.copyWith(stopSound: path));
    }
  }

  Future<void> setHistoryRetentionDays(int days) async {
    await getIt<SharedPreferences>().setInt(
      AppConstants.historyRetentionDaysKey,
      days,
    );
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.copyWith(historyRetentionDays: days));
    }
  }

  Future<void> setMaxRecordingMinutes(int minutes) async {
    await getIt<SharedPreferences>().setInt(
      AppConstants.maxRecordingMinutesKey,
      minutes,
    );
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.copyWith(maxRecordingMinutes: minutes));
    }
  }

  /// 只刷新已載入的權限資料；錄製期間不重新檢查或重建設定。
  Future<void> refreshPermissions() async {
    if (state.value == null || state.value!.isRecordingHotkey) return;
    final bool isAccessibility = await _checkAccessibility();
    final bool isMicrophone = await _checkMicrophone();
    if (!ref.mounted) return;

    final SettingsState? current = state.value;
    if (current == null || current.isRecordingHotkey) return;
    state = AsyncData(
      current.copyWith(
        isAccessibilityAuthorized: isAccessibility,
        isMicrophoneAuthorized: isMicrophone,
      ),
    );
  }

  Future<bool> _checkMicrophone() async {
    final AudioRecorder recorder = AudioRecorder();
    try {
      return await recorder.hasPermission();
    } finally {
      await recorder.dispose();
    }
  }

  Future<bool> _checkAccessibility() async {
    // Windows doesn't require Accessibility permission for SendInput
    if (Platform.isWindows) return true;
    const channel = MethodChannel('com.zerotype.app/permission');
    try {
      return await channel.invokeMethod<bool>('checkAccessibility') ?? false;
    } catch (e) {
      debugPrint('[SettingsController] checkAccessibility error: $e');
      return false;
    }
  }
}
