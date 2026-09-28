import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

/// 支援的修飾鍵列舉
enum HotkeyModifierKey {
  control,
  shift,
  alt,
  meta;

  /// 固定格式修飾鍵字串（傳遞給原生層或比對使用）
  String get flagName {
    switch (this) {
      case HotkeyModifierKey.control:
        return 'control';
      case HotkeyModifierKey.shift:
        return 'shift';
      case HotkeyModifierKey.alt:
        return 'alt';
      case HotkeyModifierKey.meta:
        return 'meta';
    }
  }

  /// 轉換為 hotkey_manager 的 HotKeyModifier
  HotKeyModifier toHotKeyModifier() {
    switch (this) {
      case HotkeyModifierKey.control:
        return HotKeyModifier.control;
      case HotkeyModifierKey.shift:
        return HotKeyModifier.shift;
      case HotkeyModifierKey.alt:
        return HotKeyModifier.alt;
      case HotkeyModifierKey.meta:
        return HotKeyModifier.meta;
    }
  }

  /// 從 hotkey_manager 的 HotKeyModifier 轉換
  static HotkeyModifierKey? fromHotKeyModifier(HotKeyModifier modifier) {
    switch (modifier) {
      case HotKeyModifier.control:
        return HotkeyModifierKey.control;
      case HotKeyModifier.shift:
        return HotkeyModifierKey.shift;
      case HotKeyModifier.alt:
        return HotkeyModifierKey.alt;
      case HotKeyModifier.meta:
        return HotkeyModifierKey.meta;
      default:
        return null;
    }
  }
}

/// 解析熱鍵組合失敗的原因
enum HotkeyParseFailureReason {
  /// 未按任何鍵
  empty,

  /// 只有修飾鍵，缺少主鍵
  modifiersOnly,

  /// Windows 上缺少修飾鍵
  noModifiersOnWindows,

  /// Windows 系統保留或衝突熱鍵組合
  windowsReserved,

  /// 不支援的主鍵（無法對應到合法 Virtual-Key）
  unsupportedKey,
}

/// 熱鍵解析結果封裝
sealed class HotkeyParseResult {
  const HotkeyParseResult();
}

/// 解析成功
class HotkeyParseSuccess extends HotkeyParseResult {
  final HotkeyCombo combo;
  const HotkeyParseSuccess(this.combo);
}

/// 解析失敗
class HotkeyParseFailure extends HotkeyParseResult {
  final HotkeyParseFailureReason reason;
  final String message;
  const HotkeyParseFailure(this.reason, this.message);
}

/// 純邏輯熱鍵組合，不直接依賴原生 channel
class HotkeyCombo {
  /// 主鍵（如 Space、A、F1）
  final PhysicalKeyboardKey key;

  /// 修飾鍵集合（保持固定排序：control, shift, alt, meta）
  final List<HotkeyModifierKey> modifiers;

  HotkeyCombo({required this.key, required List<HotkeyModifierKey> modifiers})
    : modifiers = _sortModifiers(modifiers),
      _sourceHotKey = null;

  HotkeyCombo._restored({
    required this.key,
    required List<HotkeyModifierKey> modifiers,
    required HotKey source,
  }) : modifiers = _sortModifiers(modifiers),
       _sourceHotKey = HotKey(
         identifier: source.identifier,
         key: source.key,
         modifiers: List<HotKeyModifier>.unmodifiable(source.modifiers ?? []),
         scope: HotKeyScope.system,
       );

  // 保留既有 macOS 設定的 logical key 與 Fn／Caps Lock，不縮減舊組合。
  final HotKey? _sourceHotKey;

  List<HotKeyModifier> get _extraModifiers =>
      (_sourceHotKey?.modifiers ?? <HotKeyModifier>[])
          .where(
            (HotKeyModifier modifier) =>
                HotkeyModifierKey.fromHotKeyModifier(modifier) == null,
          )
          .toList();

  /// 固定的修飾鍵排序
  static List<HotkeyModifierKey> _sortModifiers(
    Iterable<HotkeyModifierKey> mods,
  ) {
    final set = mods.toSet();
    const order = [
      HotkeyModifierKey.control,
      HotkeyModifierKey.shift,
      HotkeyModifierKey.alt,
      HotkeyModifierKey.meta,
    ];
    return List<HotkeyModifierKey>.unmodifiable(order.where(set.contains));
  }

