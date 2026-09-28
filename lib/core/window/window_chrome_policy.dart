import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// 視窗樣式與標題列策略
class WindowChromePolicy {
  /// 視窗標題列樣式（Windows 使用 normal，macOS 使用 hidden）
  final TitleBarStyle titleBarStyle;

  /// 是否在 Flutter 內容區頂端顯示內建假標題（高 44px 的 Zero Type）
  final bool showInAppHeader;

  /// 是否攔截視窗關閉事件並阻止預設關閉動作
  final bool preventClose;

  const WindowChromePolicy({
    required this.titleBarStyle,
    required this.showInAppHeader,
    required this.preventClose,
  });

  /// 依目標平台決定對應的視窗策略
  factory WindowChromePolicy.fromPlatform(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.windows:
        return const WindowChromePolicy(
          titleBarStyle: TitleBarStyle.normal,
          showInAppHeader: false,
          preventClose: true,
        );
      case TargetPlatform.macOS:
        return const WindowChromePolicy(
          titleBarStyle: TitleBarStyle.hidden,
          showInAppHeader: true,
          preventClose: true,
        );
      case TargetPlatform.linux:
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return const WindowChromePolicy(
          titleBarStyle: TitleBarStyle.hidden,
          showInAppHeader: true,
          preventClose: true,
        );
    }
  }

  /// 取得當前環境策略，允許在測試或呼叫端傳入指定平台覆寫
  static WindowChromePolicy current([TargetPlatform? platform]) {
    return WindowChromePolicy.fromPlatform(platform ?? defaultTargetPlatform);
  }
}
