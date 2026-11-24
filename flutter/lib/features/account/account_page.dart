import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/user.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../settings/settings_page.dart';

/// Personal center ("我的", phase 3 §5.14): account card, invite
/// section, entry list, logout.
///
/// All data is real, from the watched [homeControllerProvider] user
/// (`/api/me`). There is no invite code in the user model, so the
/// invite section shows "即将上线" and no code or link is fabricated.
/// The entry rows lead to pages that land in later slices, so they are
/// disabled with the reason shown. Logout clears the local session;
/// [app.dart] routes back to the login page when the auth state flips
/// to logged-out.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final extra = Theme.of(context).extension<ZgltExtraColors>()!;
    final home = ref.watch(homeControllerProvider);
    final loading = home.isRefreshing && home.user == null;
    final loadFailed = home.error != null && home.user == null;

    return Scaffold(
      appBar: AppBar(title: Text('我的', style: textTheme.titleMedium)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (home.offline) ...[
            const _OfflineBanner(),
            const SizedBox(height: 12),
          ],
          if (loading) ...[
            const _Skeleton(height: 132),
          ] else if (loadFailed) ...[
            _ErrorBlock(
              message: '账号信息加载失败，请重试',
              onRetry: () =>
                  ref.read(homeControllerProvider.notifier).refresh(),
            ),
          ] else ...[
            _AccountCard(user: home.user, offline: home.offline),
            const SizedBox(height: 12),
            const _InviteCard(),
            const SizedBox(height: 12),
            _Card(
              child: Column(
                children: [
                  _DisabledEntry(
                    icon: Icons.workspaces_outlined,
                    label: '工作空间',
                  ),
                  Divider(height: 1),
                  _DisabledEntry(icon: Icons.devices_outlined, label: '设备管理'),
                  Divider(height: 1),
                  _DisabledEntry(icon: Icons.shield_outlined, label: '安全中心'),
                  Divider(height: 1),
                  _DisabledEntry(icon: Icons.headset_outlined, label: '客服中心'),
                  Divider(height: 1),
                  _Entry(
                    icon: Icons.settings_outlined,
                    label: '设置',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
                child: Text(
                  '退出登录',
                  style: TextStyle(
                    color: extra.danger,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final extra = Theme.of(context).extension<ZgltExtraColors>()!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: extra.warningSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Text(
        '无网络，余额为缓存数据',
        style: textTheme.bodySmall?.copyWith(color: extra.warning),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final extra = Theme.of(context).extension<ZgltExtraColors>()!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: extra.dangerSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: textTheme.bodySmall?.copyWith(color: extra.danger),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A Material (not a plain Container): enabled ListTiles / InkWells
    // inside paint their ink on it. Same colour, border and radius as
    // the Container version.
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

Widget _kvRow(BuildContext context, String key, Widget value) {
  final textTheme = Theme.of(context).textTheme;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(key, style: textTheme.bodySmall),
        Flexible(child: value),
      ],
    ),
  );
}

/// Account card: email, nickname, balance (¥). Offline, the balance is
/// marked cached — the banner carries the exact wording.
class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user, required this.offline});

  final User? user;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final extra = Theme.of(context).extension<ZgltExtraColors>()!;
    final current = user;
    if (current == null) {
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('账号', style: textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('暂无数据', style: textTheme.bodyMedium),
          ],
        ),
      );
    }
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('账号', style: textTheme.titleMedium),
          const SizedBox(height: 2),
          _kvRow(
            context,
            '邮箱',
            Text(
              current.email.isNotEmpty ? current.email : '—',
              style: textTheme.titleSmall,
            ),
          ),
          _kvRow(
            context,
            '昵称',
            Text(
              current.name.isNotEmpty ? current.name : '—',
              style: textTheme.titleSmall,
            ),
          ),
          _kvRow(
            context,
            '余额',
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '¥${current.balance.toStringAsFixed(2)}',
                  style: textTheme.headlineSmall?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (offline) ...[
                  const SizedBox(width: 8),
                  Container(
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: extra.warningSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '缓存',
                      style: textTheme.labelSmall?.copyWith(
                        color: extra.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Invite section. No invite code exists in the user model, so none is
/// shown — the feature is marked "即将上线" instead of faking one.
class _InviteCard extends StatelessWidget {
  const _InviteCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('邀请好友', style: textTheme.titleMedium),
              Container(
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text('即将上线', style: textTheme.labelSmall),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('邀请功能即将上线', style: textTheme.bodySmall),
          const SizedBox(height: 6),
          Text('暂无邀请记录', style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// An entry that opens a page (settings, slice 3).
class _Entry extends StatelessWidget {
  const _Entry({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label, style: textTheme.titleSmall),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// An entry whose page lands in a later slice: visibly disabled.
class _DisabledEntry extends StatelessWidget {
  const _DisabledEntry({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: false,
      leading: Icon(icon),
      title: Text(label, style: textTheme.titleSmall),
      trailing: Text('即将上线', style: textTheme.bodySmall),
      onTap: null,
    );
  }
}
