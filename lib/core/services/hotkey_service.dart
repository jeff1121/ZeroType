import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../hotkey/global_hotkey_registrar.dart';
import '../hotkey/hotkey_combo.dart';

typedef HotkeyCallback = Future<void> Function();

/// 全域熱鍵的載入、暫停與註冊交易；成功註冊後才提交新設定。
class HotkeyService {
  HotkeyService({
    required SharedPreferences prefs,
    required GlobalHotkeyRegistrar registrar,
    TargetPlatform? platform,
  }) : _prefs = prefs,
       _registrar = registrar,
       platform = platform ?? defaultTargetPlatform,
       _currentCombo = _loadCombo(prefs, platform ?? defaultTargetPlatform);

  final SharedPreferences _prefs;
  final GlobalHotkeyRegistrar _registrar;
  final TargetPlatform platform;

  HotkeyCombo _currentCombo;
  HotkeyCombo? _pendingCombo;
  HotkeyCallback? _onActivated;
  Future<HotkeyRegistrationResult>? _initialization;
  bool _isPaused = true;
  bool _disposed = false;

  /// 已儲存的組合在建構時同步載入，避免設定頁讀到未初始化或過時預設值。
  HotkeyCombo get currentCombo => _currentCombo;
  HotKey get currentHotkey => _currentCombo.toHotKey();
  bool get isPaused => _isPaused;

  void setCallback(HotkeyCallback callback) {
    _onActivated = callback;
  }

  /// 多個呼叫端共用同一個初始化工作，失敗也以結果明確回報。
  Future<HotkeyRegistrationResult> initialize() {
    return _initialization ??= _initialize();
  }

  Future<HotkeyRegistrationResult> _initialize() async {
    final HotkeyCombo fallback = HotkeyCombo.defaultForPlatform(platform);
    if (platform == TargetPlatform.windows) {
      final HotkeyRegistrationResult migrated = await _saveCombo(_currentCombo);
      if (!migrated.isSuccess) return migrated;
    }
    HotkeyRegistrationResult result = await _register(_currentCombo);
    if (!result.isSuccess && _currentCombo != fallback) {
      final HotkeyRegistrationResult originalFailure = result;
      _currentCombo = fallback;
      if (platform == TargetPlatform.windows) {
        final HotkeyRegistrationResult saved = await _saveCombo(fallback);
        if (!saved.isSuccess) return saved;
      }
      result = await _register(fallback);
      if (result.isSuccess && platform == TargetPlatform.macOS) {
        final HotkeyRegistrationResult saved = await _saveCombo(fallback);
        _isPaused = false;
        return saved.isSuccess ? originalFailure : saved;
      }
    }
    if (!result.isSuccess) return result;

    final HotkeyRegistrationResult saved = await _saveCombo(_currentCombo);
    _isPaused = false;
    return saved;
  }

  /// 錄製期間只暫存候選組合，resume 真正註冊成功後才寫入設定。
  Future<HotkeyRegistrationResult> updateHotkey(HotkeyCombo newCombo) async {
    if (_disposed) return const HotkeyRegistrationFailure('熱鍵服務已關閉。');
    final HotkeyParseFailure? invalid = newCombo.validate(platform);
    if (invalid != null) {
      return HotkeyRegistrationFailure(invalid.message, invalid.reason);
    }
    if (_isPaused) {
      _pendingCombo = newCombo;
      return const HotkeyRegistrationSuccess();
    }
    return _replaceCurrent(newCombo);
  }

  Future<HotkeyRegistrationResult> updateHotKeyFromObject(HotKey newKey) async {
    try {
      return await updateHotkey(HotkeyCombo.fromHotKey(newKey));
    } catch (error) {
      return HotkeyRegistrationFailure('無法讀取快捷鍵組合：$error', error);
    }
  }

  Future<HotkeyRegistrationResult> _replaceCurrent(
    HotkeyCombo candidate,
  ) async {
    _isPaused = true;
    HotkeyRegistrationResult result = await _register(candidate);
    if (result.isSuccess) result = await _saveCombo(candidate);
    if (result.isSuccess) {
      _currentCombo = candidate;
      _isPaused = false;
      return result;
    }

    final HotkeyRegistrationResult restored = await _register(_currentCombo);
    _isPaused = !restored.isSuccess;
    return _withRestoreFailure(result, restored);
  }

