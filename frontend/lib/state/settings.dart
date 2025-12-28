import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models.dart';
import '../api/api_client.dart';
import 'session.dart';

class SettingsState {
  final bool loading;
  final Settings? settings;
  final String? message;
  final String? error;

  SettingsState(
      {required this.loading, this.settings, this.message, this.error});

  factory SettingsState.initial() => SettingsState(loading: false);

  SettingsState copyWith({
    bool? loading,
    Settings? settings,
    String? message,
    String? error,
  }) =>
      SettingsState(
        loading: loading ?? this.loading,
        settings: settings ?? this.settings,
        message: message,
        error: error,
      );
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
    (ref) => SettingsNotifier(ref));

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier(this._ref) : super(SettingsState.initial());

  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final settings = await _api.fetchSettings();
      state = state.copyWith(loading: false, settings: settings);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> update(Settings input,
      {String? consumerKey,
      String? consumerSecret,
      String? webhookSecret}) async {
    state = state.copyWith(loading: true, error: null, message: null);
    try {
      final saved = await _api.updateSettings(
        storeUrl: input.storeUrl,
        consumerKey: consumerKey,
        consumerSecret: consumerSecret,
        webhookSecret: webhookSecret,
        includeDrafts: input.includeDrafts,
        pollingIntervalSeconds: input.pollingIntervalSeconds,
      );
      state = state.copyWith(
        loading: false,
        settings: saved,
        message: 'Settings updated',
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<String?> testConnection() async {
    try {
      await _api.testConnection();
      state = state.copyWith(message: 'Connection OK');
      return null;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return e.toString();
    }
  }

  Future<String?> runBackfill() async {
    try {
      final imported = await _api.runBackfill();
      state = state.copyWith(message: 'Imported $imported orders');
      return null;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return e.toString();
    }
  }
}
