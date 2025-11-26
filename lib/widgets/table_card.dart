import 'package:flutter/material.dart';
import '../models/table_model.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

/// Widget to display a restaurant table card
class TableCard extends StatelessWidget {
  final RestaurantTable table;
  final VoidCallback? onTap;
  final int? itemCount;
  final double? totalAmount;
  final bool highlight;
  final VoidCallback? onPreview;

  const TableCard({
    super.key,
    required this.table,
    this.onTap,
    this.itemCount,
    this.totalAmount,
    this.highlight = false,
    this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? onPreview,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            constraints: const BoxConstraints.expand(),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMedium,
              vertical: AppConstants.paddingLarge,
            ),
            decoration: BoxDecoration(
              color: highlight ? AppConstants.primaryOrange.withOpacity(0.06) : _getStatusColor(),
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              border: Border.all(
                color: highlight ? AppConstants.primaryOrange : AppConstants.dividerColor.withOpacity(0.6),
                width: highlight ? 2 : 1,
              ),
              boxShadow: highlight
                  ? [BoxShadow(color: AppConstants.primaryOrange.withOpacity(0.08), blurRadius: 8, spreadRadius: 1)]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  _getStatusIcon(),
                  size: 44,
                  color: AppConstants.textPrimary,
                ),
                const SizedBox(height: AppConstants.paddingSmall),
                Text(
                  'Table ${table.tableNumber}',
                  style: AppConstants.headingSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  _getStatusText(),
                  style: AppConstants.bodySmall.copyWith(
                    color: AppConstants.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${table.capacity} seats',
                  style: AppConstants.bodySmall,
                ),
              ],
            ),
          ),
          // Badge: items + total
          if ((itemCount ?? 0) > 0)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppConstants.primaryOrange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      '${itemCount}',
                      style: AppConstants.bodySmall.copyWith(color: AppConstants.textPrimary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      Formatters.formatCurrency(totalAmount ?? 0.0),
                      style: AppConstants.bodySmall.copyWith(color: AppConstants.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (table.status) {
      case TableStatus.free:
        return AppConstants.cardBackground;
      case TableStatus.seated:
        return AppConstants.primaryOrange.withOpacity(0.2);
      case TableStatus.ordering:
        return AppConstants.primaryOrange.withOpacity(0.12);
      case TableStatus.ready_for_payment:
        return AppConstants.successGreen.withOpacity(0.12);
      case TableStatus.waiting:
        return AppConstants.warningYellow.withOpacity(0.2);
      case TableStatus.occupied_cleaning:
        return AppConstants.darkSecondary;
    }
  }

  IconData _getStatusIcon() {
    switch (table.status) {
      case TableStatus.free:
        return Icons.check_circle_outline;
      case TableStatus.seated:
        return Icons.people;
      case TableStatus.ordering:
        return Icons.receipt_long;
      case TableStatus.ready_for_payment:
        return Icons.payment;
      case TableStatus.waiting:
        return Icons.event_seat;
      case TableStatus.occupied_cleaning:
        return Icons.cleaning_services;
    }
  }

  String _getStatusText() {
    switch (table.status) {
      case TableStatus.free:
        return 'Free';
      case TableStatus.seated:
        return 'Seated';
      case TableStatus.ordering:
        return 'Ordering';
      case TableStatus.ready_for_payment:
        return 'Ready for Payment';
      case TableStatus.waiting:
        return 'Waiting';
      case TableStatus.occupied_cleaning:
        return 'Cleaning';
    }
  }
}
