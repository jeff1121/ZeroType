import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zero_type/core/hotkey/global_hotkey_registrar.dart';
import 'package:zero_type/core/hotkey/hotkey_combo.dart';
import 'package:zero_type/core/services/hotkey_service.dart';

void main() {
  group('HotkeyService 單元測試', () {
    late FakeHotkeyRegistrar fakeRegistrar;

    setUp(() {
      fakeRegistrar = FakeHotkeyRegistrar();
    });

    test('暫停更新在註冊成功前不得覆寫已確認的熱鍵與持久化', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = HotkeyService(
        prefs: prefs,
        registrar: fakeRegistrar,
        platform: TargetPlatform.macOS,
      );
      await service.initialize();
      final original = service.currentCombo;
      final persisted = prefs.getString('global_hotkey');
      await service.pause();
      await service.updateHotkey(
        HotkeyCombo(
          key: PhysicalKeyboardKey.keyK,
          modifiers: [HotkeyModifierKey.meta],
        ),
      );
      expect(service.currentCombo, original);
      expect(prefs.getString('global_hotkey'), persisted);
      final result = await service.resume();
      expect(result.isSuccess, isTrue);
      expect(service.currentCombo.key, PhysicalKeyboardKey.keyK);
      expect(fakeRegistrar.registeredCombo, service.currentCombo);
      expect(prefs.getString('global_hotkey'), isNot(persisted));
    });

    test('沒有舊資料時，macOS 預設註冊 Alt+Space', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final service = HotkeyService(
        prefs: prefs,
        registrar: fakeRegistrar,
        platform: TargetPlatform.macOS,
      );

      await service.initialize();

      expect(service.currentCombo.key, PhysicalKeyboardKey.space);
      expect(service.currentCombo.modifiers, [HotkeyModifierKey.alt]);
      expect(fakeRegistrar.registeredCombo, service.currentCombo);
      expect(fakeRegistrar.calls, contains('register: ⌥ Option + Space'));
    });

    test('沒有舊資料時，Windows 預設註冊 Ctrl+Shift+Space', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final service = HotkeyService(
        prefs: prefs,
        registrar: fakeRegistrar,
        platform: TargetPlatform.windows,
      );

      await service.initialize();

      expect(service.currentCombo.key, PhysicalKeyboardKey.space);
      expect(service.currentCombo.modifiers, [
        HotkeyModifierKey.control,
        HotkeyModifierKey.shift,
      ]);
      expect(fakeRegistrar.registeredCombo, service.currentCombo);
      expect(
        service.currentCombo.getDisplayString(TargetPlatform.windows),
        'Ctrl + Shift + Space',
      );
    });

    test(
      'Windows 舊資料是 Alt+Space 時，不註冊 Alt+Space，改註冊並存下 Ctrl+Shift+Space',
      () async {
        final altSpaceHotKey = HotKey(
          key: PhysicalKeyboardKey.space,
          modifiers: [HotKeyModifier.alt],
          scope: HotKeyScope.system,
        );
        SharedPreferences.setMockInitialValues({
          'global_hotkey': jsonEncode(altSpaceHotKey.toJson()),
        });
        final prefs = await SharedPreferences.getInstance();

        final service = HotkeyService(
          prefs: prefs,
          registrar: fakeRegistrar,
          platform: TargetPlatform.windows,
        );

        await service.initialize();

        // 不得對 Alt+Space 呼叫註冊
        expect(fakeRegistrar.calls, isNot(contains('register: Alt + Space')));
        expect(
          fakeRegistrar.calls,
          isNot(contains('register: ⌥ Option + Space')),
        );

        // 應改為 Ctrl+Shift+Space
        expect(service.currentCombo.key, PhysicalKeyboardKey.space);
        expect(service.currentCombo.modifiers, [
          HotkeyModifierKey.control,
          HotkeyModifierKey.shift,
        ]);
        expect(fakeRegistrar.registeredCombo, service.currentCombo);

        // preferences 也被更新儲存為 Ctrl+Shift+Space
        final savedJson = prefs.getString('global_hotkey');
        expect(savedJson, isNotNull);
        final savedMap = jsonDecode(savedJson!) as Map<String, dynamic>;
        final restored = HotkeyCombo.fromHotKey(HotKey.fromJson(savedMap));
        expect(restored.modifiers, [
          HotkeyModifierKey.control,
          HotkeyModifierKey.shift,
        ]);
      },
    );

    test('updateHotkey 成功：preferences 變成新組合，registrar 最後註冊的是新組合', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final service = HotkeyService(
        prefs: prefs,
        registrar: fakeRegistrar,
        platform: TargetPlatform.windows,
      );
      await service.initialize();

      final newCombo = HotkeyCombo(
        key: PhysicalKeyboardKey.keyK,
        modifiers: [HotkeyModifierKey.control, HotkeyModifierKey.alt],
      );

      final result = await service.updateHotkey(newCombo);
      expect(result.isSuccess, isTrue);
      expect(service.currentCombo, equals(newCombo));
      expect(fakeRegistrar.registeredCombo, equals(newCombo));

      final savedJson = prefs.getString('global_hotkey');
      final savedMap = jsonDecode(savedJson!) as Map<String, dynamic>;
      final restored = HotkeyCombo.fromHotKey(HotKey.fromJson(savedMap));
      expect(restored, equals(newCombo));
    });

    test(
      'updateHotkey 失敗：preferences 仍是舊組合，registrar 最後註冊的是舊組合，失敗原因有回傳',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final service = HotkeyService(
          prefs: prefs,
          registrar: fakeRegistrar,
          platform: TargetPlatform.windows,
        );
        await service.initialize();

        final originalCombo = service.currentCombo;

        // 模擬下一次註冊失敗
        fakeRegistrar.nextResult = const HotkeyRegistrationFailure('系統熱鍵已被占用');

        final newCombo = HotkeyCombo(
          key: PhysicalKeyboardKey.keyK,
          modifiers: [HotkeyModifierKey.control, HotkeyModifierKey.alt],
        );

        final result = await service.updateHotkey(newCombo);
        expect(result.isSuccess, isFalse);
        expect(
          (result as HotkeyRegistrationFailure).message,
          contains('系統熱鍵已被占用'),
        );

        // 目前組合與註冊器還原成原本的組合
        expect(service.currentCombo, equals(originalCombo));
        expect(fakeRegistrar.registeredCombo, equals(originalCombo));
      },
    );

    test(
      'pause 呼叫 unregisterAll，暫停期間 updateHotkey 成功只更新資料，不註冊；resume 才註冊新組合',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final service = HotkeyService(
          prefs: prefs,
          registrar: fakeRegistrar,
          platform: TargetPlatform.windows,
        );
        await service.initialize();

        // 呼叫 pause
        await service.pause();
        expect(service.isPaused, isTrue);
        expect(fakeRegistrar.calls.last, equals('unregisterAll'));
        expect(fakeRegistrar.registeredCombo, isNull);

        // 暫停期間更新熱鍵
        final newCombo = HotkeyCombo(
          key: PhysicalKeyboardKey.keyJ,
          modifiers: [HotkeyModifierKey.control, HotkeyModifierKey.shift],
        );
        final callsCountBefore = fakeRegistrar.calls.length;
        final updateRes = await service.updateHotkey(newCombo);
        expect(updateRes.isSuccess, isTrue);
        expect(service.currentCombo, isNot(equals(newCombo)));
        // 暫停期間不應該對 registrar 呼叫 register
        expect(fakeRegistrar.calls.length, equals(callsCountBefore));
        expect(fakeRegistrar.registeredCombo, isNull);

        // 呼叫 resume
        await service.resume();
        expect(service.isPaused, isFalse);
        expect(fakeRegistrar.registeredCombo, equals(newCombo));
        expect(
          fakeRegistrar.registeredCombo?.getDisplayString(
            TargetPlatform.windows,
          ),
          'Ctrl + Shift + J',
        );
      },
    );

    test('resume 在未暫停時不會重複註冊', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final service = HotkeyService(
        prefs: prefs,
        registrar: fakeRegistrar,
        platform: TargetPlatform.windows,
      );
      await service.initialize();

      final callsCount = fakeRegistrar.calls.length;
      await service.resume(); // 目前不是 paused
      expect(fakeRegistrar.calls.length, equals(callsCount));
    });

    test('假 registrar 觸發 callback 時，服務有把呼叫轉給 setCallback 設上的函式', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final service = HotkeyService(
        prefs: prefs,
        registrar: fakeRegistrar,
        platform: TargetPlatform.windows,
      );
      await service.initialize();

      int callbackCount = 0;
      service.setCallback(() async {
        callbackCount++;
      });

      fakeRegistrar.trigger();
      expect(callbackCount, equals(1));

      fakeRegistrar.trigger();
      expect(callbackCount, equals(2));
    });

    test('callback 在暫停期間若仍被呼叫，服務不得再轉給外層', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final service = HotkeyService(
        prefs: prefs,
        registrar: fakeRegistrar,
        platform: TargetPlatform.windows,
      );
      await service.initialize();

      int callbackCount = 0;
      service.setCallback(() async {
        callbackCount++;
      });

      await service.pause();
      expect(service.isPaused, isTrue);

      fakeRegistrar.trigger();
      expect(callbackCount, equals(0)); // 暫停中被擋下
    });

    test('建構時即載入 macOS 已存熱鍵，初始化只註冊一次', () async {
      final combo = HotkeyCombo(
        key: PhysicalKeyboardKey.keyK,
        modifiers: [HotkeyModifierKey.meta],
      );
      SharedPreferences.setMockInitialValues({
        'global_hotkey': jsonEncode(combo.toHotKey().toJson()),
      });
      final prefs = await SharedPreferences.getInstance();
      final registrar = ScriptedRegistrar();
      final pending = Completer<HotkeyRegistrationResult>();
      registrar.pending = pending;
      final service = HotkeyService(
        prefs: prefs,
        registrar: registrar,
        platform: TargetPlatform.macOS,
      );
      expect(service.currentCombo, combo);
      final first = service.initialize();
      final second = service.initialize();
      expect(identical(first, second), isTrue);
      expect(service.currentCombo, combo);
      expect(registrar.attempts, [combo]);
      pending.complete(const HotkeyRegistrationSuccess());
      expect((await first).isSuccess, isTrue);
      expect((await second).isSuccess, isTrue);
      expect(registrar.attempts, [combo]);
    });

    test('壞 JSON 與非法舊鍵皆退回平台預設', () async {
      for (final json in ['{broken', '[]', 'null']) {
        SharedPreferences.setMockInitialValues({'global_hotkey': json});
        final prefs = await SharedPreferences.getInstance();
        final service = HotkeyService(
          prefs: prefs,
          registrar: ScriptedRegistrar(),
          platform: TargetPlatform.macOS,
        );
        expect(
          service.currentCombo,
          HotkeyCombo.defaultForPlatform(TargetPlatform.macOS),
        );
        expect((await service.initialize()).isSuccess, isTrue);
      }
    });

    test('Windows 已存合法鍵註冊失敗，改存並註冊預設；預設失敗仍回報', () async {
      final original = HotkeyCombo(
        key: PhysicalKeyboardKey.keyK,
        modifiers: [HotkeyModifierKey.control],
      );
      for (final fallbackSucceeds in [true, false]) {
        SharedPreferences.setMockInitialValues({
          'global_hotkey': jsonEncode(original.toHotKey().toJson()),
        });
        final prefs = await SharedPreferences.getInstance();
        final registrar = ScriptedRegistrar()
          ..results.add(const HotkeyRegistrationFailure('1409'))
          ..results.add(
            fallbackSucceeds
                ? const HotkeyRegistrationSuccess()
                : const HotkeyRegistrationFailure('預設鍵也被占用 1409'),
          );
        final service = HotkeyService(
          prefs: prefs,
          registrar: registrar,
          platform: TargetPlatform.windows,
        );
        final result = await service.initialize();
        expect(result.isSuccess, fallbackSucceeds);
        expect(service.isPaused, !fallbackSucceeds);
        expect(registrar.attempts, [
          original,
          HotkeyCombo.defaultForPlatform(TargetPlatform.windows),
        ]);
        final saved = HotkeyCombo.fromHotKey(
          HotKey.fromJson(
            jsonDecode(prefs.getString('global_hotkey')!)
                as Map<String, dynamic>,
          ),
        );
        expect(saved, HotkeyCombo.defaultForPlatform(TargetPlatform.windows));
      }
    });

    test('macOS 舊鍵註冊失敗後恢復預設，同時回報原失敗原因', () async {
      final original = HotkeyCombo(
        key: PhysicalKeyboardKey.keyK,
        modifiers: [HotkeyModifierKey.meta],
      );
      SharedPreferences.setMockInitialValues({
        'global_hotkey': jsonEncode(original.toHotKey().toJson()),
      });
      final prefs = await SharedPreferences.getInstance();
      final registrar = ScriptedRegistrar()
        ..results.add(const HotkeyRegistrationFailure('macOS 熱鍵被占用'));
      final service = HotkeyService(
        prefs: prefs,
        registrar: registrar,
        platform: TargetPlatform.macOS,
      );
      final result = await service.initialize();
      expect((result as HotkeyRegistrationFailure).message, contains('被占用'));
      expect(
        service.currentCombo,
        HotkeyCombo.defaultForPlatform(TargetPlatform.macOS),
      );
      expect(registrar.active, service.currentCombo);
      expect(service.isPaused, isFalse);
    });

    test('暫停候選註冊失敗會重新註冊舊鍵，保持原偏好設定並回報原因', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final registrar = ScriptedRegistrar();
      final service = HotkeyService(
        prefs: prefs,
        registrar: registrar,
        platform: TargetPlatform.windows,
      );
      await service.initialize();
      final original = service.currentCombo;
      final saved = prefs.getString('global_hotkey');
      final candidate = HotkeyCombo(
        key: PhysicalKeyboardKey.keyK,
        modifiers: [HotkeyModifierKey.control],
      );
      await service.pause();
      await service.updateHotkey(candidate);
      registrar.results.add(const HotkeyRegistrationFailure('1409'));
      final result = await service.resume();
      expect((result as HotkeyRegistrationFailure).message, contains('1409'));
      expect(service.currentCombo, original);
      expect(service.isPaused, isFalse);
      expect(registrar.active, original);
      expect(registrar.attempts.sublist(1), [candidate, original]);
      expect(prefs.getString('global_hotkey'), saved);
    });

    test('回滾也失敗時維持暫停並回報，不能假裝舊鍵可用', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final registrar = ScriptedRegistrar();
      final service = HotkeyService(
        prefs: prefs,
        registrar: registrar,
        platform: TargetPlatform.windows,
      );
      await service.initialize();
      final saved = prefs.getString('global_hotkey');
      registrar.results.addAll([
        const HotkeyRegistrationFailure('新鍵被占用'),
        const HotkeyRegistrationFailure('舊鍵被占用'),
      ]);
      final result = await service.updateHotkey(
        HotkeyCombo(
          key: PhysicalKeyboardKey.keyK,
          modifiers: [HotkeyModifierKey.control],
        ),
      );
      expect(
        (result as HotkeyRegistrationFailure).message,
        contains('原快捷鍵也無法恢復'),
      );
      expect(service.isPaused, isTrue);
      expect(registrar.active, isNull);
      expect(prefs.getString('global_hotkey'), saved);
    });

    test('取消丟棄候選組合，resume 失敗保留暫停且可重試', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final registrar = ScriptedRegistrar();
      final service = HotkeyService(
        prefs: prefs,
        registrar: registrar,
        platform: TargetPlatform.macOS,
      );
      await service.initialize();
      final original = service.currentCombo;
      await service.pause();
      await service.updateHotkey(
        HotkeyCombo(
          key: PhysicalKeyboardKey.keyK,
          modifiers: [HotkeyModifierKey.meta],
        ),
      );
      registrar.results.add(const HotkeyRegistrationFailure('暫時無法註冊'));
      expect((await service.resume(discardPending: true)).isSuccess, isFalse);
      expect(service.isPaused, isTrue);
      expect((await service.resume()).isSuccess, isTrue);
      expect(service.isPaused, isFalse);
      expect(registrar.active, original);
      expect(registrar.attempts, [original, original, original]);
    });

    test('Windows 保留組合不得繞過 UI 直接送進 registrar', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final registrar = ScriptedRegistrar();
      final service = HotkeyService(
        prefs: prefs,
        registrar: registrar,
        platform: TargetPlatform.windows,
      );
      await service.initialize();
      final result = await service.updateHotkey(
        HotkeyCombo.defaultForPlatform(TargetPlatform.macOS),
      );
      expect(result.isSuccess, isFalse);
      expect(registrar.attempts.length, 1);
    });

    test('dispose 後即使收到舊 callback 也不會觸發', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final registrar = ScriptedRegistrar();
      final service = HotkeyService(
        prefs: prefs,
        registrar: registrar,
        platform: TargetPlatform.macOS,
      );
      int activated = 0;
      service.setCallback(() async => activated++);
      await service.initialize();
      final oldCallback = registrar.callback!;
      await service.dispose();
      oldCallback();
      expect(activated, 0);
      expect((await service.resume()).isSuccess, isFalse);
    });

    test('偏好設定寫入失敗會還原快取、有效熱鍵與原生註冊', () async {
      final prefs = FailingPreferences();
      final registrar = ScriptedRegistrar();
      final service = HotkeyService(
        prefs: prefs,
        registrar: registrar,
        platform: TargetPlatform.macOS,
      );
      await service.initialize();
      final original = service.currentCombo;
      final saved = prefs.getString('global_hotkey');
      prefs.failNext = true;
      final result = await service.updateHotkey(
        HotkeyCombo(
          key: PhysicalKeyboardKey.keyK,
          modifiers: [HotkeyModifierKey.meta],
        ),
      );
      expect(result.isSuccess, isFalse);
      expect(service.currentCombo, original);
      expect(registrar.active, original);
      expect(prefs.getString('global_hotkey'), saved);
    });

    test('解除註冊失敗會回報且重試確實再解除，不假裝成功', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final registrar = ScriptedRegistrar();
      final service = HotkeyService(
        prefs: prefs,
        registrar: registrar,
        platform: TargetPlatform.macOS,
      );
      await service.initialize();
      registrar.failUnregister = true;
      expect((await service.pause()).isSuccess, isFalse);
      expect(registrar.active, isNotNull);
      expect((await service.pause()).isSuccess, isTrue);
      expect(registrar.active, isNull);
    });

    test('dispose 會呼叫 unregisterAll', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final service = HotkeyService(
        prefs: prefs,
        registrar: fakeRegistrar,
        platform: TargetPlatform.windows,
      );
      await service.initialize();

      await service.dispose();
      expect(fakeRegistrar.calls.last, equals('unregisterAll'));
    });
  });
}

