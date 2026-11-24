import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/user.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

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
    final home = ref.watch(homeControllerProvider);
    final loading = home.isRefreshing && home.user == null;
    final loadFailed = home.error != null && home.user == null;

    return Scaffold(
      appBar: AppBar(title: const Text('我的', style: ZgltText.heading)),
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
            const _Card(
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
                  _DisabledEntry(icon: Icons.settings_outlined, label: '设置'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
                child: const Text(
                  '退出登录',
                  style: TextStyle(
                    color: ZgltColors.danger,
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ZgltColors.warningSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Text(
        '无网络，余额为缓存数据',
        style: ZgltText.caption.copyWith(color: ZgltColors.warning),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: ZgltColors.surfaceMuted,
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ZgltColors.dangerSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: ZgltText.caption.copyWith(color: ZgltColors.danger),
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
    return Container(
      decoration: BoxDecoration(
        color: ZgltColors.surface,
        border: Border.all(color: ZgltColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

Widget _kvRow(String key, Widget value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(key, style: ZgltText.caption),
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
    final current = user;
    if (current == null) {
      return const _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('账号', style: ZgltText.heading),
            SizedBox(height: 6),
            Text('暂无数据', style: ZgltText.body),
          ],
        ),
      );
    }
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('账号', style: ZgltText.heading),
          const SizedBox(height: 2),
          _kvRow(
            '邮箱',
            Text(
              current.email.isNotEmpty ? current.email : '—',
              style: ZgltText.bodyStrong,
            ),
          ),
          _kvRow(
            '昵称',
            Text(
              current.name.isNotEmpty ? current.name : '—',
              style: ZgltText.bodyStrong,
            ),
          ),
          _kvRow(
            '余额',
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '¥${current.balance.toStringAsFixed(2)}',
                  style: ZgltText.monoLarge,
                ),
                if (offline) ...[
                  const SizedBox(width: 8),
                  Container(
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: ZgltColors.warningSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '缓存',
                      style: ZgltText.tiny.copyWith(
                        color: ZgltColors.warning,
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
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('邀请好友', style: ZgltText.heading),
              Container(
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: ZgltColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text('即将上线', style: ZgltText.tiny),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('邀请功能即将上线', style: ZgltText.caption),
          const SizedBox(height: 6),
          const Text('暂无邀请记录', style: ZgltText.caption),
        ],
      ),
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: false,
      leading: Icon(icon),
      title: Text(label, style: ZgltText.bodyStrong),
      trailing: const Text('即将上线', style: ZgltText.caption),
      onTap: null,
    );
  }
}
