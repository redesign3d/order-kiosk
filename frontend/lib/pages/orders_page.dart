import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../api/models.dart';
import '../state/orders.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/metric_card.dart';
import 'order_detail_page.dart';

const _statusSegments = <String, String>{
  'all': 'All',
  'PENDING': 'New',
  'PROCESSING': 'Processing',
  'COMPLETED': 'Completed',
  'CANCELLED': 'Cancelled',
  'REFUNDED': 'Refunded',
  'DRAFT': 'Draft',
};

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  String _selected = 'all';
  Timer? _timer;
  final _searchController = TextEditingController();
  int _currentInterval = 15;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _load(reset: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _ensurePolling(int interval) {
    if (_timer != null && _currentInterval == interval) return;
    _currentInterval = interval;
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: interval), (_) => _load());
  }

  Future<void> _load({bool reset = false}) async {
    final status = _selected == 'all' ? null : _selected;
    await ref.read(ordersProvider.notifier).load(
          status: status,
          search:
              _searchController.text.isEmpty ? null : _searchController.text,
          reset: reset,
        );
  }

  String _formatCurrency(Order order) {
    final formatter = NumberFormat.simpleCurrency(name: order.currency);
    return formatter.format(order.total);
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(ordersProvider);
    final settingsState = ref.watch(settingsProvider);
    final interval =
        settingsState.settings?.pollingIntervalSeconds ?? _currentInterval;
    _ensurePolling(interval);
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Orders'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _load,
          child: const Icon(CupertinoIcons.refresh, size: 20),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CupertinoSegmentedControl<String>(
                    groupValue: _selected,
                    onValueChanged: (val) {
                      setState(() => _selected = val);
                      _load(reset: true);
                    },
                    children: _statusSegments.map(
                      (key, value) => MapEntry(
                        key,
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: Text(value),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CupertinoSearchTextField(
                    controller: _searchController,
                    onSubmitted: (_) => _load(reset: true),
                    onSuffixTap: () {
                      _searchController.clear();
                      _load(reset: true);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (ordersState.metrics != null)
                    _buildMetrics(ordersState.metrics!, isDark),
                ],
              ),
            ),
            Expanded(
              child: ordersState.loading && ordersState.orders.isEmpty
                  ? const Center(child: CupertinoActivityIndicator())
                  : _buildList(ordersState, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetrics(OrderMetrics metrics, bool isDark) {
    String byStatus(String status) {
      final found = metrics.byStatus.firstWhere(
        (s) => s.status == status,
        orElse: () => OrderStatusMetric(status: status, count: 0, total: 0),
      );
      return '${found.count} · ${NumberFormat.compactCurrency(symbol: '').format(found.total)}';
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        MetricCard(
            title: 'Today',
            value: NumberFormat.compactSimpleCurrency()
                .format(metrics.revenueToday)),
        MetricCard(
            title: 'Last 7d',
            value:
                NumberFormat.compactSimpleCurrency().format(metrics.revenue7d)),
        MetricCard(
            title: 'Avg order',
            value: NumberFormat.simpleCurrency().format(metrics.avgOrderValue)),
        MetricCard(title: 'Processing', value: byStatus('PROCESSING')),
        MetricCard(title: 'Completed', value: byStatus('COMPLETED')),
      ],
    );
  }

  Widget _buildList(OrdersState state, bool isDark) {
    if (state.error != null) {
      return Center(
          child: Text(state.error!,
              style: const TextStyle(color: CupertinoColors.systemRed)));
    }

    if (state.orders.isEmpty) {
      return const Center(child: Text('No orders yet'));
    }

    return CupertinoScrollbar(
      child: ListView.builder(
        itemCount: state.orders.length,
        itemBuilder: (context, index) {
          final order = state.orders[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(
                    builder: (_) => OrderDetailPage(order: order)),
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : AppColors.cardLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? CupertinoColors.systemGrey3
                        : CupertinoColors.systemGrey5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('#${order.number}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                          order.billingName ?? 'Guest',
                          style: const TextStyle(
                              color: CupertinoColors.systemGrey),
                        ),
                        Text(
                          DateFormat.MMMd()
                              .add_jm()
                              .format(order.updatedAt.toLocal()),
                          style: const TextStyle(
                              color: CupertinoColors.systemGrey, fontSize: 12),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _StatusPill(status: order.status),
                        const SizedBox(height: 6),
                        Text(
                          _formatCurrency(order),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = {
      'PENDING': CupertinoColors.activeOrange,
      'PROCESSING': CupertinoColors.activeGreen,
      'COMPLETED': CupertinoColors.systemGreen,
      'CANCELLED': CupertinoColors.systemRed,
      'REFUNDED': CupertinoColors.systemTeal,
      'DRAFT': CupertinoColors.systemGrey,
    };
    final color = colors[status] ?? CupertinoColors.systemGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style:
            TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
