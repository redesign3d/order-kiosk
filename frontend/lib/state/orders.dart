import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models.dart';
import '../api/api_client.dart';
import 'session.dart';

class OrdersState {
  final bool loading;
  final List<Order> orders;
  final OrderMetrics? metrics;
  final int total;
  final String? error;
  final String? statusFilter;
  final String? search;
  final DateTime? modifiedAfter;

  OrdersState({
    required this.loading,
    required this.orders,
    required this.total,
    this.metrics,
    this.error,
    this.statusFilter,
    this.search,
    this.modifiedAfter,
  });

  factory OrdersState.initial() =>
      OrdersState(loading: false, orders: const [], total: 0, metrics: null);

  OrdersState copyWith({
    bool? loading,
    List<Order>? orders,
    OrderMetrics? metrics,
    int? total,
    String? error,
    String? statusFilter,
    String? search,
    DateTime? modifiedAfter,
  }) =>
      OrdersState(
        loading: loading ?? this.loading,
        orders: orders ?? this.orders,
        metrics: metrics ?? this.metrics,
        total: total ?? this.total,
        error: error,
        statusFilter: statusFilter ?? this.statusFilter,
        search: search ?? this.search,
        modifiedAfter: modifiedAfter ?? this.modifiedAfter,
      );
}

final ordersProvider = StateNotifierProvider<OrdersNotifier, OrdersState>(
    (ref) => OrdersNotifier(ref));

class OrdersNotifier extends StateNotifier<OrdersState> {
  OrdersNotifier(this._ref) : super(OrdersState.initial());

  final Ref _ref;
  int _page = 1;
  final int _pageSize = 25;

  ApiClient get _api => _ref.read(apiClientProvider);

  Future<void> load(
      {String? status, String? search, bool reset = false}) async {
    if (reset) _page = 1;
    state = state.copyWith(
        loading: true, statusFilter: status, search: search, error: null);
    try {
      final response = await _api.fetchOrders(
        page: _page,
        pageSize: _pageSize,
        status: status,
        search: search,
        modifiedAfter: state.modifiedAfter?.toIso8601String(),
      );
      state = state.copyWith(
        loading: false,
        orders: response.items,
        metrics: response.metrics,
        total: response.total,
        modifiedAfter: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<Order?> fetchOrder(int id) async {
    try {
      return await _api.fetchOrder(id);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }
}
