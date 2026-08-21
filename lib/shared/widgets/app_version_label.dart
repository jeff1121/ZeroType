import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 側邊欄底部的淡色版號，不搶焦點；懸停可看完整版本與 build number。
class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({super.key});

  static final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
      fontSize: 10,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
      height: 1,
    );

    return FutureBuilder<PackageInfo>(
      future: _packageInfo,
      builder: (context, snapshot) {
        final version = snapshot.data?.version;
        if (version == null || version.isEmpty) {
          return const SizedBox(height: 10);
        }
        final buildNumber = snapshot.data?.buildNumber ?? '';
        final label = 'v$version';
        final tooltip = buildNumber.isEmpty ? label : '$label ($buildNumber)';
        return Tooltip(
          message: tooltip,
          waitDuration: const Duration(milliseconds: 400),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14, top: 4),
            child: Text(label, style: style),
          ),
        );
      },
    );
  }
}
