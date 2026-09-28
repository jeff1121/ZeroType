import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zero_type/core/window/window_chrome_policy.dart';

void main() {
  group('WindowChromePolicy 視窗外觀策略', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('Windows 平台：原生標題列、不顯示假標題、攔截關閉', () {
      final policy = WindowChromePolicy.fromPlatform(TargetPlatform.windows);
      expect(policy.titleBarStyle, TitleBarStyle.normal);
      expect(policy.showInAppHeader, isFalse);
      expect(policy.preventClose, isTrue);
    });

    test('macOS 平台：隱藏標題列、顯示假標題、攔截關閉', () {
      final policy = WindowChromePolicy.fromPlatform(TargetPlatform.macOS);
      expect(policy.titleBarStyle, TitleBarStyle.hidden);
      expect(policy.showInAppHeader, isTrue);
      expect(policy.preventClose, isTrue);
    });

    test('Linux 平台：不會被誤判為 Windows，隱藏標題列並攔截關閉', () {
      final policy = WindowChromePolicy.fromPlatform(TargetPlatform.linux);
      expect(policy.titleBarStyle, TitleBarStyle.hidden);
      expect(policy.showInAppHeader, isTrue);
      expect(policy.preventClose, isTrue);
    });

    test('其他平台分支覆蓋（android、iOS、fuchsia）', () {
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.fuchsia,
      ]) {
        final policy = WindowChromePolicy.fromPlatform(platform);
        expect(policy.titleBarStyle, TitleBarStyle.hidden);
        expect(policy.showInAppHeader, isTrue);
        expect(policy.preventClose, isTrue);
      }
    });

    test('current() 支援 debugDefaultTargetPlatformOverride 翻轉平台', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final winPolicy = WindowChromePolicy.current();
      expect(winPolicy.titleBarStyle, TitleBarStyle.normal);
      expect(winPolicy.showInAppHeader, isFalse);
      expect(winPolicy.preventClose, isTrue);

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final macPolicy = WindowChromePolicy.current();
      expect(macPolicy.titleBarStyle, TitleBarStyle.hidden);
      expect(macPolicy.showInAppHeader, isTrue);
      expect(macPolicy.preventClose, isTrue);
    });

    test('current() 傳入明確平台參數優先於環境預設', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final policy = WindowChromePolicy.current(TargetPlatform.windows);
      expect(policy.titleBarStyle, TitleBarStyle.normal);
      expect(policy.showInAppHeader, isFalse);
      expect(policy.preventClose, isTrue);
    });
  });
}