  /// 取得各平台的預設組合
  /// - macOS：Alt+Space
  /// - Windows 及其他：Ctrl+Shift+Space
  factory HotkeyCombo.defaultForPlatform([TargetPlatform? platform]) {
    final target = platform ?? defaultTargetPlatform;
    if (target == TargetPlatform.macOS) {
      return HotkeyCombo(
        key: PhysicalKeyboardKey.space,
        modifiers: const [HotkeyModifierKey.alt],
      );
    }
    return HotkeyCombo(
      key: PhysicalKeyboardKey.space,
      modifiers: const [HotkeyModifierKey.control, HotkeyModifierKey.shift],
    );
  }

  /// 判斷是否為修飾鍵
  static bool isModifierKey(PhysicalKeyboardKey key) {
    return _resolveModifier(key) != null;
  }

  /// 將左右修飾鍵解析為修飾鍵列舉
  static HotkeyModifierKey? _resolveModifier(PhysicalKeyboardKey key) {
    if (key == PhysicalKeyboardKey.controlLeft ||
        key == PhysicalKeyboardKey.controlRight) {
      return HotkeyModifierKey.control;
    }
    if (key == PhysicalKeyboardKey.shiftLeft ||
        key == PhysicalKeyboardKey.shiftRight) {
      return HotkeyModifierKey.shift;
    }
    if (key == PhysicalKeyboardKey.altLeft ||
        key == PhysicalKeyboardKey.altRight) {
      return HotkeyModifierKey.alt;
    }
    if (key == PhysicalKeyboardKey.metaLeft ||
        key == PhysicalKeyboardKey.metaRight) {
      return HotkeyModifierKey.meta;
    }
    return null;
  }

  /// 判斷給定按鍵組合是否符合 Windows 保留組合
  static bool isWindowsReserved({
    required PhysicalKeyboardKey key,
    required List<HotkeyModifierKey> modifiers,
  }) {
    // 1. 任何包含 Ctrl+Alt+Delete 的組合（包含額外修飾鍵）
    if (key == PhysicalKeyboardKey.delete &&
        modifiers.contains(HotkeyModifierKey.control) &&
        modifiers.contains(HotkeyModifierKey.alt)) {
      return true;
    }

    // 2. Alt + Space
    if (key == PhysicalKeyboardKey.space &&
        modifiers.length == 1 &&
        modifiers.contains(HotkeyModifierKey.alt)) {
      return true;
    }

    // 3. Alt + F4
    if (key == PhysicalKeyboardKey.f4 &&
        modifiers.length == 1 &&
        modifiers.contains(HotkeyModifierKey.alt)) {
      return true;
    }

    // 4. Ctrl + Esc
    if (key == PhysicalKeyboardKey.escape &&
        modifiers.length == 1 &&
        modifiers.contains(HotkeyModifierKey.control)) {
      return true;
    }

    return false;
  }

  /// 從按下的一組 PhysicalKeyboardKey 解析熱鍵組合
  static HotkeyParseResult parse(
    List<PhysicalKeyboardKey> keys, {
    TargetPlatform? platform,
  }) {
    if (keys.isEmpty) {
      return const HotkeyParseFailure(
        HotkeyParseFailureReason.empty,
        '請按下欲設定的快捷鍵組合。',
      );
    }

    final target = platform ?? defaultTargetPlatform;
    final Set<HotkeyModifierKey> modifiers = {};
    PhysicalKeyboardKey? mainKey;

    for (final k in keys) {
      final mod = _resolveModifier(k);
      if (mod != null) {
        modifiers.add(mod);
      } else {
        // 多個非修飾鍵時，以最後一個為主鍵
        mainKey = k;
      }
    }

    if (mainKey == null) {
      return const HotkeyParseFailure(
        HotkeyParseFailureReason.modifiersOnly,
        '請同時按住修飾鍵與一個主鍵，例如 Ctrl+Shift+Space。',
      );
    }

    final HotkeyCombo combo = HotkeyCombo(
      key: mainKey,
      modifiers: modifiers.toList(),
    );
    return combo.validate(target) ?? HotkeyParseSuccess(combo);
  }

