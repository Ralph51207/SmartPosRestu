import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/expense_service.dart';
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

  List<ExpenseRecord> _filterExpenses(List<ExpenseRecord> expenses) {
    return expenses.where((expense) => _isDateInRange(expense.date)).toList();
  }

  double _calculateTotalExpenses(List<ExpenseRecord> expenses) {
    return expenses.fold(0.0, (sum, expense) => sum + expense.amount);
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
    if (_startDate == null) {
      return 'All dates';
    }
    if (_endDate == null) {
      return Formatters.formatDate(_startDate!);
    }
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

  Future<void> _showAddExpenseDialog() async {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedCategory = 'Utilities';
    final expenseService = Provider.of<ExpenseService>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    const categories = [
      'Utilities',
      'Supplies',
      'Salaries',
      'Rent',
      'Maintenance',
      'Marketing',
      'Transportation',
      'Other',
    ];

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppConstants.darkSecondary,
          title: const Text('Add Expense', style: AppConstants.headingSmall),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    if (value == null) {
                      return;
                    }
                    setDialogState(() {
                      selectedCategory = value;
                    });
                  },
                ),
                const SizedBox(height: AppConstants.paddingMedium),
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
                const Text('Amount', style: AppConstants.bodyMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
                const Text('Date', style: AppConstants.bodyMedium),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (pickerContext, child) => Theme(
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
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: AppConstants.bodyMedium.copyWith(
                  color: AppConstants.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final description = descriptionController.text.trim();
                final rawAmount = amountController.text.trim().replaceAll(
                  ',',
                  '',
                );

                if (description.isEmpty || rawAmount.isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all fields'),
                      backgroundColor: AppConstants.errorRed,
                    ),
                  );
                  return;
                }

                final amount = double.tryParse(rawAmount);
                if (amount == null || amount <= 0) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid amount'),
                      backgroundColor: AppConstants.errorRed,
                    ),
                  );
                  return;
                }

                try {
                  await expenseService.addExpense(
                    category: selectedCategory,
                    description: description,
                    amount: amount,
                    date: selectedDate,
                  );
                  if (!mounted) {
                    return;
                  }
                  Navigator.of(dialogContext).pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Expense added successfully'),
                      backgroundColor: AppConstants.successGreen,
                    ),
                  );
                } catch (e) {
                  if (!mounted) {
                    return;
                  }
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Failed to add expense. Please try again.'),
                      backgroundColor: AppConstants.errorRed,
                    ),
                  );
                }
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
    final expenseService = Provider.of<ExpenseService>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    String? selectedExpenseId;
    bool isDeleteMode = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: AppConstants.darkSecondary,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: StreamBuilder<List<ExpenseRecord>>(
              stream: expenseService.watchExpenses(),
              builder: (streamContext, snapshot) {
                final expenses = _filterExpenses(
                  snapshot.data ?? const <ExpenseRecord>[],
                );
                final totalExpenses = _calculateTotalExpenses(expenses);
                final isLoading =
                    snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData;

                ExpenseRecord? selectedExpense;
                if (selectedExpenseId != null) {
                  for (final expense in expenses) {
                    if (expense.id == selectedExpenseId) {
                      selectedExpense = expense;
                      break;
                    }
                  }
                }

                Future<void> confirmDeletion() async {
                  if (selectedExpense == null) {
                    return;
                  }

                  final shouldDelete = await showDialog<bool>(
                    context: dialogContext,
                    builder: (confirmContext) => AlertDialog(
                      backgroundColor: AppConstants.darkSecondary,
                      title: const Text(
                        'Delete Expense',
                        style: AppConstants.headingSmall,
                      ),
                      content: Text(
                        'Are you sure you want to delete "${selectedExpense!.description}"?',
                        style: AppConstants.bodyMedium,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(confirmContext).pop(false),
                          child: Text(
                            'Cancel',
                            style: AppConstants.bodyMedium.copyWith(
                              color: AppConstants.textSecondary,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.of(confirmContext).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.errorRed,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  if (shouldDelete != true) {
                    return;
                  }

                  try {
                    await expenseService.deleteExpense(selectedExpense.id);
                    if (!mounted) return;
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Expense deleted'),
                        backgroundColor: AppConstants.successGreen,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Failed to delete expense. Please try again.',
                        ),
                        backgroundColor: AppConstants.errorRed,
                      ),
                    );
                  } finally {
                    setDialogState(() {
                      selectedExpenseId = null;
                      isDeleteMode = false;
                    });
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Expenses',
                          style: AppConstants.headingMedium,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                        ),
                      ],
                    ),
                    const Divider(color: AppConstants.dividerColor),
                    const SizedBox(height: AppConstants.paddingSmall),
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
                          const Text(
                            'Total Expenses',
                            style: AppConstants.bodyLarge,
                          ),
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
                    if (isDeleteMode)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppConstants.paddingSmall,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.touch_app,
                              size: 18,
                              color: AppConstants.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedExpense == null
                                    ? 'Select an expense to delete, then confirm.'
                                    : 'Selected "${selectedExpense.description}".',
                                style: AppConstants.bodySmall.copyWith(
                                  color: AppConstants.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppConstants.primaryOrange,
                              ),
                            )
                          : expenses.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_outlined,
                                    size: 64,
                                    color: AppConstants.textSecondary
                                        .withOpacity(0.5),
                                  ),
                                  const SizedBox(
                                    height: AppConstants.paddingMedium,
                                  ),
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
                              separatorBuilder: (_, __) => const SizedBox(
                                height: AppConstants.paddingSmall,
                              ),
                              itemBuilder: (itemContext, index) {
                                final expense = expenses[index];
                                final isSelected =
                                    isDeleteMode &&
                                    expense.id == selectedExpenseId;

                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: isDeleteMode
                                        ? () {
                                            setDialogState(() {
                                              selectedExpenseId =
                                                  selectedExpenseId ==
                                                      expense.id
                                                  ? null
                                                  : expense.id;
                                            });
                                          }
                                        : null,
                                    borderRadius: BorderRadius.circular(
                                      AppConstants.radiusMedium,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(
                                        AppConstants.paddingMedium,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppConstants.cardBackground,
                                        borderRadius: BorderRadius.circular(
                                          AppConstants.radiusMedium,
                                        ),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppConstants.errorRed
                                              : AppConstants.dividerColor,
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: AppConstants.errorRed
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(
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
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        expense.category,
                                                        style: AppConstants
                                                            .bodySmall
                                                            .copyWith(
                                                              color: AppConstants
                                                                  .primaryOrange,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      '• ${Formatters.formatDate(expense.date)}',
                                                      style: AppConstants
                                                          .bodySmall
                                                          .copyWith(
                                                            color: AppConstants
                                                                .textSecondary,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  expense.description,
                                                  style:
                                                      AppConstants.bodyMedium,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(
                                            width: AppConstants.paddingSmall,
                                          ),
                                          SizedBox(
                                            width: 96,
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                Formatters.formatCurrency(
                                                  expense.amount,
                                                ),
                                                style: AppConstants.bodyLarge
                                                    .copyWith(
                                                      color:
                                                          AppConstants.errorRed,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: AppConstants.paddingMedium),
                    Row(
                      children: [
                        if (!isDeleteMode)
                          ElevatedButton.icon(
                            onPressed: expenses.isEmpty
                                ? null
                                : () {
                                    setDialogState(() {
                                      isDeleteMode = true;
                                      selectedExpenseId = null;
                                    });
                                  },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete Expense'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.errorRed,
                              foregroundColor: Colors.white,
                            ),
                          )
                        else ...[
                          ElevatedButton.icon(
                            onPressed: selectedExpense == null
                                ? null
                                : () => confirmDeletion(),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Confirm Delete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.errorRed,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: AppConstants.paddingSmall),
                          OutlinedButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                isDeleteMode = false;
                                selectedExpenseId = null;
                              });
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('Cancel'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppConstants.textSecondary,
                              side: const BorderSide(
                                color: AppConstants.dividerColor,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: Text(
                            'Close',
                            style: AppConstants.bodyMedium.copyWith(
                              color: AppConstants.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
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
    final expenseService = Provider.of<ExpenseService>(context, listen: false);

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
        builder: (context, transactionSnapshot) {
          if (transactionSnapshot.hasError) {
            return _buildErrorState(
              transactionSnapshot.error?.toString() ??
                  'Failed to load sales data',
            );
          }
          if (transactionSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppConstants.primaryOrange,
              ),
            );
          }

          final transactions = _filterTransactions(
            transactionSnapshot.data ?? const <TransactionRecord>[],
          );
          final summaries = _buildSummaries(transactions);
          final totalSales = _calculateSalesTotal(transactions);
          final totalOrders = transactions.length;
          final avgOrderValue = totalOrders == 0
              ? 0.0
              : totalSales / totalOrders;

          return StreamBuilder<List<ExpenseRecord>>(
            stream: expenseService.watchExpenses(),
            builder: (context, expenseSnapshot) {
              if (expenseSnapshot.hasError) {
                return _buildErrorState(
                  'Failed to load expenses. Please try again later.',
                );
              }

              final filteredExpenses = _filterExpenses(
                expenseSnapshot.data ?? const <ExpenseRecord>[],
              );
              final totalExpenses = _calculateTotalExpenses(filteredExpenses);
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
                            filteredExpenses,
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
    List<ExpenseRecord> expenses,
  ) {
    const cardHeight = 160.0;
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
              height: cardHeight,
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
                showBadge: expenses.isNotEmpty,
                badgeValue: expenses.length,
                height: cardHeight,
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
              height: cardHeight,
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
                  onPressed: () => _showAddExpenseDialog(),
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
    double height = 160,
  }) {
    final valueText = Formatters.formatCurrency(value);

    return SizedBox(
      height: height,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: AppConstants.cardBackground,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: AppConstants.bodySmall.copyWith(
                        color: AppConstants.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      valueText,
                      style: AppConstants.bodyLarge.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
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
