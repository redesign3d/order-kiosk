import 'dart:convert';

import 'package:http/http.dart' as http;

import 'http_client_stub.dart' if (dart.library.html) 'http_client_web.dart';
import 'models.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  final http.Client _client;
  final String baseUrl;
  String? csrfToken;

  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? createHttpClient(),
        baseUrl = baseUrl ??
            const String.fromEnvironment('API_BASE_URL', defaultValue: '/api');

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$normalizedBase$normalizedPath');
    if (query == null) return uri;
    return uri.replace(
      queryParameters: query.map(
        (key, value) => MapEntry(key, value == null ? null : value.toString()),
      ),
    );
  }

  Map<String, String> _headers({bool includeJson = true}) {
    final headers = <String, String>{};
    if (includeJson) {
      headers['Content-Type'] = 'application/json';
    }
    if (csrfToken != null) {
      headers['x-csrf-token'] = csrfToken!;
    }
    return headers;
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return json.decode(response.body) as Map<String, dynamic>;
    }
    final message = response.body.isNotEmpty ? response.body : 'Request failed';
    throw ApiException(message, statusCode: response.statusCode);
  }

  Future<SessionInfo> login(String email, String password) async {
    final res = await _client.post(
      _uri('/auth/login'),
      headers: _headers(),
      body: json.encode({'email': email, 'password': password}),
    );
    final data = await _handleResponse(res);
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    csrfToken = data['csrfToken'] as String?;
    if (csrfToken == null) {
      throw ApiException('Missing CSRF token from server');
    }
    return SessionInfo(user: user, csrfToken: csrfToken!);
  }

  Future<void> logout() async {
    final res = await _client.post(_uri('/auth/logout'), headers: _headers());
    await _handleResponse(res);
    csrfToken = null;
  }

  Future<SessionInfo> me() async {
    final res = await _client.get(_uri('/auth/me'));
    final data = await _handleResponse(res);
    if (data['user'] == null) throw ApiException('Not authenticated');
    final token = data['csrfToken'] as String?;
    if (token != null) csrfToken = token;
    return SessionInfo(
      user: User.fromJson(data['user'] as Map<String, dynamic>),
      csrfToken: token ?? csrfToken ?? '',
    );
  }

  Future<OrdersResponse> fetchOrders({
    required int page,
    required int pageSize,
    String? status,
    String? search,
    String? modifiedAfter,
  }) async {
    final res = await _client.get(
      _uri('/orders', {
        'page': page,
        'pageSize': pageSize,
        if (status != null) 'status': status,
        if (search != null && search.isNotEmpty) 'search': search,
        if (modifiedAfter != null) 'modified_after': modifiedAfter,
      }),
      headers: _headers(includeJson: false),
    );
    final data = await _handleResponse(res);
    return OrdersResponse.fromJson(data);
  }

  Future<Order> fetchOrder(int id) async {
    final res = await _client.get(_uri('/orders/$id'),
        headers: _headers(includeJson: false));
    final data = await _handleResponse(res);
    return Order.fromJson(data);
  }

  Future<Settings?> fetchSettings() async {
    final res = await _client.get(_uri('/settings'),
        headers: _headers(includeJson: false));
    if (res.statusCode == 401) return null;
    final data = await _handleResponse(res);
    if (data['settings'] == null) return null;
    return Settings.fromJson(data['settings'] as Map<String, dynamic>);
  }

  Future<Settings> updateSettings({
    required String storeUrl,
    String? consumerKey,
    String? consumerSecret,
    String? webhookSecret,
    required bool includeDrafts,
    required int pollingIntervalSeconds,
  }) async {
    final res = await _client.put(
      _uri('/settings'),
      headers: _headers(),
      body: json.encode({
        'storeUrl': storeUrl,
        'consumerKey': consumerKey,
        'consumerSecret': consumerSecret,
        'webhookSecret': webhookSecret,
        'includeDrafts': includeDrafts,
        'pollingIntervalSeconds': pollingIntervalSeconds,
      }),
    );
    final data = await _handleResponse(res);
    return Settings.fromJson(data['settings'] as Map<String, dynamic>);
  }

  Future<void> testConnection() async {
    final res = await _client.post(_uri('/settings/test-connection'),
        headers: _headers());
    await _handleResponse(res);
  }

  Future<int> runBackfill() async {
    final res = await _client.post(_uri('/sync/backfill'), headers: _headers());
    final data = await _handleResponse(res);
    return data['imported'] as int? ?? 0;
  }
}
