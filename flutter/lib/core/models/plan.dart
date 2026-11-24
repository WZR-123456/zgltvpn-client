/// Plan model — field names follow the backend exactly (architecture §4.2).
class Plan {
  const Plan({
    required this.id,
    required this.name,
    required this.kind,
    required this.trafficGb,
    required this.prices,
    required this.nodeIds,
    required this.enabled,
    this.devices,
    this.speed,
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    final pricesJson = json['prices'];
    final nodeIdsJson = json['node_ids'];
    return Plan(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      kind: json['kind'] as String? ?? 'sub',
      trafficGb: json['traffic_gb'] is num
          ? (json['traffic_gb'] as num).toDouble()
          : 0,
      prices: pricesJson is Map<String, dynamic>
          ? PlanPrices.fromJson(pricesJson)
          : const PlanPrices(),
      nodeIds: nodeIdsJson is List
          ? nodeIdsJson.whereType<String>().toList()
          : const <String>[],
      enabled: json['enabled'] as bool? ?? true,
      devices: json['devices'] as String?,
      speed: json['speed'] as String?,
    );
  }

  final String id;
  final String name;

  /// `sub` (subscription plan) or `pack` (traffic pack).
  final String kind;

  /// Traffic allowance, GB (may be backend dirty data — see [Format]).
  final double trafficGb;

  final PlanPrices prices;

  /// Node ids included in this plan; empty means unrestricted.
  final List<String> nodeIds;

  final bool enabled;

  /// Device count limit, as stored by the backend (a string).
  final String? devices;

  /// Speed limit, as stored by the backend (a string).
  final String? speed;
}

/// Multi-period pricing for a plan (CNY).
class PlanPrices {
  const PlanPrices({this.month, this.quarter, this.year});

  factory PlanPrices.fromJson(Map<String, dynamic> json) {
    return PlanPrices(
      month: _toDouble(json['month']),
      quarter: _toDouble(json['quarter']),
      year: _toDouble(json['year']),
    );
  }

  final double? month;
  final double? quarter;
  final double? year;

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return null;
  }
}
