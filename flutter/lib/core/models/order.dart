/// One order from GET /api/u/orders (backend v11).
///
/// The backend returns a bare array of order records for the logged-in
/// user (newest first, max 50). Fields are shown as stored — nothing is
/// invented when a field is missing.
class Order {
  const Order({
    required this.id,
    required this.item,
    required this.amount,
    required this.status,
    required this.created,
    this.kind = '',
    this.channel = '',
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final amount = json['amount'];
    return Order(
      id: json['id'] as String? ?? '',
      item: json['item'] as String? ?? '',
      amount: amount is num ? amount.toDouble() : 0,
      status: json['status'] as String? ?? '',
      created: json['created'] is int
          ? json['created'] as int
          : (json['created'] as num?)?.toInt() ?? 0,
      kind: json['kind'] as String? ?? '',
      channel: json['channel'] as String? ?? '',
    );
  }

  /// Order id (10 random chars server-side).
  final String id;

  /// Item description, e.g. '月套餐 month'. Empty when the backend
  /// stored none.
  final String item;

  /// Amount actually paid, CNY.
  final double amount;

  /// Raw status string from the backend ('paid', ...).
  final String status;

  /// Created time, milliseconds since epoch. 0 when unknown.
  final int created;

  /// Order kind ('plan', 'reset', ...).
  final String kind;

  /// Payment channel ('余额支付', ...).
  final String channel;

  /// Display label for [status]. Unknown values are shown as stored,
  /// never mapped to a made-up state.
  String get statusLabel => switch (status) {
    'paid' => '已支付',
    'pending' => '待支付',
    'cancelled' => '已取消',
    'refunded' => '已退款',
    '' => '—',
    _ => status,
  };
}
