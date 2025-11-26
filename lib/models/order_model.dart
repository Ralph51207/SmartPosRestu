/// Order status enum
enum OrderStatus {
  pending,
  preparing,
  ready,
  completed,
  cancelled,
}

/// Order item model
Map<String, dynamic> _stringKeyedMap(Map<dynamic, dynamic> source) {
  final result = <String, dynamic>{};
  source.forEach((key, value) {
    if (key == null) {
      return;
    }
    result[key.toString()] = value;
  });
  return result;
}

class OrderItem {
  final String id;
  final String name;
  final int quantity;
  final double price;
  final double totalPrice;
  final String? notes; // special instructions
  final String? category; // e.g. "beverages"
  final String? categoryLabel; // e.g. "Beverages"

  OrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    required this.totalPrice,
    this.notes,
    this.category,
    this.categoryLabel,
  });

  // Helper: convert Map<dynamic,dynamic> -> Map<String,dynamic>
  static Map<String, dynamic> _toStringKeyedMap(dynamic raw) {
    if (raw == null) return <String, dynamic>{};
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  // Accept Map<dynamic,dynamic> snapshots safely
  factory OrderItem.fromJson(dynamic raw) {
    final json = _toStringKeyedMap(raw);
    return OrderItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      quantity: (json['quantity'] is num) ? (json['quantity'] as num).toInt() : int.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      price: (json['price'] is num) ? (json['price'] as num).toDouble() : double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      totalPrice: (json['totalPrice'] is num) ? (json['totalPrice'] as num).toDouble() : double.tryParse(json['totalPrice']?.toString() ?? '0') ?? 0.0,
      notes: (json['notes']?.toString()),
      category: json['category']?.toString(),
      categoryLabel: json['categoryLabel']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'price': price,
        'totalPrice': totalPrice,
        'notes': notes ?? '',
        'category': category ?? '',
        'categoryLabel': categoryLabel ?? '',
      };
}

/// Order model
class Order {
  final String id;
  final String tableNumber;
  final List<OrderItem> items;
  final double totalAmount;
  final DateTime timestamp;
  OrderStatus status;
  final String? notes;
  final bool payNow;

  Order({
    required this.id,
    required this.tableNumber,
    required this.items,
    required this.totalAmount,
    required this.timestamp,
    required this.status,
    this.notes,
    this.payNow = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tableNumber': tableNumber,
      'items': items.map((item) => item.toJson()).toList(),
      'totalAmount': totalAmount,
      'timestamp': timestamp.toIso8601String(),
      'status': status.toString().split('.').last,
      'notes': notes,
      'payNow': payNow,
    };
  }

  factory Order.fromJson(Map<dynamic, dynamic> json) {
    final map = json is Map<String, dynamic>
        ? json
        : _stringKeyedMap(json);

    final id = map['id']?.toString() ?? '';
    final tableNumber = map['tableNumber']?.toString() ?? 'NO_TABLE';
    final totalAmountValue = map['totalAmount'];
    final totalAmount = totalAmountValue is num
        ? totalAmountValue.toDouble()
        : double.tryParse(totalAmountValue?.toString() ?? '0') ?? 0;

    final timestampValue = map['timestamp']?.toString();
    final timestamp = timestampValue != null
        ? DateTime.tryParse(timestampValue) ?? DateTime.now()
        : DateTime.now();

    final statusValue = map['status']?.toString() ?? 'pending';
    final status = OrderStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusValue,
      orElse: () => OrderStatus.pending,
    );

    final items = <OrderItem>[];
    final rawItems = map['items'];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map) {
          items.add(OrderItem.fromJson(Map<dynamic, dynamic>.from(item)));
        }
      }
    } else if (rawItems is Map) {
      rawItems.forEach((key, value) {
        if (value is Map) {
          items.add(OrderItem.fromJson(Map<dynamic, dynamic>.from(value)));
        }
      });
    }

    return Order(
      id: id,
      tableNumber: tableNumber,
      items: items,
      totalAmount: totalAmount,
      timestamp: timestamp,
      status: status,
      notes: map['notes']?.toString(),
      payNow: (map['payNow'] as bool?) ?? true,
    );
  }

  Order copyWith({
    String? tableNumber,
    List<OrderItem>? items,
    double? totalAmount,
    DateTime? timestamp,
    OrderStatus? status,
    String? notes,
    bool? payNow,
  }) {
    return Order(
      id: id,
      tableNumber: tableNumber ?? this.tableNumber,
      items: items != null ? List<OrderItem>.from(items) : List<OrderItem>.from(this.items),
      totalAmount: totalAmount ?? this.totalAmount,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      payNow: payNow ?? this.payNow,
    );
  }
}
