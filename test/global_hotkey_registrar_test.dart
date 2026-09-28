import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:zero_type/core/hotkey/global_hotkey_registrar.dart';
import 'package:zero_type/core/hotkey/hotkey_combo.dart';

class TestHotKeyManager implements HotKeyManager {
  Object? registerError;
  Object? unregisterError;
  HotKey? registered;
  HotKeyHandler? handler;
  final List<String> calls = <String>[];

  @override
  Future<void> register(
    HotKey hotKey, {
    HotKeyHandler? keyDownHandler,
    HotKeyHandler? keyUpHandler,
  }) async {
    calls.add('register');
    if (registerError case final Object error) throw error;
    registered = hotKey;
    handler = keyDownHandler;
  }

  @override
  Future<void> unregisterAll() async {
    calls.add('unregisterAll');
    if (unregisterError case final Object error) throw error;
    registered = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel methods = MethodChannel(
    WindowsHotkeyRegistrar.channelName,
  );
  const MethodChannel events = MethodChannel(
    WindowsHotkeyRegistrar.eventChannelName,
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final HotkeyCombo defaultCombo = HotkeyCombo.defaultForPlatform(
    TargetPlatform.windows,
  );
  late WindowsHotkeyRegistrar registrar;
  late List<MethodCall> methodCalls;
  late List<MethodCall> eventCalls;
  Object? response;
  Object? methodError;

  Future<void> emit(Object? event) async {
    final Completer<void> delivered = Completer<void>();
    messenger.handlePlatformMessage(
      WindowsHotkeyRegistrar.eventChannelName,
      const StandardMethodCodec().encodeSuccessEnvelope(event),
      (_) => delivered.complete(),
    );
    await delivered.future;
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    methodCalls = <MethodCall>[];
    eventCalls = <MethodCall>[];
    response = true;
    methodError = null;
    registrar = WindowsHotkeyRegistrar();
    messenger.setMockMethodCallHandler(methods, (MethodCall call) async {
      methodCalls.add(call);
      if (methodError case final Object error) throw error;
      return call.method == 'register' ? response : null;
    });
    messenger.setMockMethodCallHandler(events, (MethodCall call) async {
      eventCalls.add(call);
      return null;
    });
  });

  tearDown(() async {
    methodError = null;
    await registrar.dispose();
    await Future<void>.delayed(Duration.zero);
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(events, null);
  });

  test('Windows 保留鍵、無修飾鍵與不支援主鍵不會送到原生層', () async {
    for (final HotkeyCombo combo in <HotkeyCombo>[
      HotkeyCombo(
        key: PhysicalKeyboardKey.space,
        modifiers: [HotkeyModifierKey.alt],
      ),
      HotkeyCombo(
        key: PhysicalKeyboardKey.f4,
        modifiers: [HotkeyModifierKey.alt],
      ),
      HotkeyCombo(
        key: PhysicalKeyboardKey.escape,
        modifiers: [HotkeyModifierKey.control],
      ),
      HotkeyCombo(
        key: PhysicalKeyboardKey.delete,
        modifiers: [HotkeyModifierKey.control, HotkeyModifierKey.alt],
      ),
      HotkeyCombo(key: PhysicalKeyboardKey.keyA, modifiers: []),
      HotkeyCombo(
        key: PhysicalKeyboardKey.controlLeft,
        modifiers: [HotkeyModifierKey.shift],
      ),
      HotkeyCombo(
        key: PhysicalKeyboardKey.arrowUp,
        modifiers: [HotkeyModifierKey.control],
      ),
    ]) {
      expect(
        await registrar.register(combo, onTrigger: () {}),
        isA<HotkeyRegistrationFailure>(),
      );
    }
    expect(methodCalls, isEmpty);
    expect(eventCalls, isEmpty);
  });

  test('Windows 成功傳送 vk 與固定順序 flags，只有 id 1 會觸發', () async {
    int count = 0;
    final HotkeyRegistrationResult result = await registrar.register(
      defaultCombo,
      onTrigger: () => count++,
    );
    expect(result.isSuccess, isTrue);
    expect(methodCalls.single.method, 'register');
    expect(methodCalls.single.arguments, {
      'vk': 32,
      'modifiers': ['control', 'shift'],
    });
    await emit({'id': 2});
    await emit('無效事件');
    await emit(null);
    expect(count, 0);
    await emit({'id': 1});
    expect(count, 1);
    await registrar.unregisterAll();
    await emit({'id': 1});
    expect(count, 1);
    expect(methodCalls.last.method, 'unregisterAll');
  });

  test('Windows 回傳 false 或 null 都是失敗且不保留新 callback', () async {
    for (final Object? failedResponse in <Object?>[false, null]) {
      int count = 0;
      response = failedResponse;
      expect(
        await registrar.register(defaultCombo, onTrigger: () => count++),
        isA<HotkeyRegistrationFailure>(),
      );
      await emit({'id': 1});
      expect(count, 0);
    }
  });

  test('Windows PlatformException 保留原生 1409 並顯示繁中原因', () async {
    methodError = PlatformException(
      code: 'hotkey_register_failed',
      message: '1409',
    );
    final HotkeyRegistrationFailure result =
        await registrar.register(defaultCombo, onTrigger: () {})
            as HotkeyRegistrationFailure;
    expect(result.message, contains('1409'));
    expect(result.message, contains('這個快捷鍵無法在 Windows 使用'));
    expect(result.details, isA<PlatformException>());
  });

  test('Windows 無 message 的 PlatformException 仍保留 code', () async {
    methodError = PlatformException(code: 'hotkey_register_failed');
    final HotkeyRegistrationFailure result =
        await registrar.register(defaultCombo, onTrigger: () {})
            as HotkeyRegistrationFailure;
    expect(result.message, contains('hotkey_register_failed'));
  });

  test('Windows 缺少 plugin 會轉為失敗結果', () async {
    methodError = MissingPluginException('測試未載入 plugin');
    expect(
      await registrar.register(defaultCombo, onTrigger: () {}),
      isA<HotkeyRegistrationFailure>(),
    );
  });

  test('解除註冊失敗必須傳給服務，不能假裝已暫停', () async {
    methodError = PlatformException(code: 'unregister_failed', message: '5');
    await expectLater(
      registrar.unregisterAll(),
      throwsA(isA<PlatformException>()),
    );
  });

  test('macOS 仍以 system scope 註冊，並轉發按下事件', () async {
    final TestHotKeyManager manager = TestHotKeyManager();
    final MacosHotkeyRegistrar mac = MacosHotkeyRegistrar(manager: manager);
    int count = 0;
    final HotkeyCombo combo = HotkeyCombo.defaultForPlatform(
      TargetPlatform.macOS,
    );
    expect(
      (await mac.register(combo, onTrigger: () => count++)).isSuccess,
      isTrue,
    );
    expect(manager.calls, ['unregisterAll', 'register']);
    expect(manager.registered!.scope, HotKeyScope.system);
    expect(manager.registered!.modifiers, [HotKeyModifier.alt]);
    manager.handler!(manager.registered!);
    expect(count, 1);
  });

  test('macOS 註冊例外轉為可顯示錯誤；解除例外不吞掉', () async {
    final TestHotKeyManager manager = TestHotKeyManager();
    final MacosHotkeyRegistrar mac = MacosHotkeyRegistrar(manager: manager);
    manager.registerError = StateError('測試衝突');
    final HotkeyRegistrationFailure result =
        await mac.register(defaultCombo, onTrigger: () {})
            as HotkeyRegistrationFailure;
    expect(result.message, contains('macOS 熱鍵註冊失敗'));
    manager.unregisterError = StateError('測試解除失敗');
    await expectLater(mac.unregisterAll(), throwsStateError);
  });

  test('Windows dispose 解除原生註冊並取消 EventChannel listener', () async {
    await registrar.register(defaultCombo, onTrigger: () {});
    await registrar.dispose();
    expect(methodCalls.last.method, 'unregisterAll');
    expect(eventCalls.map((MethodCall call) => call.method), [
      'listen',
      'cancel',
    ]);
  });

  test('Windows event 錯誤後不再轉發舊 callback', () async {
    int count = 0;
    await registrar.register(defaultCombo, onTrigger: () => count++);
    final Completer<void> delivered = Completer<void>();
    messenger.handlePlatformMessage(
      WindowsHotkeyRegistrar.eventChannelName,
      const StandardMethodCodec().encodeErrorEnvelope(
        code: 'stream_failed',
        message: '測試失敗',
      ),
      (_) => delivered.complete(),
    );
    await delivered.future;
    await emit({'id': 1});
    expect(count, 0);
  });

  test('Windows 四種 modifiers 固定序列只傳到自有 channel', () async {
    final HotkeyCombo combo = HotkeyCombo(
      key: PhysicalKeyboardKey.keyZ,
      modifiers: HotkeyModifierKey.values.reversed.toList(),
    );
    expect(
      (await registrar.register(combo, onTrigger: () {})).isSuccess,
      isTrue,
    );
    expect(methodCalls.single.arguments, {
      'vk': 90,
      'modifiers': ['control', 'shift', 'alt', 'meta'],
    });
  });

  test('macOS 拒絕修飾鍵主鍵且 dispose 使用原 manager', () async {
    final TestHotKeyManager manager = TestHotKeyManager();
    final MacosHotkeyRegistrar mac = MacosHotkeyRegistrar(manager: manager);
    final HotkeyCombo invalid = HotkeyCombo(
      key: PhysicalKeyboardKey.altLeft,
      modifiers: [],
    );
    expect(
      await mac.register(invalid, onTrigger: () {}),
      isA<HotkeyRegistrationFailure>(),
    );
    expect(manager.calls, isEmpty);
    await mac.dispose();
    expect(manager.calls, ['unregisterAll']);
  });

  test('假 registrar 失敗消耗一次且會清除有效註冊', () async {
    final FakeHotkeyRegistrar fake = FakeHotkeyRegistrar();
    await fake.register(defaultCombo, onTrigger: () {});
    fake.nextResult = const HotkeyRegistrationFailure('測試衝突');
    expect(
      (await fake.register(defaultCombo, onTrigger: () {})).isSuccess,
      isFalse,
    );
    expect(fake.registeredCombo, isNull);
    expect(
      (await fake.register(defaultCombo, onTrigger: () {})).isSuccess,
      isTrue,
    );
    expect(fake.registeredCombo, defaultCombo);
  });
}
