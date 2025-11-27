import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/staff_model.dart';
import '../utils/constants.dart';

/// Widget to display a staff member card
class StaffCard extends StatelessWidget {
  final Staff staff;
  final VoidCallback? onTap;

  const StaffCard({super.key, required this.staff, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        margin: const EdgeInsets.only(bottom: AppConstants.paddingSmall),
        decoration: BoxDecoration(
          color: AppConstants.cardBackground,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(color: AppConstants.dividerColor, width: 1),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppConstants.primaryOrange,
              child: staff.photoUrl != null
                  ? ClipOval(
                      child: Image.network(
                        staff.photoUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildInitials();
                        },
                      ),
                    )
                  : _buildInitials(),
            ),
            const SizedBox(width: AppConstants.paddingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(staff.name, style: AppConstants.headingSmall),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        _getRoleIcon(),
                        size: 16,
                        color: AppConstants.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        staff.roleDisplayName,
                        style: AppConstants.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.star,
                        size: 16,
                        color: AppConstants.warningYellow,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${staff.performanceScore.toStringAsFixed(1)} • ${staff.totalOrdersServed} orders',
                        style: AppConstants.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Chip(
                        label: Text(
                          staff.statusDisplayName,
                          style: AppConstants.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: _statusColor(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 0,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Text(
                        'Shift: ${_formatShiftRange()}',
                        style: AppConstants.bodySmall.copyWith(
                          color: AppConstants.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppConstants.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitials() {
    final initials = staff.name
        .split(' ')
        .map((word) => word.isNotEmpty ? word[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return Text(
      initials,
      style: AppConstants.headingMedium.copyWith(color: Colors.white),
    );
  }

  IconData _getRoleIcon() {
    switch (staff.role) {
      case StaffRole.manager:
        return Icons.admin_panel_settings;
      case StaffRole.waiter:
        return Icons.room_service;
      case StaffRole.chef:
        return Icons.restaurant;
      case StaffRole.cashier:
        return Icons.point_of_sale;
    }
  }

  Color _statusColor() {
    switch (staff.status) {
      case StaffShiftStatus.onDuty:
        return AppConstants.successGreen;
      case StaffShiftStatus.offDuty:
        return Colors.blueGrey;
      case StaffShiftStatus.dayOff:
        return AppConstants.errorRed;
    }
  }

  String _formatShiftRange() {
    if (staff.shiftStart.isEmpty || staff.shiftEnd.isEmpty) {
      return 'Not set';
    }

    final start = _parseTime(staff.shiftStart);
    final end = _parseTime(staff.shiftEnd);

    if (start == null || end == null) {
      return 'Not set';
    }

    final formatter = DateFormat('h:mm a');
    final startDate = DateTime(0, 1, 1, start.hour, start.minute);
    final endDate = DateTime(0, 1, 1, end.hour, end.minute);
    return '${formatter.format(startDate)} - ${formatter.format(endDate)}';
  }

  TimeOfDay? _parseTime(String value) {
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
}