  /// 驗證直接建構或由舊設定還原的組合，避免繞過錄製器的檢查。
  HotkeyParseFailure? validate(TargetPlatform platform) {
    if (isModifierKey(key)) {
      return const HotkeyParseFailure(
        HotkeyParseFailureReason.modifiersOnly,
        '請同時按住修飾鍵與一個主鍵，例如 Ctrl+Shift+Space。',
      );
    }
    if (platform != TargetPlatform.windows) return null;
    if (_extraModifiers.isNotEmpty) {
      return const HotkeyParseFailure(
        HotkeyParseFailureReason.unsupportedKey,
        'Windows 快捷鍵不支援 Fn 或 Caps Lock 修飾鍵，請換一組。',
      );
    }
    if (modifiers.isEmpty) {
      return const HotkeyParseFailure(
        HotkeyParseFailureReason.noModifiersOnWindows,
        'Windows 快捷鍵必須包含至少一個修飾鍵（如 Ctrl、Shift、Alt）。',
      );
    }
    if (isWindowsReserved(key: key, modifiers: modifiers)) {
      return const HotkeyParseFailure(
        HotkeyParseFailureReason.windowsReserved,
        '這個快捷鍵無法在 Windows 使用（系統保留或已被其他程式占用）。請換一組。',
      );
    }
    if (windowsVirtualKey == null) {
      return const HotkeyParseFailure(
        HotkeyParseFailureReason.unsupportedKey,
        '此按鍵不受 Windows 全域熱鍵支援，請改用字母、數字、Space、Escape 或 F1–F12。',
      );
    }
    return null;
  }

  /// 取得 Windows Virtual-Key 代碼
  /// - Space = 32
  /// - 0–9 = 48–57
  /// - A–Z = 65–90
  /// - Escape = 27
  /// - F1–F12 = 112–123
  /// - 其餘按鍵回傳 null
  static int? getWindowsVirtualKey(PhysicalKeyboardKey key) {
    if (key == PhysicalKeyboardKey.space) return 32;
    if (key == PhysicalKeyboardKey.escape) return 27;

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
    final digitIndex = digits.indexOf(key);
    if (digitIndex != -1) return 48 + digitIndex;

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
    final letterIndex = letters.indexOf(key);
    if (letterIndex != -1) return 65 + letterIndex;

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
    final fIndex = fKeys.indexOf(key);
    if (fIndex != -1) return 112 + fIndex;

    return null;
  }

  /// 取得此熱鍵的 Windows virtual-key
  int? get windowsVirtualKey => getWindowsVirtualKey(key);

  /// 取得修飾鍵 flag 字串列表（順序固定：control, shift, alt, meta）
  List<String> get modifierFlags => modifiers.map((m) => m.flagName).toList();

  /// 取得主鍵標籤名稱
  static String getKeyLabel(PhysicalKeyboardKey key) {
    if (key == PhysicalKeyboardKey.space) return 'Space';
    if (key == PhysicalKeyboardKey.escape) return 'Esc';

    // debugName 在 Release 為 null；正式畫面必須使用穩定鍵值。
    final int? vk = getWindowsVirtualKey(key);
    if (vk != null) {
      if (vk >= 112) return 'F${vk - 111}';
      return String.fromCharCode(vk);
    }
    final Map<PhysicalKeyboardKey, String> labels =
        <PhysicalKeyboardKey, String>{
          PhysicalKeyboardKey.arrowUp: 'Arrow Up',
          PhysicalKeyboardKey.arrowDown: 'Arrow Down',
          PhysicalKeyboardKey.arrowLeft: 'Arrow Left',
          PhysicalKeyboardKey.arrowRight: 'Arrow Right',
          PhysicalKeyboardKey.delete: 'Delete',
          PhysicalKeyboardKey.backspace: 'Backspace',
          PhysicalKeyboardKey.enter: 'Enter',
          PhysicalKeyboardKey.tab: 'Tab',
          PhysicalKeyboardKey.home: 'Home',
          PhysicalKeyboardKey.end: 'End',
          PhysicalKeyboardKey.pageUp: 'Page Up',
          PhysicalKeyboardKey.pageDown: 'Page Down',
          PhysicalKeyboardKey.capsLock: 'Caps Lock',
          PhysicalKeyboardKey.fn: 'Fn',
          PhysicalKeyboardKey.minus: '-',
          PhysicalKeyboardKey.equal: '=',
          PhysicalKeyboardKey.bracketLeft: '[',
          PhysicalKeyboardKey.bracketRight: ']',
          PhysicalKeyboardKey.backslash: r'\',
          PhysicalKeyboardKey.semicolon: ';',
          PhysicalKeyboardKey.quote: "'",
          PhysicalKeyboardKey.backquote: '`',
          PhysicalKeyboardKey.comma: ',',
          PhysicalKeyboardKey.period: '.',
          PhysicalKeyboardKey.slash: '/',
        };
    return labels[key] ?? 'Key 0x${key.usbHidUsage.toRadixString(16)}';
  }

