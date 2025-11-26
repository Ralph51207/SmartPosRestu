import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

/// Expense record persisted to Firebase Realtime Database.
class ExpenseRecord {
  ExpenseRecord({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.date,
    required this.createdAt,
  });

  final String id;
  final String category;
  final String description;
  final double amount;
  final DateTime date;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'description': description,
      'amount': amount,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ExpenseRecord.fromJson(Map<String, dynamic> json) {
    return ExpenseRecord(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Uncategorized',
      description: json['description']?.toString() ?? '',
      amount: _asDouble(json['amount']),
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
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

/// Handles CRUD operations for expenses stored in Firebase Realtime Database.
class ExpenseService {
  ExpenseService._internal() {
    _database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          'https://smart-restaurant-pos-default-rtdb.asia-southeast1.firebasedatabase.app',
    );
    _expensesRef = _database.ref('expenses');
  }

  static final ExpenseService _instance = ExpenseService._internal();

  factory ExpenseService() => _instance;

  late final FirebaseDatabase _database;
  late final DatabaseReference _expensesRef;

  /// Stream all expenses ordered from latest to oldest.
  Stream<List<ExpenseRecord>> watchExpenses() {
    return _expensesRef.onValue.map((event) {
      final raw = event.snapshot.value;
      final records = <ExpenseRecord>[];

      if (raw is Map) {
        raw.forEach((key, value) {
          final map = _stringKeyedMap(value);
          if (map == null) {
            return;
          }
          map['id'] ??= key.toString();
          records.add(ExpenseRecord.fromJson(map));
        });
      }

      records.sort((a, b) => b.date.compareTo(a.date));
      return records;
    });
  }

  /// Add a new expense entry.
  Future<ExpenseRecord> addExpense({
    required String category,
    required String description,
    required double amount,
    required DateTime date,
  }) async {
    final ref = _expensesRef.push();
    final record = ExpenseRecord(
      id: ref.key ?? '',
      category: category,
      description: description,
      amount: amount,
      date: date,
      createdAt: DateTime.now(),
    );

    await ref.set(record.toJson());
    return record;
  }

  /// Delete an expense by id.
  Future<void> deleteExpense(String id) async {
    if (id.isEmpty) {
      return;
    }
    await _expensesRef.child(id).remove();
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
