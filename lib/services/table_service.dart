import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/table_model.dart';
import 'order_service.dart';

/// Firebase database service for table management
/// Handles CRUD operations for restaurant tables
class TableService {
  static const String _databaseUrl =
      'https://smart-restaurant-pos-default-rtdb.asia-southeast1.firebasedatabase.app';

  final FirebaseDatabase _databaseInstance = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: _databaseUrl,
  );

  DatabaseReference get _tablesRef => _databaseInstance.ref('tables');
  DatabaseReference get _metaRef => _databaseInstance.ref('meta');

  DatabaseReference _tableRef(String tableId) =>
      _databaseInstance.ref('tables/$tableId');

  static final RegExp _tableIdPattern = RegExp(r'^TAB(\d+)$');

  Map<String, dynamic>? _stringKeyedMap(dynamic value) {
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

  String _formatTableId(int number) {
    return 'TAB${number.toString().padLeft(3, '0')}';
  }

  int? _extractTableNumber(String id) {
    final match = _tableIdPattern.firstMatch(id);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
  }

  Future<void> _ensureTableCounterInitialized() async {
    final counterRef = _metaRef.child('nextTableNumber');
    final snapshot = await counterRef.get();
    if (snapshot.exists) {
      final value = snapshot.value;
      if (value is int || value is double) {
        return;
      }
    }

    final highest = await _calculateHighestTableNumber();
    await counterRef.set(highest);
  }

  Future<int> _calculateHighestTableNumber() async {
    int highest = 0;
    try {
      final snapshot = await _tablesRef.get();
      if (snapshot.exists && snapshot.value is Map) {
        final tableMap = snapshot.value as Map<dynamic, dynamic>;
        for (final entry in tableMap.entries) {
          final key = entry.key.toString();
          final keyNumber = _extractTableNumber(key);
          if (keyNumber != null && keyNumber > highest) {
            highest = keyNumber;
          }

          final value = entry.value;
          if (value is Map && value['id'] is String) {
            final valueNumber = _extractTableNumber(value['id'] as String);
            if (valueNumber != null && valueNumber > highest) {
              highest = valueNumber;
            }
          }
        }
      }
    } catch (e) {
      print('Error calculating highest table number: $e');
    }
    return highest;
  }

  Future<String> generateNextTableId() async {
    final counterRef = _metaRef.child('nextTableNumber');
    try {
      await _ensureTableCounterInitialized();
      final result = await counterRef.runTransaction((mutableData) {
        final dynamic data = mutableData;
        final current = _asInt(data.value);
        final nextValue = current + 1;
        data.value = nextValue;
        return Transaction.success(data);
      });

      final nextNumber = _asInt(result.snapshot.value);
      return _formatTableId(nextNumber);
    } catch (e) {
      print('Error generating next table ID: $e');
      final fallback = (await _calculateHighestTableNumber()) + 1;
      try {
        await counterRef.set(fallback);
      } catch (_) {
        // ignore secondary errors
      }
      return _formatTableId(fallback);
    }
  }

  /// Get all tables stream (real-time updates)
  Stream<List<RestaurantTable>> getTablesStream() {
    return _tablesRef.onValue.map((event) {
      final tables = <RestaurantTable>[];
      final data = event.snapshot.value;
      if (data is Map) {
        data.forEach((key, value) {
          final map = _stringKeyedMap(value);
          if (map == null) {
            return;
          }
          tables.add(RestaurantTable.fromJson(map));
        });
      }
      return tables;
    });
  }

  /// Get single table by ID
  Future<RestaurantTable?> getTable(String tableId) async {
    try {
      final snapshot = await _tableRef(tableId).get();
      if (snapshot.exists) {
        final map = _stringKeyedMap(snapshot.value);
        if (map == null) {
          return null;
        }
        return RestaurantTable.fromJson(map);
      }
      return null;
    } catch (e) {
      print('Error getting table: $e');
      return null;
    }
  }

  Future<RestaurantTable?> getTableByNumber(String tableNumber) async {
    try {
      final snapshot = await _tablesRef
          .orderByChild('tableNumber')
          .equalTo(tableNumber)
          .limitToFirst(1)
          .get();

      if (snapshot.exists) {
        final value = snapshot.value;
        if (value is Map) {
          final firstEntry = value.entries.first;
          final map = _stringKeyedMap(firstEntry.value);
          if (map != null) {
            return RestaurantTable.fromJson(map);
          }
        }
      }
      return null;
    } catch (e) {
      print('Error getting table by number: $e');
      return null;
    }
  }

  /// Create new table
  Future<void> createTable(RestaurantTable table) async {
    try {
      var tableId = table.id;
      if (tableId.isEmpty) {
        tableId = await generateNextTableId();
      }
      await _tableRef(tableId).set(table.copyWith(id: tableId).toJson());
    } catch (e) {
      print('Error creating table: $e');
      rethrow;
    }
  }

  /// Update existing table
  Future<void> updateTable(RestaurantTable table) async {
    try {
      await _tableRef(table.id).update(table.toJson());
    } catch (e) {
      print('Error updating table: $e');
      rethrow;
    }
  }

  /// Update table status
  Future<void> updateTableStatus(String tableId, TableStatus status) async {
    try {
      await _tableRef(tableId).update({
        'status': status.toString().split('.').last,
      });
    } catch (e) {
      print('Error updating table status: $e');
      rethrow;
    }
  }

  /// Assign order to table
  Future<void> assignOrderToTable(String tableId, String orderId) async {
    try {
      await _tableRef(tableId).update({
        'currentOrderId': orderId,
        'status': TableStatus.seated.toString().split('.').last,
      });
    } catch (e) {
      print('Error assigning order to table: $e');
      rethrow;
    }
  }

  Future<void> assignOrderToTableByNumber(String tableNumber, String orderId) async {
    final table = await getTableByNumber(tableNumber);
    if (table == null) {
      return;
    }
    // Prefer atomic assignment via OrderService to update both table and order together
    final orderService = OrderService();
    await orderService.assignOrderToTableAtomic(orderId, table.id);
  }

  /// Clear table (mark as available)
  Future<void> clearTable(String tableId) async {
    try {
      await _tableRef(tableId).update({
        'currentOrderId': null,
        'status': TableStatus.free.toString().split('.').last,
      });
    } catch (e) {
      print('Error clearing table: $e');
      rethrow;
    }
  }

  Future<void> clearTableByNumber(String tableNumber) async {
    final table = await getTableByNumber(tableNumber);
    if (table == null) {
      return;
    }
    // If the table has an associated order, detach it atomically;
    // otherwise clear the table status directly.
    if (table.currentOrderId != null && table.currentOrderId!.isNotEmpty) {
      final orderService = OrderService();
      await orderService.detachOrderFromTableAtomic(table.currentOrderId!);
    } else {
      await clearTable(table.id);
    }
  }

  /// Delete table
  Future<void> deleteTable(String tableId) async {
    try {
      await _tableRef(tableId).remove();
    } catch (e) {
      print('Error deleting table: $e');
      rethrow;
    }
  }

  /// Get available tables
  Future<List<RestaurantTable>> getAvailableTables() async {
    try {
        final snapshot = await _tablesRef
          .orderByChild('status')
          .equalTo(TableStatus.free.toString().split('.').last)
          .get();

      final tables = <RestaurantTable>[];
      if (snapshot.exists) {
        final data = snapshot.value;
        if (data is Map) {
          data.forEach((key, value) {
            final map = _stringKeyedMap(value);
            if (map == null) {
              return;
            }
            tables.add(RestaurantTable.fromJson(map));
          });
        }
      }
      return tables;
    } catch (e) {
      print('Error getting available tables: $e');
      return [];
    }
  }
}