/// 模擬 SharedPreferences 先更新快取、平台寫入才回傳失敗。
class FailingPreferences extends Fake implements SharedPreferences {
  String? value;
  bool failNext = false;

  @override
  String? getString(String key) => value;

  @override
  Future<bool> setString(String key, String value) async {
    this.value = value;
    final bool failed = failNext;
    failNext = false;
    return !failed;
  }

  @override
  Future<bool> remove(String key) async {
    value = null;
    return true;
  }
}

/// 每次 register 都先移除舊鍵，忠實模擬原生註冊失敗後沒有有效鍵的狀態。
class ScriptedRegistrar extends GlobalHotkeyRegistrar {
  final Queue<HotkeyRegistrationResult> results =
      Queue<HotkeyRegistrationResult>();
  final List<HotkeyCombo> attempts = <HotkeyCombo>[];
  HotkeyCombo? active;
  HotkeyTriggerCallback? callback;
  Completer<HotkeyRegistrationResult>? pending;
  bool failUnregister = false;

  @override
  Future<HotkeyRegistrationResult> register(
    HotkeyCombo combo, {
    required HotkeyTriggerCallback onTrigger,
  }) async {
    attempts.add(combo);
    active = null;
    callback = onTrigger;
    final HotkeyRegistrationResult result = pending != null
        ? await pending!.future
        : results.isNotEmpty
        ? results.removeFirst()
        : const HotkeyRegistrationSuccess();
    if (result.isSuccess) active = combo;
    return result;
  }

  @override
  Future<void> unregisterAll() async {
    if (failUnregister) {
      failUnregister = false;
      throw StateError('解除註冊失敗');
    }
    active = null;
  }
}
