import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/order.dart';
import '../../core/theme.dart';
import '../../core/utils/format.dart';
import 'orders_controller.dart';

/// Orders page: the user's own orders from GET /api/u/orders.
///
/// Read-only and real — every row comes from the backend. No order is
/// ever fabricated; an empty list shows "暂无订单".
class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final orders = ref.watch(ordersControllerProvider);
    final loading = orders.isLoading && orders.orders.isEmpty;
    final loadFailed = orders.error != null && orders.orders.isEmpty;

    return Scaffold(
      appBar: AppBar(title: Text('我的订单', style: textTheme.titleMedium)),
      body: loading
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                _Skeleton(height: 72),
                SizedBox(height: 8),
                _Skeleton(height: 72),
                SizedBox(height: 8),
                _Skeleton(height: 72),
              ],
            )
          : loadFailed
          ? _ErrorBlock(
              message: orders.error!,
              onRetry: () => ref.read(ordersControllerProvider.notifier).load(),
            )
          : orders.orders.isEmpty
          ? Center(child: Text('暂无订单', style: textTheme.bodyMedium))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: orders.orders
                  .map(
                    (order) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _OrderCard(order: order),
                    ),
                  )
                  .toList(),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: textTheme.bodyMedium?.copyWith(color: extra.danger),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 160,
              child: OutlinedButton(
                onPressed: onRetry,
                child: const Text('重试'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final extra = Theme.of(context).extension<ZgltExtraColors>()!;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order.item.isNotEmpty ? order.item : '—',
                    style: textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '¥${order.amount == order.amount.truncateToDouble() ? order.amount.toInt() : order.amount.toStringAsFixed(2)}',
                  style: textTheme.titleSmall?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.created > 0 ? Format.expiry(order.created) : '时间未知',
                  style: textTheme.bodySmall,
                ),
                Container(
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: order.status == 'paid'
                        ? extra.accentSoft
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    order.statusLabel,
                    style: textTheme.labelSmall?.copyWith(
                      color: order.status == 'paid'
                          ? scheme.primary
                          : extra.text3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (order.channel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(order.channel, style: textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
