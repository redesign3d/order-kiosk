import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../api/models.dart';
import '../state/orders.dart';
import '../theme.dart';

class OrderDetailPage extends ConsumerStatefulWidget {
  const OrderDetailPage({super.key, required this.order});

  final Order order;

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  late Order _order;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final latest =
        await ref.read(ordersProvider.notifier).fetchOrder(_order.id);
    if (latest != null && mounted) {
      setState(() => _order = latest);
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  String _formatMoney(double value) {
    final formatter = NumberFormat.simpleCurrency(name: _order.currency);
    return formatter.format(value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Order #${_order.number}'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _refresh,
          child: _loading
              ? const CupertinoActivityIndicator()
              : const Icon(CupertinoIcons.refresh, size: 20),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _InfoRow(label: 'Status', value: _order.status),
            _InfoRow(label: 'Customer', value: _order.billingName ?? 'Unknown'),
            _InfoRow(label: 'Email', value: _order.billingEmail ?? '—'),
            _InfoRow(label: 'Payment', value: _order.paymentMethod ?? '—'),
            _InfoRow(
                label: 'Placed',
                value: DateFormat.yMMMd()
                    .add_jm()
                    .format(_order.createdAt.toLocal())),
            const SizedBox(height: 16),
            Text(
              'Items',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? CupertinoColors.white : CupertinoColors.black,
              ),
            ),
            const SizedBox(height: 8),
            ..._order.items.map(
              (item) => Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : AppColors.cardLight,
                  borderRadius: BorderRadius.circular(12),
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
                        Text(item.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          'x${item.quantity} ${item.sku ?? ''}',
                          style: const TextStyle(
                              color: CupertinoColors.systemGrey),
                        ),
                      ],
                    ),
                    Text(_formatMoney(item.total)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(
                  _formatMoney(_order.total),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            if (_order.customerNote != null) ...[
              const SizedBox(height: 12),
              Text(
                'Customer note',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? CupertinoColors.white : CupertinoColors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(_order.customerNote!),
            ]
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: CupertinoColors.systemGrey)),
          Text(value),
        ],
      ),
    );
  }
}
