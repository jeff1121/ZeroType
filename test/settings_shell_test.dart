import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zero_type/core/di/injection.dart';
import 'package:zero_type/core/hotkey/global_hotkey_registrar.dart';
import 'package:zero_type/core/hotkey/hotkey_combo.dart';
import 'package:zero_type/core/router/app_router.dart';
import 'package:zero_type/core/services/hotkey_service.dart';
import 'package:zero_type/core/services/sound_service.dart';
import 'package:zero_type/features/settings/presentation/controllers/settings_controller.dart';
import 'package:zero_type/features/settings/presentation/controllers/settings_state.dart';
import 'package:zero_type/features/settings/presentation/widgets/hotkey_recorder_overlay.dart';
import 'package:zero_type/shared/widgets/main_shell.dart';

class _FailedSettingsController extends SettingsController {
  @override
  Future<SettingsState> build() async => throw StateError('測試載入失敗');

  @override
  Future<void> refreshPermissions() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late FakeHotkeyRegistrar registrar;
  late HotkeyService service;
  int permissionReads = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'has_shown_permission_prompt_v1': true,
    });
    prefs = await SharedPreferences.getInstance();
    registrar = FakeHotkeyRegistrar();
    service = HotkeyService(
      prefs: prefs,
      registrar: registrar,
      platform: TargetPlatform.macOS,
    );
    getIt.registerSingleton<SharedPreferences>(prefs);
    getIt.registerSingleton<HotkeyService>(service);
    getIt.registerSingleton<SoundService>(SoundService(prefs: prefs));
    permissionReads = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.zerotype.app/permission'),
      (call) async {
        permissionReads++;
        return true;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (call) async {
        return call.method == 'hasPermission' ? true : null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (_) async => {
        'appName': 'ZeroType',
        'packageName': 'com.zerotype.zeroType',
        'version': '1.5.3',
        'buildNumber': '9',
        'buildSignature': '',
      },
    );
  });

  tearDown(() async {
    await service.dispose();
    await getIt.reset();
    debugDefaultTargetPlatformOverride = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'com.zerotype.app/permission',
      'com.llfbandit.record/messages',
      'dev.fluttercommunity.plus/package_info',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
  });

  Future<void> mountShell(
    WidgetTester tester,
    TargetPlatform platform, {
    Widget? background,
    bool openSettings = true,
  }) async {
    await getIt.unregister<HotkeyService>();
    service = HotkeyService(
      prefs: prefs,
      registrar: registrar,
      platform: platform,
    );
    getIt.registerSingleton<HotkeyService>(service);
    await tester.binding.setSurfaceSize(const Size(1000, 750));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = RootStackRouter.build(
      routes: [
        AutoRoute(
          page: MainShellRoute.page,
          initial: true,
          children: [
            for (final name in [
              ModelConfigRoute.name,
              PromptRoute.name,
              DictionaryRoute.name,
              HistoryRoute.name,
            ])
              AutoRoute(
                page: PageInfo(
                  name,
                  builder: (_) =>
                      background ?? const Center(child: Text('測試分頁')),
                ),
              ),
            AutoRoute(page: SettingsRoute.page),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router.config())),
    );
    await tester.pumpAndSettle();
    if (openSettings) {
      await tester.tap(find.text('設定'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('錄製期間排除背景焦點，Space 不會啟動背景按鈕', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    int clicks = 0;
    await mountShell(
      tester,
      TargetPlatform.macOS,
      openSettings: false,
      background: Center(
        child: TextButton(
          focusNode: focus,
          onPressed: () {
            clicks++;
          },
          child: const Text('背景按鈕'),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MainShellPage)),
    );
    await container
        .read(settingsControllerProvider.notifier)
        .startRecordingHotkey();
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isFalse);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(clicks, 0);
    await container
        .read(settingsControllerProvider.notifier)
        .stopRecordingHotkey();
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('設定載入失敗有可見原因與重試，不是整頁消失', (tester) async {
    final router = RootStackRouter.build(
      routes: [AutoRoute(page: SettingsRoute.page, initial: true)],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsControllerProvider.overrideWith(
            _FailedSettingsController.new,
          ),
        ],
        child: MaterialApp.router(routerConfig: router.config()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('設定載入失敗'), findsWidgets);
    expect(find.text('重試'), findsOneWidget);
  });

  for (final platform in [TargetPlatform.macOS, TargetPlatform.windows]) {
    testWidgets('${platform.name} 真實 Shell 依平台顯示標題且設定項完整', (tester) async {
      await mountShell(tester, platform);
      expect(find.byType(MainShellPage), findsOneWidget);
      expect(
        find.text('Zero Type'),
        platform == TargetPlatform.macOS ? findsOneWidget : findsNothing,
      );
      expect(find.text('開機啟動'), findsOneWidget);
      expect(find.text('歷史記錄保留時間'), findsOneWidget);
      expect(find.text('最長錄音時間'), findsOneWidget);
      expect(find.text('全局錄音快捷鍵'), findsOneWidget);
      expect(find.text('啟用音效'), findsOneWidget);
      expect(find.text('輔助使用權限'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(platform));
  }

  testWidgets('從設定錄製到儲存實際恢復熱鍵，失敗時保住舊鍵並顯示原因', (tester) async {
    await mountShell(tester, TargetPlatform.macOS);
    await tester.ensureVisible(find.text('全局錄音快捷鍵'));
    await tester.tap(find.text('全局錄音快捷鍵'));
    await tester.pumpAndSettle();
    expect(service.isPaused, isTrue);
    expect(find.byType(HotkeyRecorderOverlay), findsOneWidget);
    final reads = permissionReads;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(permissionReads, reads);
    expect(find.byType(HotkeyRecorderOverlay), findsOneWidget);
    // 全視窗遮罩下，側欄不可點擊。
    expect(find.text('模型').hitTestable(), findsNothing);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    await tester.tap(find.text('儲存設定'));
    await tester.pumpAndSettle();
    expect(find.byType(HotkeyRecorderOverlay), findsNothing);
    expect(service.isPaused, isFalse);
    expect(registrar.registeredCombo?.key, PhysicalKeyboardKey.keyK);
    final saved = prefs.getString('global_hotkey');
    expect(jsonDecode(saved!), isA<Map<String, dynamic>>());
    int activations = 0;
    service.setCallback(() async {
      activations++;
    });
    registrar.trigger();
    expect(activations, 1);

    await tester.tap(find.text('全局錄音快捷鍵'));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyJ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyJ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    registrar.nextResult = const HotkeyRegistrationFailure('測試註冊失敗 1409');
    await tester.tap(find.text('儲存設定'));
    await tester.pumpAndSettle();
    expect(service.currentCombo.key, PhysicalKeyboardKey.keyK);
    expect(prefs.getString('global_hotkey'), saved);
    expect(registrar.registeredCombo?.key, PhysicalKeyboardKey.keyK);
    expect(service.isPaused, isFalse);
    expect(find.textContaining('測試註冊失敗 1409'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('Esc 取消真的移除覆蓋層並恢復舊熱鍵，多次掛載沒有殘留 handler', (tester) async {
    await mountShell(tester, TargetPlatform.macOS);
    for (int i = 0; i < 2; i++) {
      await tester.ensureVisible(find.text('全局錄音快捷鍵'));
      await tester.tap(find.text('全局錄音快捷鍵'));
      await tester.pumpAndSettle();
      expect(service.isPaused, isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(HotkeyRecorderOverlay), findsNothing);
      expect(service.isPaused, isFalse);
      expect(
        registrar.registeredCombo,
        HotkeyCombo.defaultForPlatform(TargetPlatform.macOS),
      );
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
    await tester.pump();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
