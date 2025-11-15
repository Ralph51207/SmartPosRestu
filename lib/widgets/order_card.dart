import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

/// Widget to display an order card
class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;

  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppConstants.cardBackground,
      margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        side: BorderSide(
          color: _getStatusColor(order.status).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Order ID
                  Row(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        color: AppConstants.primaryOrange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Order #${order.id}',
                        style: AppConstants.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(order.status),
                      ),
                    ),
                    child: Text(
                      _getStatusText(order.status),
                      style: AppConstants.bodySmall.copyWith(
                        color: _getStatusColor(order.status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.paddingSmall),
              const Divider(color: AppConstants.dividerColor, height: 1),
              const SizedBox(height: AppConstants.paddingSmall),
              
              // Table and time info
              Row(
                children: [
                  // Table number
                  Icon(
                    Icons.table_restaurant,
                    color: AppConstants.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Table ${order.tableNumber}',
                    style: AppConstants.bodyMedium,
                  ),
                  const SizedBox(width: AppConstants.paddingMedium),
                  // Time
                  Icon(
                    Icons.access_time,
                    color: AppConstants.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    Formatters.formatTime(order.timestamp),
                    style: AppConstants.bodyMedium.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.paddingSmall),
              
              // Items count and total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.items.length} item${order.items.length > 1 ? 's' : ''}',
                    style: AppConstants.bodyMedium.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                  ),
                  Text(
                    Formatters.formatCurrency(order.totalAmount),
                    style: AppConstants.bodyLarge.copyWith(
                      color: AppConstants.primaryOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppConstants.warningYellow;
      case OrderStatus.preparing:
        return Colors.blue;
      case OrderStatus.ready:
        return AppConstants.primaryOrange;
      case OrderStatus.completed:
        return AppConstants.successGreen;
      case OrderStatus.cancelled:
        return AppConstants.errorRed;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'PENDING';
      case OrderStatus.preparing:
        return 'PREPARING';
      case OrderStatus.ready:
        return 'READY';
      case OrderStatus.completed:
        return 'COMPLETED';
      case OrderStatus.cancelled:
        return 'CANCELLED';
    }
  }
}
