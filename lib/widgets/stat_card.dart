import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Reusable stat card widget for displaying key metrics
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;
  final String? percentageChange; // e.g., "+5.2%" or "-1.8%"

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.onTap,
    this.percentageChange,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: AppConstants.cardBackground,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(
            color: AppConstants.dividerColor,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon and title on the same row
            Row(
              children: [
                Icon(
                  icon,
                  color: AppConstants.textSecondary,
                  size: 24,
                ),
                const SizedBox(width: AppConstants.paddingSmall),
                Expanded(
                  child: Text(
                    title,
                    style: AppConstants.bodyMedium.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios,
                    color: AppConstants.textSecondary,
                    size: 16,
                  ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            // Value (large text)
            Text(
              value,
              style: AppConstants.headingLarge.copyWith(
                color: AppConstants.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Percentage change (if provided)
            if (percentageChange != null) ...[
              const SizedBox(height: AppConstants.paddingSmall),
              Row(
                children: [
                  Icon(
                    percentageChange!.startsWith('+') 
                        ? Icons.arrow_upward 
                        : Icons.arrow_downward,
                    color: percentageChange!.startsWith('+') 
                        ? AppConstants.successGreen 
                        : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    percentageChange!,
                    style: AppConstants.bodySmall.copyWith(
                      color: percentageChange!.startsWith('+') 
                          ? AppConstants.successGreen 
                          : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
