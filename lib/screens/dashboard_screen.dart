import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/transaction_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/stat_card.dart';

/// Sales Dashboard - Home screen with key metrics and quick stats
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TransactionService _transactionService = TransactionService();
  final NumberFormat _countFormatter = NumberFormat.decimalPattern();

  String _selectedPeriod = 'Daily';
  bool _isLoading = true;
  String? _error;

  double _totalSales = 0;
  int _totalOrders = 0;
  double _averageOrderValue = 0;
  int _customerCount = 0;

  double? _salesChangePercent;
  double? _ordersChangePercent;
  double? _aovChangePercent;
  double? _customerChangePercent;

  Map<String, _ChartSeries> _chartData = {};
  List<_DashboardInsight> _insights = const [];
  List<_TopSellingItem> _topSellingItems = const [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        backgroundColor: AppConstants.darkSecondary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            final scaffoldState = context.findAncestorStateOfType<ScaffoldState>();
            if (scaffoldState != null) {
              scaffoldState.openDrawer();
            }
          },
        ),
        title: Row(
          children: [
            Icon(
              Icons.dashboard,
              color: AppConstants.primaryOrange,
            ),
            const SizedBox(width: AppConstants.paddingSmall),
            const Text(
              'Dashboard',
              style: AppConstants.headingMedium,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Show notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              // TODO: Show profile
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppConstants.primaryOrange,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        children: const [
          SizedBox(height: 200),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        children: [
          Icon(Icons.error_outline, color: AppConstants.errorRed, size: 48),
          const SizedBox(height: AppConstants.paddingMedium),
          Text(
            _error!,
            style: AppConstants.bodyLarge,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          ElevatedButton.icon(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeSection(),
          const SizedBox(height: AppConstants.paddingLarge),
          const Text(
            'Today\'s Overview',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildMetricsGrid(),
          const SizedBox(height: AppConstants.paddingLarge),
          _buildSalesSection(),
          const SizedBox(height: AppConstants.paddingLarge),
          const Text(
            'Insights & AI Recommendations',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildAIRecommendations(),
          const SizedBox(height: AppConstants.paddingLarge),
          const Text(
            'Top Selling Items',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildTopSellingItems(),
        ],
      ),
    );
  }

  /// Welcome section with date
  Widget _buildWelcomeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConstants.primaryOrange,
            AppConstants.accentOrange,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome Back!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            Formatters.formatDate(DateTime.now()),
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  /// Metrics grid with key stats
  Widget _buildMetricsGrid() {
    final metrics = [
      _MetricData(
        title: 'Total Sales',
        value: Formatters.formatCurrency(_totalSales),
        icon: Icons.attach_money,
        color: AppConstants.successGreen,
        change: _formatDelta(_salesChangePercent),
      ),
      _MetricData(
        title: 'Total Orders',
        value: _countFormatter.format(_totalOrders),
        icon: Icons.shopping_bag,
        color: AppConstants.primaryOrange,
        change: _formatDelta(_ordersChangePercent),
      ),
      _MetricData(
        title: 'Avg. Order Value',
        value: Formatters.formatCurrency(_averageOrderValue),
        icon: Icons.trending_up,
        color: Colors.blue,
        change: _formatDelta(_aovChangePercent),
      ),
      _MetricData(
        title: 'Customer Count',
        value: _countFormatter.format(_customerCount),
        icon: Icons.people,
        color: AppConstants.warningYellow,
        change: _formatDelta(_customerChangePercent),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppConstants.paddingMedium,
      crossAxisSpacing: AppConstants.paddingMedium,
      childAspectRatio: 1.3,
      children: metrics
          .map(
            (metric) => StatCard(
              title: metric.title,
              value: metric.value,
              icon: metric.icon,
              color: metric.color,
              percentageChange: metric.change,
            ),
          )
          .toList(),
    );
  }

  /// Sales chart widget with period toggle
  Widget _buildSalesSection() {
    return Container(
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
          // Header with title and toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sales Overview',
                style: AppConstants.headingSmall,
              ),
              // Period toggle buttons
              Container(
                decoration: BoxDecoration(
                  color: AppConstants.darkSecondary,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                ),
                child: Row(
                  children: [
                    _buildPeriodButton('Daily'),
                    _buildPeriodButton('Weekly'),
                    _buildPeriodButton('Monthly'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          // Chart
          SizedBox(
            height: 250,
            child: _buildSalesChart(),
          ),
        ],
      ),
    );
  }

  /// Period toggle button
  Widget _buildPeriodButton(String period) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingSmall,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppConstants.primaryOrange
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
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

  /// Sales chart widget
  Widget _buildSalesChart() {
    final series = _chartData[_selectedPeriod];
    if (series == null || series.spots.every((spot) => spot.y == 0)) {
      return Center(
        child: Text(
          'Not enough sales data yet.',
          style: AppConstants.bodySmall.copyWith(
            color: AppConstants.textSecondary,
          ),
        ),
      );
    }

    final double maxY = series.maxY <= 0 ? 100.0 : series.maxY;
    final double interval = series.interval <= 0 ? _computeYAxisInterval(maxY) : series.interval;
    final labels = series.labels;
    final spots = series.spots;

    return LineChart(
      LineChartData(
        maxY: maxY,
        minY: 0.0,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: interval,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppConstants.dividerColor.withValues(alpha: 0.3),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: AppConstants.dividerColor.withValues(alpha: 0.3),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value == 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '₱${value.toInt()}',
                    style: AppConstants.bodySmall.copyWith(fontSize: 10),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < labels.length) {
                  return Text(
                    labels[value.toInt()],
                    style: AppConstants.bodySmall,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppConstants.primaryOrange,
            barWidth: 3,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppConstants.primaryOrange.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  /// AI Recommendations section
  Widget _buildAIRecommendations() {
    if (_insights.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: AppConstants.cardBackground,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(color: AppConstants.dividerColor),
        ),
        child: Text(
          'No insights yet. Keep logging transactions to unlock AI summaries.',
          style: AppConstants.bodySmall.copyWith(
            color: AppConstants.textSecondary,
          ),
        ),
      );
    }

    return Column(
      children: _insights.map((insight) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          decoration: BoxDecoration(
            color: AppConstants.cardBackground,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(color: AppConstants.dividerColor, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppConstants.paddingSmall),
                decoration: BoxDecoration(
                  color: insight.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                ),
                child: Icon(insight.icon, color: insight.color, size: 24),
              ),
              const SizedBox(width: AppConstants.paddingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight.title,
                      style: AppConstants.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      insight.description,
                      style: AppConstants.bodySmall.copyWith(
                        color: AppConstants.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Top selling items list
  Widget _buildTopSellingItems() {
    if (_topSellingItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: AppConstants.cardBackground,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(color: AppConstants.dividerColor, width: 1),
        ),
        child: Text(
          'No sales recorded for the selected window.',
          style: AppConstants.bodySmall.copyWith(
            color: AppConstants.textSecondary,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: AppConstants.dividerColor,
          width: 1,
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _topSellingItems.length,
        separatorBuilder: (context, index) => Divider(
          color: AppConstants.dividerColor,
          height: 1,
        ),
        itemBuilder: (context, index) {
          final item = _topSellingItems[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppConstants.primaryOrange.withValues(alpha: 0.2),
              child: Text(
                '${index + 1}',
                style: AppConstants.bodyMedium.copyWith(
                  color: AppConstants.primaryOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              item.name,
              style: AppConstants.bodyLarge,
            ),
            subtitle: Text(
              '${item.quantity} sold',
              style: AppConstants.bodySmall,
            ),
            trailing: Text(
              Formatters.formatCurrency(item.revenue),
              style: AppConstants.bodyLarge.copyWith(
                color: AppConstants.successGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }

  /// Refresh data
  Future<void> _refreshData() async {
    await _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final transactions = await _transactionService.fetchTransactions();
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final yesterdayStart = todayStart.subtract(const Duration(days: 1));
      final weekStart = todayStart.subtract(const Duration(days: 6));
      final monthStart = todayStart.subtract(const Duration(days: 27));

      final todayTxns = <TransactionRecord>[];
      final yesterdayTxns = <TransactionRecord>[];
      final weekTxns = <TransactionRecord>[];
      final monthTxns = <TransactionRecord>[];

      for (final txn in transactions) {
        final day = DateTime(txn.timestamp.year, txn.timestamp.month, txn.timestamp.day);
        if (day == todayStart) {
          todayTxns.add(txn);
        } else if (day == yesterdayStart) {
          yesterdayTxns.add(txn);
        }

        if (!day.isBefore(weekStart) && !day.isAfter(todayStart)) {
          weekTxns.add(txn);
        }

        if (!day.isBefore(monthStart) && !day.isAfter(todayStart)) {
          monthTxns.add(txn);
        }
      }

      final todaySales = _sumRevenue(todayTxns);
      final yesterdaySales = _sumRevenue(yesterdayTxns);
      final todayOrders = todayTxns.length;
      final yesterdayOrders = yesterdayTxns.length;
        final todayAov = todayOrders == 0 ? 0.0 : todaySales / todayOrders;
        final yesterdayAov =
          yesterdayOrders == 0 ? 0.0 : yesterdaySales / math.max(1, yesterdayOrders);
      final todayCustomers = _uniqueCustomers(todayTxns);
      final yesterdayCustomers = _uniqueCustomers(yesterdayTxns);

      final salesChange = _percentChange(todaySales, yesterdaySales);
      final ordersChange = _percentChange(todayOrders.toDouble(), yesterdayOrders.toDouble());
      final aovChange = _percentChange(todayAov, yesterdayAov);
      final customerChange = _percentChange(todayCustomers.toDouble(), yesterdayCustomers.toDouble());

      final chartData = <String, _ChartSeries>{
        'Daily': _buildDailySeries(todayTxns),
        'Weekly': _buildWeeklySeries(weekTxns, weekStart),
        'Monthly': _buildMonthlySeries(monthTxns, monthStart),
      };

      final topItems = _computeTopItems(weekTxns);
      final insights = _buildInsights(
        chartData['Daily'],
        topItems,
        todaySales,
        salesChange,
      );

      setState(() {
        _totalSales = todaySales;
        _totalOrders = todayOrders;
        _averageOrderValue = todayAov;
        _customerCount = todayCustomers;
        _salesChangePercent = salesChange;
        _ordersChangePercent = ordersChange;
        _aovChangePercent = aovChange;
        _customerChangePercent = customerChange;
        _chartData = chartData;
        _topSellingItems = topItems;
        _insights = insights;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load dashboard data: $e';
      });
    }
  }

  double _sumRevenue(List<TransactionRecord> records) {
    return records.fold<double>(0.0, (sum, txn) => sum + txn.saleAmount);
  }

  int _uniqueCustomers(List<TransactionRecord> records) {
    final ids = <String>{};
    for (final record in records) {
      final metaId = record.metadata?['customerId']?.toString();
      if (metaId != null && metaId.trim().isNotEmpty) {
        ids.add(metaId.trim());
      } else if (record.tableNumber.trim().isNotEmpty) {
        ids.add(record.tableNumber.trim());
      } else {
        ids.add(record.orderId);
      }
    }
    return ids.length;
  }

  _ChartSeries _buildDailySeries(List<TransactionRecord> records) {
    const bucketCount = 6;
    final bucketTotals = List<double>.filled(bucketCount, 0.0);
    const bucketSize = 24 / bucketCount;
    for (final txn in records) {
      var bucket = (txn.timestamp.hour / bucketSize).floor();
      if (bucket < 0) {
        bucket = 0;
      } else if (bucket >= bucketCount) {
        bucket = bucketCount - 1;
      }
      bucketTotals[bucket] += txn.saleAmount;
    }

    final labels = List<String>.generate(bucketCount, (index) {
      final hour = ((24 / bucketCount) * index).round() % 24;
      final label = DateFormat('ha').format(DateTime(0, 1, 1, hour));
      return label.replaceAll(':00', '');
    });

    final spots = List<FlSpot>.generate(
      bucketCount,
      (index) => FlSpot(index.toDouble(), bucketTotals[index]),
    );

    final maxValue = bucketTotals.fold<double>(0.0, (prev, value) => value > prev ? value : prev);
    final maxY = _niceCeiling(maxValue);
    return _ChartSeries(
      spots: spots,
      labels: labels,
      maxY: maxY,
      interval: _computeYAxisInterval(maxY),
    );
  }

  _ChartSeries _buildWeeklySeries(List<TransactionRecord> records, DateTime start) {
    final totals = List<double>.filled(7, 0.0);
    for (final txn in records) {
      final dayIndex = txn.timestamp.difference(start).inDays;
      if (dayIndex >= 0 && dayIndex < 7) {
        totals[dayIndex] += txn.saleAmount;
      }
    }

    final labels = List<String>.generate(7, (index) {
      final labelDate = start.add(Duration(days: index));
      return DateFormat('EEE').format(labelDate);
    });

    final spots = List<FlSpot>.generate(
      7,
      (index) => FlSpot(index.toDouble(), totals[index]),
    );

    final maxValue = totals.fold<double>(0.0, (prev, value) => value > prev ? value : prev);
    final maxY = _niceCeiling(maxValue);
    return _ChartSeries(
      spots: spots,
      labels: labels,
      maxY: maxY,
      interval: _computeYAxisInterval(maxY),
    );
  }

  _ChartSeries _buildMonthlySeries(List<TransactionRecord> records, DateTime start) {
    final totals = List<double>.filled(4, 0.0);
    for (final txn in records) {
      final dayIndex = txn.timestamp.difference(start).inDays;
      if (dayIndex >= 0 && dayIndex < 28) {
        final bucket = dayIndex ~/ 7;
        totals[bucket] += txn.saleAmount;
      }
    }

    final labels = List<String>.generate(4, (index) => 'Week ${index + 1}');
    final spots = List<FlSpot>.generate(
      4,
      (index) => FlSpot(index.toDouble(), totals[index]),
    );
    final maxValue = totals.fold<double>(0.0, (prev, value) => value > prev ? value : prev);
    final maxY = _niceCeiling(maxValue);
    return _ChartSeries(
      spots: spots,
      labels: labels,
      maxY: maxY,
      interval: _computeYAxisInterval(maxY),
    );
  }

  List<_TopSellingItem> _computeTopItems(List<TransactionRecord> records) {
    final accumulator = <String, _TopSellingItemBuilder>{};
    for (final txn in records) {
      for (final item in txn.items) {
        final builder = accumulator.putIfAbsent(
          item.name,
          () => _TopSellingItemBuilder(name: item.name),
        );
        builder.quantity += item.quantity;
        builder.revenue += item.totalPrice;
      }
    }

    final items = accumulator.values
        .map((builder) => builder.build())
        .toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    if (items.length > 5) {
      return items.sublist(0, 5);
    }
    return items;
  }

  List<_DashboardInsight> _buildInsights(
    _ChartSeries? dailySeries,
    List<_TopSellingItem> topItems,
    double totalSales,
    double? salesChange,
  ) {
    final insights = <_DashboardInsight>[];

    if (dailySeries != null && dailySeries.spots.isNotEmpty) {
      final peakIndex = dailySeries.spots
          .asMap()
          .entries
          .reduce((a, b) => a.value.y >= b.value.y ? a : b)
          .key;
      if (dailySeries.spots[peakIndex].y > 0) {
        insights.add(
          _DashboardInsight(
            icon: Icons.trending_up,
            color: AppConstants.successGreen,
            title: 'Peak Hours Alert',
            description:
                'Expect highest demand around ${dailySeries.labels[peakIndex]}. Ensure staff coverage and prep.',
          ),
        );
      }
    }

    if (topItems.isNotEmpty) {
      final highlighted = topItems.take(2).map((item) => item.name).join(', ');
      insights.add(
        _DashboardInsight(
          icon: Icons.inventory_2_outlined,
          color: AppConstants.warningYellow,
          title: 'Prep Reminder',
          description: 'Top movers today: $highlighted. Verify stock before the next rush.',
        ),
      );
    }

    final change = salesChange ?? _salesChangePercent;
    if (change != null && !change.isNaN) {
      if (change > 0) {
        insights.add(
          _DashboardInsight(
            icon: Icons.auto_graph,
            color: Colors.blue,
            title: 'Growth Momentum',
            description:
                'Sales up ${_formatDelta(change) ?? '+0%'} versus yesterday. Keep promos running to sustain growth.',
          ),
        );
      } else if (change < 0) {
        insights.add(
          _DashboardInsight(
            icon: Icons.lightbulb_outline,
            color: AppConstants.primaryOrange,
            title: 'Recovery Opportunity',
            description:
                'Sales dipped ${_formatDelta(change) ?? '0%'} today. Consider limited-time offers to boost engagement.',
          ),
        );
      }
    } else if (totalSales == 0) {
      insights.add(
        _DashboardInsight(
          icon: Icons.info_outline,
          color: AppConstants.textSecondary,
          title: 'No Transactions Yet',
          description: 'Log at least one sale to unlock personalized recommendations.',
        ),
      );
    }

    return insights;
  }

  double _niceCeiling(double value) {
    if (value <= 0) {
      return 0.0;
    }
    final log10 = math.log(value) / math.ln10;
    final magnitude = math.pow(10, log10.floor()).toDouble();
    final normalized = value / magnitude;

    double niceNormalized;
    if (normalized <= 1) {
      niceNormalized = 1;
    } else if (normalized <= 2) {
      niceNormalized = 2;
    } else if (normalized <= 5) {
      niceNormalized = 5;
    } else {
      niceNormalized = 10;
    }

    return niceNormalized * magnitude;
  }

  double _computeYAxisInterval(double maxY) {
    if (maxY <= 0) {
      return 100.0;
    }
    final target = maxY / 5;
    final magnitude = math.pow(10, (math.log(target) / math.ln10).floor()).toDouble();
    final normalized = target / magnitude;
    double niceNormalized;
    if (normalized <= 1) {
      niceNormalized = 1;
    } else if (normalized <= 2) {
      niceNormalized = 2;
    } else if (normalized <= 5) {
      niceNormalized = 5;
    } else {
      niceNormalized = 10;
    }
    final interval = niceNormalized * magnitude;
    return interval <= 0 ? 1.0 : interval;
  }

  double? _percentChange(double current, double previous) {
    if (current.isNaN || previous.isNaN) {
      return null;
    }
    if (previous.abs() < 0.0001) {
      if (current.abs() < 0.0001) {
        return 0.0;
      }
      return double.nan;
    }
    final delta = ((current - previous) / previous) * 100;
    if (delta.isNaN || delta.isInfinite) {
      return null;
    }
    return delta;
  }

  String? _formatDelta(double? percent) {
    if (percent == null) {
      return null;
    }
    if (percent.isNaN) {
      return 'New';
    }
    if (percent.abs() < 0.05) {
      return '0%';
    }
    final precision = percent.abs() >= 10 ? 0 : 1;
    final sign = percent > 0 ? '+' : '';
    return '$sign${percent.toStringAsFixed(precision)}%';
  }
}

class _ChartSeries {
  const _ChartSeries({
    required this.spots,
    required this.labels,
    required this.maxY,
    required this.interval,
  });

  final List<FlSpot> spots;
  final List<String> labels;
  final double maxY;
  final double interval;
}

class _DashboardInsight {
  const _DashboardInsight({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
}

class _TopSellingItem {
  const _TopSellingItem({
    required this.name,
    required this.quantity,
    required this.revenue,
  });

  final String name;
  final int quantity;
  final double revenue;
}

class _TopSellingItemBuilder {
  _TopSellingItemBuilder({required this.name});

  final String name;
  int quantity = 0;
  double revenue = 0;

  _TopSellingItem build() => _TopSellingItem(name: name, quantity: quantity, revenue: revenue);
}

class _MetricData {
  const _MetricData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.change,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? change;
}