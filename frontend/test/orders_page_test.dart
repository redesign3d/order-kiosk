import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:frontend/api/api_client.dart';
import 'package:frontend/api/models.dart';
import 'package:frontend/pages/orders_page.dart';
import 'package:frontend/state/orders.dart';
import 'package:frontend/state/settings.dart';
import 'package:frontend/state/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockApiClient api;

  setUp(() {
    api = _MockApiClient();
    final order = Order(
      id: 1,
      number: 'A100',
      status: 'PROCESSING',
      currency: 'USD',
      total: 25,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      items: [
        OrderItem(name: 'Widget', quantity: 1, total: 25, sku: 'W-1'),
      ],
    );
    when(
      () => api.fetchOrders(
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
        status: any(named: 'status'),
        search: any(named: 'search'),
        modifiedAfter: any(named: 'modifiedAfter'),
      ),
    ).thenAnswer(
      (_) async => OrdersResponse(
        items: [order],
        total: 1,
        metrics: OrderMetrics(
          byStatus: [
            OrderStatusMetric(status: 'PROCESSING', count: 1, total: 25)
          ],
          revenueToday: 25,
          revenue7d: 25,
          avgOrderValue: 25,
        ),
      ),
    );
    when(() => api.fetchOrder(any())).thenAnswer((_) async => order);
  });

  testWidgets('shows orders and metrics', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          settingsProvider.overrideWith((ref) => SettingsNotifier(ref)),
          ordersProvider.overrideWith((ref) => OrdersNotifier(ref)),
        ],
        child: const CupertinoApp(home: OrdersPage()),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('#A100'), findsOneWidget);
    expect(find.textContaining('Processing'), findsWidgets);
  });
}
