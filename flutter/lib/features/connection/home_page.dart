import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/user.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils/format.dart';
import '../account/account_page.dart';
import '../coming_soon/coming_soon_page.dart';
import '../membership/membership_page.dart';
import '../servers/servers_page.dart';
import 'home_controller.dart';

/// Home shell (phase 3 §5.1 + the Android home mockup).
///
/// All data comes from real API calls (`/api/me`, `/api/nodes`, subscription
/// fetch+merge). Nothing is faked: no fake speeds, no fake latency, no fake
/// "connected". Every not-yet-built action is tappable and opens an honest
/// "即将上线" page naming the feature — the connect button never pretends
/// to connect (the real VPN core lands with the Phase 2.5 prototype).
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _tabIndex = 0;

  static const _tabs = <({String label, IconData icon})>[
    (label: '首页', icon: Icons.home_outlined),
    (label: '服务器', icon: Icons.dns_outlined),
    (label: '会员', icon: Icons.card_membership_outlined),
    (label: '消息', icon: Icons.message_outlined),
    (label: '我的', icon: Icons.person_outlined),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeControllerProvider.notifier).refresh();
    });
  }

  Future<void> _onRefreshSubscription() async {
    await ref.read(homeControllerProvider.notifier).refresh();
    if (!mounted) return;
    final state = ref.read(homeControllerProvider);
    final message = state.offline
        ? '同步失败，已显示缓存数据'
        : state.subscriptionNote ?? '订阅已更新 · ${state.nodeTags.length} 个节点';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                'Z',
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('ZGLTVPN', style: textTheme.titleMedium),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: _SyncBadge(home: home)),
          ),
        ],
      ),
      body: switch (_tabIndex) {
        0 => _buildHome(context, home),
        1 => const ServersPage(),
        2 => const MembershipPage(),
        3 => const ComingSoonBody(feature: '消息中心', detail: '站内信与通知功能即将上线。'),
        4 => const AccountPage(),
        _ => const ComingSoonBody(feature: '消息中心'),
      },
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (index) => setState(() => _tabIndex = index),
        items: _tabs
            .map(
              (tab) => BottomNavigationBarItem(
                icon: Icon(tab.icon),
                label: tab.label,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildHome(BuildContext context, HomeState home) {
    final scheme = Theme.of(context).colorScheme;
    if (home.isRefreshing && home.user == null && home.error == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _Skeleton(height: 220),
          SizedBox(height: 12),
          _Skeleton(height: 96),
          SizedBox(height: 12),
          _Skeleton(height: 120),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(homeControllerProvider.notifier).refresh(),
      color: scheme.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (home.offline) ...[
            _OfflineBanner(home: home),
            const SizedBox(height: 12),
          ],
          if (home.error != null && home.user == null) ...[
            _ErrorBlock(
              message: home.error!,
              onRetry: () =>
                  ref.read(homeControllerProvider.notifier).refresh(),
            ),
            const SizedBox(height: 12),
          ],
          _ConnectCard(home: home),
          const SizedBox(height: 12),
          const _SpeedCard(),
          const SizedBox(height: 12),
          _TrafficCard(user: home.user),
          const SizedBox(height: 12),
          _MembershipCard(user: home.user),
          const SizedBox(height: 12),
          _QuickActions(
            onServers: () => setState(() => _tabIndex = 1),
            onRefreshSubscription: _onRefreshSubscription,
          ),
        ],
      ),
    );
  }
}

/// "已同步 HH:MM" / "未同步" badge (phase 3 §3 TopBar).
class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.home});

  final HomeState home;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final extra = Theme.of(context).extension<ZgltExtraColors>()!;
    final text = home.offline
        ? '未同步'
        : home.lastSync != null
        ? '已同步 ${Format.syncTime(home.lastSync!)}'
        : '未同步';
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Text(
        text,
        style: textTheme.labelSmall?.copyWith(color: extra.text2),
      ),
    );
  }
}

