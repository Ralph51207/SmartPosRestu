import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/order_model.dart';

/// Represents a completed transaction saved to Firebase.
class TransactionRecord {
  final String id;
  final String orderId;
  final String tableNumber;
  final double totalAmount;
  final double amountPaid;
  final double change;
  final String paymentMethod;
  final DateTime timestamp;
  final OrderStatus status;
  final List<OrderItem> items;
  final String? notes;
  final Map<String, dynamic>? metadata;

  TransactionRecord({
    required this.id,
    required this.orderId,
    required this.tableNumber,
    required this.totalAmount,
    required this.amountPaid,
    required this.change,
    required this.paymentMethod,
    required this.timestamp,
    required this.status,
    required this.items,
    this.notes,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'orderId': orderId,
      'tableNumber': tableNumber,
      'totalAmount': totalAmount,
      'amountPaid': amountPaid,
      'change': change,
      'paymentMethod': paymentMethod,
      'timestamp': timestamp.toIso8601String(),
      'status': status.toString().split('.').last,
      'notes': notes,
      'items': items.map((item) => item.toJson()).toList(),
    };

    if (metadata != null && metadata!.isNotEmpty) {
      map['metadata'] = metadata;
    }

    return map;
  }

  /// Returns the effective sales amount for this transaction. Falls back to
  /// [amountPaid] when [totalAmount] is unavailable (0) so UI can still show
  /// meaningful figures for manually completed orders.
  double get saleAmount => totalAmount != 0 ? totalAmount : amountPaid;

  /// Treats negative sale amounts as refunds for quick styling decisions.
  bool get isRefund => saleAmount < 0;

  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    final List<OrderItem> parsedItems = [];
    final rawItems = json['items'];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map) {
          parsedItems.add(OrderItem.fromJson(Map<dynamic, dynamic>.from(item)));
        }
      }
    } else if (rawItems is Map) {
      rawItems.forEach((key, value) {
        if (value is Map) {
          parsedItems.add(OrderItem.fromJson(Map<dynamic, dynamic>.from(value)));
        }
      });
    }

    final statusValue = json['status']?.toString() ?? 'completed';
    final parsedStatus = OrderStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusValue,
      orElse: () => OrderStatus.completed,
    );

    return TransactionRecord(
      id: json['id']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      tableNumber: json['tableNumber']?.toString() ?? 'NO_TABLE',
      totalAmount: _asDouble(json['totalAmount']),
      amountPaid: _asDouble(json['amountPaid']),
      change: _asDouble(json['change']),
      paymentMethod: json['paymentMethod']?.toString() ?? 'Unknown',
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      status: parsedStatus,
      items: parsedItems,
      notes: json['notes']?.toString(),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  static double _asDouble(dynamic value) {
    if (value is int) {
      return value.toDouble();
    }
    if (value is double) {
      return value;
    }
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }
}

/// Service responsible for persisting and streaming transaction records.
class TransactionService {
  static const String _databaseUrl =
      'https://smart-restaurant-pos-default-rtdb.asia-southeast1.firebasedatabase.app';

  static final TransactionService _instance = TransactionService._internal();

  factory TransactionService() => _instance;

  TransactionService._internal() {
    _database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: _databaseUrl,
    );
    _transactionsRef = _database.ref('transactions');
  }

  late final FirebaseDatabase _database;
  late final DatabaseReference _transactionsRef;

  DatabaseReference _transactionRef(String orderId) =>
      _transactionsRef.child(orderId);

  /// Save checkout/transaction data for an order.
  ///
  /// When [allowOverwrite] is false, an existing transaction entry will not be
  /// replaced and the call resolves successfully without writing new data.
  Future<Map<String, dynamic>> saveCheckout({
    required Order order,
    required String paymentMethod,
    required double amountPaid,
    required double change,
    bool allowOverwrite = false,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final ref = _transactionRef(order.id);
      final snapshot = await ref.get();
      if (snapshot.exists && !allowOverwrite) {
        return {
          'success': true,
          'transactionId': order.id,
          'message': 'Transaction already recorded',
        };
      }

      final record = TransactionRecord(
        id: order.id,
        orderId: order.id,
        tableNumber: order.tableNumber,
        totalAmount: order.totalAmount,
        amountPaid: amountPaid,
        change: change,
        paymentMethod: paymentMethod,
        timestamp: DateTime.now(),
        status: order.status,
        notes: order.notes,
        items: order.items,
        metadata: metadata,
      );

      await ref.set(record.toJson());
      return {'success': true, 'transactionId': order.id};
    } catch (e) {
      return {'success': false, 'message': 'Failed to save transaction: $e'};
    }
  }

  /// Stream transactions ordered by latest timestamp first.
  Stream<List<TransactionRecord>> watchTransactions() {
    return _transactionsRef.onValue.map((event) {
      final raw = event.snapshot.value;
      final records = <TransactionRecord>[];

      if (raw is Map) {
        raw.forEach((key, value) {
          final map = _stringKeyedMap(value);
          if (map == null) {
            return;
          }
          map['id'] ??= key.toString();
          records.add(TransactionRecord.fromJson(map));
        });
      }

      records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return records;
    });
  }

  Map<String, dynamic>? _stringKeyedMap(dynamic source) {
    if (source is Map) {
      final map = <String, dynamic>{};
      source.forEach((key, value) {
        if (key == null) {
          return;
        }
        map[key.toString()] = value;
      });
      return map;
    }
    return null;
  }
}
