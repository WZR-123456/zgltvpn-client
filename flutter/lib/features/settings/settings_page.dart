import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/providers.dart';
import '../coming_soon/coming_soon_page.dart';
import 'settings_controller.dart';

/// Settings page (phase 3 §5.11), opened from the account tab.
///
/// Every row is tappable and honest about what works: theme applies
/// for real, the toggles are real local preferences persisted in
/// SharedPreferences (their features take effect once the VPN /
/// notification features land), and language / update check open an
/// honest "即将上线" page — there is no version-check API, so no
/// "already latest" result is fabricated.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final notifier = ref.read(settingsControllerProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text('设置', style: textTheme.titleMedium)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(label: '外观', textTheme: textTheme),
          _Card(
            child: Column(
              children: AppThemeMode.values.map((mode) {
                final selected = settings.themeMode == mode;
                return _ThemeRow(
                  mode: mode,
                  selected: selected,
                  onTap: () => notifier.setThemeMode(mode),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader(label: '语言', textTheme: textTheme),
          _Card(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('语言', style: textTheme.titleSmall),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('简体中文', style: textTheme.bodyMedium),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => openComingSoon(
                context,
                feature: '更多语言',
                detail: '当前仅支持简体中文，更多语言在后续版本中上线。',
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader(label: '连接', textTheme: textTheme),
          _Card(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('自动连接', style: textTheme.titleSmall),
                  subtitle: Text(
                    '偏好已保存，连接功能上线后自动连接',
                    style: textTheme.bodySmall,
                  ),
                  value: settings.autoConnect,
                  onChanged: (value) => notifier.setAutoConnect(value),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('订阅自动刷新', style: textTheme.titleSmall),
                  subtitle: Text('偏好已保存，上线后自动刷新订阅', style: textTheme.bodySmall),
                  value: settings.autoRefreshSubscription,
                  onChanged: (value) =>
                      notifier.setAutoRefreshSubscription(value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader(label: '通知', textTheme: textTheme),
          _Card(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('通知', style: textTheme.titleSmall),
              subtitle: Text('偏好已保存，通知功能上线后生效', style: textTheme.bodySmall),
              value: settings.notificationsEnabled,
              onChanged: (value) => notifier.setNotificationsEnabled(value),
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader(label: '关于', textTheme: textTheme),
          _Card(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('应用名称', style: textTheme.titleSmall),
                  trailing: Text('ZGLTVPN', style: textTheme.bodyMedium),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('版本', style: textTheme.titleSmall),
                  trailing: Text(
                    ApiConfig.clientVersion,
                    style: textTheme.bodyMedium,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('检查更新', style: textTheme.titleSmall),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openComingSoon(
                    context,
                    feature: '检查更新',
                    detail: '当前版本没有版本检查接口，无法确认是否为最新版本。',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.textTheme});

  final String label;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label, style: textTheme.bodySmall),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A Material (not a plain Container): the theme rows and switches
    // inside paint their ink on it. Same colour, border and radius.
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

/// One theme option: the selected row shows a check mark.
class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final AppThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(mode.label, style: textTheme.titleSmall),
      trailing: selected
          ? Icon(Icons.check, color: scheme.primary)
          : const SizedBox.shrink(),
      onTap: onTap,
    );
  }
}
