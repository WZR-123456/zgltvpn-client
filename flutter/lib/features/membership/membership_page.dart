import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/plan.dart';
import '../../core/models/user.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils/format.dart';
import '../coming_soon/coming_soon_page.dart';
import 'membership_controller.dart';
import 'orders_page.dart';

/// Membership page (phase 3 §5.7): current plan + plan list.
///
/// All data is real: the current plan comes from the watched
/// [homeControllerProvider] user (`/api/me`), the plan list from
/// [membershipControllerProvider] (`/api/plans`), and the orders list
/// from GET /api/u/orders. Purchase/renewal is not built yet, so every
/// buy button is tappable and opens an honest "即将上线" page naming
/// the feature — nothing is faked, and no purchase is ever charged.
class MembershipPage extends ConsumerWidget {
  const MembershipPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final membership = ref.watch(membershipControllerProvider);
    final home = ref.watch(homeControllerProvider);
    final loading = membership.isLoading && membership.plans.isEmpty;
    final loadFailed = membership.error != null && membership.plans.isEmpty;

    return Scaffold(
      appBar: AppBar(title: Text('会员中心', style: textTheme.titleMedium)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (membership.offline) ...[
            const _OfflineBanner(),
            const SizedBox(height: 12),
          ],
          if (loading) ...[
            const _Skeleton(height: 220),
            const SizedBox(height: 12),
            const _Skeleton(height: 72),
            const SizedBox(height: 8),
            const _Skeleton(height: 72),
            const SizedBox(height: 8),
            const _Skeleton(height: 72),
          ] else if (loadFailed) ...[
            _ErrorBlock(
              message: membership.error!,
              onRetry: () =>
                  ref.read(membershipControllerProvider.notifier).load(),
            ),
          ] else ...[
            _CurrentPlanCard(user: home.user, offline: membership.offline),
            const SizedBox(height: 12),
            _PeriodSegment(
              selected: membership.selectedPeriod,
              onSelected: (period) => ref
                  .read(membershipControllerProvider.notifier)
                  .selectPeriod(period),
            ),
            const SizedBox(height: 12),
            if (membership.plans.isEmpty)
              _Card(child: Text('暂无在售套餐', style: textTheme.bodyMedium))
            else
              ...membership.plans.map(
                (plan) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PlanCard(
                    plan: plan,
                    period: membership.selectedPeriod,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('会员权益', style: textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text('暂无数据', style: textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Card(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text('我的订单', style: textTheme.titleSmall),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const OrdersPage())),
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
        '无网络，无法购买',
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
    // A Material (not a plain Container): the plan card's InkWell paints
    // its ripple on it. Same colour, border and radius as before.
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

/// Current-plan card from the `/api/me` user: name, expiry, remaining
/// traffic (same math as the home traffic card), renew button.
class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.user, required this.offline});

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
            Text('当前套餐', style: textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('暂无数据', style: textTheme.bodyMedium),
          ],
        ),
      );
    }
    if (!current.hasActivePlan && current.planDisplayName.isEmpty) {
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前套餐', style: textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('暂无生效套餐', style: textTheme.bodyMedium),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => openComingSoon(
                context,
                feature: '购买与续订',
                detail:
                    '套餐购买与续订功能即将上线，届时可在应用内用余额购买；'
                    '当前请在网站上购买。',
              ),
              child: const Text('去购买套餐'),
            ),
            if (offline) ...[
              const SizedBox(height: 6),
              Text('无网络，显示的是缓存数据', style: textTheme.bodySmall),
            ],
          ],
        ),
      );
    }
    final planName = current.planDisplayName.isNotEmpty
        ? current.planDisplayName
        : '当前套餐';
    final expires = current.expires;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('当前套餐', style: textTheme.titleMedium),
          const SizedBox(height: 2),
          _kvRow(context, '套餐', Text(planName, style: textTheme.titleSmall)),
          _kvRow(
            context,
            '到期日',
            Text(
              Format.expiry(expires),
              style: textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
            ),
          ),
          _trafficSection(context, current),
          if (shouldShowExpiryReminder(expires)) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: extra.warningSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: Text(
                '套餐将于 ${Format.expiry(expires)} 到期',
                style: textTheme.bodySmall?.copyWith(color: extra.warning),
              ),
            ),
          ],
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

  /// Remaining-traffic progress bar, same math as the home traffic card:
  /// hidden when the total is backend dirty data, labelled, never raw.
  Widget _trafficSection(BuildContext context, User user) {
    final textTheme = Theme.of(context).textTheme;
    final used = user.trafficUsed;
    final total = user.trafficTotal;
    final dirty = Format.isDirtyTraffic(total);
    final remaining = dirty ? 0 : (total - used).clamp(0, total);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('剩余流量', style: textTheme.bodySmall),
              Text(
                dirty ? Format.bytes(total) : '剩余 ${Format.bytes(remaining)}',
                style: textTheme.bodySmall,
              ),
            ],
          ),
          if (!dirty && total > 0) ...[
            const SizedBox(height: 8),
            _TrafficBar(used: used, total: total),
            const SizedBox(height: 6),
            Text(
              '已用 ${Format.bytes(used)} / 总计 ${Format.bytes(total)}',
              style: textTheme.bodySmall,
            ),
          ] else if (dirty) ...[
            const SizedBox(height: 6),
            Text('流量总额数据异常，显示可能不准', style: textTheme.bodySmall),
          ] else ...[
            const SizedBox(height: 6),
            Text('暂无流量数据', style: textTheme.bodySmall),
          ],
        ],
      ),
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

