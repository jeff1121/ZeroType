import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:zero_type/core/di/injection.dart';
import 'package:zero_type/core/hotkey/hotkey_combo.dart';
import 'package:zero_type/core/hotkey/global_hotkey_registrar.dart';
import 'package:zero_type/core/services/sound_service.dart';
import 'package:zero_type/core/theme/theme_controller.dart';
import '../controllers/settings_controller.dart';

@RoutePage()
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage>
    with WidgetsBindingObserver, AutoRouteAwareStateMixin<SettingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _refreshPermissionsIfNeeded(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissionsIfNeeded();
    }
  }

  @override
  void didPush() => _refreshPermissionsIfNeeded();

  @override
  void didPopNext() => _refreshPermissionsIfNeeded();

  Future<void> _refreshPermissionsIfNeeded() async {
    if (!mounted) return;
    final data = ref.read(settingsControllerProvider).value;
    if (data == null || data.isRecordingHotkey) return;
    try {
      await ref.read(settingsControllerProvider.notifier).refreshPermissions();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('權限狀態更新失敗：$error')));
    }
  }

  Future<void> _startHotkeyRecording() async {
    final result = await ref
        .read(settingsControllerProvider.notifier)
        .startRecordingHotkey();
    if (!mounted) return;
    if (result is HotkeyRegistrationFailure) {
      // 暫停及恢復同時失敗時，恢復遮罩仍在；錯誤必須顯示於遮罩之上。
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('無法開始錄製快捷鍵'),
          content: Text(result.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeControllerProvider);
    final isDark = themeMode == ThemeMode.dark;
    final settings = ref.watch(settingsControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: 24,
              right: 24,
              bottom: 24,
              top: 30,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '設定',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                if (settings.hasError)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('設定載入失敗：${settings.error}'),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: () =>
                                ref.invalidate(settingsControllerProvider),
                            child: const Text('重試'),
                          ),
                        ],
                      ),
                    ),
                  ),

                // --- General Settings Section ---
                _SectionHeader(title: '一般設定'),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    // Theme Toggle
                    _SettingTile(
                      icon: isDark ? Icons.dark_mode : Icons.light_mode,
                      title: '深色模式',
                      subtitle: '切換應用程式的外觀風格',
                      trailing: _AppToggle(
                        value: isDark,
                        onChanged: (_) => ref
                            .read(themeControllerProvider.notifier)
                            .toggleTheme(),
                        activeIcon: Icons.nightlight_round,
                        inactiveIcon: Icons.wb_sunny_rounded,
                      ),
                    ),
                    const Divider(height: 1, indent: 56),

                    // Launch at Startup
                    settings.when(
                      data: (data) => _SettingTile(
                        icon: Icons.launch,
                        title: '開機啟動',
                        subtitle: '在電腦啟動時自動開啟 ZeroType',
                        trailing: Switch(
                          value: data.launchAtStartup,
                          onChanged: (val) => ref
                              .read(settingsControllerProvider.notifier)
                              .toggleLaunchAtStartup(val),
                        ),
                      ),
                      loading: () => const _LoadingTile(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    const Divider(height: 1, indent: 56),
                    // History Retention Days
                    settings.when(
                      data: (data) => _SettingTile(
                        icon: Icons.history,
                        title: '歷史記錄保留時間',
                        subtitle: '超過保留天數的記錄將自動刪除',
                        trailing: SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 7, label: Text('7天')),
                            ButtonSegment(value: 14, label: Text('14天')),
                            ButtonSegment(value: 30, label: Text('30天')),
                          ],
                          selected: {data.historyRetentionDays},
                          onSelectionChanged: (selection) => ref
                              .read(settingsControllerProvider.notifier)
                              .setHistoryRetentionDays(selection.first),
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                      loading: () => const _LoadingTile(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    const Divider(height: 1, indent: 56),
                    // Max Recording Duration
                    settings.when(
                      data: (data) => _SettingTile(
                        icon: Icons.timer_outlined,
                        title: '最長錄音時間',
                        subtitle: '超過此時長將自動停止並送出辨識',
                        trailing: SizedBox(
                          width: 200,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 140,
                                child: Slider(
                                  value: data.maxRecordingMinutes.toDouble(),
                                  min: 1,
                                  max: 5,
                                  divisions: 4,
                                  onChanged: (val) => ref
                                      .read(settingsControllerProvider.notifier)
                                      .setMaxRecordingMinutes(val.round()),
                                ),
                              ),
                              Text(
                                '${data.maxRecordingMinutes} 分鐘',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      loading: () => const _LoadingTile(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // --- Shortcut Section ---
                _SectionHeader(title: '快捷鍵'),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    settings.when(
                      data: (data) => InkWell(
                        onTap: _startHotkeyRecording,
                        borderRadius: BorderRadius.circular(16),
                        child: _SettingTile(
                          icon: Icons.keyboard,
                          title: '全局錄音快捷鍵',
                          subtitle: '按下此組合鍵即可開始/停止錄音',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withAlpha(50),
                              ),
                            ),
                            child: _buildHotkeyDisplay(context, data.hotkey),
                          ),
                        ),
                      ),
                      loading: () => const _LoadingTile(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // --- Sound Section ---
                _SectionHeader(title: '音效'),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    settings.when(
                      data: (data) => _SettingTile(
                        icon: Icons.volume_up,
                        title: '啟用音效',
                        subtitle: '開始與停止錄音時播放提示音',
                        trailing: Switch(
                          value: data.soundEnabled,
                          onChanged: (val) => ref
                              .read(settingsControllerProvider.notifier)
                              .toggleSound(val),
                        ),
                      ),
                      loading: () => const _LoadingTile(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    const Divider(height: 1, indent: 56),
                    settings.when(
                      data: (data) => _SoundPickerTile(
                        icon: Icons.play_circle_outline,
                        title: '開始錄音音效',
                        subtitle: '按下快捷鍵開始錄音時播放',
                        selectedPath: data.startSound,
                        enabled: data.soundEnabled,
                        onChanged: (path) => ref
                            .read(settingsControllerProvider.notifier)
                            .setStartSound(path),
                      ),
                      loading: () => const _LoadingTile(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    const Divider(height: 1, indent: 56),
                    settings.when(
                      data: (data) => _SoundPickerTile(
                        icon: Icons.stop_circle_outlined,
                        title: '停止錄音音效',
                        subtitle: '再次按下快捷鍵停止錄音時播放',
                        selectedPath: data.stopSound,
                        enabled: data.soundEnabled,
                        onChanged: (path) => ref
                            .read(settingsControllerProvider.notifier)
                            .setStopSound(path),
                      ),
                      loading: () => const _LoadingTile(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // --- System Permission Section ---
                _SectionHeader(title: '系統權限'),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    settings.when(
                      data: (data) => _PermissionTile(
                        icon: Icons.accessibility_new,
                        title: '輔助使用權限',
                        subtitle: '自動貼上功能需要此權限以模擬鍵盤動作',
                        isAuthorized: data.isAccessibilityAuthorized,
                        actionLabel: data.isAccessibilityAuthorized
                            ? '打開設定'
                            : '請求授權',
                        onCheck: () async {
                          const channel = MethodChannel(
                            'com.zerotype.app/permission',
                          );
                          if (!data.isAccessibilityAuthorized) {
                            await channel.invokeMethod('requestAccessibility');
                          }
                          await channel.invokeMethod(
                            'openAccessibilitySettings',
                          );
                          ref
                              .read(settingsControllerProvider.notifier)
                              .refreshPermissions();
                        },
                      ),
                      loading: () => const _LoadingTile(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    const Divider(height: 1, indent: 56),
                    settings.when(
                      data: (data) => _PermissionTile(
                        icon: Icons.mic,
                        title: '麥克風權限',
                        subtitle: '語音辨識功能需要存取你的麥克風',
                        isAuthorized: data.isMicrophoneAuthorized,
                        onCheck: () => const MethodChannel(
                          'com.zerotype.app/permission',
                        ).invokeMethod('openMicrophoneSettings'),
                      ),
                      loading: () => const _LoadingTile(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotkeyDisplay(BuildContext context, HotKey hotkey) {
    final combo = HotkeyCombo.fromHotKey(hotkey);
    final parts = combo.getDisplayParts();
    final List<Widget> widgets = [];

    for (int i = 0; i < parts.length; i++) {
      if (i > 0) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('+'),
          ),
        );
      }
      widgets.add(_KeyBadge(label: parts[i]));
    }

    return Row(mainAxisSize: MainAxisSize.min, children: widgets);
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withAlpha(26),
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isAuthorized;
  final VoidCallback onCheck;
  final String actionLabel;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isAuthorized,
    required this.onCheck,
    this.actionLabel = '打開設定',
  });

  @override
  Widget build(BuildContext context) {
    return _SettingTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isAuthorized ? Colors.green : Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isAuthorized ? Colors.green : Colors.red).withAlpha(
                    102,
                  ),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isAuthorized ? '已授權' : '未授權',
            style: TextStyle(
              color: isAuthorized ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton(
            onPressed: onCheck,
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center, // Ensure vertical center alignment
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha(153),
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _AppToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData activeIcon;
  final IconData inactiveIcon;

  const _AppToggle({
    required this.value,
    required this.onChanged,
    required this.activeIcon,
    required this.inactiveIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.onSurface.withAlpha(13),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onChanged(!value),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(
            value ? activeIcon : inactiveIcon,
            size: 20,
            color: value
                ? Colors.orangeAccent
                : Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _KeyBadge extends StatelessWidget {
  final String label;
  const _KeyBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: cs.primary,
        ),
      ),
    );
  }
}

class _LoadingTile extends StatelessWidget {
  const _LoadingTile();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _SoundPickerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String selectedPath;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _SoundPickerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selectedPath,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectivePath = kSystemSoundLabels.containsKey(selectedPath)
        ? selectedPath
        : (kSystemSoundLabels.containsKey(kDefaultStartSound)
              ? kDefaultStartSound
              : kSystemSoundLabels.keys.first);
    final selectedLabel = kSystemSoundLabels[effectivePath] ?? '';

    return _SettingTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<String>(
              value: effectivePath,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(12),
              selectedItemBuilder: (_) => kSystemSoundLabels.entries.map((e) {
                return Center(
                  child: Text(
                    e.value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                );
              }).toList(),
              items: kSystemSoundLabels.entries.map((e) {
                return DropdownMenuItem<String>(
                  value: e.key,
                  child: Text(e.value, style: const TextStyle(fontSize: 13)),
                );
              }).toList(),
              onChanged: enabled
                  ? (path) {
                      if (path != null) onChanged(path);
                    }
                  : null,
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: '預覽「$selectedLabel」',
              icon: Icon(Icons.play_arrow_rounded, color: cs.primary, size: 20),
              onPressed: enabled
                  ? () => getIt<SoundService>().playPreview(effectivePath)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
