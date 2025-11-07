import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  // Example data — replace with real data source
  final List<Map<String, Object>> _allTransactions = [
    {'id': 'T-001', 'amount': 1200.0, 'date': DateTime.now(), 'type': 'Sale'},
    {'id': 'T-002', 'amount': 450.5, 'date': DateTime.now().subtract(const Duration(days: 1)), 'type': 'Sale'},
    {'id': 'T-003', 'amount': 980.0, 'date': DateTime.now().subtract(const Duration(days: 2)), 'type': 'Sale'},
    {'id': 'T-004', 'amount': 300.0, 'date': DateTime.now().subtract(const Duration(days: 7)), 'type': 'Refund'},
    {'id': 'T-005', 'amount': 750.0, 'date': DateTime.now().subtract(const Duration(days: 3)), 'type': 'Sale'},
    {'id': 'T-006', 'amount': 520.0, 'date': DateTime.now().subtract(const Duration(days: 4)), 'type': 'Sale'},
    {'id': 'T-007', 'amount': 150.0, 'date': DateTime.now().subtract(const Duration(days: 5)), 'type': 'Refund'},
    {'id': 'T-008', 'amount': 890.0, 'date': DateTime.now().subtract(const Duration(days: 6)), 'type': 'Sale'},
  ];

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

  List<Map<String, Object>> get _filteredTransactions {
    return _allTransactions.where((t) {
      final date = t['date'] as DateTime;
      return _isDateInRange(date);
    }).toList();
  }

  double get _totalAmount =>
      _filteredTransactions.fold(0.0, (s, t) {
        final amount = t['amount'] as double;
        final type = t['type'] as String;
        return type == 'Refund' ? s - amount : s + amount;
      });

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
    if (_endDate == null) return 'Showing: ${Formatters.formatDate(_startDate!)}';
    return 'Showing: ${Formatters.formatDate(_startDate!)} - ${Formatters.formatDate(_endDate!)}';
  }

  @override
  Widget build(BuildContext context) {
    final transactions = _filteredTransactions;

    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        backgroundColor: AppConstants.darkSecondary,
        title: const Text('Transaction History', style: AppConstants.headingSmall),
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
      body: Column(
        children: [
          // Date selector
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            color: AppConstants.cardBackground,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dateRangeText,
                        style: AppConstants.bodyMedium,
                      ),
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
          ),

          // List of transactions
          Expanded(
            child: transactions.isEmpty
                ? Center(
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
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppConstants.paddingMedium),
                    itemCount: transactions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppConstants.paddingMedium),
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];
                      final date = transaction['date'] as DateTime;
                      final type = transaction['type'] as String;
                      final isRefund = type == 'Refund';
                      
                      return Container(
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
                                color: (isRefund ? AppConstants.errorRed : AppConstants.successGreen).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                              ),
                              child: Icon(
                                isRefund ? Icons.arrow_upward : Icons.arrow_downward,
                                color: isRefund ? AppConstants.errorRed : AppConstants.successGreen,
                              ),
                            ),
                            const SizedBox(width: AppConstants.paddingMedium),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text('Transaction ${transaction['id']}', style: AppConstants.bodyLarge),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: (isRefund ? AppConstants.errorRed : AppConstants.successGreen).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          type,
                                          style: AppConstants.bodySmall.copyWith(
                                            color: isRefund ? AppConstants.errorRed : AppConstants.successGreen,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    Formatters.formatDate(date),
                                    style: AppConstants.bodySmall.copyWith(
                                      color: AppConstants.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${isRefund ? '-' : ''}${Formatters.formatCurrency(transaction['amount'] as double)}',
                              style: AppConstants.bodyLarge.copyWith(
                                color: isRefund ? AppConstants.errorRed : AppConstants.successGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Total bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMedium,
              vertical: AppConstants.paddingMedium,
            ),
            decoration: BoxDecoration(
              color: AppConstants.darkSecondary,
              border: Border(
                top: BorderSide(color: AppConstants.dividerColor),
              ),
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
                  Formatters.formatCurrency(_totalAmount),
                  style: AppConstants.headingSmall.copyWith(
                    color: _totalAmount >= 0 ? AppConstants.successGreen : AppConstants.errorRed,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}