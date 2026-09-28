import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zero_type/core/di/injection.dart';
import 'package:zero_type/core/hotkey/global_hotkey_registrar.dart';
import 'package:zero_type/core/hotkey/hotkey_combo.dart';
import 'package:zero_type/core/services/hotkey_service.dart';
import 'package:zero_type/features/settings/presentation/controllers/settings_controller.dart';
import 'package:zero_type/features/settings/presentation/controllers/settings_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel permission = MethodChannel('com.zerotype.app/permission');
  const MethodChannel record = MethodChannel('com.llfbandit.record/messages');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late SharedPreferences prefs;
  late FakeHotkeyRegistrar registrar;
  late HotkeyService service;
  late ProviderContainer container;
  late ProviderSubscription<AsyncValue<SettingsState>> subscription;

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    registrar = FakeHotkeyRegistrar();
    messenger.setMockMethodCallHandler(permission, (_) async => true);
    messenger.setMockMethodCallHandler(
      record,
      (MethodCall call) async => call.method == 'hasPermission' ? true : null,
    );
  });

  Future<SettingsController> createController({
    TargetPlatform platform = TargetPlatform.macOS,
    GlobalHotkeyRegistrar? registration,
  }) async {
    service = HotkeyService(
      prefs: prefs,
      registrar: registration ?? registrar,
      platform: platform,
    );
    getIt.registerSingleton<SharedPreferences>(prefs);
    getIt.registerSingleton<HotkeyService>(service);
    container = ProviderContainer();
    subscription = container.listen(settingsControllerProvider, (_, _) {});
    await container.read(settingsControllerProvider.future);
    return container.read(settingsControllerProvider.notifier);
  }

  tearDown(() async {
    subscription.close();
    container.dispose();
    await service.dispose();
    await getIt.reset();
    messenger.setMockMethodCallHandler(permission, null);
    messenger.setMockMethodCallHandler(record, null);
  });

  test('真實 build 等候延遲初始化，不會讀到空值或預設熱鍵快照', () async {
    final HotkeyCombo custom = HotkeyCombo(
      key: PhysicalKeyboardKey.keyK,
      modifiers: [HotkeyModifierKey.meta],
    );
    await prefs.setString(
      'global_hotkey',
      jsonEncode(custom.toHotKey().toJson()),
    );
    final DelayedRegistrar delayed = DelayedRegistrar();
    final Future<SettingsController> pending = createController(
      registration: delayed,
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(settingsControllerProvider).isLoading, isTrue);
    expect(service.currentCombo, custom);
    delayed.ready.complete(const HotkeyRegistrationSuccess());
    await pending;
    final SettingsState state = container
        .read(settingsControllerProvider)
        .value!;
    expect(HotkeyCombo.fromHotKey(state.hotkey), custom);
    expect(state.isAccessibilityAuthorized, isTrue);
    expect(state.isMicrophoneAuthorized, isTrue);
    expect(delayed.registrations, 1);
  });

  test('初始化註冊失敗不會讓整個設定頁變 AsyncError', () async {
    registrar.nextResult = const HotkeyRegistrationFailure('macOS 熱鍵被占用');
    await createController();
    final AsyncValue<SettingsState> value = container.read(
      settingsControllerProvider,
    );
    expect(value.hasError, isFalse);
    expect(value.hasValue, isTrue);
    expect(service.isPaused, isTrue);
  });

  for (final TargetPlatform platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
  ]) {
    test('$platform 錄製、儲存後恢復原生註冊且 callback 可觸發', () async {
      final SettingsController controller = await createController(
        platform: platform,
      );
      int activated = 0;
      service.setCallback(() async => activated++);
      expect((await controller.startRecordingHotkey()).isSuccess, isTrue);
      expect(service.isPaused, isTrue);
      expect(
        container.read(settingsControllerProvider).value!.isRecordingHotkey,
        isTrue,
      );
      final HotkeyRegistrationResult result = await controller.saveHotkey([
        PhysicalKeyboardKey.controlLeft,
        PhysicalKeyboardKey.shiftLeft,
        PhysicalKeyboardKey.keyK,
      ]);
      expect(result.isSuccess, isTrue);
      expect(service.isPaused, isFalse);
      expect(registrar.registeredCombo, service.currentCombo);
      expect(service.currentCombo.key, PhysicalKeyboardKey.keyK);
      expect(
        container.read(settingsControllerProvider).value!.isRecordingHotkey,
        isFalse,
      );
      registrar.trigger();
      expect(activated, 1);
    });
  }

  test('新鍵被占用時不改徽章與 preferences，恢復舊鍵並回傳錯誤', () async {
    final SettingsController controller = await createController();
    final HotkeyCombo original = service.currentCombo;
    final String? saved = prefs.getString('global_hotkey');
    await controller.startRecordingHotkey();
    registrar.nextResult = const HotkeyRegistrationFailure('註冊失敗 1409');
    final HotkeyRegistrationResult result = await controller.saveHotkey([
      PhysicalKeyboardKey.metaLeft,
      PhysicalKeyboardKey.keyK,
    ]);
    expect((result as HotkeyRegistrationFailure).message, contains('1409'));
    expect(service.isPaused, isFalse);
    expect(registrar.registeredCombo, original);
    expect(prefs.getString('global_hotkey'), saved);
    final SettingsState current = container
        .read(settingsControllerProvider)
        .value!;
    expect(current.isRecordingHotkey, isFalse);
    expect(HotkeyCombo.fromHotKey(current.hotkey), original);
  });

  test('只有修飾鍵與 Windows 保留鍵失敗時恢復原鍵，不提交候選組合', () async {
    final SettingsController controller = await createController(
      platform: TargetPlatform.windows,
    );
    final HotkeyCombo original = service.currentCombo;
    final String? saved = prefs.getString('global_hotkey');
    for (final List<PhysicalKeyboardKey> keys in [
      [PhysicalKeyboardKey.shiftLeft],
      [PhysicalKeyboardKey.altLeft, PhysicalKeyboardKey.space],
    ]) {
      await controller.startRecordingHotkey();
      final HotkeyRegistrationResult result = await controller.saveHotkey(keys);
      expect(result.isSuccess, isFalse);
      expect(service.currentCombo, original);
      expect(service.isPaused, isFalse);
      expect(registrar.registeredCombo, original);
      expect(prefs.getString('global_hotkey'), saved);
      expect(
        container.read(settingsControllerProvider).value!.isRecordingHotkey,
        isFalse,
      );
    }
  });

  test('取消恢復失敗時保持錄製覆蓋狀態，重試成功才關閉', () async {
    final SettingsController controller = await createController();
    await controller.startRecordingHotkey();
    registrar.nextResult = const HotkeyRegistrationFailure('恢復原鍵失敗');
    expect((await controller.stopRecordingHotkey()).isSuccess, isFalse);
    expect(service.isPaused, isTrue);
    expect(
      container.read(settingsControllerProvider).value!.isRecordingHotkey,
      isTrue,
    );
    expect((await controller.stopRecordingHotkey()).isSuccess, isTrue);
    expect(service.isPaused, isFalse);
    expect(
      container.read(settingsControllerProvider).value!.isRecordingHotkey,
      isFalse,
    );
  });

  test('開始錄製暫停失敗時恢復舊鍵，不能留下不可用的全域熱鍵', () async {
    final FailingPauseRegistrar failing = FailingPauseRegistrar();
    final SettingsController controller = await createController(
      registration: failing,
    );
    final HotkeyCombo original = service.currentCombo;
    int activated = 0;
    service.setCallback(() async => activated++);
    failing.failNextPause = true;
    final HotkeyRegistrationResult result = await controller
        .startRecordingHotkey();
    expect((result as HotkeyRegistrationFailure).message, contains('暫停快捷鍵失敗'));
    expect(service.isPaused, isFalse);
    expect(failing.registeredCombo, original);
    expect(
      container.read(settingsControllerProvider).value!.isRecordingHotkey,
      isFalse,
    );
    failing.trigger();
    expect(activated, 1);
  });

  test('開始錄製暫停與舊鍵恢復皆失敗時提供錄製覆蓋層讓使用者重試', () async {
    final FailingPauseRegistrar failing = FailingPauseRegistrar();
    final SettingsController controller = await createController(
      registration: failing,
    );
    failing.failNextPause = true;
    failing.nextResult = const HotkeyRegistrationFailure('舊鍵註冊失敗 1409');
    final HotkeyRegistrationResult result = await controller
        .startRecordingHotkey();
    final String message = (result as HotkeyRegistrationFailure).message;
    expect(message, contains('暫停快捷鍵失敗'));
    expect(message, contains('舊鍵註冊失敗 1409'));
    expect(service.isPaused, isTrue);
    expect(
      container.read(settingsControllerProvider).value!.isRecordingHotkey,
      isTrue,
    );
    expect((await controller.stopRecordingHotkey()).isSuccess, isTrue);
    expect(service.isPaused, isFalse);
    expect(
      container.read(settingsControllerProvider).value!.isRecordingHotkey,
      isFalse,
    );
  });

  test('錄製中刷新權限不會查詢原生通道或清掉錄製狀態', () async {
    final SettingsController controller = await createController();
    await controller.startRecordingHotkey();
    int permissionChecks = 0;
    messenger.setMockMethodCallHandler(permission, (_) async {
      permissionChecks++;
      return false;
    });
    await controller.refreshPermissions();
    expect(permissionChecks, 0);
    expect(
      container.read(settingsControllerProvider).value!.isRecordingHotkey,
      isTrue,
    );
  });
}

class FailingPauseRegistrar extends FakeHotkeyRegistrar {
  bool failNextPause = false;

  @override
  Future<void> unregisterAll() async {
    if (failNextPause) {
      failNextPause = false;
      throw StateError('原生解除失敗');
    }
    await super.unregisterAll();
  }
}

class DelayedRegistrar extends GlobalHotkeyRegistrar {
  final Completer<HotkeyRegistrationResult> ready =
      Completer<HotkeyRegistrationResult>();
  int registrations = 0;

  @override
  Future<HotkeyRegistrationResult> register(
    HotkeyCombo combo, {
    required HotkeyTriggerCallback onTrigger,
  }) {
    registrations++;
    return ready.future;
  }

  @override
  Future<void> unregisterAll() async {}
}
