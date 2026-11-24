import 'api_client.dart';
import '../models/order.dart';

/// Orders API: GET /api/u/orders (backend v11, logged-in user only).
///
/// Returns the user's own orders, newest first (max 50 server-side).
/// The backend returns a bare array; an object with an `orders` key is
/// accepted too, for forward compatibility.
class OrdersApi {
  OrdersApi(this._client);

  final ApiClient _client;

  Future<List<Order>> orders() async {
    final response = await _client.get('/api/u/orders');
    final data = response.data;
    final list = data is Map<String, dynamic>
        ? ApiClient.asList(data['orders'])
        : ApiClient.asList(data);
    return list.whereType<Map<String, dynamic>>().map(Order.fromJson).toList();
  }
}
