import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/order_model.dart';

/// Firebase database service for order management
/// Handles CRUD operations for orders in real-time database
class OrderService {
  static const String _databaseUrl =
      'https://smart-restaurant-pos-default-rtdb.asia-southeast1.firebasedatabase.app';

  final FirebaseDatabase _databaseInstance = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: _databaseUrl,
  );

  DatabaseReference get _ordersRef => _databaseInstance.ref('orders');
  DatabaseReference get _metaRef => _databaseInstance.ref('meta');

  DatabaseReference _orderRef(String orderId) =>
      _databaseInstance.ref('orders/$orderId');

  static final RegExp _orderIdPattern = RegExp(r'^ORD(\d+)$');

  Map<String, dynamic>? _toStringKeyedMap(dynamic value) {
    if (value is Map) {
      final result = <String, dynamic>{};
      value.forEach((key, mappedValue) {
        if (key == null) {
          return;
        }
        result[key.toString()] = mappedValue;
      });
      return result;
    }
    return null;
  }

  int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    return 0;
  }

  String _formatOrderId(int number) {
    return 'ORD${number.toString().padLeft(4, '0')}';
  }

  int? _extractOrderNumber(String id) {
    final match = _orderIdPattern.firstMatch(id);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
  }

  Future<void> _ensureOrderCounterInitialized() async {
    final counterRef = _metaRef.child('nextOrderNumber');
    final snapshot = await counterRef.get();
    if (snapshot.exists) {
      final value = snapshot.value;
      if (value is int || value is double) {
        return;
      }
    }

    final highest = await _calculateHighestOrderNumber();
    await counterRef.set(highest);
  }

  Future<int> _calculateHighestOrderNumber() async {
    int highest = 0;
    try {
      final snapshot = await _ordersRef.get();
      if (snapshot.exists && snapshot.value is Map) {
        final orderMap = snapshot.value as Map<dynamic, dynamic>;
        for (final entry in orderMap.entries) {
          final key = entry.key.toString();
          final keyNumber = _extractOrderNumber(key);
          if (keyNumber != null && keyNumber > highest) {
            highest = keyNumber;
          }

          final value = entry.value;
          if (value is Map && value['id'] is String) {
            final valueNumber = _extractOrderNumber(value['id'] as String);
            if (valueNumber != null && valueNumber > highest) {
              highest = valueNumber;
            }
          }
        }
      }
    } catch (e) {
      print('Error calculating highest order number: $e');
    }
    return highest;
  }

  /// Generate the next sequential order ID backed by Firebase counter
  Future<String> generateNextOrderId() async {
    final counterRef = _metaRef.child('nextOrderNumber');
    try {
      await _ensureOrderCounterInitialized();
      final result = await counterRef.runTransaction((mutableData) {
        final dynamic data = mutableData;
        final current = _asInt(data.value);
        final nextValue = current + 1;
        data.value = nextValue;
        return Transaction.success(data);
      });

      final nextNumber = _asInt(result.snapshot.value);
      return _formatOrderId(nextNumber);
    } catch (e) {
      print('Error generating next order ID: $e');
      final fallback = (await _calculateHighestOrderNumber()) + 1;
      try {
        await counterRef.set(fallback);
      } catch (_) {
        // Ignore secondary errors; fallback formatting still returns usable ID
      }
      return _formatOrderId(fallback);
    }
  }

  /// Get orders stream (real-time updates)
  Stream<List<Order>> getOrdersStream({DateTime? start, DateTime? end}) {
    // Use the instance-backed orders ref and keep timestamp filtering optional.
    final startIso = (start ?? DateTime.now()).toIso8601String();
    Query q = _ordersRef.orderByChild('timestamp').startAt(startIso);
    if (end != null) {
      q = q.endAt(end.toIso8601String());
    }
    return q.onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <Order>[];
      if (raw is Map) {
        return raw.entries.map((e) {
          final value = e.value;
          final map = _toStringKeyedMap(value);
          if (map == null) return null;
          return Order.fromJson(map);
        }).whereType<Order>().toList();
      }
      return <Order>[];
    });
  }

  /// Get single order by ID
  Future<Order?> getOrder(String orderId) async {
    try {
      final snapshot = await _orderRef(orderId).get();
      if (snapshot.exists) {
        final map = _toStringKeyedMap(snapshot.value);
        if (map == null) {
          return null;
        }
        return Order.fromJson(map);
      }
      return null;
    } catch (e) {
      print('Error getting order: $e');
      return null;
    }
  }

  /// Create new order
  Future<void> createOrder(Order order) async {
    try {
      await _orderRef(order.id).set(order.toJson());
    } catch (e) {
      print('Error creating order: $e');
      rethrow;
    }
  }

  /// Update existing order
  Future<void> updateOrder(Order order) async {
    try {
      await _orderRef(order.id).update(order.toJson());
    } catch (e) {
      print('Error updating order: $e');
      rethrow;
    }
  }

  /// Update order status
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    try {
      await _orderRef(orderId).update({
        'status': status.toString().split('.').last,
      });
    } catch (e) {
      print('Error updating order status: $e');
      rethrow;
    }
  }

  /// Delete order
  Future<void> deleteOrder(String orderId) async {
    try {
      await _orderRef(orderId).remove();
    } catch (e) {
      print('Error deleting order: $e');
      rethrow;
    }
  }

  /// Get orders by table number
  Future<List<Order>> getOrdersByTable(String tableNumber) async {
    try {
      final snapshot = await _ordersRef
          .orderByChild('tableNumber')
          .equalTo(tableNumber)
          .get();

      final orders = <Order>[];
      if (snapshot.exists) {
        final raw = snapshot.value;
        if (raw is Map) {
          raw.forEach((key, value) {
            final map = _toStringKeyedMap(value);
            if (map == null) {
              return;
            }
            orders.add(Order.fromJson(map));
          });
        }
      }
      return orders;
    } catch (e) {
      print('Error getting orders by table: $e');
      return [];
    }
  }

  /// Get today's orders
  Future<List<Order>> getTodaysOrders() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final snapshot = await _ordersRef.get();

      final orders = <Order>[];
      if (snapshot.exists) {
        final raw = snapshot.value;
        if (raw is Map) {
          raw.forEach((key, value) {
            final map = _toStringKeyedMap(value);
            if (map == null) {
              return;
            }
            final order = Order.fromJson(map);
            if (order.timestamp.isAfter(startOfDay)) {
              orders.add(order);
            }
          });
        }
      }
      return orders;
    } catch (e) {
      print('Error getting today\'s orders: $e');
      return [];
    }
  }
}