/// 月/季/年 segment control: switches the displayed price only.
class _PeriodSegment extends StatelessWidget {
  const _PeriodSegment({required this.selected, required this.onSelected});

  final MembershipPeriod selected;
  final ValueChanged<MembershipPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<MembershipPeriod>(
      segments: MembershipPeriod.values
          .map(
            (period) => ButtonSegment(value: period, label: Text(period.label)),
          )
          .toList(),
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onSelected(selection.single),
    );
  }
}

/// One sellable plan: name + kind badge + traffic + price for the
/// selected period. Tapping the card expands it to show the plan detail
/// (all three period prices, traffic, device limit, speed limit, nodes);
/// a second tap collapses it. The buy button is tappable and opens an
/// honest "即将上线" page — purchase is not built yet, so no order is
/// ever placed (a plan with no price for the period shows "—").
/// Missing detail fields show "—", never a made-up value.
class _PlanCard extends StatefulWidget {
  const _PlanCard({required this.plan, required this.period});

  final Plan plan;
  final MembershipPeriod period;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final extra = Theme.of(context).extension<ZgltExtraColors>()!;
    final plan = widget.plan;
    final price = priceForPeriod(plan, widget.period);
    final priceText = price == null
        ? '—'
        : '${formatPrice(price)}/${widget.period.label}';
    return _Card(
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              plan.name,
                              style: textTheme.titleSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _KindBadge(kind: plan.kind),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Format.trafficGb(plan.trafficGb),
                        style: textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        priceText,
                        style: textTheme.headlineSmall?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // The app button theme sets minimumSize to
                // Size.fromHeight(48) (infinite width, for full-width
                // buttons). Inside this Row that is unbounded, so this
                // compact button must bound its own minimum width; the
                // 48 height matches the theme, the 64 width is Flutter's
                // default button minimum.
                ElevatedButton(
                  onPressed: () => openComingSoon(
                    context,
                    feature: '购买与续订',
                    detail:
                        '“${plan.name}”的购买功能即将上线，届时可在应用内'
                        '用余额购买；当前请在网站上购买。',
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  child: const Text('购买'),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: extra.text3,
                ),
              ],
            ),
            if (_expanded) ...[
              const Divider(height: 24),
              _DetailRow('月价', formatPrice(plan.prices.month)),
              _DetailRow('季价', formatPrice(plan.prices.quarter)),
              _DetailRow('年价', formatPrice(plan.prices.year)),
              _DetailRow('流量', Format.trafficGb(plan.trafficGb)),
              _DetailRow(
                '设备数',
                plan.devices != null && plan.devices!.isNotEmpty
                    ? plan.devices!
                    : '—',
              ),
              _DetailRow('限速', displaySpeed(plan.speed)),
              _DetailRow(
                '节点',
                plan.nodeIds.isEmpty ? '全部节点' : '包含 ${plan.nodeIds.length} 个节点',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One detail row in the expanded plan card.
class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: textTheme.bodySmall),
          Flexible(
            child: Text(
              value,
              style: textTheme.titleSmall,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final extra = Theme.of(context).extension<ZgltExtraColors>()!;
    final label = kind == 'pack' ? '流量包' : '套餐';
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: extra.accentSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
