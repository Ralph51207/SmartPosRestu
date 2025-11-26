Map<String, dynamic> _stringKeyedTableMap(Map<dynamic, dynamic> source) {
  final result = <String, dynamic>{};
  source.forEach((key, value) {
    if (key == null) {
      return;
    }
    result[key.toString()] = value;
  });
  return result;
}

/// Table model representing a restaurant table
class RestaurantTable {
  final String id;
  final String tableNumber;
  final int capacity;
  final TableStatus status;
  final String? currentOrderId;

  RestaurantTable({
    required this.id,
    required this.tableNumber,
    required this.capacity,
    required this.status,
    this.currentOrderId,
  });

  /// Convert to JSON for Firebase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tableNumber': tableNumber,
      'capacity': capacity,
      'status': status.toString().split('.').last,
      'currentOrderId': currentOrderId,
    };
  }

  /// Create from JSON (Firebase)
  factory RestaurantTable.fromJson(Map<dynamic, dynamic> json) {
    final map = json is Map<String, dynamic>
        ? json
        : _stringKeyedTableMap(json);

    final id = map['id']?.toString() ?? '';
    final tableNumber = map['tableNumber']?.toString() ?? '';
    final capacityValue = map['capacity'];
    final capacity = capacityValue is int
        ? capacityValue
        : int.tryParse(capacityValue?.toString() ?? '') ?? 0;
    final statusValue = map['status']?.toString() ?? 'free';
    final status = TableStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusValue,
      orElse: () => TableStatus.free,
    );
    final currentOrderId = map['currentOrderId']?.toString();

    return RestaurantTable(
      id: id,
      tableNumber: tableNumber,
      capacity: capacity,
      status: status,
      currentOrderId: currentOrderId?.isEmpty == true ? null : currentOrderId,
    );
  }

  /// Create a copy with modified fields
  RestaurantTable copyWith({
    String? id,
    String? tableNumber,
    int? capacity,
    TableStatus? status,
    String? currentOrderId,
  }) {
    return RestaurantTable(
      id: id ?? this.id,
      tableNumber: tableNumber ?? this.tableNumber,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      currentOrderId: currentOrderId ?? this.currentOrderId,
    );
  }
}

/// Table status enum
enum TableStatus {
  free,
  waiting,
  seated,
  ordering,
  ready_for_payment,
  occupied_cleaning,
}
