class User {
  final String id;
  final String email;
  final String role;
  final DateTime? lastLoginAt;

  User({
    required this.id,
    required this.email,
    required this.role,
    this.lastLoginAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        lastLoginAt: json['lastLoginAt'] != null
            ? DateTime.parse(json['lastLoginAt'] as String)
            : null,
      );
}

class OrderItem {
  final String name;
  final String? sku;
  final int quantity;
  final double total;

  OrderItem({
    required this.name,
    required this.quantity,
    required this.total,
    this.sku,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        name: json['name'] as String,
        sku: json['sku'] as String?,
        quantity: (json['quantity'] as num).toInt(),
        total: (json['total'] is String)
            ? double.tryParse(json['total'] as String) ?? 0
            : (json['total'] as num).toDouble(),
      );
}

class Order {
  final int id;
  final String number;
  final String status;
  final String currency;
  final double total;
  final String? customerNote;
  final String? paymentMethod;
  final String? billingName;
  final String? billingEmail;
  final String? shippingCity;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.number,
    required this.status,
    required this.currency,
    required this.total,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    this.customerNote,
    this.paymentMethod,
    this.billingName,
    this.billingEmail,
    this.shippingCity,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as int,
        number: json['number'] as String,
        status: json['status'] as String,
        currency: json['currency'] as String,
        total: (json['total'] is String)
            ? double.tryParse(json['total'] as String) ?? 0
            : (json['total'] as num).toDouble(),
        customerNote: json['customerNote'] as String?,
        paymentMethod: json['paymentMethod'] as String?,
        billingName: json['billingName'] as String?,
        billingEmail: json['billingEmail'] as String?,
        shippingCity: json['shippingCity'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class OrderStatusMetric {
  final String status;
  final int count;
  final double total;

  OrderStatusMetric(
      {required this.status, required this.count, required this.total});
}

class OrderMetrics {
  final List<OrderStatusMetric> byStatus;
  final double revenueToday;
  final double revenue7d;
  final double avgOrderValue;

  OrderMetrics({
    required this.byStatus,
    required this.revenueToday,
    required this.revenue7d,
    required this.avgOrderValue,
  });

  factory OrderMetrics.fromJson(Map<String, dynamic> json) => OrderMetrics(
        byStatus: (json['byStatus'] as List<dynamic>? ?? [])
            .map(
              (e) => OrderStatusMetric(
                status: (e as Map<String, dynamic>)['status'] as String,
                count: (e)['count'] as int,
                total: (e)['total'] is String
                    ? double.tryParse((e)['total'] as String) ?? 0
                    : ((e)['total'] as num?)?.toDouble() ?? 0,
              ),
            )
            .toList(),
        revenueToday: (json['revenueToday'] as num?)?.toDouble() ?? 0,
        revenue7d: (json['revenue7d'] as num?)?.toDouble() ?? 0,
        avgOrderValue: (json['avgOrderValue'] as num?)?.toDouble() ?? 0,
      );
}

class OrdersResponse {
  final List<Order> items;
  final int total;
  final OrderMetrics metrics;

  OrdersResponse(
      {required this.items, required this.total, required this.metrics});

  factory OrdersResponse.fromJson(Map<String, dynamic> json) => OrdersResponse(
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => Order.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int? ?? 0,
        metrics: OrderMetrics.fromJson(json['metrics'] as Map<String, dynamic>),
      );
}

class Settings {
  final String storeUrl;
  final bool includeDrafts;
  final int pollingIntervalSeconds;
  final bool hasCredentials;
  final bool hasWebhookSecret;

  Settings({
    required this.storeUrl,
    required this.includeDrafts,
    required this.pollingIntervalSeconds,
    required this.hasCredentials,
    required this.hasWebhookSecret,
  });

  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
        storeUrl: json['storeUrl'] as String? ?? '',
        includeDrafts: json['includeDrafts'] as bool? ?? false,
        pollingIntervalSeconds: json['pollingIntervalSeconds'] as int? ?? 15,
        hasCredentials: json['hasCredentials'] as bool? ?? false,
        hasWebhookSecret: json['hasWebhookSecret'] as bool? ?? false,
      );

  Settings copyWith({
    String? storeUrl,
    bool? includeDrafts,
    int? pollingIntervalSeconds,
    bool? hasCredentials,
    bool? hasWebhookSecret,
  }) =>
      Settings(
        storeUrl: storeUrl ?? this.storeUrl,
        includeDrafts: includeDrafts ?? this.includeDrafts,
        pollingIntervalSeconds:
            pollingIntervalSeconds ?? this.pollingIntervalSeconds,
        hasCredentials: hasCredentials ?? this.hasCredentials,
        hasWebhookSecret: hasWebhookSecret ?? this.hasWebhookSecret,
      );
}

class SessionInfo {
  final User user;
  final String csrfToken;

  SessionInfo({required this.user, required this.csrfToken});
}
