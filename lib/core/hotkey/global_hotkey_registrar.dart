import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'hotkey_combo.dart';

/// 熱鍵觸發回呼
typedef HotkeyTriggerCallback = void Function();

sealed class HotkeyRegistrationResult {
  const HotkeyRegistrationResult();
  bool get isSuccess => this is HotkeyRegistrationSuccess;
}

class HotkeyRegistrationSuccess extends HotkeyRegistrationResult {
  const HotkeyRegistrationSuccess();
}

/// 失敗原因保留原生錯誤細節，供設定頁與啟動流程顯示。
class HotkeyRegistrationFailure extends HotkeyRegistrationResult {
  final String message;
  final Object? details;

  const HotkeyRegistrationFailure(this.message, [this.details]);

  @override
  String toString() => 'HotkeyRegistrationFailure: $message';
}

abstract class GlobalHotkeyRegistrar {
  Future<HotkeyRegistrationResult> register(
    HotkeyCombo combo, {
    required HotkeyTriggerCallback onTrigger,
  });

  /// 失敗時傳播例外，呼叫端不得假裝已暫停。
  Future<void> unregisterAll();

  Future<void> dispose() => unregisterAll();
}

/// macOS 維持 hotkey_manager 的 system scope 路徑。
class MacosHotkeyRegistrar extends GlobalHotkeyRegistrar {
  final HotKeyManager _manager;

  MacosHotkeyRegistrar({HotKeyManager? manager})
    : _manager = manager ?? hotKeyManager;

  @override
  Future<HotkeyRegistrationResult> register(
    HotkeyCombo combo, {
    required HotkeyTriggerCallback onTrigger,
  }) async {
    final HotkeyParseFailure? failure = combo.validate(TargetPlatform.macOS);
    if (failure != null) {
      return HotkeyRegistrationFailure(failure.message, failure.reason);
    }
    try {
      await _manager.unregisterAll();
      await _manager.register(
        combo.toHotKey(),
        keyDownHandler: (_) => onTrigger(),
      );
      return const HotkeyRegistrationSuccess();
    } catch (error) {
      return HotkeyRegistrationFailure('macOS 熱鍵註冊失敗：$error', error);
    }
  }

  @override
  Future<void> unregisterAll() => _manager.unregisterAll();
}

/// Windows 使用自有 Win32 channel，不經 hotkey_manager 註冊。
class WindowsHotkeyRegistrar extends GlobalHotkeyRegistrar {
  static const String channelName = 'com.zerotype.app/hotkey';
  static const String eventChannelName = 'com.zerotype.app/hotkey_events';
  static const String _failureMessage =
      '這個快捷鍵無法在 Windows 使用（系統保留或已被其他程式占用）。請換一組。';

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  StreamSubscription<dynamic>? _eventSubscription;
  HotkeyTriggerCallback? _currentTrigger;

  WindowsHotkeyRegistrar({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel = methodChannel ?? const MethodChannel(channelName),
       _eventChannel = eventChannel ?? const EventChannel(eventChannelName);

  void _ensureListening() {
    _eventSubscription ??= _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map && event['id'] == 1) {
          _currentTrigger?.call();
        }
      },
      onError: (Object error) {
        _currentTrigger = null;
        debugPrint('[WindowsHotkeyRegistrar] 熱鍵事件通道失敗：$error');
      },
    );
  }

  @override
  Future<HotkeyRegistrationResult> register(
    HotkeyCombo combo, {
    required HotkeyTriggerCallback onTrigger,
  }) async {
    final HotkeyParseFailure? failure = combo.validate(TargetPlatform.windows);
    if (failure != null) {
      return HotkeyRegistrationFailure(failure.message, failure.reason);
    }

    // 原生層先解除舊組合；新組合確認註冊前不轉發任何排隊中的事件。
    _currentTrigger = null;
    try {
      _ensureListening();
      final bool? registered = await _methodChannel.invokeMethod<bool>(
        'register',
        {'vk': combo.windowsVirtualKey!, 'modifiers': combo.modifierFlags},
      );
      if (registered != true) {
        return const HotkeyRegistrationFailure(_failureMessage);
      }
      _currentTrigger = onTrigger;
      return const HotkeyRegistrationSuccess();
    } on PlatformException catch (error) {
      return HotkeyRegistrationFailure(
        '$_failureMessage 原因：${error.message ?? error.code}',
        error,
      );
    } catch (error) {
      return HotkeyRegistrationFailure('Windows 熱鍵註冊失敗：$error', error);
    }
  }

  @override
  Future<void> unregisterAll() async {
    _currentTrigger = null;
    await _methodChannel.invokeMethod<void>('unregisterAll');
  }

  @override
  Future<void> dispose() async {
    try {
      await unregisterAll();
    } finally {
      await _eventSubscription?.cancel();
      _eventSubscription = null;
      _currentTrigger = null;
    }
  }
}

/// 測試用假註冊器；失敗亦先失去舊註冊，以符合 Win32 換鍵語意。
class FakeHotkeyRegistrar extends GlobalHotkeyRegistrar {
  HotkeyRegistrationResult nextResult = const HotkeyRegistrationSuccess();
  final List<String> calls = <String>[];
  final List<HotkeyCombo> registrationAttempts = <HotkeyCombo>[];
  HotkeyCombo? registeredCombo;
  HotkeyTriggerCallback? lastTrigger;

  @override
  Future<HotkeyRegistrationResult> register(
    HotkeyCombo combo, {
    required HotkeyTriggerCallback onTrigger,
  }) async {
    calls.add('register: ${combo.getDisplayString()}');
    registrationAttempts.add(combo);
    lastTrigger = onTrigger;
    registeredCombo = null;
    final HotkeyRegistrationResult result = nextResult;
    nextResult = const HotkeyRegistrationSuccess();
    if (result.isSuccess) registeredCombo = combo;
    return result;
  }

  @override
  Future<void> unregisterAll() async {
    calls.add('unregisterAll');
    registeredCombo = null;
  }

  /// 故意允許模擬解除後才抵達的舊 callback，驗證服務的暫停防護。
  void trigger() => lastTrigger?.call();
}
