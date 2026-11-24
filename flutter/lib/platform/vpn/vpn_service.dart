/// Plugin-agnostic VPN interface (architecture §3.2).
///
/// Business code talks ONLY to this interface — never to a MethodChannel and
/// never directly to the `sing_box` plugin. Route (c) (the `sing_box`
/// plugin) is one implementation of this interface; route (a) (a self-built
/// plugin porting the SFA service layer) can replace it without touching any
/// business code.
///
/// The state machine is: idle → connecting → connected → disconnecting →
/// idle, plus `error` (with a readable reason) and `reconnecting` (with an
/// attempt count). The UI renders ONLY from this state machine — never with
/// an animation that pretends a connection succeeded.
abstract class VpnService {
  /// One-time setup (core, notification channel). Called from main().
  Future<void> initialize();

  /// Connects with a complete merged sing-box config JSON.
  /// Completes only once the tunnel is actually established.
  Future<void> connect(String fullConfigJson);

  Future<void> disconnect();

  /// Reloads the running config in place (no reconnect).
  Future<void> reload(String fullConfigJson);

  /// Switches server without rebuilding the tunnel.
  Future<void> switchServer(String outboundTag);

  /// Connection status + error reasons.
  Stream<VpnStatus> get statusStream;

  /// Live up/down speed + totals.
  Stream<TrafficStats> get trafficStream;

  /// Real latency per node tag (HTTP through the proxy, not ICMP).
  Future<List<NodeLatency>> testLatency(List<String> tags);

  /// Core logs (redacted before display/upload).
  Future<String> getLogs();
}

enum VpnState {
  idle,
  connecting,
  connected,
  disconnecting,
  error,
  reconnecting,
}

class VpnStatus {
  const VpnStatus({
    required this.state,
    this.error,
    this.currentNode,
    this.connectedAt,
    this.reconnectAttempt,
  });

  final VpnState state;

  /// Human-readable reason when [state] is [VpnState.error].
  final String? error;

  final String? currentNode;
  final DateTime? connectedAt;

  /// Attempt count when [state] is [VpnState.reconnecting].
  final int? reconnectAttempt;
}

class TrafficStats {
  const TrafficStats({
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.downloadTotal,
    required this.uploadTotal,
  });

  /// Current download speed, bytes/second.
  final int downloadSpeed;

  /// Current upload speed, bytes/second.
  final int uploadSpeed;

  /// Session download total, bytes.
  final int downloadTotal;

  /// Session upload total, bytes.
  final int uploadTotal;
}

class NodeLatency {
  const NodeLatency({required this.tag, required this.ms});

  final String tag;

  /// Round-trip milliseconds.
  final int ms;
}

/// Slice-1 stub: the real implementation lands with the Phase 2.5 prototype
/// (sing_box plugin adapter). `connect()` fails loudly instead of pretending
/// to connect — the home shell shows the connect button disabled until then.
class StubVpnService implements VpnService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> connect(String fullConfigJson) {
    return Future.error(StateError('VPN 连接功能尚未上线（阶段 2.5 原型后接入）'));
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> reload(String fullConfigJson) async {}

  @override
  Future<void> switchServer(String outboundTag) async {}

  @override
  Stream<VpnStatus> get statusStream =>
      Stream<VpnStatus>.value(const VpnStatus(state: VpnState.idle));

  @override
  Stream<TrafficStats> get trafficStream => const Stream<TrafficStats>.empty();

  @override
  Future<List<NodeLatency>> testLatency(List<String> tags) async =>
      <NodeLatency>[];

  @override
  Future<String> getLogs() async => '';
}
