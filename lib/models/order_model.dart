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
  final String? category;
  final String? categoryLabel;

  OrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    this.category,
    this.categoryLabel,
  });

  double get totalPrice => price * quantity;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'price': price,
      'category': category,
      'categoryLabel': categoryLabel,
    };
  }

  factory OrderItem.fromJson(Map<dynamic, dynamic> json) {
    final map = json is Map<String, dynamic>
        ? json
        : _stringKeyedMap(json);

    final id = map['id']?.toString() ?? '';
    final name = map['name']?.toString() ?? '';
    final quantityValue = map['quantity'];
    final quantity = quantityValue is int
        ? quantityValue
        : int.tryParse(quantityValue?.toString() ?? '') ?? 0;
    final priceValue = map['price'];
    final price = priceValue is num
        ? priceValue.toDouble()
        : double.tryParse(priceValue?.toString() ?? '0') ?? 0;

    return OrderItem(
      id: id,
      name: name,
      quantity: quantity,
      price: price,
      category: map['category']?.toString(),
      categoryLabel: map['categoryLabel']?.toString(),
    );
  }
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
