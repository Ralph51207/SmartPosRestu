import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import 'transaction_history_screen.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedPeriod = 'Daily';

  // Example sales data
  final List<Map<String, Object>> _allSales = [
    {'date': DateTime.now(), 'total': 15420.0, 'orders': 45, 'avgOrder': 342.67},
    {'date': DateTime.now().subtract(const Duration(days: 1)), 'total': 13850.0, 'orders': 38, 'avgOrder': 364.47},
    {'date': DateTime.now().subtract(const Duration(days: 2)), 'total': 16200.0, 'orders': 52, 'avgOrder': 311.54},
    {'date': DateTime.now().subtract(const Duration(days: 3)), 'total': 14670.0, 'orders': 41, 'avgOrder': 357.80},
    {'date': DateTime.now().subtract(const Duration(days: 4)), 'total': 17350.0, 'orders': 55, 'avgOrder': 315.45},
    {'date': DateTime.now().subtract(const Duration(days: 5)), 'total': 12890.0, 'orders': 36, 'avgOrder': 358.06},
    {'date': DateTime.now().subtract(const Duration(days: 6)), 'total': 18920.0, 'orders': 61, 'avgOrder': 310.16},
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

  List<Map<String, Object>> get _filteredSales {
    return _allSales.where((s) {
      final date = s['date'] as DateTime;
      return _isDateInRange(date);
    }).toList();
  }

  double get _totalSales =>
      _filteredSales.fold(0.0, (s, sale) => s + (sale['total'] as double));

  int get _totalOrders =>
      _filteredSales.fold(0, (s, sale) => s + (sale['orders'] as int));

  double get _avgOrderValue =>
      _totalOrders > 0 ? _totalSales / _totalOrders : 0.0;

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
    final sales = _filteredSales;

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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Exporting sales report...'),
                  backgroundColor: AppConstants.primaryOrange,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
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

            // Summary Cards
            Container(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              color: AppConstants.darkBackground,
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Sales',
                      Formatters.formatCurrency(_totalSales),
                      Icons.attach_money,
                      AppConstants.successGreen,
                    ),
                  ),
                  const SizedBox(width: AppConstants.paddingMedium),
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Orders',
                      _totalOrders.toString(),
                      Icons.shopping_bag,
                      AppConstants.primaryOrange,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
              child: _buildSummaryCard(
                'Average Order Value',
                Formatters.formatCurrency(_avgOrderValue),
                Icons.trending_up,
                Colors.blue,
              ),
            ),

            const SizedBox(height: AppConstants.paddingMedium),

            // Period selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
              child: Row(
                children: [
                  const Text('View: ', style: AppConstants.bodyMedium),
                  const SizedBox(width: 8),
                  _buildPeriodChip('Daily'),
                  const SizedBox(width: 8),
                  _buildPeriodChip('Weekly'),
                  const SizedBox(width: 8),
                  _buildPeriodChip('Monthly'),
                ],
              ),
            ),

            const SizedBox(height: AppConstants.paddingMedium),

            // Chart
            Container(
              height: 300,
              margin: const EdgeInsets.all(AppConstants.paddingMedium),
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              decoration: BoxDecoration(
                color: AppConstants.cardBackground,
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                border: Border.all(color: AppConstants.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sales Trend', style: AppConstants.headingSmall),
                  const SizedBox(height: AppConstants.paddingMedium),
                  Expanded(
                    child: sales.isEmpty
                        ? Center(
                            child: Text(
                              'No sales data available',
                              style: AppConstants.bodyMedium.copyWith(
                                color: AppConstants.textSecondary,
                              ),
                            ),
                          )
                        : _buildSalesChart(),
                  ),
                ],
              ),
            ),

            // Sales list
            sales.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(AppConstants.paddingLarge),
                    child: Column(
                      children: [
                        Icon(
                          Icons.bar_chart_outlined,
                          size: 64,
                          color: AppConstants.textSecondary.withOpacity(0.5),
                        ),
                        const SizedBox(height: AppConstants.paddingMedium),
                        Text(
                          'No sales found',
                          style: AppConstants.bodyMedium.copyWith(
                            color: AppConstants.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppConstants.paddingMedium),
                    itemCount: sales.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppConstants.paddingMedium),
                    itemBuilder: (context, index) {
                      final sale = sales[index];
                      final date = sale['date'] as DateTime;

                      return Container(
                        padding: const EdgeInsets.all(AppConstants.paddingMedium),
                        decoration: BoxDecoration(
                          color: AppConstants.cardBackground,
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                          border: Border.all(color: AppConstants.dividerColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  Formatters.formatDate(date),
                                  style: AppConstants.bodyLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  Formatters.formatCurrency(sale['total'] as double),
                                  style: AppConstants.bodyLarge.copyWith(
                                    color: AppConstants.successGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Divider(color: AppConstants.dividerColor),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildSaleDetail(
                                  'Orders',
                                  sale['orders'].toString(),
                                  Icons.shopping_cart,
                                ),
                                _buildSaleDetail(
                                  'Avg Order',
                                  Formatters.formatCurrency(sale['avgOrder'] as double),
                                  Icons.trending_up,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppConstants.bodySmall.copyWith(
              color: AppConstants.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppConstants.headingSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String period) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = period),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingMedium,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.primaryOrange : AppConstants.darkSecondary,
          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
          border: Border.all(
            color: isSelected ? AppConstants.primaryOrange : AppConstants.dividerColor,
          ),
        ),
        child: Text(
          period,
          style: AppConstants.bodySmall.copyWith(
            color: isSelected ? Colors.white : AppConstants.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSalesChart() {
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (_filteredSales.length - 1).toDouble(),
        minY: 0,
        maxY: _filteredSales.isEmpty
            ? 10
            : _filteredSales
                    .map((s) => s['total'] as double)
                    .reduce((a, b) => a > b ? a : b) *
                1.2,
        lineTouchData: LineTouchData(enabled: true),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppConstants.dividerColor.withOpacity(0.3),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  Formatters.formatCurrency(value),
                  style: AppConstants.bodySmall.copyWith(
                    color: AppConstants.textSecondary,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _filteredSales.length) return const Text('');
                final date = _filteredSales[index]['date'] as DateTime;
                return Text(
                  '${date.day}/${date.month}',
                  style: AppConstants.bodySmall.copyWith(
                    color: AppConstants.textSecondary,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              _filteredSales.length,
              (index) => FlSpot(
                index.toDouble(),
                _filteredSales[index]['total'] as double,
              ),
            ),
            isCurved: true,
            gradient: LinearGradient(
              colors: [AppConstants.primaryOrange, AppConstants.accentOrange],
            ),
            barWidth: 3,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppConstants.primaryOrange.withOpacity(0.3),
                  AppConstants.accentOrange.withOpacity(0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleDetail(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppConstants.primaryOrange, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppConstants.bodySmall.copyWith(
            color: AppConstants.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppConstants.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}