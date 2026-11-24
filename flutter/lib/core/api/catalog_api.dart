import 'api_client.dart';
import '../models/node.dart';
import '../models/plan.dart';

/// Public catalog API: plans + nodes (no login needed).
class CatalogApi {
  CatalogApi(this._client);

  final ApiClient _client;

  /// Enabled plan list. The backend may return a bare array or an object
  /// with a `plans` key; both shapes are accepted.
  Future<List<Plan>> plans() async {
    final response = await _client.get('/api/plans');
    final data = response.data;
    final list = data is Map<String, dynamic>
        ? ApiClient.asList(data['plans'])
        : ApiClient.asList(data);
    return list.whereType<Map<String, dynamic>>().map(Plan.fromJson).toList();
  }

  /// Enabled node list (no passwords/uuids — safe to display).
  Future<List<Node>> nodes() async {
    final response = await _client.get('/api/nodes');
    final data = response.data;
    final list = data is Map<String, dynamic>
        ? ApiClient.asList(data['nodes'])
        : ApiClient.asList(data);
    return list.whereType<Map<String, dynamic>>().map(Node.fromJson).toList();
  }

  /// Node status + latency + recent check history (public).
  Future<List<NodeStatus>> nodeStatus() async {
    final response = await _client.get('/api/nodestatus');
    final data = response.data;
    final list = data is Map<String, dynamic>
        ? ApiClient.asList(data['nodes'] ?? data['status'])
        : ApiClient.asList(data);
    return list
        .whereType<Map<String, dynamic>>()
        .map(NodeStatus.fromJson)
        .toList();
  }
}
