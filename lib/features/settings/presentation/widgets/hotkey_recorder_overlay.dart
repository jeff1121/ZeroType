import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zero_type/core/hotkey/global_hotkey_registrar.dart';
import 'package:zero_type/core/hotkey/hotkey_combo.dart';

/// 覆蓋整個主視窗，錄製時不依賴設定頁的鍵盤焦點。
class HotkeyRecorderOverlay extends StatefulWidget {
  const HotkeyRecorderOverlay({
    super.key,
    required this.onSave,
    required this.onClose,
    this.platform,
  });

  final Future<HotkeyRegistrationResult> Function(List<PhysicalKeyboardKey>)
  onSave;
  final Future<HotkeyRegistrationResult> Function() onClose;
  final TargetPlatform? platform;

  @override
  State<HotkeyRecorderOverlay> createState() => _HotkeyRecorderOverlayState();
}

class _HotkeyRecorderOverlayState extends State<HotkeyRecorderOverlay> {
  final List<PhysicalKeyboardKey> _recordedKeys = [];
  final GlobalKey<ScaffoldMessengerState> _feedbackKey = GlobalKey();
  bool _allKeysReleased = true;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    final pressed = HardwareKeyboard.instance.physicalKeysPressed;
    // 焦點切換的合成放鍵與儲存期間的放鍵也必須結束上一組輸入。
    if (event is KeyUpEvent && pressed.isEmpty) _allKeysReleased = true;
    if (_isBusy || event.synthesized) return false;
    if (event is KeyDownEvent) {
      if (event.physicalKey == PhysicalKeyboardKey.escape &&
          pressed.length == 1) {
        _handleAction(widget.onClose);
        return false;
      }
      setState(() {
        if (_allKeysReleased) {
          _recordedKeys.clear();
          _allKeysReleased = false;
        }
        for (final key in pressed) {
          if (!_recordedKeys.contains(key)) _recordedKeys.add(key);
        }
      });
    } else if (event is KeyUpEvent && pressed.isEmpty) {
      _allKeysReleased = true;
    }
    return false;
  }

  Future<void> _handleAction(
    Future<HotkeyRegistrationResult> Function() action,
  ) async {
    if (_isBusy) return;
    // Controller 可能在 await 期間移除覆蓋層，先保留外層 messenger。
    final outerMessenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _isBusy = true);
    HotkeyRegistrationResult result;
    try {
      result = await action();
    } catch (error) {
      result = HotkeyRegistrationFailure('快捷鍵設定失敗：$error');
    }
    if (result is HotkeyRegistrationFailure) {
      // 等錄製旗標的重建完成，再決定訊息應顯示在遮罩內或設定頁上。
      final message = result.message;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final messenger = mounted ? _feedbackKey.currentState : outerMessenger;
        if (messenger != null && messenger.mounted) {
          messenger.showSnackBar(SnackBar(content: Text(message)));
        }
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
    if (mounted) setState(() => _isBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final platform = widget.platform ?? defaultTargetPlatform;
    final parts = HotkeyCombo.getRecordedDisplayParts(_recordedKeys, platform);
    return ScaffoldMessenger(
      key: _feedbackKey,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.95),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 48,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.keyboard,
                      color: Colors.orangeAccent,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '錄製快捷鍵組合',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.orangeAccent.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        parts.isEmpty ? '等待輸入...' : parts.join(' + '),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '請「同時按住」組合鍵，放開後可重新輸入',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 24,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: _isBusy
                              ? null
                              : () => _handleAction(widget.onClose),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                          ),
                          child: const Text('取消'),
                        ),
                        if (_recordedKeys.isNotEmpty)
                          FilledButton(
                            onPressed: _isBusy
                                ? null
                                : () => _handleAction(
                                    () => widget.onSave(
                                      List<PhysicalKeyboardKey>.unmodifiable(
                                        _recordedKeys,
                                      ),
                                    ),
                                  ),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.orangeAccent,
                              foregroundColor: Colors.black,
                            ),
                            child: Text(_isBusy ? '處理中...' : '儲存設定'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: '取消錄製',
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: _isBusy ? null : () => _handleAction(widget.onClose),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