  /// 取得各平台的按鍵標籤列表
  /// - Windows：Ctrl, Shift, Alt, Win, Space, A...
  /// - macOS：⌃ Control, ⇧ Shift, ⌥ Option, ⌘ Command, Space, A...
  List<String> getDisplayParts([TargetPlatform? platform]) {
    final target = platform ?? defaultTargetPlatform;
    final isWin = target == TargetPlatform.windows;
    final List<String> parts = [];

    for (final HotkeyModifierKey modifier in modifiers) {
      parts.add(_modifierLabel(modifier, isWin));
    }
    for (final HotKeyModifier modifier in _extraModifiers) {
      parts.add(modifier == HotKeyModifier.fn ? 'Fn' : 'Caps Lock');
    }
    parts.add(getKeyLabel(key));
    return parts;
  }

  static String _modifierLabel(HotkeyModifierKey modifier, bool isWindows) {
    return switch (modifier) {
      HotkeyModifierKey.control => isWindows ? 'Ctrl' : '⌃ Control',
      HotkeyModifierKey.shift => isWindows ? 'Shift' : '⇧ Shift',
      HotkeyModifierKey.alt => isWindows ? 'Alt' : '⌥ Option',
      HotkeyModifierKey.meta => isWindows ? 'Win' : '⌘ Command',
    };
  }

  /// 錄製預覽亦使用同一套標籤；尚未有主鍵時仍顯示已按下的修飾鍵。
  static List<String> getRecordedDisplayParts(
    List<PhysicalKeyboardKey> keys, [
    TargetPlatform? platform,
  ]) {
    final Set<HotkeyModifierKey> modifiers = <HotkeyModifierKey>{};
    PhysicalKeyboardKey? mainKey;
    for (final PhysicalKeyboardKey key in keys) {
      final HotkeyModifierKey? modifier = _resolveModifier(key);
      if (modifier != null) {
        modifiers.add(modifier);
      } else {
        mainKey = key;
      }
    }
    final bool isWindows =
        (platform ?? defaultTargetPlatform) == TargetPlatform.windows;
    return <String>[
      for (final HotkeyModifierKey modifier in _sortModifiers(modifiers))
        _modifierLabel(modifier, isWindows),
      if (mainKey != null) getKeyLabel(mainKey),
    ];
  }

  /// 格式化顯示字串，以 '+' 連接
  String getDisplayString([TargetPlatform? platform]) {
    return getDisplayParts(platform).join(' + ');
  }

  /// 轉換為相容既有持久化的 HotKey 物件
  HotKey toHotKey() {
    return _sourceHotKey ??
        HotKey(
          key: key,
          modifiers: modifiers.map((m) => m.toHotKeyModifier()).toList(),
          scope: HotKeyScope.system,
        );
  }

  /// 從既有的 HotKey 物件轉換回 HotkeyCombo
  factory HotkeyCombo.fromHotKey(HotKey hotKey) {
    final mods = <HotkeyModifierKey>[];
    if (hotKey.modifiers != null) {
      for (final m in hotKey.modifiers!) {
        final mod = HotkeyModifierKey.fromHotKeyModifier(m);
        if (mod != null && !mods.contains(mod)) {
          mods.add(mod);
        }
      }
    }
    final PhysicalKeyboardKey physicalKey;
    if (hotKey.key is PhysicalKeyboardKey) {
      physicalKey = hotKey.key as PhysicalKeyboardKey;
    } else {
      physicalKey = hotKey.physicalKey;
    }
    return HotkeyCombo._restored(
      key: physicalKey,
      modifiers: mods,
      source: hotKey,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HotkeyCombo &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          listEquals(modifiers, other.modifiers) &&
          listEquals(_extraModifiers, other._extraModifiers);

  @override
  int get hashCode => Object.hash(
    key,
    Object.hashAll(modifiers),
    Object.hashAll(_extraModifiers),
  );

  @override
  String toString() => getDisplayString();
}
