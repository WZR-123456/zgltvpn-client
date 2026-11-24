import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/orders_api.dart';
import '../../core/models/order.dart';
import '../../core/providers.dart';

/// Orders state: the user's own orders from [OrdersApi.orders].
class OrdersState {
  const OrdersState({
    this.orders = const <Order>[],
    this.isLoading = false,
    this.error,
  });

  final List<Order> orders;

  final bool isLoading;

  /// Load error, shown with a retry button when there is no list yet.
  final String? error;

  OrdersState copyWith({
    List<Order>? orders,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return OrdersState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class OrdersController extends StateNotifier<OrdersState> {
  OrdersController(this._ordersApi) : super(const OrdersState(isLoading: true));

  final OrdersApi _ordersApi;
  bool _loading = false;

  /// Loads the order list. A failure shows the error state (with
  /// retry); no orders are ever fabricated.
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final orders = await _ordersApi.orders();
      state = state.copyWith(orders: orders, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.kind == ApiErrorKind.network
            ? '网络异常，请重试'
            : e.message.isNotEmpty
            ? e.message
            : '订单加载失败，请重试',
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, error: '订单加载失败，请重试');
    } finally {
      _loading = false;
    }
  }
}

final ordersControllerProvider =
    StateNotifierProvider<OrdersController, OrdersState>(
      (ref) => OrdersController(ref.watch(ordersApiProvider))..load(),
    );
