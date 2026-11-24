import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/node.dart';
import '../../core/theme.dart';
import '../../core/utils/format.dart';
import 'servers_controller.dart';

/// Servers page (phase 3 §5.2): search + node list grouped by region.
///
/// All data comes from the public catalog API. Anything not yet built is
/// shown disabled with its reason — nothing is faked: no favorites/recent
/// segments (no persistence layer yet), and node switching is disabled
/// until the VPN connection feature lands.
class ServersPage extends ConsumerStatefulWidget {
  const ServersPage({super.key});

  @override
  ConsumerState<ServersPage> createState() => _ServersPageState();
}

class _ServersPageState extends ConsumerState<ServersPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(serversControllerProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serversControllerProvider);
    final notifier = ref.read(serversControllerProvider.notifier);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: notifier.setSearchQuery,
            decoration: InputDecoration(
              hintText: '搜索节点 / 地区',
              prefixIcon: const Icon(Icons.search_outlined),
              suffixIcon: _SearchClearButton(
                onClear: () {
                  _searchController.clear();
                  notifier.setSearchQuery('');
                },
              ),
            ),
          ),
        ),
        Expanded(child: _buildBody(context, state)),
      ],
    );
  }

  Widget _buildBody(BuildContext context, ServersState state) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // First load, nothing cached yet: 8-row skeleton (§5.2 加载).
    if (state.loading && state.nodes.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 8,
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: _SkeletonRow(),
        ),
      );
    }
    // Load failed with nothing cached: error block + retry (§5.2 错误).
    if (state.error != null && state.nodes.isEmpty) {
      return _CenterState(
        message: state.error!,
        buttonLabel: '重试',
        onButton: () => ref.read(serversControllerProvider.notifier).refresh(),
      );
    }
    // Loaded, but no nodes at all: empty state (§5.2 空数据).
    if (state.nodes.isEmpty) {
      return _CenterState(
        message: '暂无可用节点',
        buttonLabel: '刷新',
        onButton: () => ref.read(serversControllerProvider.notifier).refresh(),
      );
    }
    // Search matched nothing: keep the list hidden, offer to clear.
    if (state.filteredNodes.isEmpty) {
      return _CenterState(
        message: '未找到匹配的节点',
        buttonLabel: '清除搜索',
        onButton: () {
          _searchController.clear();
          ref.read(serversControllerProvider.notifier).setSearchQuery('');
        },
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(serversControllerProvider.notifier).refresh(),
      color: scheme.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          if (state.offline) ...[
            _OfflineBanner(state: state),
            const SizedBox(height: 8),
          ],
          if (state.error != null) ...[
            _ErrorBanner(
              message: state.error!,
              onRetry: () =>
                  ref.read(serversControllerProvider.notifier).refresh(),
            ),
            const SizedBox(height: 8),
          ],
          for (final entry in state.groupedNodes.entries) ...[
            _RegionHeader(region: entry.key),
            ...entry.value.map((node) => _NodeRow(node: node, state: state)),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          Text(
            '延迟为服务端 TCP 检测结果',
            style: textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SearchClearButton extends ConsumerWidget {
  const _SearchClearButton({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(
      serversControllerProvider.select((state) => state.searchQuery),
    );
    if (query.isEmpty) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.clear_outlined),
      tooltip: '清除搜索',
      onPressed: onClear,
    );
  }
}

/// Static grey row used while the first load is running (no shimmer).
class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

/// Centered icon + message + one main action (§8.1 空数据 / 错误).
class _CenterState extends StatelessWidget {
  const _CenterState({
    required this.message,
    required this.buttonLabel,
    required this.onButton,
  });

  final String message;
  final String buttonLabel;
  final VoidCallback onButton;

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
            Icon(Icons.dns_outlined, size: 48, color: extra.text3),
            const SizedBox(height: 12),
            Text(
              message,
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 160,
              child: OutlinedButton(
                onPressed: onButton,
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.state});

  final ServersState state;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final extra = Theme.of(context).extension<ZgltExtraColors>()!;
    final sync = state.lastSync != null
        ? ' · 最后同步 ${Format.syncTime(state.lastSync!)}'
        : '';
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: extra.warningSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Text(
        '无网络，节点状态为缓存数据$sync',
        style: textTheme.bodySmall?.copyWith(color: extra.warning),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

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

class _RegionHeader extends StatelessWidget {
  const _RegionHeader({required this.region});

  final String region;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        region.isEmpty ? '其他地区' : region,
        style: textTheme.titleMedium,
      ),
    );
  }
}

/// One 56dp node row (§5.2). Disabled nodes are greyed and not tappable.
class _NodeRow extends StatelessWidget {
  const _NodeRow({required this.node, required this.state});

  final Node node;
  final ServersState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final status = state.statusFor(node);
    final disabled = status == ServersNodeStatus.disabled;
    final latency = state.latencyMs(node);
    final row = SizedBox(
      height: 56,
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(node.name, style: textTheme.titleSmall, maxLines: 1),
                const SizedBox(height: 2),
                Text(
                  '${node.region.isEmpty ? '未知地区' : node.region} · ${node.type}',
                  style: textTheme.bodySmall,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            latency == null ? '—' : '${latency}ms',
            style: textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
          ),
          const SizedBox(width: 8),
          _StatusBadge(status: status),
        ],
      ),
    );
    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: row,
    );
    final boxed = Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outline)),
      ),
      child: padded,
    );
    if (disabled) {
      return Opacity(opacity: 0.55, child: boxed);
    }
    return Material(
      color: scheme.surface,
      child: InkWell(
        onTap: () => _showNodeSheet(context, node, state),
        child: boxed,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final ServersNodeStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final extra = Theme.of(context).extension<ZgltExtraColors>()!;
    final (Color bg, Color fg) = switch (status) {
      ServersNodeStatus.available => (extra.accentSoft, scheme.primary),
      ServersNodeStatus.unreachable => (extra.dangerSoft, extra.danger),
      ServersNodeStatus.disabled => (
        scheme.surfaceContainerHighest,
        extra.text3,
      ),
      ServersNodeStatus.unknown => (
        scheme.surfaceContainerHighest,
        extra.text3,
      ),
    };
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        status.label,
        style: textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Node detail bottom sheet (§5.2): details + latency + switch button.
///
/// The switch button is disabled until the VPN connection feature lands —
/// it must never pretend a switch happened.
Future<void> _showNodeSheet(
  BuildContext context,
  Node node,
  ServersState state,
) {
  final scheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;
  final status = state.statusFor(node);
  final latency = state.latencyMs(node);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: scheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    node.name,
                    style: textTheme.titleLarge,
                    maxLines: 1,
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 12),
            _DetailRow(label: '地区', value: node.region),
            _DetailRow(label: '类型', value: node.type),
            _DetailRow(label: '服务器', value: node.server),
            _DetailRow(label: '端口', value: '${node.port}'),
            _DetailRow(label: 'TLS', value: node.tls ? '开启' : '关闭'),
            _DetailRow(
              label: '延迟',
              value: latency == null ? '—' : '${latency}ms',
            ),
            const SizedBox(height: 4),
            Text('延迟为服务端 TCP 检测结果', style: textTheme.labelSmall),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: null,
                child: const Text('切换到该节点'),
              ),
            ),
            const SizedBox(height: 8),
            Center(child: Text('节点切换随 VPN 连接功能上线', style: textTheme.bodySmall)),
          ],
        ),
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: textTheme.bodySmall),
          Flexible(
            child: Text(
              value.isEmpty ? '—' : value,
              style: textTheme.bodyMedium,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
