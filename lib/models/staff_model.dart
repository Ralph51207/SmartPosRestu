/// Staff model representing restaurant employees
class Staff {
  final String id;
  final String name;
  final String email;
  final StaffRole role;
  final String? photoUrl;
  final DateTime hireDate;
  final double performanceScore;
  final int totalOrdersServed;
  final StaffShiftStatus status;
  final String shiftStart;
  final String shiftEnd;
  final StaffAccessLevel accessLevel;

  Staff({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.photoUrl,
    required this.hireDate,
    this.performanceScore = 0.0,
    this.totalOrdersServed = 0,
    this.status = StaffShiftStatus.offDuty,
    this.shiftStart = '',
    this.shiftEnd = '',
    this.accessLevel = StaffAccessLevel.staff,
  });

  /// Convert to JSON for Firebase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
      'photoUrl': photoUrl,
      'hireDate': hireDate.toIso8601String(),
      'performanceScore': performanceScore,
      'totalOrdersServed': totalOrdersServed,
      'status': status.name,
      'shiftStart': shiftStart,
      'shiftEnd': shiftEnd,
      'accessLevel': accessLevel.name,
    };
  }

  /// Create from JSON (Firebase)
  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: StaffRole.values.firstWhere((e) => e.name == json['role']),
      photoUrl: json['photoUrl'],
      hireDate: DateTime.parse(json['hireDate']),
      performanceScore: (json['performanceScore'] is num)
          ? (json['performanceScore'] as num).toDouble()
          : double.tryParse(json['performanceScore']?.toString() ?? '') ?? 0.0,
      totalOrdersServed: json['totalOrdersServed'] ?? 0,
      status: StaffShiftStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => StaffShiftStatus.offDuty,
      ),
      shiftStart: json['shiftStart'] ?? '',
      shiftEnd: json['shiftEnd'] ?? '',
      accessLevel: StaffAccessLevel.values.firstWhere(
        (level) => level.name == json['accessLevel'],
        orElse: () => StaffAccessLevel.staff,
      ),
    );
  }

  Staff copyWith({
    String? id,
    String? name,
    String? email,
    StaffRole? role,
    String? photoUrl,
    DateTime? hireDate,
    double? performanceScore,
    int? totalOrdersServed,
    StaffShiftStatus? status,
    String? shiftStart,
    String? shiftEnd,
    StaffAccessLevel? accessLevel,
  }) {
    return Staff(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      hireDate: hireDate ?? this.hireDate,
      performanceScore: performanceScore ?? this.performanceScore,
      totalOrdersServed: totalOrdersServed ?? this.totalOrdersServed,
      status: status ?? this.status,
      shiftStart: shiftStart ?? this.shiftStart,
      shiftEnd: shiftEnd ?? this.shiftEnd,
      accessLevel: accessLevel ?? this.accessLevel,
    );
  }

  /// Get role display name
  String get roleDisplayName {
    switch (role) {
      case StaffRole.manager:
        return 'Manager';
      case StaffRole.waiter:
        return 'Waiter';
      case StaffRole.chef:
        return 'Chef';
      case StaffRole.cashier:
        return 'Cashier';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case StaffShiftStatus.onDuty:
        return 'On Duty';
      case StaffShiftStatus.offDuty:
        return 'Off Duty';
      case StaffShiftStatus.dayOff:
        return 'Day Off';
    }
  }
}

/// Staff role enum
enum StaffRole { manager, waiter, chef, cashier }

/// Staff availability status
enum StaffShiftStatus { onDuty, offDuty, dayOff }

/// Access level for future role-based control
enum StaffAccessLevel { manager, staff }
