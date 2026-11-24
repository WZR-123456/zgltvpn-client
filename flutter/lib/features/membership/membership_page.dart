import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/plan.dart';
import '../../core/models/user.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils/format.dart';
import 'membership_controller.dart';

/// Membership page (phase 3 §5.7): current plan + plan list.
///
/// All data is real: the current plan comes from the watched
/// [homeControllerProvider] user (`/api/me`), the plan list from
/// [membershipControllerProvider] (`/api/plans`). Purchase/renewal is
/// not built yet, so every buy button is disabled with the reason
/// shown — nothing is faked.
class MembershipPage extends ConsumerWidget {
  const MembershipPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(membershipControllerProvider);
    final home = ref.watch(homeControllerProvider);
    final loading = membership.isLoading && membership.plans.isEmpty;
    final loadFailed = membership.error != null && membership.plans.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('会员中心', style: ZgltText.heading)),
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
              const _Card(child: Text('暂无在售套餐', style: ZgltText.body))
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
            const SizedBox(height: 4),
            const Text(
              '购买与续订功能即将上线',
              style: ZgltText.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('会员权益', style: ZgltText.heading),
                  SizedBox(height: 6),
                  Text('暂无数据', style: ZgltText.body),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Card(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: false,
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('我的订单', style: ZgltText.bodyStrong),
                trailing: const Text('即将上线', style: ZgltText.caption),
                onTap: null,
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
        '无网络，无法购买',
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

/// Current-plan card from the `/api/me` user: name, expiry, remaining
/// traffic (same math as the home traffic card), renew button.
class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.user, required this.offline});

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
            Text('当前套餐', style: ZgltText.heading),
            SizedBox(height: 6),
            Text('暂无数据', style: ZgltText.body),
          ],
        ),
      );
    }
    if (!current.hasActivePlan && current.planDisplayName.isEmpty) {
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('当前套餐', style: ZgltText.heading),
            const SizedBox(height: 6),
            const Text('暂无生效套餐', style: ZgltText.body),
            const SizedBox(height: 10),
            const ElevatedButton(onPressed: null, child: Text('去购买套餐')),
            const SizedBox(height: 6),
            const Text('购买与续订功能即将上线', style: ZgltText.caption),
            if (offline) ...[
              const SizedBox(height: 6),
              const Text('无网络，显示的是缓存数据', style: ZgltText.caption),
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
          const Text('当前套餐', style: ZgltText.heading),
          const SizedBox(height: 2),
          _kvRow('套餐', Text(planName, style: ZgltText.bodyStrong)),
          _kvRow('到期日', Text(Format.expiry(expires), style: ZgltText.mono)),
          _trafficSection(current),
          if (shouldShowExpiryReminder(expires)) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: ZgltColors.warningSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: Text(
                '套餐将于 ${Format.expiry(expires)} 到期',
                style: ZgltText.caption.copyWith(color: ZgltColors.warning),
              ),
            ),
          ],
          const SizedBox(height: 10),
          const ElevatedButton(onPressed: null, child: Text('续订套餐')),
          const SizedBox(height: 6),
          const Text('购买与续订功能即将上线', style: ZgltText.caption),
        ],
      ),
    );
  }

  /// Remaining-traffic progress bar, same math as the home traffic card:
  /// hidden when the total is backend dirty data, labelled, never raw.
  Widget _trafficSection(User user) {
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
              const Text('剩余流量', style: ZgltText.caption),
              Text(
                dirty ? Format.bytes(total) : '剩余 ${Format.bytes(remaining)}',
                style: ZgltText.caption,
              ),
            ],
          ),
          if (!dirty && total > 0) ...[
            const SizedBox(height: 8),
            _TrafficBar(used: used, total: total),
            const SizedBox(height: 6),
            Text(
              '已用 ${Format.bytes(used)} / 总计 ${Format.bytes(total)}',
              style: ZgltText.caption,
            ),
          ] else if (dirty) ...[
            const SizedBox(height: 6),
            const Text('流量总额数据异常，显示可能不准', style: ZgltText.caption),
          ] else ...[
            const SizedBox(height: 6),
            const Text('暂无流量数据', style: ZgltText.caption),
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
/// selected period. The buy button is disabled — purchase is not built
/// yet (a plan with no price for the period shows "—").
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.period});

  final Plan plan;
  final MembershipPeriod period;

  @override
  Widget build(BuildContext context) {
    final price = priceForPeriod(plan, period);
    final priceText = price == null
        ? '—'
        : '${formatPrice(price)}/${period.label}';
    return _Card(
      child: Row(
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
                        style: ZgltText.bodyStrong,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _KindBadge(kind: plan.kind),
                  ],
                ),
                const SizedBox(height: 4),
                Text(Format.trafficGb(plan.trafficGb), style: ZgltText.caption),
                const SizedBox(height: 4),
                Text(priceText, style: ZgltText.monoLarge),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const ElevatedButton(onPressed: null, child: Text('购买')),
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
    final label = kind == 'pack' ? '流量包' : '套餐';
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: ZgltColors.accentSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: ZgltText.tiny.copyWith(
          color: ZgltColors.accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