/// Static grey block used while the first sync is loading (no shimmer).
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

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.home});

  final HomeState home;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final extra = Theme.of(context).extension<ZgltExtraColors>()!;
    final sync = home.lastSync != null
        ? ' · 最后同步 ${Format.syncTime(home.lastSync!)}'
        : '';
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: extra.warningSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Text(
        '无网络，显示的是缓存数据$sync',
        style: textTheme.bodySmall?.copyWith(color: extra.warning),
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

/// White card shell (phase 3 §3: 1px border, radius 12, padding 16).
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
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

List<Widget> _withDividers(List<Widget> rows) {
  final out = <Widget>[];
  for (var i = 0; i < rows.length; i++) {
    if (i > 0) out.add(const Divider(height: 1));
    out.add(rows[i]);
  }
  return out;
}

/// Connect card: 96dp round button + state + current node.
///
/// The button is tappable but never pretends to connect: it opens an
/// honest "即将上线" page until the Phase 2.5 prototype wires the real
/// VPN core.
class _ConnectCard extends StatelessWidget {
  const _ConnectCard({required this.home});

  final HomeState home;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final extra = Theme.of(context).extension<ZgltExtraColors>()!;
    final nodeLabel = home.nodeTags.isEmpty
        ? '暂无可用节点'
        : '自动 · ${home.nodeTags.length} 个节点';
    return _Card(
      child: Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(
            width: 96,
            height: 96,
            child: ElevatedButton(
              onPressed: () => openComingSoon(
                context,
                feature: 'VPN 连接',
                detail:
                    '连接功能需接入真实 VPN 核心（阶段 2.5 原型），'
                    '当前版本不会假装连接。',
              ),
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                backgroundColor: scheme.primary,
              ),
              child: const Icon(Icons.power_settings_new, size: 40),
            ),
          ),
          const SizedBox(height: 14),
          Text('未连接', style: textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(
            'VPN 连接功能开发中，阶段 2.5 原型后上线',
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ..._withDividers([
            _kvRow(
              context,
              '当前节点',
              Text(nodeLabel, style: textTheme.titleSmall),
            ),
            if (home.subscriptionNote != null)
              _kvRow(
                context,
                '订阅',
                Flexible(
                  child: Text(
                    home.subscriptionNote!,
                    style: textTheme.bodySmall?.copyWith(color: extra.warning),
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
          ]),
        ],
      ),
    );
  }
}

/// Live speed card. No data yet (no tunnel) — shows "暂无数据", never fake
/// numbers (phase 3 principle: real data or "暂无数据").
class _SpeedCard extends StatelessWidget {
  const _SpeedCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('实时速率', style: textTheme.titleMedium),
          const SizedBox(height: 10),
          Text('暂无数据', style: textTheme.bodyMedium),
          const SizedBox(height: 2),
          Text('连接后显示实时速率、延迟与累计流量', style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Traffic card from /api/me (server-authoritative). Dirty totals are
/// labelled, never shown as real numbers.
class _TrafficCard extends StatelessWidget {
  const _TrafficCard({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final planName = user?.planDisplayName ?? '';
    final sub = planName.isNotEmpty ? planName : '暂无生效套餐';
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('流量', style: textTheme.titleMedium),
              Text(sub, style: textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 10),
          if (user == null) ...[
            Text('暂无数据', style: textTheme.bodyMedium),
            const SizedBox(height: 2),
            Text('登录后同步流量数据', style: textTheme.bodySmall),
          ] else ...[
            _trafficBody(context, user!),
          ],
        ],
      ),
    );
  }

  Widget _trafficBody(BuildContext context, User user) {
    final textTheme = Theme.of(context).textTheme;
    final used = user.trafficUsed;
    final total = user.trafficTotal;
    final dirty = Format.isDirtyTraffic(total);
    final remaining = dirty ? 0 : (total - used).clamp(0, total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('已用', style: textTheme.bodySmall),
                  Text(
                    Format.bytes(used),
                    style: textTheme.headlineSmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('总计', style: textTheme.bodySmall),
                  Text(
                    Format.bytes(total),
                    style: textTheme.headlineSmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!dirty && total > 0) ...[
          const SizedBox(height: 10),
          _TrafficBar(used: used, total: total),
          const SizedBox(height: 6),
          Text(
            '已用 ${Format.bytes(used)} / 总计 ${Format.bytes(total)}'
            ' · 剩余 ${Format.bytes(remaining)}',
            style: textTheme.bodySmall,
          ),
        ] else if (dirty) ...[
          const SizedBox(height: 6),
          Text('流量总额数据异常，显示可能不准', style: textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _TrafficBar extends StatelessWidget {
  const _TrafficBar({required this.used, required this.total});

  final int used;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final extra = Theme.of(context).extension<ZgltExtraColors>()!;
    final ratio = (used / total).clamp(0.0, 1.0);
    final color = ratio > 1
        ? extra.danger
        : ratio > 0.8
        ? extra.warning
        : scheme.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: ratio,
        minHeight: 6,
        backgroundColor: scheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

/// Membership card from /api/me.
class _MembershipCard extends StatelessWidget {
  const _MembershipCard({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final planName = user?.planDisplayName ?? '';
    final expires = user?.expires ?? 0;
    final days = Format.daysRemaining(expires);
    final expired = expires > 0 && days < 0;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('会员', style: textTheme.titleMedium),
          const SizedBox(height: 2),
          ..._withDividers([
            _kvRow(
              context,
              '当前套餐',
              Text(
                planName.isNotEmpty ? planName : '暂无生效套餐',
                style: textTheme.titleSmall,
              ),
            ),
            _kvRow(
              context,
              '到期日',
              Text(
                Format.expiry(expires),
                style: textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
              ),
            ),
            _kvRow(context, '状态', _PlanBadge(expired: expired, days: days)),
          ]),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => openComingSoon(
              context,
              feature: '购买与续订',
              detail:
                  '套餐购买与续订功能即将上线，届时可在应用内用余额购买；'
                  '当前请在网站上购买。',
            ),
            child: const Text('续订套餐'),
          ),
        ],
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.expired, required this.days});

  final bool expired;
  final int days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final extra = Theme.of(context).extension<ZgltExtraColors>()!;
    final (String text, Color bg, Color fg) = expired
        ? ('已过期', extra.dangerSoft, extra.danger)
        : days <= 30
        ? ('$days 天后到期', extra.warningSoft, extra.warning)
        : ('生效中', extra.accentSoft, scheme.primary);
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Quick actions row. 服务器 switches to the servers tab and 刷新订阅
/// refreshes the subscription; 测速 and 客服 are tappable and open an
/// honest "即将上线" page — nothing here is disabled any more.
class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onServers,
    required this.onRefreshSubscription,
  });

  final VoidCallback onServers;
  final Future<void> Function() onRefreshSubscription;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuickAction(
          icon: Icons.dns_outlined,
          label: '服务器',
          onTap: () async => onServers(),
        ),
        const SizedBox(width: 8),
        _QuickAction(
          icon: Icons.speed_outlined,
          label: '测速',
          onTap: () async => openComingSoon(
            context,
            feature: '测速',
            detail: '节点测速功能即将上线，当前不显示任何测速结果。',
          ),
        ),
        const SizedBox(width: 8),
        _QuickAction(
          icon: Icons.refresh_outlined,
          label: '刷新订阅',
          onTap: onRefreshSubscription,
        ),
        const SizedBox(width: 8),
        _QuickAction(
          icon: Icons.headset_outlined,
          label: '客服',
          onTap: () async => openComingSoon(
            context,
            feature: '客服中心',
            detail: '客服中心即将上线，可提交工单与查看回复。',
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final extra = Theme.of(context).extension<ZgltExtraColors>()!;
    final box = Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(height: 6),
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(color: extra.text2),
            ),
          ],
        ),
      ),
    );
    return Expanded(
      child: InkWell(
        onTap: () => onTap(),
        borderRadius: BorderRadius.circular(12),
        child: box,
      ),
    );
  }
}
