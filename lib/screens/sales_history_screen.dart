import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/transaction_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import 'transaction_history_screen.dart';

enum SalesGrouping { daily, monthly }

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  SalesGrouping _grouping = SalesGrouping.daily;

  // Expenses data
  final List<Map<String, dynamic>> _allExpenses = [
    {
      'id': 'EXP-001',
      'category': 'Utilities',
      'description': 'Electricity Bill',
      'amount': 2500.0,
      'date': DateTime.now(),
    },
    {
      'id': 'EXP-002',
      'category': 'Supplies',
      'description': 'Food Ingredients',
      'amount': 5800.0,
      'date': DateTime.now().subtract(const Duration(days: 1)),
    },
    {
      'id': 'EXP-003',
      'category': 'Salaries',
      'description': 'Staff Wages',
      'amount': 8000.0,
      'date': DateTime.now().subtract(const Duration(days: 2)),
    },
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

  List<Map<String, dynamic>> get _filteredExpenses {
    return _allExpenses.where((e) {
      final date = e['date'] as DateTime;
      return _isDateInRange(date);
    }).toList();
  }

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

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
    if (_startDate == null) return 'All dates';
    if (_endDate == null) return Formatters.formatDate(_startDate!);
    return '${Formatters.formatDate(_startDate!)} - ${Formatters.formatDate(_endDate!)}';
  }

  void _printReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Printing sales report...'),
        backgroundColor: AppConstants.primaryOrange,
      ),
    );
  }

  void _exportToExcel() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exporting to Excel...'),
        backgroundColor: AppConstants.successGreen,
      ),
    );
  }

  void _showAddExpenseDialog() {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedCategory = 'Utilities';

    final categories = [
      'Utilities',
      'Supplies',
      'Salaries',
      'Rent',
      'Maintenance',
      'Marketing',
      'Transportation',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppConstants.darkSecondary,
          title: const Text('Add Expense', style: AppConstants.headingSmall),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Dropdown
                const Text('Category', style: AppConstants.bodyMedium),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppConstants.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusSmall,
                      ),
                      borderSide: const BorderSide(
                        color: AppConstants.dividerColor,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusSmall,
                      ),
                      borderSide: const BorderSide(
                        color: AppConstants.dividerColor,
                      ),
                    ),
                  ),
                  dropdownColor: AppConstants.cardBackground,
                  items: categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category, style: AppConstants.bodyMedium),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedCategory = value!;
                    });
                  },
                ),
                const SizedBox(height: AppConstants.paddingMedium),

                // Description
                const Text('Description', style: AppConstants.bodyMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  style: AppConstants.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Enter description',
                    hintStyle: AppConstants.bodyMedium.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppConstants.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusSmall,
                      ),
                      borderSide: const BorderSide(
                        color: AppConstants.dividerColor,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusSmall,
                      ),
                      borderSide: const BorderSide(
                        color: AppConstants.dividerColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMedium),

                // Amount
                const Text('Amount', style: AppConstants.bodyMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: AppConstants.bodyMedium,
                  decoration: InputDecoration(
                    hintText: '0.00',
                    prefixText: '₱ ',
                    hintStyle: AppConstants.bodyMedium.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppConstants.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusSmall,
                      ),
                      borderSide: const BorderSide(
                        color: AppConstants.dividerColor,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusSmall,
                      ),
                      borderSide: const BorderSide(
                        color: AppConstants.dividerColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMedium),

                // Date Picker
                const Text('Date', style: AppConstants.bodyMedium),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
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
                      setDialogState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppConstants.cardBackground,
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusSmall,
                      ),
                      border: Border.all(color: AppConstants.dividerColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          Formatters.formatDate(selectedDate),
                          style: AppConstants.bodyMedium,
                        ),
                        const Icon(
                          Icons.calendar_today,
                          color: AppConstants.primaryOrange,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: AppConstants.bodyMedium.copyWith(
                  color: AppConstants.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (descriptionController.text.isEmpty ||
                    amountController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all fields'),
                      backgroundColor: AppConstants.errorRed,
                    ),
                  );
                  return;
                }

                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid amount'),
                      backgroundColor: AppConstants.errorRed,
                    ),
                  );
                  return;
                }

                setState(() {
                  _allExpenses.add({
                    'id': 'EXP-${_allExpenses.length + 1}',
                    'category': selectedCategory,
                    'description': descriptionController.text,
                    'amount': amount,
                    'date': selectedDate,
                  });
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Expense added successfully'),
                    backgroundColor: AppConstants.successGreen,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryOrange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Expense'),
            ),
          ],
        ),
      ),
    );
  }

  void _showExpensesDialog() {
    final expenses = _filteredExpenses;
    final totalExpenses = expenses.fold(
      0.0,
      (sum, expense) => sum + _asDouble(expense['amount']),
    );
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppConstants.darkSecondary,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Expenses', style: AppConstants.headingMedium),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: AppConstants.dividerColor),
              const SizedBox(height: AppConstants.paddingSmall),

              // Total Expenses Summary
              Container(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                decoration: BoxDecoration(
                  color: AppConstants.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(
                    AppConstants.radiusMedium,
                  ),
                  border: Border.all(color: AppConstants.errorRed),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Expenses', style: AppConstants.bodyLarge),
                    Text(
                      Formatters.formatCurrency(totalExpenses),
                      style: AppConstants.headingSmall.copyWith(
                        color: AppConstants.errorRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.paddingMedium),

              // Expenses List
              Expanded(
                child: expenses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_outlined,
                              size: 64,
                              color: AppConstants.textSecondary.withOpacity(
                                0.5,
                              ),
                            ),
                            const SizedBox(height: AppConstants.paddingMedium),
                            Text(
                              'No expenses recorded',
                              style: AppConstants.bodyMedium.copyWith(
                                color: AppConstants.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: expenses.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppConstants.paddingSmall),
                        itemBuilder: (context, index) {
                          final expense = expenses[index];
                          return Container(
                            padding: const EdgeInsets.all(
                              AppConstants.paddingMedium,
                            ),
                            decoration: BoxDecoration(
                              color: AppConstants.cardBackground,
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusMedium,
                              ),
                              border: Border.all(
                                color: AppConstants.dividerColor,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppConstants.errorRed.withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppConstants.radiusSmall,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.money_off,
                                    color: AppConstants.errorRed,
                                  ),
                                ),
                                const SizedBox(
                                  width: AppConstants.paddingMedium,
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            expense['category'],
                                            style: AppConstants.bodySmall
                                                .copyWith(
                                                  color: AppConstants
                                                      .primaryOrange,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '• ${Formatters.formatDate(expense['date'])}',
                                            style: AppConstants.bodySmall
                                                .copyWith(
                                                  color: AppConstants
                                                      .textSecondary,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        expense['description'],
                                        style: AppConstants.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  Formatters.formatCurrency(
                                    _asDouble(expense['amount']),
                                  ),
                                  style: AppConstants.bodyLarge.copyWith(
                                    color: AppConstants.errorRed,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                  ),
                                  color: AppConstants.errorRed,
                                  onPressed: () {
                                    setState(() {
                                      _allExpenses.remove(expense);
                                    });
                                    Navigator.pop(context);
                                    _showExpensesDialog();
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
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
        title: const Text('Sales History', style: AppConstants.headingSmall),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'View Transactions',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TransactionHistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export to Excel',
            onPressed: _exportToExcel,
          ),
        ],
      ),
      body: StreamBuilder<List<TransactionRecord>>(
        stream: transactionService.watchTransactions(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(
              snapshot.error?.toString() ?? 'Failed to load sales data',
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppConstants.primaryOrange,
              ),
            );
          }

          final transactions = _filterTransactions(
            snapshot.data ?? const <TransactionRecord>[],
          );
          final summaries = _buildSummaries(transactions);
          final totalSales = _calculateSalesTotal(transactions);
          final totalOrders = transactions.length;
          final avgOrderValue = totalOrders == 0 ? 0.0 : totalSales / totalOrders;
          final expenses = _filteredExpenses;
          final totalExpenses = expenses.fold(
            0.0,
            (sum, expense) => sum + _asDouble(expense['amount']),
          );
          final netProfit = totalSales - totalExpenses;

          return Column(
            children: [
              _buildDateSelectorSection(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildProfitCards(
                        totalSales,
                        totalExpenses,
                        netProfit,
                        expenses.length,
                      ),
                      _buildSalesTable(summaries),
                      const SizedBox(height: AppConstants.paddingMedium),
                    ],
                  ),
                ),
              ),
              _buildFooter(totalSales, totalOrders, avgOrderValue),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateSelectorSection() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      color: AppConstants.cardBackground,
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.date_range,
                color: AppConstants.primaryOrange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _dateRangeText,
                  style: AppConstants.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_startDate != null)
                IconButton(
                  onPressed: _clearDates,
                  icon: const Icon(Icons.clear),
                  color: AppConstants.textSecondary,
                  iconSize: 20,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickSingleDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: const Text('Single Date'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppConstants.primaryOrange,
                    side: const BorderSide(color: AppConstants.primaryOrange),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range, size: 16),
                  label: const Text('Date Range'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppConstants.primaryOrange,
                    side: const BorderSide(color: AppConstants.primaryOrange),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildGroupingToggle(),
        ],
      ),
    );
  }

  Widget _buildGroupingToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChoiceChip(
          label: const Text('Daily'),
          selected: _grouping == SalesGrouping.daily,
          onSelected: (selected) {
            if (selected) {
              setState(() => _grouping = SalesGrouping.daily);
            }
          },
          selectedColor: AppConstants.primaryOrange,
          backgroundColor: AppConstants.darkSecondary,
          labelStyle: TextStyle(
            color: _grouping == SalesGrouping.daily
                ? Colors.white
                : AppConstants.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        ChoiceChip(
          label: const Text('Monthly'),
          selected: _grouping == SalesGrouping.monthly,
          onSelected: (selected) {
            if (selected) {
              setState(() => _grouping = SalesGrouping.monthly);
            }
          },
          selectedColor: AppConstants.primaryOrange,
          backgroundColor: AppConstants.darkSecondary,
          labelStyle: TextStyle(
            color: _grouping == SalesGrouping.monthly
                ? Colors.white
                : AppConstants.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildProfitCards(
    double grossProfit,
    double totalExpenses,
    double netProfit,
    int expenseCount,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Row(
        children: [
          Expanded(
            child: _buildProfitCard(
              'Gross Profit',
              grossProfit,
              AppConstants.successGreen,
              Icons.trending_up,
            ),
          ),
          const SizedBox(width: AppConstants.paddingMedium),
          Expanded(
            child: GestureDetector(
              onTap: _showExpensesDialog,
              child: _buildProfitCard(
                'Expenses',
                totalExpenses,
                AppConstants.errorRed,
                Icons.money_off,
                showBadge: true,
                badgeValue: expenseCount,
              ),
            ),
          ),
          const SizedBox(width: AppConstants.paddingMedium),
          Expanded(
            child: _buildProfitCard(
              'Net Profit',
              netProfit,
              netProfit >= 0
                  ? AppConstants.primaryOrange
                  : AppConstants.errorRed,
              Icons.account_balance_wallet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesTable(List<_SalesSummary> summaries) {
    final hasData = summaries.isNotEmpty;
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(AppConstants.paddingMedium),
          decoration: BoxDecoration(
            color: AppConstants.darkSecondary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppConstants.radiusMedium),
              topRight: Radius.circular(AppConstants.radiusMedium),
            ),
            border: Border.all(color: AppConstants.dividerColor),
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(2),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: AppConstants.primaryOrange.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppConstants.radiusMedium),
                    topRight: Radius.circular(AppConstants.radiusMedium),
                  ),
                ),
                children: [
                  _buildHeaderCell(
                    _grouping == SalesGrouping.daily ? 'Date' : 'Month',
                  ),
                  _buildHeaderCell('Total Sales'),
                  _buildHeaderCell('Orders'),
                  _buildHeaderCell('Avg Order'),
                ],
              ),
            ],
          ),
        ),
        if (!hasData)
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingLarge * 2),
            child: Column(
              children: [
                Icon(
                  Icons.table_chart_outlined,
                  size: 64,
                  color: AppConstants.textSecondary.withOpacity(0.5),
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                Text(
                  'No sales data found',
                  style: AppConstants.bodyMedium.copyWith(
                    color: AppConstants.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMedium,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: AppConstants.dividerColor),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppConstants.radiusMedium),
                bottomRight: Radius.circular(AppConstants.radiusMedium),
              ),
            ),
            child: Column(
              children: [
                for (var i = 0; i < summaries.length; i++)
                  _buildSalesRow(
                    summaries[i],
                    isLast: i == summaries.length - 1,
                    isAlternate: i.isEven,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSalesRow(
    _SalesSummary summary, {
    required bool isLast,
    required bool isAlternate,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isAlternate
            ? AppConstants.cardBackground
            : AppConstants.darkBackground,
        border: !isLast
            ? const Border(
                bottom: BorderSide(
                  color: AppConstants.dividerColor,
                  width: 0.5,
                ),
              )
            : null,
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(1.5),
          3: FlexColumnWidth(2),
        },
        children: [
          TableRow(
            children: [
              _buildDataCell(_formatSummaryDate(summary.date), isLast),
              _buildDataCell(
                Formatters.formatCurrency(summary.total),
                isLast,
                color: AppConstants.successGreen,
                bold: true,
              ),
              _buildDataCell(summary.orders.toString(), isLast, centered: true),
              _buildDataCell(
                Formatters.formatCurrency(summary.avgOrder),
                isLast,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(
    double totalSales,
    int totalOrders,
    double avgOrderValue,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.darkSecondary,
        border: const Border(
          top: BorderSide(color: AppConstants.dividerColor, width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                'Total Sales',
                Formatters.formatCurrency(totalSales),
                AppConstants.successGreen,
              ),
              Container(width: 1, height: 40, color: AppConstants.dividerColor),
              _buildSummaryItem(
                'Total Orders',
                totalOrders.toString(),
                AppConstants.primaryOrange,
              ),
              Container(width: 1, height: 40, color: AppConstants.dividerColor),
              _buildSummaryItem(
                'Avg Order',
                Formatters.formatCurrency(avgOrderValue),
                Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showAddExpenseDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Expense'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.errorRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMedium,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.paddingSmall),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _printReport,
                  icon: const Icon(Icons.print),
                  label: const Text('Print Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMedium,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
              'Unable to load sales',
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

  List<TransactionRecord> _filterTransactions(
    List<TransactionRecord> transactions,
  ) {
    return transactions
        .where((record) => _isDateInRange(record.timestamp))
        .toList();
  }

  List<_SalesSummary> _buildSummaries(List<TransactionRecord> transactions) {
    final Map<String, _SalesSummary> grouped = {};
    for (final transaction in transactions) {
      final timestamp = transaction.timestamp;
      final keyDate = _grouping == SalesGrouping.daily
          ? DateTime(timestamp.year, timestamp.month, timestamp.day)
          : DateTime(timestamp.year, timestamp.month);
      final key = keyDate.toIso8601String();
      final summary = grouped.putIfAbsent(
        key,
        () => _SalesSummary(date: keyDate),
      );
      summary.addTransaction(transaction);
    }
    final summaries = grouped.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return summaries;
  }

  double _calculateSalesTotal(List<TransactionRecord> transactions) {
    return transactions.fold(0.0, (sum, record) => sum + record.saleAmount);
  }

  String _formatSummaryDate(DateTime date) {
    if (_grouping == SalesGrouping.daily) {
      return Formatters.formatDate(date);
    }
    return DateFormat('MMMM yyyy').format(date);
  }

  Widget _buildProfitCard(
    String label,
    double value,
    Color color,
    IconData icon, {
    bool showBadge = false,
    int badgeValue = 0,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppConstants.bodySmall.copyWith(
                  color: AppConstants.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                Formatters.formatCurrency(value),
                style: AppConstants.bodyLarge.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          if (showBadge)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppConstants.primaryOrange,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$badgeValue',
                  style: AppConstants.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: AppConstants.bodyMedium.copyWith(
          fontWeight: FontWeight.bold,
          color: AppConstants.primaryOrange,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDataCell(
    String text,
    bool isLast, {
    Color? color,
    bool bold = false,
    bool centered = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: isLast
            ? const BorderRadius.only(
                bottomLeft: Radius.circular(AppConstants.radiusMedium),
                bottomRight: Radius.circular(AppConstants.radiusMedium),
              )
            : null,
      ),
      child: Text(
        text,
        style: AppConstants.bodyMedium.copyWith(
          color: color ?? AppConstants.textPrimary,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
        textAlign: centered ? TextAlign.center : TextAlign.left,
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: AppConstants.bodySmall.copyWith(
            color: AppConstants.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppConstants.headingSmall.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Aggregated sales data for a specific day or month.
class _SalesSummary {
  _SalesSummary({required this.date});

  final DateTime date;
  double total = 0;
  int orders = 0;

  double get avgOrder => orders == 0 ? 0 : total / orders;

  void addTransaction(TransactionRecord record) {
    total += record.saleAmount;
    orders += 1;
  }
}
