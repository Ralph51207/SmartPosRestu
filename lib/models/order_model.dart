/// Order status enum
enum OrderStatus {
  pending,
  preparing,
  ready,
  completed,
  cancelled,
}

/// Order item model
class OrderItem {
  final String id;
  final String name;
  final int quantity;
  final double price;

  OrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
  });

  double get totalPrice => price * quantity;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'price': price,
    };
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      name: json['name'] as String,
      quantity: json['quantity'] as int,
      price: (json['price'] as num).toDouble(),
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

  Order({
    required this.id,
    required this.tableNumber,
    required this.items,
    required this.totalAmount,
    required this.timestamp,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tableNumber': tableNumber,
      'items': items.map((item) => item.toJson()).toList(),
      'totalAmount': totalAmount,
      'timestamp': timestamp.toIso8601String(),
      'status': status.toString().split('.').last,
    };
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      tableNumber: json['tableNumber'] as String,
      items: (json['items'] as List)
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: OrderStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => OrderStatus.pending,
      ),
    );
  }
}
