import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/catalog_api.dart';
import '../../core/models/node.dart';
import '../../core/providers.dart';

/// Servers state (phase 3 §5.2).
///
/// All data comes from the public catalog API (`/api/nodes` +
/// `/api/nodestatus`). A failed refresh keeps the last-known list and marks
/// the page stale — it never invents nodes or latency.
class ServersState {
  const ServersState({
    this.nodes = const <Node>[],
    this.statuses = const <String, NodeStatus>{},
    this.loading = false,
    this.isRefreshing = false,
    this.error,
    this.offline = false,
    this.searchQuery = '',
    this.lastSync,
  });

  /// Nodes from `GET /api/nodes` (backend order).
  final List<Node> nodes;

  /// Node status from `GET /api/nodestatus`, keyed by node name.
  /// [NodeStatus] carries no node id, so the name is the only join key;
  /// a node with no matching status entry shows latency "—".
  final Map<String, NodeStatus> statuses;

  /// True while the first load is running (no data yet).
  final bool loading;

  /// True while a pull-to-refresh / retry is running over cached data.
  final bool isRefreshing;

  /// Last load error. Shown as an error block when there is no data yet,
  /// and as a banner above the cached list otherwise.
  final String? error;

  /// True when the list on screen comes from the last successful load
  /// (the latest refresh hit a network failure).
  final bool offline;

  /// Raw search text; filtering is case-insensitive substring on
  /// name/region (see [filteredNodes]).
  final String searchQuery;

  final DateTime? lastSync;

  /// Nodes matching [searchQuery], in backend order.
  List<Node> get filteredNodes {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return nodes;
    return nodes
        .where(
          (node) =>
              node.name.toLowerCase().contains(query) ||
              node.region.toLowerCase().contains(query),
        )
        .toList();
  }

  /// [filteredNodes] grouped by region, region keys sorted for a stable
  /// list; nodes inside a group keep backend order.
  Map<String, List<Node>> get groupedNodes {
    final groups = <String, List<Node>>{};
    for (final node in filteredNodes) {
      groups.putIfAbsent(node.region, () => <Node>[]).add(node);
    }
    final keys = groups.keys.toList()..sort();
    return {for (final key in keys) key: groups[key]!};
  }

  /// Latency from `/api/nodestatus` only (never from anywhere else).
  /// Null when the node has no status entry — the page shows "—".
  /// While [offline] the page shows "—" for every row instead.
  int? latencyMs(Node node) {
    if (offline) return null;
    return statuses[node.name]?.ms;
  }

  /// Display status for one node. The backend TCP check (`check.ok` /
  /// status `ok`) is real server-side data, but it is TCP-only — it does
  /// NOT prove the protocol connects, so the badge never claims more
  /// than "可用" for the TCP check.
  ServersNodeStatus statusFor(Node node) {
    if (!node.enabled) return ServersNodeStatus.disabled;
    final status = statuses[node.name];
    if (status != null) {
      return status.ok
          ? ServersNodeStatus.available
          : ServersNodeStatus.unreachable;
    }
    final check = node.check;
    if (check != null) {
      return check.ok
          ? ServersNodeStatus.available
          : ServersNodeStatus.unreachable;
    }
    return ServersNodeStatus.unknown;
  }

  ServersState copyWith({
    List<Node>? nodes,
    Map<String, NodeStatus>? statuses,
    bool? loading,
    bool? isRefreshing,
    String? error,
    bool? offline,
    String? searchQuery,
    DateTime? lastSync,
  }) {
    return ServersState(
      nodes: nodes ?? this.nodes,
      statuses: statuses ?? this.statuses,
      loading: loading ?? this.loading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
      offline: offline ?? this.offline,
      searchQuery: searchQuery ?? this.searchQuery,
      lastSync: lastSync ?? this.lastSync,
    );
  }
}

/// Badge shown at the end of a node row.
enum ServersNodeStatus {
  available,
  unreachable,
  disabled,

  /// No `/api/nodestatus` entry and no `check` on the node: the page shows
  /// the badge "暂无数据" and latency "—" rather than guessing.
  unknown,
}

extension ServersNodeStatusLabel on ServersNodeStatus {
  String get label => switch (this) {
    ServersNodeStatus.available => '可用',
    ServersNodeStatus.unreachable => '不可达',
    ServersNodeStatus.disabled => '已停用',
    ServersNodeStatus.unknown => '暂无数据',
  };
}

class ServersController extends StateNotifier<ServersState> {
  ServersController(this._catalogApi) : super(const ServersState());

  final CatalogApi _catalogApi;

  /// Loads nodes + statuses together; pull-to-refresh re-runs both.
  /// A failure keeps the last-known list: network failure marks the page
  /// [ServersState.offline], any other failure records [ServersState.error].
  Future<void> refresh() async {
    if (state.loading || state.isRefreshing) return;
    final hasData = state.nodes.isNotEmpty;
    state = state.copyWith(
      loading: !hasData,
      isRefreshing: hasData,
      error: null,
    );
    try {
      final results = await Future.wait([
        _catalogApi.nodes(),
        _catalogApi.nodeStatus(),
      ]);
      final nodes = results[0] as List<Node>;
      final statuses = results[1] as List<NodeStatus>;
      state = state.copyWith(
        nodes: nodes,
        statuses: {for (final s in statuses) s.name: s},
        loading: false,
        isRefreshing: false,
        offline: false,
        lastSync: DateTime.now(),
      );
    } on ApiException catch (e) {
      final isNetwork = e.kind == ApiErrorKind.network;
      state = state.copyWith(
        loading: false,
        isRefreshing: false,
        // Network failure: the offline banner explains it, no error block.
        // Any other failure: show the backend message verbatim (§8.2),
        // or the generic copy when the backend gave none.
        error: isNetwork
            ? null
            : (e.message.isNotEmpty ? e.message : '节点列表加载失败，请重试'),
        offline: isNetwork,
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        isRefreshing: false,
        error: '节点列表加载失败，请重试',
      );
    }
  }

  /// Updates the search query; filtering is derived, no reload.
  void setSearchQuery(String query) {
    if (query == state.searchQuery) return;
    state = state.copyWith(searchQuery: query);
  }
}

/// Servers controller, built from [catalogApiProvider] (defined here so
/// `core/providers.dart` stays untouched).
final serversControllerProvider =
    StateNotifierProvider<ServersController, ServersState>(
      (ref) => ServersController(ref.watch(catalogApiProvider)),
    );
