import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/models.dart';

class SessionState {
  final bool loading;
  final User? user;
  final String? csrfToken;
  final String? error;

  const SessionState({
    required this.loading,
    this.user,
    this.csrfToken,
    this.error,
  });

  factory SessionState.loading() => const SessionState(loading: true);
  factory SessionState.unauthenticated() => const SessionState(loading: false);

  SessionState copyWith({
    bool? loading,
    User? user,
    String? csrfToken,
    String? error,
  }) =>
      SessionState(
        loading: loading ?? this.loading,
        user: user ?? this.user,
        csrfToken: csrfToken ?? this.csrfToken,
        error: error,
      );
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  final api = ref.watch(apiClientProvider);
  return SessionNotifier(api)..bootstrap();
});

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier(this.api) : super(SessionState.loading());

  final ApiClient api;

  Future<void> bootstrap() async {
    try {
      final session = await api.me();
      api.csrfToken = session.csrfToken;
      state = SessionState(
          loading: false, user: session.user, csrfToken: session.csrfToken);
    } catch (_) {
      state = SessionState.unauthenticated();
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      final session = await api.login(email, password);
      api.csrfToken = session.csrfToken;
      state = SessionState(
          loading: false, user: session.user, csrfToken: session.csrfToken);
      return true;
    } catch (e) {
      state = SessionState(loading: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await api.logout();
    state = SessionState.unauthenticated();
  }

  void setCsrf(String? token) {
    state = state.copyWith(csrfToken: token);
    api.csrfToken = token;
  }
}
