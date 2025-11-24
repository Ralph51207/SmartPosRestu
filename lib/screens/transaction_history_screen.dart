import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order_model.dart';
import '../services/transaction_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isDateInRange(DateTime date) {
    if (_startDate == null && _endDate == null) return true;
    if (_startDate != null && _endDate == null) {
      return _isSameDay(date, _startDate!);
    }
    if (_startDate == null || _endDate == null) return false;
    return !date.isBefore(_startDate!) && !date.isAfter(_endDate!);
  }

  List<TransactionRecord> _applyDateFilter(List<TransactionRecord> source) {
    return source.where((record) => _isDateInRange(record.timestamp)).toList();
  }

  double _calculateTotal(List<TransactionRecord> transactions) {
    return transactions.fold(0.0, (sum, record) => sum + record.saleAmount);
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now(), // Restrict to present day and earlier
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppConstants.primaryOrange,
            onPrimary: Colors.white,
            surface: AppConstants.cardBackground,
            onSurface: AppConstants.textPrimary,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _pickSingleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now(), // Restrict to present day and earlier
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppConstants.primaryOrange,
            onPrimary: Colors.white,
            surface: AppConstants.cardBackground,
            onSurface: AppConstants.textPrimary,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        _endDate = null;
      });
    }
  }

  void _clearDates() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  String get _dateRangeText {
    if (_startDate == null) return 'Showing: All dates';
    if (_endDate == null)
      return 'Showing: ${Formatters.formatDate(_startDate!)}';
    return 'Showing: ${Formatters.formatDate(_startDate!)} - ${Formatters.formatDate(_endDate!)}';
  }

  @override
  Widget build(BuildContext context) {
    final transactionService = Provider.of<TransactionService>(
      context,
      listen: false,
    );

    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        backgroundColor: AppConstants.darkSecondary,
        title: const Text(
          'Transaction History',
          style: AppConstants.headingSmall,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Exporting transactions...'),
                  backgroundColor: AppConstants.primaryOrange,
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<TransactionRecord>>(
        stream: transactionService.watchTransactions(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(
              snapshot.error?.toString() ?? 'Unknown error',
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          final fetched = snapshot.data ?? const <TransactionRecord>[];
          final transactions = _applyDateFilter(fetched);
          final totalAmount = _calculateTotal(transactions);

          return Column(
            children: [
              _buildDateSelector(),
              Expanded(
                child: transactions.isEmpty
                    ? _buildEmptyState()
                    : _buildTransactionsList(transactions),
              ),
              _buildTotalBar(totalAmount),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      color: AppConstants.cardBackground,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(_dateRangeText, style: AppConstants.bodyMedium),
              ),
              if (_startDate != null)
                IconButton(
                  onPressed: _clearDates,
                  icon: const Icon(Icons.clear),
                  color: AppConstants.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickSingleDate,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: const Text('Single Date'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.darkSecondary,
                    foregroundColor: AppConstants.primaryOrange,
                    side: const BorderSide(color: AppConstants.primaryOrange),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: const Text('Date Range'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.darkSecondary,
                    foregroundColor: AppConstants.primaryOrange,
                    side: const BorderSide(color: AppConstants.primaryOrange),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(List<TransactionRecord> transactions) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      itemCount: transactions.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppConstants.paddingMedium),
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        final isRefund = transaction.isRefund;
        final amountColor = isRefund
            ? AppConstants.errorRed
            : AppConstants.successGreen;
        final amountValue = transaction.saleAmount.abs();
        final itemsPreview = _buildItemsPreview(transaction);

        return InkWell(
          onTap: () => _showTransactionDetails(transaction),
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          child: Container(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            decoration: BoxDecoration(
              color: AppConstants.cardBackground,
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              border: Border.all(color: AppConstants.dividerColor),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: amountColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusSmall,
                    ),
                  ),
                  child: Icon(
                    isRefund ? Icons.arrow_upward : Icons.arrow_downward,
                    color: amountColor,
                  ),
                ),
                const SizedBox(width: AppConstants.paddingMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Order ${transaction.orderId}',
                            style: AppConstants.bodyLarge,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: amountColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              transaction.paymentMethod,
                              style: AppConstants.bodySmall.copyWith(
                                color: amountColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatTableLabel(transaction.tableNumber)} • ${Formatters.formatDate(transaction.timestamp)}',
                        style: AppConstants.bodySmall.copyWith(
                          color: AppConstants.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        itemsPreview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppConstants.bodySmall.copyWith(
                          color: AppConstants.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  Formatters.formatCurrency(amountValue),
                  style: AppConstants.bodyLarge.copyWith(
                    color: amountColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTransactionDetails(TransactionRecord transaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusLarge),
        ),
      ),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, controller) {
            return SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.all(AppConstants.paddingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order ${transaction.orderId}',
                        style: AppConstants.headingMedium,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppConstants.successGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          transaction.paymentMethod,
                          style: AppConstants.bodySmall.copyWith(
                            color: AppConstants.successGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.paddingSmall),
                  Text(
                    '${_formatTableLabel(transaction.tableNumber)} • ${Formatters.formatDateTime(transaction.timestamp)}',
                    style: AppConstants.bodySmall.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingLarge),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppConstants.paddingLarge),
                    decoration: BoxDecoration(
                      color: AppConstants.darkSecondary,
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMedium,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Amount',
                          style: AppConstants.bodyMedium.copyWith(
                            color: AppConstants.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.formatCurrency(
                            transaction.saleAmount.abs(),
                          ),
                          style: AppConstants.headingLarge.copyWith(
                            color: AppConstants.successGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppConstants.paddingMedium),
                        _buildDetailRow(
                          'Amount Paid',
                          Formatters.formatCurrency(transaction.amountPaid),
                        ),
                        _buildDetailRow(
                          'Change',
                          Formatters.formatCurrency(transaction.change),
                        ),
                        _buildDetailRow(
                          'Status',
                          transaction.status.toString().split('.').last,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingLarge),
                  Text('Items', style: AppConstants.headingSmall),
                  const SizedBox(height: AppConstants.paddingSmall),
                  if (transaction.items.isEmpty)
                    Text(
                      'No items recorded',
                      style: AppConstants.bodySmall.copyWith(
                        color: AppConstants.textSecondary,
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _groupItemsByCategory(transaction.items)
                          .entries
                          .map(
                            (entry) => _buildCategorySection(
                              entry.key,
                              entry.value,
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: AppConstants.paddingLarge),
                  if (transaction.notes != null &&
                      transaction.notes!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Notes', style: AppConstants.headingSmall),
                        const SizedBox(height: AppConstants.paddingSmall),
                        Text(
                          transaction.notes!,
                          style: AppConstants.bodyMedium,
                        ),
                        const SizedBox(height: AppConstants.paddingLarge),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _buildItemsPreview(TransactionRecord transaction) {
    if (transaction.items.isEmpty) {
      return 'No items recorded';
    }
    final previewItems = transaction.items.take(3).map((item) {
      final category = _resolveCategoryLabel(item);
      final categoryText = category.isEmpty ? '' : ' ($category)';
      return '${item.quantity}× ${item.name}$categoryText';
    }).toList();

    final remaining = transaction.items.length - previewItems.length;
    final base = previewItems.join(', ');
    return remaining > 0 ? '$base +$remaining more' : base;
  }

  Map<String, List<OrderItem>> _groupItemsByCategory(List<OrderItem> items) {
    final grouped = <String, List<OrderItem>>{};
    for (final item in items) {
      final resolved = _resolveCategoryLabel(item);
      final label = resolved.isEmpty ? 'Uncategorized' : resolved;
      grouped.putIfAbsent(label, () => []).add(item);
    }
    return grouped;
  }

  String _resolveCategoryLabel(OrderItem item) {
    final label = item.categoryLabel?.trim();
    if (label != null && label.isNotEmpty) {
      return label;
    }
    final raw = item.category?.trim();
    if (raw != null && raw.isNotEmpty) {
      return _beautifyCategory(raw);
    }
    return '';
  }

  String _beautifyCategory(String raw) {
    final spaced = raw
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        );
    final words = spaced
      .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) =>
            word[0].toUpperCase() + word.substring(1).toLowerCase())
        .toList();
    return words.join(' ');
  }

  Widget _buildCategorySection(String category, List<OrderItem> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category,
            style: AppConstants.bodyMedium.copyWith(
              color: AppConstants.primaryOrange,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          ...items.map(_buildItemRow),
        ],
      ),
    );
  }

  Widget _buildItemRow(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppConstants.primaryOrange.withOpacity(0.1),
            child: Text(
              item.quantity.toString(),
              style: AppConstants.bodyMedium,
            ),
          ),
          const SizedBox(width: AppConstants.paddingSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: AppConstants.bodyMedium),
                Text(
                  '${Formatters.formatCurrency(item.price)} each',
                  style: AppConstants.bodySmall.copyWith(
                    color: AppConstants.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            Formatters.formatCurrency(item.totalPrice),
            style: AppConstants.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppConstants.bodySmall.copyWith(
              color: AppConstants.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppConstants.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: AppConstants.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          Text(
            'No transactions found',
            style: AppConstants.bodyMedium.copyWith(
              color: AppConstants.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: AppConstants.primaryOrange),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppConstants.errorRed, size: 48),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              'Failed to load transactions',
              style: AppConstants.headingSmall.copyWith(
                color: AppConstants.errorRed,
              ),
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppConstants.bodySmall.copyWith(
                color: AppConstants.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalBar(double totalAmount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: AppConstants.paddingMedium,
      ),
      decoration: BoxDecoration(
        color: AppConstants.darkSecondary,
        border: Border(top: BorderSide(color: AppConstants.dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Amount',
                style: AppConstants.bodySmall.copyWith(
                  color: AppConstants.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _startDate == null
                    ? 'All dates'
                    : _endDate == null
                    ? Formatters.formatDate(_startDate!)
                    : '${Formatters.formatDate(_startDate!)} - ${Formatters.formatDate(_endDate!)}',
                style: AppConstants.bodySmall.copyWith(
                  color: AppConstants.textSecondary,
                ),
              ),
            ],
          ),
          Text(
            Formatters.formatCurrency(totalAmount),
            style: AppConstants.headingSmall.copyWith(
              color: totalAmount >= 0
                  ? AppConstants.successGreen
                  : AppConstants.errorRed,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTableLabel(String tableNumber) {
    if (tableNumber.trim().isEmpty || tableNumber == 'NO_TABLE') {
      return 'No table';
    }
    return 'Table $tableNumber';
  }
}
