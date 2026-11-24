/// Node model — field names follow the backend exactly (architecture §4.2).
///
/// `GET /api/nodes` deliberately omits passwords/uuids, so the public node
/// list is safe to display.
class Node {
  const Node({
    required this.id,
    required this.name,
    required this.region,
    required this.type,
    required this.server,
    required this.port,
    required this.tls,
    required this.enabled,
    this.sni,
    this.skipCert = false,
    this.check,
  });

  factory Node.fromJson(Map<String, dynamic> json) {
    final checkJson = json['check'];
    return Node(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      region: json['region'] as String? ?? '',
      type: json['type'] as String? ?? '',
      server: json['server'] as String? ?? '',
      port: json['port'] is int
          ? json['port'] as int
          : (json['port'] as num?)?.toInt() ?? 0,
      tls: json['tls'] as bool? ?? false,
      enabled: json['enabled'] as bool? ?? true,
      sni: json['sni'] as String?,
      skipCert: json['skip_cert'] as bool? ?? false,
      check: checkJson is Map<String, dynamic>
          ? NodeCheck.fromJson(checkJson)
          : null,
    );
  }

  final String id;
  final String name;
  final String region;

  /// Protocol: vmess | vless | trojan | ss | hysteria2.
  final String type;

  final String server;
  final int port;
  final bool tls;
  final bool enabled;
  final String? sni;
  final bool skipCert;

  /// Last TCP health check from the backend (TCP only — a green check does
  /// NOT prove the protocol actually connects).
  final NodeCheck? check;
}

/// One backend TCP health check result.
class NodeCheck {
  const NodeCheck({required this.ok, this.ms, this.at});

  factory NodeCheck.fromJson(Map<String, dynamic> json) {
    return NodeCheck(
      ok: json['ok'] as bool? ?? false,
      ms: json['ms'] is int ? json['ms'] as int : (json['ms'] as num?)?.toInt(),
      at: json['at'] is int ? json['at'] as int : (json['at'] as num?)?.toInt(),
    );
  }

  final bool ok;

  /// Round-trip milliseconds.
  final int? ms;

  /// Check time, milliseconds since epoch.
  final int? at;
}

/// Node status from `GET /api/nodestatus` (public, no login needed).
class NodeStatus {
  const NodeStatus({
    required this.name,
    required this.region,
    required this.ok,
    this.ms,
    this.history = const <NodeCheck>[],
  });

  factory NodeStatus.fromJson(Map<String, dynamic> json) {
    final historyJson = json['history'];
    return NodeStatus(
      name: json['name'] as String? ?? '',
      region: json['region'] as String? ?? '',
      ok: json['ok'] as bool? ?? false,
      ms: json['ms'] is int ? json['ms'] as int : (json['ms'] as num?)?.toInt(),
      history: historyJson is List
          ? historyJson
                .whereType<Map<String, dynamic>>()
                .map(NodeCheck.fromJson)
                .toList()
          : const <NodeCheck>[],
    );
  }

  final String name;
  final String region;
  final bool ok;
  final int? ms;
  final List<NodeCheck> history;
}
