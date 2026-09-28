import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:zero_type/core/hotkey/hotkey_combo.dart';

void main() {
  group('HotkeyCombo 純邏輯測試', () {
    test('空列表失敗', () {
      final result = HotkeyCombo.parse([]);
      expect(result, isA<HotkeyParseFailure>());
      final failure = result as HotkeyParseFailure;
      expect(failure.reason, HotkeyParseFailureReason.empty);
      expect(failure.message, contains('請按下'));
    });

    test('只有 Shift 失敗，原因是只有修飾鍵', () {
      final result = HotkeyCombo.parse([PhysicalKeyboardKey.shiftLeft]);
      expect(result, isA<HotkeyParseFailure>());
      final failure = result as HotkeyParseFailure;
      expect(failure.reason, HotkeyParseFailureReason.modifiersOnly);
      expect(failure.message, contains('請同時按住修飾鍵與一個主鍵'));
    });

    test('左右修飾鍵都視為對應修飾鍵（Alt, Control, Shift, Meta）', () {
      // 左右 Control
      final resCtrlL =
          HotkeyCombo.parse([
                PhysicalKeyboardKey.controlLeft,
                PhysicalKeyboardKey.keyA,
              ], platform: TargetPlatform.macOS)
              as HotkeyParseSuccess;
      final resCtrlR =
          HotkeyCombo.parse([
                PhysicalKeyboardKey.controlRight,
                PhysicalKeyboardKey.keyA,
              ], platform: TargetPlatform.macOS)
              as HotkeyParseSuccess;
      expect(resCtrlL.combo.modifiers, [HotkeyModifierKey.control]);
      expect(resCtrlR.combo.modifiers, [HotkeyModifierKey.control]);

      // 左右 Alt
      final resAltL =
          HotkeyCombo.parse([
                PhysicalKeyboardKey.altLeft,
                PhysicalKeyboardKey.keyA,
              ], platform: TargetPlatform.macOS)
              as HotkeyParseSuccess;
      final resAltR =
          HotkeyCombo.parse([
                PhysicalKeyboardKey.altRight,
                PhysicalKeyboardKey.keyA,
              ], platform: TargetPlatform.macOS)
              as HotkeyParseSuccess;
      expect(resAltL.combo.modifiers, [HotkeyModifierKey.alt]);
      expect(resAltR.combo.modifiers, [HotkeyModifierKey.alt]);

      // 左右 Shift
      final resShiftL =
          HotkeyCombo.parse([
                PhysicalKeyboardKey.shiftLeft,
                PhysicalKeyboardKey.keyA,
              ], platform: TargetPlatform.macOS)
              as HotkeyParseSuccess;
      final resShiftR =
          HotkeyCombo.parse([
                PhysicalKeyboardKey.shiftRight,
                PhysicalKeyboardKey.keyA,
              ], platform: TargetPlatform.macOS)
              as HotkeyParseSuccess;
      expect(resShiftL.combo.modifiers, [HotkeyModifierKey.shift]);
      expect(resShiftR.combo.modifiers, [HotkeyModifierKey.shift]);

      // 左右 Meta
      final resMetaL =
          HotkeyCombo.parse([
                PhysicalKeyboardKey.metaLeft,
                PhysicalKeyboardKey.keyA,
              ], platform: TargetPlatform.macOS)
              as HotkeyParseSuccess;
      final resMetaR =
          HotkeyCombo.parse([
                PhysicalKeyboardKey.metaRight,
                PhysicalKeyboardKey.keyA,
              ], platform: TargetPlatform.macOS)
              as HotkeyParseSuccess;
      expect(resMetaL.combo.modifiers, [HotkeyModifierKey.meta]);
      expect(resMetaR.combo.modifiers, [HotkeyModifierKey.meta]);
    });

    test('Alt+Space 在 macOS 成功，在 Windows 失敗', () {
      final macRes = HotkeyCombo.parse([
        PhysicalKeyboardKey.altLeft,
        PhysicalKeyboardKey.space,
      ], platform: TargetPlatform.macOS);
      expect(macRes, isA<HotkeyParseSuccess>());
      final macCombo = (macRes as HotkeyParseSuccess).combo;
      expect(macCombo.key, PhysicalKeyboardKey.space);
      expect(macCombo.modifiers, [HotkeyModifierKey.alt]);

      final winRes = HotkeyCombo.parse([
        PhysicalKeyboardKey.altLeft,
        PhysicalKeyboardKey.space,
      ], platform: TargetPlatform.windows);
      expect(winRes, isA<HotkeyParseFailure>());
      final winFailure = winRes as HotkeyParseFailure;
      expect(winFailure.reason, HotkeyParseFailureReason.windowsReserved);
    });

    test(
      'Ctrl+Shift+Space 在 Windows 成功，virtual-key 是 32，修飾鍵是 control 與 shift',
      () {
        final result = HotkeyCombo.parse([
          PhysicalKeyboardKey.controlLeft,
          PhysicalKeyboardKey.shiftLeft,
          PhysicalKeyboardKey.space,
        ], platform: TargetPlatform.windows);
        expect(result, isA<HotkeyParseSuccess>());
        final combo = (result as HotkeyParseSuccess).combo;
        expect(combo.key, PhysicalKeyboardKey.space);
        expect(combo.windowsVirtualKey, 32);
        expect(combo.modifierFlags, ['control', 'shift']);
        expect(combo.modifiers, [
          HotkeyModifierKey.control,
          HotkeyModifierKey.shift,
        ]);
      },
    );

    test('Alt+F4、Ctrl+Esc、Ctrl+Alt+Delete 在 Windows 失敗', () {
      // Alt + F4
      final altF4 = HotkeyCombo.parse([
        PhysicalKeyboardKey.altLeft,
        PhysicalKeyboardKey.f4,
      ], platform: TargetPlatform.windows);
      expect(altF4, isA<HotkeyParseFailure>());
      expect(
        (altF4 as HotkeyParseFailure).reason,
        HotkeyParseFailureReason.windowsReserved,
      );

      // Ctrl + Esc
      final ctrlEsc = HotkeyCombo.parse([
        PhysicalKeyboardKey.controlLeft,
        PhysicalKeyboardKey.escape,
      ], platform: TargetPlatform.windows);
      expect(ctrlEsc, isA<HotkeyParseFailure>());
      expect(
        (ctrlEsc as HotkeyParseFailure).reason,
        HotkeyParseFailureReason.windowsReserved,
      );

      // Ctrl + Alt + Delete
      final ctrlAltDel = HotkeyCombo.parse([
        PhysicalKeyboardKey.controlLeft,
        PhysicalKeyboardKey.altLeft,
        PhysicalKeyboardKey.delete,
      ], platform: TargetPlatform.windows);
      expect(ctrlAltDel, isA<HotkeyParseFailure>());
      expect(
        (ctrlAltDel as HotkeyParseFailure).reason,
        HotkeyParseFailureReason.windowsReserved,
      );

      // 含額外修飾鍵的 Ctrl + Alt + Shift + Delete 同樣在 Windows 失敗
      final ctrlAltShiftDel = HotkeyCombo.parse([
        PhysicalKeyboardKey.controlLeft,
        PhysicalKeyboardKey.altLeft,
        PhysicalKeyboardKey.shiftLeft,
        PhysicalKeyboardKey.delete,
      ], platform: TargetPlatform.windows);
      expect(ctrlAltShiftDel, isA<HotkeyParseFailure>());
      expect(
        (ctrlAltShiftDel as HotkeyParseFailure).reason,
        HotkeyParseFailureReason.windowsReserved,
      );
    });

    test('沒有修飾鍵的單一字母在 Windows 失敗，在 macOS 成功', () {
      final winRes = HotkeyCombo.parse([
        PhysicalKeyboardKey.keyA,
      ], platform: TargetPlatform.windows);
      expect(winRes, isA<HotkeyParseFailure>());
      expect(
        (winRes as HotkeyParseFailure).reason,
        HotkeyParseFailureReason.noModifiersOnWindows,
      );

      final macRes = HotkeyCombo.parse([
        PhysicalKeyboardKey.keyA,
      ], platform: TargetPlatform.macOS);
      expect(macRes, isA<HotkeyParseSuccess>());
      final combo = (macRes as HotkeyParseSuccess).combo;
      expect(combo.key, PhysicalKeyboardKey.keyA);
      expect(combo.modifiers, isEmpty);
    });

    test('A 的 virtual-key 是 65，0 是 48，F1 是 112，F12 是 123，Escape 是 27', () {
      expect(
        HotkeyCombo.getWindowsVirtualKey(PhysicalKeyboardKey.keyA),
        equals(65),
      );
      expect(
        HotkeyCombo.getWindowsVirtualKey(PhysicalKeyboardKey.digit0),
        equals(48),
      );
      expect(
        HotkeyCombo.getWindowsVirtualKey(PhysicalKeyboardKey.f1),
        equals(112),
      );
      expect(
        HotkeyCombo.getWindowsVirtualKey(PhysicalKeyboardKey.f12),
        equals(123),
      );
      expect(
        HotkeyCombo.getWindowsVirtualKey(PhysicalKeyboardKey.escape),
        equals(27),
      );
      expect(
        HotkeyCombo.getWindowsVirtualKey(PhysicalKeyboardKey.space),
        equals(32),
      );
    });

    test('完整驗證所有 0-9、A-Z、F1-F12 的 Virtual-Key 數值', () {
      // 0-9
      const digits = [
        PhysicalKeyboardKey.digit0,
        PhysicalKeyboardKey.digit1,
        PhysicalKeyboardKey.digit2,
        PhysicalKeyboardKey.digit3,
        PhysicalKeyboardKey.digit4,
        PhysicalKeyboardKey.digit5,
        PhysicalKeyboardKey.digit6,
        PhysicalKeyboardKey.digit7,
        PhysicalKeyboardKey.digit8,
        PhysicalKeyboardKey.digit9,
      ];
      for (int i = 0; i < digits.length; i++) {
        expect(HotkeyCombo.getWindowsVirtualKey(digits[i]), equals(48 + i));
      }

      // A-Z
      const letters = [
        PhysicalKeyboardKey.keyA,
        PhysicalKeyboardKey.keyB,
        PhysicalKeyboardKey.keyC,
        PhysicalKeyboardKey.keyD,
        PhysicalKeyboardKey.keyE,
        PhysicalKeyboardKey.keyF,
        PhysicalKeyboardKey.keyG,
        PhysicalKeyboardKey.keyH,
        PhysicalKeyboardKey.keyI,
        PhysicalKeyboardKey.keyJ,
        PhysicalKeyboardKey.keyK,
        PhysicalKeyboardKey.keyL,
        PhysicalKeyboardKey.keyM,
        PhysicalKeyboardKey.keyN,
        PhysicalKeyboardKey.keyO,
        PhysicalKeyboardKey.keyP,
        PhysicalKeyboardKey.keyQ,
        PhysicalKeyboardKey.keyR,
        PhysicalKeyboardKey.keyS,
        PhysicalKeyboardKey.keyT,
        PhysicalKeyboardKey.keyU,
        PhysicalKeyboardKey.keyV,
        PhysicalKeyboardKey.keyW,
        PhysicalKeyboardKey.keyX,
        PhysicalKeyboardKey.keyY,
        PhysicalKeyboardKey.keyZ,
      ];
      for (int i = 0; i < letters.length; i++) {
        expect(HotkeyCombo.getWindowsVirtualKey(letters[i]), equals(65 + i));
      }

      // F1-F12
      const fKeys = [
        PhysicalKeyboardKey.f1,
        PhysicalKeyboardKey.f2,
        PhysicalKeyboardKey.f3,
        PhysicalKeyboardKey.f4,
        PhysicalKeyboardKey.f5,
        PhysicalKeyboardKey.f6,
        PhysicalKeyboardKey.f7,
        PhysicalKeyboardKey.f8,
        PhysicalKeyboardKey.f9,
        PhysicalKeyboardKey.f10,
        PhysicalKeyboardKey.f11,
        PhysicalKeyboardKey.f12,
      ];
      for (int i = 0; i < fKeys.length; i++) {
        expect(HotkeyCombo.getWindowsVirtualKey(fKeys[i]), equals(112 + i));
      }
    });

    test('未支援的主鍵（例如方向鍵）取 virtual-key 失敗', () {
      expect(
        HotkeyCombo.getWindowsVirtualKey(PhysicalKeyboardKey.arrowUp),
        isNull,
      );
      expect(
        HotkeyCombo.getWindowsVirtualKey(PhysicalKeyboardKey.arrowDown),
        isNull,
      );

      final result = HotkeyCombo.parse([
        PhysicalKeyboardKey.controlLeft,
        PhysicalKeyboardKey.arrowUp,
      ], platform: TargetPlatform.windows);
      expect(result, isA<HotkeyParseFailure>());
      expect(
        (result as HotkeyParseFailure).reason,
        HotkeyParseFailureReason.unsupportedKey,
      );
    });

    test('Windows 顯示字串含 Ctrl、Alt、Win，不含 Option、不含 ⌘', () {
      final combo = HotkeyCombo(
        key: PhysicalKeyboardKey.space,
        modifiers: [
          HotkeyModifierKey.control,
          HotkeyModifierKey.alt,
          HotkeyModifierKey.meta,
        ],
      );
      final display = combo.getDisplayString(TargetPlatform.windows);
      expect(display, contains('Ctrl'));
      expect(display, contains('Alt'));
      expect(display, contains('Win'));
      expect(display, isNot(contains('Option')));
      expect(display, isNot(contains('⌘')));
      expect(display, isNot(contains('⌃')));
    });

    test('macOS 顯示字串含 ⌥ Option 與 ⌘ Command', () {
      final combo = HotkeyCombo(
        key: PhysicalKeyboardKey.space,
        modifiers: [HotkeyModifierKey.alt, HotkeyModifierKey.meta],
      );
      final display = combo.getDisplayString(TargetPlatform.macOS);
      expect(display, contains('⌥ Option'));
      expect(display, contains('⌘ Command'));
      expect(display, contains('Space'));
    });

    test('預設組合：Windows 是 Ctrl+Shift+Space，macOS 是 Alt+Space', () {
      final winDefault = HotkeyCombo.defaultForPlatform(TargetPlatform.windows);
      expect(winDefault.key, PhysicalKeyboardKey.space);
      expect(winDefault.modifiers, [
        HotkeyModifierKey.control,
        HotkeyModifierKey.shift,
      ]);
      expect(
        winDefault.getDisplayString(TargetPlatform.windows),
        'Ctrl + Shift + Space',
      );

      final macDefault = HotkeyCombo.defaultForPlatform(TargetPlatform.macOS);
      expect(macDefault.key, PhysicalKeyboardKey.space);
      expect(macDefault.modifiers, [HotkeyModifierKey.alt]);
      expect(
        macDefault.getDisplayString(TargetPlatform.macOS),
        '⌥ Option + Space',
      );
    });

    test('多個非修飾鍵時，以最後一個當主鍵', () {
      final result = HotkeyCombo.parse([
        PhysicalKeyboardKey.controlLeft,
        PhysicalKeyboardKey.keyA,
        PhysicalKeyboardKey.keyB,
      ], platform: TargetPlatform.windows);
      expect(result, isA<HotkeyParseSuccess>());
      final combo = (result as HotkeyParseSuccess).combo;
      expect(combo.key, PhysicalKeyboardKey.keyB);
      expect(combo.modifiers, [HotkeyModifierKey.control]);
    });

    test('轉成 HotKey 再轉回，主鍵與修飾鍵相同', () {
      final original = HotkeyCombo(
        key: PhysicalKeyboardKey.keyA,
        modifiers: [HotkeyModifierKey.control, HotkeyModifierKey.shift],
      );
      final hotKey = original.toHotKey();
      expect(hotKey.key, PhysicalKeyboardKey.keyA);
      expect(hotKey.scope, HotKeyScope.system);
      expect(
        hotKey.modifiers,
        containsAll([HotKeyModifier.control, HotKeyModifier.shift]),
      );

      final restored = HotkeyCombo.fromHotKey(hotKey);
      expect(restored.key, original.key);
      expect(restored.modifiers, original.modifiers);
      expect(restored, equals(original));
    });

    test('HotKey.toJson() 再 HotKey.fromJson() 後仍得到同一組主鍵與修飾鍵', () {
      final original = HotkeyCombo(
        key: PhysicalKeyboardKey.space,
        modifiers: [
          HotkeyModifierKey.control,
          HotkeyModifierKey.shift,
          HotkeyModifierKey.alt,
        ],
      );
      final hotKey = original.toHotKey();
      final jsonMap = hotKey.toJson();
      final jsonString = jsonEncode(jsonMap);

      final decodedMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final restoredHotKey = HotKey.fromJson(decodedMap);
      final restoredCombo = HotkeyCombo.fromHotKey(restoredHotKey);

      expect(restoredCombo.key, original.key);
      expect(restoredCombo.modifiers, original.modifiers);
      expect(restoredCombo, equals(original));
    });

    test('保留舊 macOS logical key、Fn、Caps Lock 與 identifier', () {
      final HotKey original = HotKey(
        identifier: 'legacy-hotkey',
        key: LogicalKeyboardKey.keyK,
        modifiers: [
          HotKeyModifier.fn,
          HotKeyModifier.capsLock,
          HotKeyModifier.meta,
        ],
      );
      final HotkeyCombo restored = HotkeyCombo.fromHotKey(
        HotKey.fromJson(
          jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
        ),
      );
      expect(restored.key, PhysicalKeyboardKey.keyK);
      expect(restored.toHotKey().key, LogicalKeyboardKey.keyK);
      expect(restored.toHotKey().identifier, 'legacy-hotkey');
      expect(restored.toHotKey().modifiers, [
        HotKeyModifier.fn,
        HotKeyModifier.capsLock,
        HotKeyModifier.meta,
      ]);
      expect(restored.validate(TargetPlatform.macOS), isNull);
      expect(
        restored.validate(TargetPlatform.windows)?.reason,
        HotkeyParseFailureReason.unsupportedKey,
      );
      expect(restored.getDisplayParts(TargetPlatform.macOS), [
        '⌘ Command',
        'Fn',
        'Caps Lock',
        'K',
      ]);
      expect(
        () => restored.toHotKey().modifiers!.clear(),
        throwsUnsupportedError,
      );
    });

    test('fromHotKey 可處理 null 與重複修飾鍵，組合不可變', () {
      final HotkeyCombo noModifiers = HotkeyCombo.fromHotKey(
        HotKey(key: PhysicalKeyboardKey.keyA),
      );
      expect(noModifiers.modifiers, isEmpty);
      final HotkeyCombo duplicates = HotkeyCombo.fromHotKey(
        HotKey(
          key: PhysicalKeyboardKey.space,
          modifiers: [
            HotKeyModifier.meta,
            HotKeyModifier.alt,
            HotKeyModifier.alt,
            HotKeyModifier.shift,
            HotKeyModifier.control,
          ],
        ),
      );
      expect(duplicates.modifierFlags, ['control', 'shift', 'alt', 'meta']);
      expect(() => duplicates.modifiers.clear(), throwsUnsupportedError);
      expect(duplicates.toHotKey().modifiers, contains(HotKeyModifier.meta));
    });

    test('所有四種修飾鍵的轉換與兩平台顯示名稱', () {
      final HotkeyCombo combo = HotkeyCombo(
        key: PhysicalKeyboardKey.space,
        modifiers: HotkeyModifierKey.values,
      );
      expect(combo.toHotKey().modifiers, [
        HotKeyModifier.control,
        HotKeyModifier.shift,
        HotKeyModifier.alt,
        HotKeyModifier.meta,
      ]);
      expect(combo.modifierFlags, ['control', 'shift', 'alt', 'meta']);
      expect(combo.getDisplayParts(TargetPlatform.windows), [
        'Ctrl',
        'Shift',
        'Alt',
        'Win',
        'Space',
      ]);
      expect(combo.getDisplayParts(TargetPlatform.macOS), [
        '⌃ Control',
        '⇧ Shift',
        '⌥ Option',
        '⌘ Command',
        'Space',
      ]);
      expect(HotkeyModifierKey.fromHotKeyModifier(HotKeyModifier.fn), isNull);
      expect(
        HotkeyModifierKey.fromHotKeyModifier(HotKeyModifier.capsLock),
        isNull,
      );
    });

    test('錄製預覽共用解析與名稱，可顯示只有修飾鍵或最後主鍵', () {
      expect(
        HotkeyCombo.getRecordedDisplayParts([], TargetPlatform.windows),
        isEmpty,
      );
      expect(
        HotkeyCombo.getRecordedDisplayParts([
          PhysicalKeyboardKey.shiftLeft,
        ], TargetPlatform.windows),
        ['Shift'],
      );
      expect(
        HotkeyCombo.getRecordedDisplayParts([
          PhysicalKeyboardKey.metaRight,
          PhysicalKeyboardKey.altRight,
          PhysicalKeyboardKey.controlRight,
          PhysicalKeyboardKey.shiftRight,
          PhysicalKeyboardKey.keyA,
          PhysicalKeyboardKey.keyB,
        ], TargetPlatform.macOS),
        ['⌃ Control', '⇧ Shift', '⌥ Option', '⌘ Command', 'B'],
      );
      expect(
        HotkeyCombo.getRecordedDisplayParts([
          PhysicalKeyboardKey.altLeft,
          PhysicalKeyboardKey.space,
        ]),
        isNotEmpty,
      );
    });

    test('直接建構時仍拒絕修飾鍵主鍵，macOS 不套 Windows 保留規則', () {
      final HotkeyCombo invalid = HotkeyCombo(
        key: PhysicalKeyboardKey.shiftLeft,
        modifiers: [HotkeyModifierKey.control],
      );
      expect(
        invalid.validate(TargetPlatform.macOS)?.reason,
        HotkeyParseFailureReason.modifiersOnly,
      );
      for (final PhysicalKeyboardKey key in [
        PhysicalKeyboardKey.f4,
        PhysicalKeyboardKey.escape,
        PhysicalKeyboardKey.delete,
        PhysicalKeyboardKey.arrowUp,
      ]) {
        expect(
          HotkeyCombo(
            key: key,
            modifiers: HotkeyModifierKey.values,
          ).validate(TargetPlatform.macOS),
          isNull,
        );
      }
      expect(HotkeyCombo.isModifierKey(PhysicalKeyboardKey.keyA), isFalse);
      expect(HotkeyCombo.isModifierKey(PhysicalKeyboardKey.metaRight), isTrue);
      expect(
        HotkeyCombo.isWindowsReserved(
          key: PhysicalKeyboardKey.delete,
          modifiers: [HotkeyModifierKey.alt],
        ),
        isFalse,
      );
      expect(
        HotkeyCombo.isWindowsReserved(
          key: PhysicalKeyboardKey.delete,
          modifiers: [HotkeyModifierKey.control],
        ),
        isFalse,
      );
      expect(
        HotkeyCombo.isWindowsReserved(
          key: PhysicalKeyboardKey.f4,
          modifiers: [HotkeyModifierKey.control],
        ),
        isFalse,
      );
      expect(
        HotkeyCombo.isWindowsReserved(
          key: PhysicalKeyboardKey.escape,
          modifiers: [HotkeyModifierKey.alt],
        ),
        isFalse,
      );
    });

    test('名稱不依賴 debugName，未知鍵仍有穩定識別碼', () {
      expect(HotkeyCombo.getKeyLabel(PhysicalKeyboardKey.keyA), 'A');
      expect(HotkeyCombo.getKeyLabel(PhysicalKeyboardKey.keyZ), 'Z');
      expect(HotkeyCombo.getKeyLabel(PhysicalKeyboardKey.digit0), '0');
      expect(HotkeyCombo.getKeyLabel(PhysicalKeyboardKey.digit9), '9');
      expect(HotkeyCombo.getKeyLabel(PhysicalKeyboardKey.f1), 'F1');
      expect(HotkeyCombo.getKeyLabel(PhysicalKeyboardKey.f12), 'F12');
      expect(HotkeyCombo.getKeyLabel(PhysicalKeyboardKey.space), 'Space');
      expect(HotkeyCombo.getKeyLabel(PhysicalKeyboardKey.escape), 'Esc');
      expect(HotkeyCombo.getKeyLabel(PhysicalKeyboardKey.arrowUp), 'Arrow Up');
      expect(
        HotkeyCombo.getKeyLabel(const PhysicalKeyboardKey(0xffffff)),
        'Key 0xffffff',
      );
    });

    test('預設平台與組合相等性覆蓋含不同主鍵及修飾鍵', () {
      final HotkeyCombo original = HotkeyCombo.defaultForPlatform();
      final HotkeyCombo copy = HotkeyCombo.fromHotKey(original.toHotKey());
      expect(original, same(original));
      expect(original, copy);
      expect(original.hashCode, copy.hashCode);
      expect(original == Object(), isFalse);
      expect(
        original == HotkeyCombo(key: PhysicalKeyboardKey.keyA, modifiers: []),
        isFalse,
      );
      expect(
        original == HotkeyCombo(key: original.key, modifiers: []),
        isFalse,
      );
      expect(original.toString(), original.getDisplayString());
      expect(
        HotkeyCombo.defaultForPlatform(TargetPlatform.linux).modifierFlags,
        ['control', 'shift'],
      );
    });
  });
}
