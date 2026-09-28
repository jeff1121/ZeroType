import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_type/core/hotkey/global_hotkey_registrar.dart';
import 'package:zero_type/core/hotkey/hotkey_combo.dart';
import 'package:zero_type/features/settings/presentation/widgets/hotkey_recorder_overlay.dart';

Widget createTestWidget({
  required Future<HotkeyRegistrationResult> Function(List<PhysicalKeyboardKey>)
  onSave,
  required VoidCallback onClose,
  TargetPlatform? platform,
}) {
  return MaterialApp(
    home: Scaffold(
      body: HotkeyRecorderOverlay(
        onSave: onSave,
        onClose: () async {
          onClose();
          return const HotkeyRegistrationSuccess();
        },
        platform: platform,
      ),
    ),
  );
}

void main() {
  group('HotkeyRecorderOverlay Widget 測試', () {
    testWidgets('焦點切換合成放開 Alt 後，下一組錄製不殘留 Alt', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          platform: TargetPlatform.windows,
          onSave: (_) async => const HotkeyRegistrationSuccess(),
          onClose: () {},
        ),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      HardwareKeyboard.instance.handleKeyEvent(
        const KeyUpEvent(
          physicalKey: PhysicalKeyboardKey.altLeft,
          logicalKey: LogicalKeyboardKey.altLeft,
          timeStamp: Duration.zero,
          synthesized: true,
        ),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(find.text('Ctrl + Shift + Space'), findsOneWidget);
      expect(find.textContaining('Alt'), findsNothing);
    });
    testWidgets('700×500 最小視窗下 macOS 長組合不溢出且儲存鈕可點', (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        createTestWidget(
          platform: TargetPlatform.macOS,
          onSave: (_) async => const HotkeyRegistrationSuccess(),
          onClose: () {},
        ),
      );
      final keys = [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.metaLeft,
        LogicalKeyboardKey.space,
      ];
      for (final key in keys) {
        await tester.sendKeyDownEvent(key);
      }
      await tester.pump();
      for (final key in keys.reversed) {
        await tester.sendKeyUpEvent(key);
      }
      expect(tester.takeException(), isNull);
      expect(find.text('儲存設定').hitTestable(), findsOneWidget);
    });
    testWidgets('覆蓋層出現後，按下 Control、Shift、Space，畫面文字包含 Windows 平台標籤且含 Space', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          onSave: (keys) async => const HotkeyRegistrationSuccess(),
          onClose: () {},
          platform: TargetPlatform.windows,
        ),
      );

      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.controlLeft,
        physicalKey: PhysicalKeyboardKey.controlLeft,
      );
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.shiftLeft,
        physicalKey: PhysicalKeyboardKey.shiftLeft,
      );
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.space,
        physicalKey: PhysicalKeyboardKey.space,
      );
      await tester.pump();

      expect(find.textContaining('Ctrl'), findsWidgets);
      expect(find.textContaining('Shift'), findsWidgets);
      expect(find.textContaining('Space'), findsWidgets);
      expect(find.textContaining('Option'), findsNothing);
      expect(find.textContaining('Command'), findsNothing);

      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.space,
        physicalKey: PhysicalKeyboardKey.space,
      );
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.shiftLeft,
        physicalKey: PhysicalKeyboardKey.shiftLeft,
      );
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.controlLeft,
        physicalKey: PhysicalKeyboardKey.controlLeft,
      );
      await tester.pump();
    });

    testWidgets('只按下 Shift 再按儲存，不會成功儲存，找得到失敗文案', (tester) async {
      bool saveCalled = false;
      await tester.pumpWidget(
        createTestWidget(
          onSave: (keys) async {
            saveCalled = true;
            final parsed = HotkeyCombo.parse(
              keys,
              platform: TargetPlatform.windows,
            );
            if (parsed is HotkeyParseFailure) {
              return HotkeyRegistrationFailure(parsed.message, parsed.reason);
            }
            return const HotkeyRegistrationSuccess();
          },
          onClose: () {},
          platform: TargetPlatform.windows,
        ),
      );

      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.shiftLeft,
        physicalKey: PhysicalKeyboardKey.shiftLeft,
      );
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.shiftLeft,
        physicalKey: PhysicalKeyboardKey.shiftLeft,
      );
      await tester.pump();

      final saveButton = find.text('儲存設定');
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(saveCalled, isTrue);
      expect(find.textContaining('請同時按住修飾鍵與一個主鍵'), findsOneWidget);
    });

    testWidgets('只按下 Escape，覆蓋層關閉，沒有儲存', (tester) async {
      bool closeCalled = false;
      bool saveCalled = false;

      await tester.pumpWidget(
        createTestWidget(
          onSave: (keys) async {
            saveCalled = true;
            return const HotkeyRegistrationSuccess();
          },
          onClose: () {
            closeCalled = true;
          },
          platform: TargetPlatform.windows,
        ),
      );

      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.escape,
        physicalKey: PhysicalKeyboardKey.escape,
      );
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.escape,
        physicalKey: PhysicalKeyboardKey.escape,
      );
      await tester.pump();

      expect(closeCalled, isTrue);
      expect(saveCalled, isFalse);
    });

    testWidgets('注入 Windows 平台時，Alt+Space 不能變成已儲存熱鍵，且找得到保留鍵文案', (tester) async {
      HotkeyRegistrationResult? savedResult;

      await tester.pumpWidget(
        createTestWidget(
          onSave: (keys) async {
            final parsed = HotkeyCombo.parse(
              keys,
              platform: TargetPlatform.windows,
            );
            if (parsed is HotkeyParseFailure) {
              savedResult = HotkeyRegistrationFailure(
                parsed.message,
                parsed.reason,
              );
            } else {
              savedResult = const HotkeyRegistrationSuccess();
            }
            return savedResult!;
          },
          onClose: () {},
          platform: TargetPlatform.windows,
        ),
      );

      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.altLeft,
        physicalKey: PhysicalKeyboardKey.altLeft,
      );
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.space,
        physicalKey: PhysicalKeyboardKey.space,
      );
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.space,
        physicalKey: PhysicalKeyboardKey.space,
      );
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.altLeft,
        physicalKey: PhysicalKeyboardKey.altLeft,
      );
      await tester.pump();

      final saveButton = find.text('儲存設定');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(savedResult, isA<HotkeyRegistrationFailure>());
      expect(find.textContaining('這個快捷鍵無法在 Windows 使用'), findsOneWidget);
    });

    testWidgets('注入 macOS 平台時，Alt+Space 的顯示含 Option，且可以被視為合法組合', (
      tester,
    ) async {
      final fakeRegistrar = FakeHotkeyRegistrar();
      HotkeyRegistrationResult? savedResult;

      await tester.pumpWidget(
        createTestWidget(
          onSave: (keys) async {
            final parsed = HotkeyCombo.parse(
              keys,
              platform: TargetPlatform.macOS,
            );
            if (parsed is HotkeyParseFailure) {
              return HotkeyRegistrationFailure(parsed.message, parsed.reason);
            }
            final combo = (parsed as HotkeyParseSuccess).combo;
            savedResult = await fakeRegistrar.register(combo, onTrigger: () {});
            return savedResult!;
          },
          onClose: () {},
          platform: TargetPlatform.macOS,
        ),
      );

      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.altLeft,
        physicalKey: PhysicalKeyboardKey.altLeft,
      );
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.space,
        physicalKey: PhysicalKeyboardKey.space,
      );
      await tester.pump();

      // macOS 應顯示 ⌥ Option 與 Space
      expect(find.textContaining('⌥ Option'), findsWidgets);
      expect(find.textContaining('Space'), findsWidgets);

      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.space,
        physicalKey: PhysicalKeyboardKey.space,
      );
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.altLeft,
        physicalKey: PhysicalKeyboardKey.altLeft,
      );
      await tester.pump();

      final saveButton = find.text('儲存設定');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(savedResult?.isSuccess, isTrue);
      expect(fakeRegistrar.registeredCombo?.key, PhysicalKeyboardKey.space);
      expect(fakeRegistrar.registeredCombo?.modifiers, [HotkeyModifierKey.alt]);
    });

    testWidgets('測試一：組件 dispose 後 handler 不得殘留 (第 1 次)', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          onSave: (keys) async => const HotkeyRegistrationSuccess(),
          onClose: () {},
          platform: TargetPlatform.windows,
        ),
      );

      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyA,
        physicalKey: PhysicalKeyboardKey.keyA,
      );
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.keyA,
        physicalKey: PhysicalKeyboardKey.keyA,
      );
      await tester.pump();

      // 卸載
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('測試二：組件 dispose 後 handler 不得殘留 (第 2 次確認無殘留)', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          onSave: (keys) async => const HotkeyRegistrationSuccess(),
          onClose: () {},
          platform: TargetPlatform.windows,
        ),
      );

      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyB,
        physicalKey: PhysicalKeyboardKey.keyB,
      );
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.keyB,
        physicalKey: PhysicalKeyboardKey.keyB,
      );
      await tester.pump();

      // 畫面上應只有 B，絕不能有前一次的 A
      expect(find.textContaining('B'), findsWidgets);
      expect(find.textContaining('A'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
