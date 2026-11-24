import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/user.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils/format.dart';
import 'home_controller.dart';

/// Home shell (phase 3 §5.1 + the Android home mockup).
///
/// All data comes from real API calls (`/api/me`, `/api/nodes`, subscription
/// fetch+merge). Anything not yet built is shown disabled with its reason —
/// nothing is faked: no fake speeds, no fake latency, no fake "connected".
/// The connect button stays disabled until the Phase 2.5 prototype wires
/// the real VPN core.
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: ZgltColors.accent,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Z',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text('ZGLTVPN', style: ZgltText.heading),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: _SyncBadge(home: home)),
          ),
        ],
      ),
      body: _tabIndex == 0
          ? _buildHome(context, home)
          : _ComingSoonPage(
              label: _tabs[_tabIndex].label,
              icon: _tabs[_tabIndex].icon,
            ),
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
      color: ZgltColors.accent,
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
          _QuickActions(onRefreshSubscription: _onRefreshSubscription),
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
    final text = home.offline
        ? '未同步'
        : home.lastSync != null
        ? '已同步 ${Format.syncTime(home.lastSync!)}'
        : '未同步';
    return Container(
      decoration: BoxDecoration(
        color: ZgltColors.surfaceMuted,
        border: Border.all(color: ZgltColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Text(text, style: ZgltText.tiny.copyWith(color: ZgltColors.text2)),
    );
  }
}

/// Static grey block used while the first sync is loading (no shimmer).
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

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.home});

  final HomeState home;

  @override
  Widget build(BuildContext context) {
    final sync = home.lastSync != null
        ? ' · 最后同步 ${Format.syncTime(home.lastSync!)}'
        : '';
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ZgltColors.warningSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Text(
        '无网络，显示的是缓存数据$sync',
        style: ZgltText.caption.copyWith(color: ZgltColors.warning),
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

/// White card shell (phase 3 §3: 1px border, radius 12, padding 16).
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
/// The button is disabled until the Phase 2.5 prototype wires the real VPN
/// core — it must never pretend to connect.
class _ConnectCard extends StatelessWidget {
  const _ConnectCard({required this.home});

  final HomeState home;

  @override
  Widget build(BuildContext context) {
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
              onPressed: null,
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                backgroundColor: ZgltColors.accent,
              ),
              child: const Icon(Icons.power_settings_new, size: 40),
            ),
          ),
          const SizedBox(height: 14),
          const Text('未连接', style: ZgltText.title),
          const SizedBox(height: 2),
          const Text(
            'VPN 连接功能开发中，阶段 2.5 原型后上线',
            style: ZgltText.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ..._withDividers([
            _kvRow('当前节点', Text(nodeLabel, style: ZgltText.bodyStrong)),
            if (home.subscriptionNote != null)
              _kvRow(
                '订阅',
                Flexible(
                  child: Text(
                    home.subscriptionNote!,
                    style: ZgltText.caption.copyWith(color: ZgltColors.warning),
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
    return const _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('实时速率', style: ZgltText.heading),
          SizedBox(height: 10),
          Text('暂无数据', style: ZgltText.body),
          SizedBox(height: 2),
          Text('连接后显示实时速率、延迟与累计流量', style: ZgltText.caption),
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
    final planName = user?.planDisplayName ?? '';
    final sub = planName.isNotEmpty ? planName : '暂无生效套餐';
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('流量', style: ZgltText.heading),
              Text(sub, style: ZgltText.caption),
            ],
          ),
          const SizedBox(height: 10),
          if (user == null) ...[
            const Text('暂无数据', style: ZgltText.body),
            const SizedBox(height: 2),
            const Text('登录后同步流量数据', style: ZgltText.caption),
          ] else ...[
            _trafficBody(user!),
          ],
        ],
      ),
    );
  }

  Widget _trafficBody(User user) {
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
                  const Text('已用', style: ZgltText.caption),
                  Text(Format.bytes(used), style: ZgltText.monoLarge),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('总计', style: ZgltText.caption),
                  Text(Format.bytes(total), style: ZgltText.monoLarge),
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
            style: ZgltText.caption,
          ),
        ] else if (dirty) ...[
          const SizedBox(height: 6),
          const Text('流量总额数据异常，显示可能不准', style: ZgltText.caption),
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
    final ratio = (used / total).clamp(0.0, 1.0);
    final color = ratio > 1
        ? ZgltColors.danger
        : ratio > 0.8
        ? ZgltColors.warning
        : ZgltColors.accent;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: ratio,
        minHeight: 6,
        backgroundColor: ZgltColors.surfaceMuted,
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
    final planName = user?.planDisplayName ?? '';
    final expires = user?.expires ?? 0;
    final days = Format.daysRemaining(expires);
    final expired = expires > 0 && days < 0;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('会员', style: ZgltText.heading),
          const SizedBox(height: 2),
          ..._withDividers([
            _kvRow(
              '当前套餐',
              Text(
                planName.isNotEmpty ? planName : '暂无生效套餐',
                style: ZgltText.bodyStrong,
              ),
            ),
            _kvRow('到期日', Text(Format.expiry(expires), style: ZgltText.mono)),
            _kvRow('状态', _PlanBadge(expired: expired, days: days)),
          ]),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: null, child: const Text('续订套餐')),
          const SizedBox(height: 6),
          const Text(
            '购买与续订功能即将上线',
            style: ZgltText.caption,
            textAlign: TextAlign.center,
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
    final (String text, Color bg, Color fg) = expired
        ? ('已过期', ZgltColors.dangerSoft, ZgltColors.danger)
        : days <= 30
        ? ('$days 天后到期', ZgltColors.warningSoft, ZgltColors.warning)
        : ('生效中', ZgltColors.accentSoft, ZgltColors.accent);
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
        style: ZgltText.tiny.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Quick actions row. Only "刷新订阅" works in slice 1; the rest are
/// visibly disabled with an "即将上线" label.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onRefreshSubscription});

  final Future<void> Function() onRefreshSubscription;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuickAction(icon: Icons.dns_outlined, label: '服务器', enabled: false),
        const SizedBox(width: 8),
        _QuickAction(icon: Icons.speed_outlined, label: '测速', enabled: false),
        const SizedBox(width: 8),
        _QuickAction(
          icon: Icons.refresh_outlined,
          label: '刷新订阅',
          enabled: true,
          onTap: onRefreshSubscription,
        ),
        const SizedBox(width: 8),
        _QuickAction(icon: Icons.headset_outlined, label: '客服', enabled: false),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.enabled,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Icon(icon, size: 20, color: ZgltColors.accent),
        const SizedBox(height: 6),
        Text(label, style: ZgltText.caption.copyWith(color: ZgltColors.text2)),
        if (!enabled) const Text('即将上线', style: ZgltText.tiny),
      ],
    );
    final box = Container(
      decoration: BoxDecoration(
        color: ZgltColors.surface,
        border: Border.all(color: ZgltColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Center(child: content),
    );
    return Expanded(
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: onTap == null
            ? box
            : InkWell(
                onTap: () => onTap!(),
                borderRadius: BorderRadius.circular(12),
                child: box,
              ),
      ),
    );
  }
}

/// Placeholder page for tabs that land in later slices.
class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: ZgltColors.text3),
          const SizedBox(height: 12),
          Text('$label即将上线', style: ZgltText.body),
          const SizedBox(height: 4),
          const Text('该功能在后续切片中上线', style: ZgltText.caption),
        ],
      ),
    );
  }
}
