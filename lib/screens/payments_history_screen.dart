import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

class PaymentsHistoryScreen extends StatefulWidget {
  const PaymentsHistoryScreen({super.key});

  @override
  State<PaymentsHistoryScreen> createState() => _PaymentsHistoryScreenState();
}

class _PaymentsHistoryScreenState extends State<PaymentsHistoryScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  // Example data — replace with real data source
  final List<Map<String, Object>> _allPayments = [
    {'id': 'P-001', 'amount': 1200.0, 'date': DateTime.now()},
    {'id': 'P-002', 'amount': 450.5, 'date': DateTime.now().subtract(const Duration(days: 1))},
    {'id': 'P-003', 'amount': 980.0, 'date': DateTime.now().subtract(const Duration(days: 2))},
    {'id': 'P-004', 'amount': 300.0, 'date': DateTime.now().subtract(const Duration(days: 7))},
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

  List<Map<String, Object>> get _filteredPayments {
    return _allPayments.where((p) {
      final date = p['date'] as DateTime;
      return _isDateInRange(date);
    }).toList();
  }

  double get _totalAmount =>
      _filteredPayments.fold(0.0, (s, p) => s + (p['amount'] as double));

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
    final payments = _filteredPayments;

    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        backgroundColor: AppConstants.darkSecondary,
        title: const Text('Payments History', style: AppConstants.headingSmall),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
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
                      child: TextButton.icon(
                        onPressed: _pickSingleDate,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: const Text('Single Date'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppConstants.primaryOrange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _pickDateRange,
                        icon: const Icon(Icons.date_range, size: 18),
                        label: const Text('Date Range'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppConstants.primaryOrange,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // List of payments
          Expanded(
            child: payments.isEmpty
                ? Center(
                    child: Text(
                      'No payments found',
                      style: AppConstants.bodyMedium.copyWith(color: AppConstants.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppConstants.paddingMedium),
                    itemCount: payments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppConstants.paddingMedium),
                    itemBuilder: (context, index) {
                      final p = payments[index];
                      final date = p['date'] as DateTime;
                      return Container(
                        padding: const EdgeInsets.all(AppConstants.paddingMedium),
                        decoration: BoxDecoration(
                          color: AppConstants.cardBackground,
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                          border: Border.all(color: AppConstants.dividerColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Payment ${p['id']}', style: AppConstants.bodyLarge),
                                const SizedBox(height: 4),
                                Text(Formatters.formatDate(date),
                                    style: AppConstants.bodySmall.copyWith(color: AppConstants.textSecondary)),
                              ],
                            ),
                            Text(
                              Formatters.formatCurrency(p['amount'] as double),
                              style: AppConstants.bodyLarge.copyWith(
                                  color: AppConstants.successGreen, fontWeight: FontWeight.bold),
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
              vertical: AppConstants.paddingSmall,
            ),
            decoration: BoxDecoration(
              color: AppConstants.darkSecondary,
              border: Border(top: BorderSide(color: AppConstants.dividerColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _startDate == null ? 'Total (All dates)' : 'Total (${Formatters.formatDate(_startDate!)})',
                  style: AppConstants.bodyLarge,
                ),
                Text(
                  Formatters.formatCurrency(_totalAmount),
                  style: AppConstants.bodyLarge.copyWith(
                    color: AppConstants.primaryOrange,
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