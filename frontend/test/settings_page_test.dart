import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/api/api_client.dart';
import 'package:frontend/api/models.dart';
import 'package:frontend/pages/settings_page.dart';
import 'package:frontend/state/session.dart';
import 'package:frontend/state/settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockApiClient api;

  setUp(() {
    api = _MockApiClient();
    when(() => api.fetchSettings()).thenAnswer(
      (_) async => Settings(
        storeUrl: 'https://example.com',
        includeDrafts: false,
        pollingIntervalSeconds: 15,
        hasCredentials: true,
        hasWebhookSecret: true,
      ),
    );
  });

  testWidgets('renders settings fields', (tester) async {
    final sessionNotifier = SessionNotifier(api)
      ..state = SessionState(
        loading: false,
        user: User(
            id: '1', email: 'admin@test.com', role: 'ADMIN', lastLoginAt: null),
        csrfToken: 'token',
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          settingsProvider.overrideWith((ref) => SettingsNotifier(ref)),
          sessionProvider.overrideWith((ref) => sessionNotifier),
        ],
        child: const CupertinoApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('WooCommerce connection'), findsOneWidget);
    expect(find.text('https://example.com'), findsOneWidget);
  });
}