  /// 先擋住尚在傳遞中的 callback，再解除原生註冊。
  Future<HotkeyRegistrationResult> pause() async {
    if (_disposed) return const HotkeyRegistrationFailure('熱鍵服務已關閉。');
    _isPaused = true;
    try {
      await _registrar.unregisterAll();
      return const HotkeyRegistrationSuccess();
    } catch (error) {
      return HotkeyRegistrationFailure('暫停快捷鍵失敗：$error', error);
    }
  }

  /// 取消錄製時捨棄候選組合；任何註冊失敗都不會被當成恢復成功。
  Future<HotkeyRegistrationResult> resume({bool discardPending = false}) async {
    if (_disposed) return const HotkeyRegistrationFailure('熱鍵服務已關閉。');
    if (discardPending) _pendingCombo = null;
    if (!_isPaused) return const HotkeyRegistrationSuccess();

    final HotkeyCombo? candidate = _pendingCombo;
    _pendingCombo = null;
    if (candidate != null) return _replaceCurrent(candidate);

    final HotkeyRegistrationResult result = await _register(_currentCombo);
    if (result.isSuccess) _isPaused = false;
    return result;
  }

  Future<void> dispose() async {
    _disposed = true;
    _isPaused = true;
    _pendingCombo = null;
    _onActivated = null;
    await _registrar.dispose();
  }

  void _handleTrigger() {
    if (_isPaused || _disposed) return;
    _onActivated?.call();
  }

  Future<HotkeyRegistrationResult> _register(HotkeyCombo combo) async {
    if (_disposed) return const HotkeyRegistrationFailure('熱鍵服務已關閉。');
    try {
      return await _registrar.register(combo, onTrigger: _handleTrigger);
    } catch (error) {
      return HotkeyRegistrationFailure('快捷鍵註冊失敗：$error', error);
    }
  }

  Future<HotkeyRegistrationResult> _saveCombo(HotkeyCombo combo) async {
    final String? previous = _prefs.getString(AppConstants.hotkeyKey);
    Object? failure;
    try {
      final bool saved = await _prefs.setString(
        AppConstants.hotkeyKey,
        jsonEncode(combo.toHotKey().toJson()),
      );
      if (saved) return const HotkeyRegistrationSuccess();
      failure = '偏好設定寫入未成功';
    } catch (error) {
      failure = error;
    }

    // SharedPreferences 先更新快取才寫入平台；失敗時也要回復舊快取。
    try {
      final bool restored = previous == null
          ? await _prefs.remove(AppConstants.hotkeyKey)
          : await _prefs.setString(AppConstants.hotkeyKey, previous);
      if (!restored) {
        return HotkeyRegistrationFailure('儲存快捷鍵失敗，且無法還原原設定：$failure', failure);
      }
    } catch (error) {
      return HotkeyRegistrationFailure(
        '儲存快捷鍵失敗：$failure；還原原設定失敗：$error',
        error,
      );
    }
    return HotkeyRegistrationFailure('儲存快捷鍵失敗：$failure', failure);
  }

  static HotkeyCombo _loadCombo(
    SharedPreferences prefs,
    TargetPlatform platform,
  ) {
    final String? json = prefs.getString(AppConstants.hotkeyKey);
    if (json != null) {
      try {
        final Map<String, dynamic> decoded =
            jsonDecode(json) as Map<String, dynamic>;
        final HotkeyCombo combo = HotkeyCombo.fromHotKey(
          HotKey.fromJson(decoded),
        );
        if (combo.validate(platform) == null) return combo;
        debugPrint('[HotkeyService] 已儲存的熱鍵不適用於此平台，改用預設值。');
      } catch (error) {
        debugPrint('[HotkeyService] 載入熱鍵設定失敗，改用預設值：$error');
      }
    }
    return HotkeyCombo.defaultForPlatform(platform);
  }

  static HotkeyRegistrationResult _withRestoreFailure(
    HotkeyRegistrationResult failure,
    HotkeyRegistrationResult restored,
  ) {
    if (restored is! HotkeyRegistrationFailure) return failure;
    final String reason = (failure as HotkeyRegistrationFailure).message;
    return HotkeyRegistrationFailure(
      '$reason 原快捷鍵也無法恢復：${restored.message}',
      restored.details,
    );
  }
}
