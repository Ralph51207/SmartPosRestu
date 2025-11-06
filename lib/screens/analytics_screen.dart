import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/sales_data_model.dart';
import '../services/forecast_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/stat_card.dart';

/// Sales & Performance Analysis screen with AI forecasting
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  final ForecastService _forecastService = ForecastService();
  late TabController _tabController;
  List<SalesForecast> _forecasts = [];
  List<String> _insights = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAnalyticsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
              Icons.analytics,
              color: AppConstants.primaryOrange,
            ),
            const SizedBox(width: AppConstants.paddingSmall),
            const Text(
              'Analytics',
              style: AppConstants.headingMedium,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalyticsData,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportReport,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppConstants.primaryOrange,
          labelColor: AppConstants.primaryOrange,
          unselectedLabelColor: AppConstants.textSecondary,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Forecast'),
            Tab(text: 'Insights'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppConstants.primaryOrange,
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildForecastTab(),
                _buildInsightsTab(),
              ],
            ),
    );
  }

  /// Overview tab with historical data
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key metrics cards
          _buildMetricsCards(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Revenue chart
          const Text(
            'Revenue Trend (30 Days)',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildRevenueChart(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Performance comparison
          const Text(
            'Performance Comparison',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildPerformanceComparison(),
        ],
      ),
    );
  }

  /// Forecast tab with AI predictions
  Widget _buildForecastTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Forecast badge
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppConstants.primaryOrange.withOpacity(0.3),
                  AppConstants.accentOrange.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: AppConstants.primaryOrange,
                ),
                const SizedBox(width: AppConstants.paddingSmall),
                const Expanded(
                  child: Text(
                    'AI-Powered Sales Forecast',
                    style: AppConstants.headingSmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.paddingLarge),

          // Forecast chart
          const Text(
            '7-Day Revenue Forecast',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildForecastChart(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Forecast details
          const Text(
            'Daily Forecasts',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildForecastList(),
        ],
      ),
    );
  }

  /// Insights tab with AI recommendations
  Widget _buildInsightsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Insights & Recommendations',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildInsightsList(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Category analysis
          const Text(
            'Category Analysis',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildCategoryAnalysis(),
        ],
      ),
    );
  }

  /// Metrics cards
  Widget _buildMetricsCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Total Revenue',
                value: '₱45,230',
                icon: Icons.trending_up,
                color: AppConstants.successGreen,
                percentageChange: '+12.5%',
              ),
            ),
            const SizedBox(width: AppConstants.paddingMedium),
            Expanded(
              child: StatCard(
                title: 'Avg. Order Value',
                value: '₱62.40',
                icon: Icons.shopping_cart,
                color: Colors.blue,
                percentageChange: '+5.2%',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.paddingMedium),
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Total Orders',
                value: '725',
                icon: Icons.receipt,
                color: AppConstants.primaryOrange,
                percentageChange: '-3.1%',
              ),
            ),
            const SizedBox(width: AppConstants.paddingMedium),
            Expanded(
              child: StatCard(
                title: 'Customer Return',
                value: '68%',
                icon: Icons.people,
                color: AppConstants.warningYellow,
                percentageChange: '+8.3%',
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Revenue chart
  Widget _buildRevenueChart() {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.dividerColor, width: 1),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppConstants.dividerColor,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '₱${Formatters.formatCompactNumber(value)}',
                    style: AppConstants.bodySmall,
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 5,
                getTitlesWidget: (value, meta) {
                  return Text(
                    'Day ${value.toInt()}',
                    style: AppConstants.bodySmall,
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(30, (i) {
                return FlSpot(
                    i.toDouble(), 1000 + (i * 50) + (i % 3 * 200).toDouble());
              }),
              isCurved: true,
              color: AppConstants.primaryOrange,
              barWidth: 3,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppConstants.primaryOrange.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Performance comparison chart
  Widget _buildPerformanceComparison() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.dividerColor, width: 1),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const categories = [
                    'This Week',
                    'Last Week',
                    'This Month',
                    'Last Month'
                  ];
                  if (value.toInt() < categories.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        categories[value.toInt()],
                        style: AppConstants.bodySmall,
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            BarChartGroupData(x: 0, barRods: [
              BarChartRodData(
                  toY: 85, color: AppConstants.primaryOrange, width: 20)
            ]),
            BarChartGroupData(x: 1, barRods: [
              BarChartRodData(toY: 72, color: Colors.blue, width: 20)
            ]),
            BarChartGroupData(x: 2, barRods: [
              BarChartRodData(
                  toY: 90, color: AppConstants.successGreen, width: 20)
            ]),
            BarChartGroupData(x: 3, barRods: [
              BarChartRodData(
                  toY: 78, color: AppConstants.textSecondary, width: 20)
            ]),
          ],
        ),
      ),
    );
  }

  /// Forecast chart
  Widget _buildForecastChart() {
    if (_forecasts.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text('Loading forecast...'),
      );
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.dividerColor, width: 1),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    Formatters.formatCurrency(value),
                    style: AppConstants.bodySmall,
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() < _forecasts.length) {
                    return Text(
                      Formatters.formatDate(_forecasts[value.toInt()].date)
                          .split(',')[0],
                      style: AppConstants.bodySmall,
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: _forecasts
                  .asMap()
                  .entries
                  .map((e) =>
                      FlSpot(e.key.toDouble(), e.value.predictedRevenue))
                  .toList(),
              isCurved: true,
              color: AppConstants.accentOrange,
              barWidth: 3,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppConstants.accentOrange.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Forecast list
  Widget _buildForecastList() {
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.dividerColor, width: 1),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _forecasts.length,
        separatorBuilder: (context, index) =>
            Divider(color: AppConstants.dividerColor, height: 1),
        itemBuilder: (context, index) {
          final forecast = _forecasts[index];
          return ListTile(
            leading: Icon(
              Icons.calendar_today,
              color: AppConstants.primaryOrange,
            ),
            title: Text(
              Formatters.formatDate(forecast.date),
              style: AppConstants.bodyLarge,
            ),
            subtitle: Text(
              'Confidence: ${Formatters.formatPercentage(forecast.confidence * 100)}',
              style: AppConstants.bodySmall,
            ),
            trailing: Text(
              Formatters.formatCurrency(forecast.predictedRevenue),
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

  /// Insights list
  Widget _buildInsightsList() {
    if (_insights.isEmpty) {
      return const Center(child: Text('Loading insights...'));
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
              Icon(
                Icons.lightbulb,
                color: AppConstants.warningYellow,
                size: 24,
              ),
              const SizedBox(width: AppConstants.paddingMedium),
              Expanded(
                child: Text(
                  insight,
                  style: AppConstants.bodyLarge,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Category analysis
  Widget _buildCategoryAnalysis() {
    final categories = [
      {'name': 'Appetizers', 'percentage': 25.0},
      {'name': 'Main Course', 'percentage': 45.0},
      {'name': 'Desserts', 'percentage': 15.0},
      {'name': 'Beverages', 'percentage': 15.0},
    ];

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.dividerColor, width: 1),
      ),
      child: Column(
        children: categories.map((category) {
          final percentage = category['percentage'] as double;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      category['name'] as String,
                      style: AppConstants.bodyLarge,
                    ),
                    Text(
                      '${percentage.toInt()}%',
                      style: AppConstants.bodyLarge.copyWith(
                        color: AppConstants.primaryOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: AppConstants.dividerColor,
                  color: AppConstants.primaryOrange,
                  minHeight: 8,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Load analytics data
  Future<void> _loadAnalyticsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final startDate = DateTime.now();
      final endDate = startDate.add(const Duration(days: 7));

      final forecasts = await _forecastService.getSalesForecast(
        startDate: startDate,
        endDate: endDate,
      );

      final insights = await _forecastService.getSalesInsights();

      setState(() {
        _forecasts = forecasts;
        _insights = insights;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading analytics: $e'),
          backgroundColor: AppConstants.errorRed,
        ),
      );
    }
  }

  /// Export report
  void _exportReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export report feature coming soon!'),
        backgroundColor: AppConstants.primaryOrange,
      ),
    );
  }
}
