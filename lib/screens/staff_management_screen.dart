import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/staff_model.dart';
import '../services/staff_service.dart';
import '../utils/constants.dart';
import '../widgets/staff_card.dart';

/// Staff Management screen - View staff and their performance
class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  StaffRole? _filterRole;

  @override
  Widget build(BuildContext context) {
    final staffService = context.read<StaffService>();

    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        backgroundColor: AppConstants.darkSecondary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            final scaffoldState = context
                .findAncestorStateOfType<ScaffoldState>();
            if (scaffoldState != null) {
              scaffoldState.openDrawer();
            }
          },
        ),
        title: Row(
          children: [
            Icon(Icons.people, color: AppConstants.primaryOrange),
            const SizedBox(width: AppConstants.paddingSmall),
            const Text('Staff', style: AppConstants.headingMedium),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Staff>>(
        stream: staffService.getStaffStream(),
        builder: (context, snapshot) {
          final isLoading =
              snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData;
          final staffList = snapshot.data ?? [];
          final filteredStaff = _filterRole == null
              ? staffList
              : staffList.where((staff) => staff.role == _filterRole).toList();

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingLarge),
                child: Text(
                  'Failed to load staff. Please try again later.',
                  textAlign: TextAlign.center,
                  style: AppConstants.bodyLarge,
                ),
              ),
            );
          }

          return Column(
            children: [
              _buildStatsBar(staffList),
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppConstants.primaryOrange,
                        ),
                      )
                    : _buildStaffList(filteredStaff),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewStaff,
        backgroundColor: AppConstants.primaryOrange,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Staff'),
      ),
    );
  }

  /// Stats bar showing staff metrics
  Widget _buildStatsBar(List<Staff> staffList) {
    final totalStaff = staffList.length;
    final onDutyCount = staffList
        .where((member) => member.status == StaffShiftStatus.onDuty)
        .length;
    final dayOffCount = staffList
        .where((member) => member.status == StaffShiftStatus.dayOff)
        .length;

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      color: AppConstants.darkSecondary,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Total Staff',
            totalStaff.toString(),
            AppConstants.primaryOrange,
          ),
          _buildStatItem(
            'On Duty',
            onDutyCount.toString(),
            AppConstants.successGreen,
          ),
          _buildStatItem(
            'Day Off',
            dayOffCount.toString(),
            AppConstants.errorRed,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: AppConstants.headingMedium.copyWith(color: color)),
        const SizedBox(height: 4),
        Text(label, style: AppConstants.bodySmall),
      ],
    );
  }

  /// Staff list
  Widget _buildStaffList(List<Staff> staffList) {
    if (staffList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: AppConstants.textSecondary,
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              'No staff members found',
              style: AppConstants.headingSmall.copyWith(
                color: AppConstants.textSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              'Tap "Add Staff" to get started.',
              style: AppConstants.bodySmall.copyWith(
                color: AppConstants.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      itemCount: staffList.length,
      itemBuilder: (context, index) {
        return StaffCard(
          staff: staffList[index],
          onTap: () => _showStaffDetails(staffList[index]),
        );
      },
    );
  }

  Future<void> _showStaffForm({Staff? existingStaff}) async {
    final staffService = context.read<StaffService>();
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: existingStaff?.name ?? '',
    );
    final emailController = TextEditingController(
      text: existingStaff?.email ?? '',
    );
    DateTime hireDate = existingStaff?.hireDate ?? DateTime.now();
    StaffRole role = existingStaff?.role ?? StaffRole.waiter;
    StaffShiftStatus status = existingStaff?.status ?? StaffShiftStatus.offDuty;
    StaffAccessLevel accessLevel =
        existingStaff?.accessLevel ?? StaffAccessLevel.staff;
    TimeOfDay? shiftStart = _timeOfDayFromString(
      existingStaff?.shiftStart ?? '',
    );
    TimeOfDay? shiftEnd = _timeOfDayFromString(existingStaff?.shiftEnd ?? '');
    bool isSaving = false;

    final bool? wasSaved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppConstants.cardBackground,
          title: Text(
            existingStaff == null ? 'Add Staff' : 'Edit Staff',
            style: AppConstants.headingMedium,
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppConstants.paddingMedium),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!value.contains('@')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppConstants.paddingMedium),
                  DropdownButtonFormField<StaffRole>(
                    value: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: StaffRole.values
                        .map(
                          (role) => DropdownMenuItem(
                            value: role,
                            child: Text(_roleLabel(role)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => role = value);
                      }
                    },
                  ),
                  const SizedBox(height: AppConstants.paddingMedium),
                  DropdownButtonFormField<StaffShiftStatus>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: StaffShiftStatus.values
                        .map(
                          (statusOption) => DropdownMenuItem(
                            value: statusOption,
                            child: Text(_statusLabel(statusOption)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => status = value);
                      }
                    },
                  ),
                  const SizedBox(height: AppConstants.paddingMedium),
                  DropdownButtonFormField<StaffAccessLevel>(
                    value: accessLevel,
                    decoration: const InputDecoration(
                      labelText: 'Access Level',
                    ),
                    items: StaffAccessLevel.values
                        .map(
                          (level) => DropdownMenuItem(
                            value: level,
                            child: Text(_accessLevelLabel(level)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => accessLevel = value);
                      }
                    },
                  ),
                  const SizedBox(height: AppConstants.paddingMedium),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: dialogContext,
                        initialDate: hireDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedDate != null) {
                        setDialogState(() => hireDate = pickedDate);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Hire Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatHireDate(hireDate)),
                          const Icon(Icons.calendar_today, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingMedium),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            final pickedTime = await showTimePicker(
                              context: dialogContext,
                              initialTime:
                                  shiftStart ??
                                  const TimeOfDay(hour: 9, minute: 0),
                            );
                            if (pickedTime != null) {
                              setDialogState(() => shiftStart = pickedTime);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Shift Start',
                              border: OutlineInputBorder(),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatTimeForDisplay(shiftStart)),
                                const Icon(Icons.access_time, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppConstants.paddingSmall),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            final pickedTime = await showTimePicker(
                              context: dialogContext,
                              initialTime:
                                  shiftEnd ??
                                  const TimeOfDay(hour: 17, minute: 0),
                            );
                            if (pickedTime != null) {
                              setDialogState(() => shiftEnd = pickedTime);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Shift End',
                              border: OutlineInputBorder(),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatTimeForDisplay(shiftEnd)),
                                const Icon(Icons.access_time, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving
                  ? null
                  : () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (isSaving) {
                  return;
                }
                if (!formKey.currentState!.validate()) {
                  return;
                }
                final bothTimesSet =
                    (shiftStart != null && shiftEnd != null) ||
                    (shiftStart == null && shiftEnd == null);
                if (!bothTimesSet) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please set both shift start and end.'),
                      backgroundColor: AppConstants.errorRed,
                    ),
                  );
                  return;
                }

                setDialogState(() => isSaving = true);

                final staffToSave = (existingStaff == null)
                    ? Staff(
                        id: _generateStaffId(),
                        name: nameController.text.trim(),
                        email: emailController.text.trim(),
                        role: role,
                        hireDate: hireDate,
                        performanceScore: 0,
                        totalOrdersServed: 0,
                        status: status,
                        shiftStart: _timeOfDayToStorage(shiftStart),
                        shiftEnd: _timeOfDayToStorage(shiftEnd),
                        accessLevel: accessLevel,
                      )
                    : existingStaff.copyWith(
                        name: nameController.text.trim(),
                        email: emailController.text.trim(),
                        role: role,
                        hireDate: hireDate,
                        status: status,
                        shiftStart: _timeOfDayToStorage(shiftStart),
                        shiftEnd: _timeOfDayToStorage(shiftEnd),
                        accessLevel: accessLevel,
                      );

                try {
                  if (existingStaff == null) {
                    await staffService.createStaff(staffToSave);
                  } else {
                    await staffService.updateStaff(staffToSave);
                  }

                  if (!mounted) {
                    return;
                  }

                  Navigator.of(dialogContext).pop(true);
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to save staff: $e'),
                      backgroundColor: AppConstants.errorRed,
                    ),
                  );
                }
              },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(existingStaff == null ? 'Add Staff' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    emailController.dispose();

    if (!mounted || wasSaved != true) {
      return;
    }

    final successMessage = existingStaff == null
        ? 'Staff member added'
        : 'Staff member updated';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(successMessage),
        backgroundColor: AppConstants.successGreen,
      ),
    );
  }

  Color _statusColor(StaffShiftStatus status) {
    switch (status) {
      case StaffShiftStatus.onDuty:
        return AppConstants.successGreen;
      case StaffShiftStatus.offDuty:
        return Colors.blueGrey;
      case StaffShiftStatus.dayOff:
        return AppConstants.errorRed;
    }
  }

  String _formatHireDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _formatShiftRange(String start, String end) {
    final startTime = _timeOfDayFromString(start);
    final endTime = _timeOfDayFromString(end);

    if (startTime == null || endTime == null) {
      return 'Not set';
    }

    final formatter = DateFormat('h:mm a');
    final startDate = DateTime(0, 1, 1, startTime.hour, startTime.minute);
    final endDate = DateTime(0, 1, 1, endTime.hour, endTime.minute);

    return '${formatter.format(startDate)} - ${formatter.format(endDate)}';
  }

  String _accessLevelLabel(StaffAccessLevel level) {
    switch (level) {
      case StaffAccessLevel.manager:
        return 'Manager';
      case StaffAccessLevel.staff:
        return 'Staff';
    }
  }

  String _roleLabel(StaffRole role) {
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

  String _statusLabel(StaffShiftStatus status) {
    switch (status) {
      case StaffShiftStatus.onDuty:
        return 'On Duty';
      case StaffShiftStatus.offDuty:
        return 'Off Duty';
      case StaffShiftStatus.dayOff:
        return 'Day Off';
    }
  }

  TimeOfDay? _timeOfDayFromString(String value) {
    if (value.isEmpty) {
      return null;
    }
    final parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _timeOfDayToStorage(TimeOfDay? time) {
    if (time == null) {
      return '';
    }
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatTimeForDisplay(TimeOfDay? time) {
    if (time == null) {
      return 'Not set';
    }
    final dateTime = DateTime(0, 1, 1, time.hour, time.minute);
    return DateFormat('h:mm a').format(dateTime);
  }

  String _generateStaffId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Show filter dialog
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.cardBackground,
        title: const Text('Filter by Role', style: AppConstants.headingSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<StaffRole?>(
              title: const Text('All Staff', style: AppConstants.bodyMedium),
              value: null,
              groupValue: _filterRole,
              activeColor: AppConstants.primaryOrange,
              onChanged: (value) {
                setState(() {
                  _filterRole = value;
                });
                Navigator.pop(context);
              },
            ),
            ...StaffRole.values.map((role) {
              return RadioListTile<StaffRole?>(
                title: Text(_roleLabel(role), style: AppConstants.bodyMedium),
                value: role,
                groupValue: _filterRole,
                activeColor: AppConstants.primaryOrange,
                onChanged: (value) {
                  setState(() {
                    _filterRole = value;
                  });
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Show staff details
  void _showStaffDetails(Staff staff) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusLarge),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(
                      bottom: AppConstants.paddingMedium,
                    ),
                    decoration: BoxDecoration(
                      color: AppConstants.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: AppConstants.primaryOrange,
                    child: Text(
                      staff.name
                          .split(' ')
                          .map((w) => w.isNotEmpty ? w[0] : '')
                          .take(2)
                          .join()
                          .toUpperCase(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                Center(
                  child: Text(staff.name, style: AppConstants.headingLarge),
                ),
                Center(
                  child: Text(
                    staff.roleDisplayName,
                    style: AppConstants.bodyLarge.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                Center(
                  child: Chip(
                    label: Text(
                      staff.statusDisplayName,
                      style: AppConstants.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: _statusColor(staff.status),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.paddingSmall,
                      vertical: 0,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingLarge),
                _buildDetailRow('Email', staff.email, Icons.email),
                _buildDetailRow(
                  'Performance Score',
                  '${staff.performanceScore.toStringAsFixed(1)}/10',
                  Icons.star,
                ),
                _buildDetailRow(
                  'Orders Served',
                  staff.totalOrdersServed.toString(),
                  Icons.receipt,
                ),
                _buildDetailRow(
                  'Hire Date',
                  _formatHireDate(staff.hireDate),
                  Icons.calendar_today,
                ),
                _buildDetailRow(
                  'Shift',
                  _formatShiftRange(staff.shiftStart, staff.shiftEnd),
                  Icons.schedule,
                ),
                _buildDetailRow(
                  'Access Level',
                  _accessLevelLabel(staff.accessLevel),
                  Icons.verified_user,
                ),
                const SizedBox(height: AppConstants.paddingLarge),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _editStaff(staff);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryOrange,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMedium,
                      ),
                    ),
                  ),
                  child: const Text('Edit Staff'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppConstants.primaryOrange),
          const SizedBox(width: AppConstants.paddingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppConstants.bodySmall),
                Text(value, style: AppConstants.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Add new staff
  void _addNewStaff() {
    _showStaffForm();
  }

  /// Edit staff
  void _editStaff(Staff staff) {
    _showStaffForm(existingStaff: staff);
  }
}
