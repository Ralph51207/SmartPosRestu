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
  
  // Date range filters
  String _selectedHistoricalRange = 'This Week';
  String _selectedForecastRange = '7 Days';
  
  // Comparison overlay
  bool _showComparisonOverlay = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
            icon: const Icon(Icons.compare_arrows),
            onPressed: () {
              setState(() {
                _showComparisonOverlay = true;
              });
            },
            tooltip: 'Compare Historical vs Forecast',
          ),
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
            Tab(text: 'Historical Analysis'),
            Tab(text: 'AI Forecast'),
          ],
        ),
      ),
      body: Stack(
        children: [
          _isLoading
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
                  ],
                ),
          // Comparison overlay
          if (_showComparisonOverlay) _buildComparisonOverlay(),
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
          // Date range selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Historical Analysis',
                style: AppConstants.headingSmall,
              ),
              _buildDateRangeDropdown(
                value: _selectedHistoricalRange,
                items: ['Today', 'Yesterday', 'This Week', 'Last Week', 'This Month'],
                onChanged: (value) {
                  setState(() {
                    _selectedHistoricalRange = value!;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          
          // Key metrics cards
          _buildMetricsCards(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Sales Trend Chart
          const Text(
            'Sales Trend',
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
          // AI Forecast header with date range
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Container(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: AppConstants.primaryOrange,
                          ),
                          const SizedBox(width: AppConstants.paddingSmall),
                          const Expanded(
                            child: Text(
                              'AI Forecast Results',
                              style: AppConstants.headingSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Predictions based on weather, holidays, and past trends.',
                        style: AppConstants.bodySmall.copyWith(
                          color: AppConstants.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.paddingMedium),
              _buildDateRangeDropdown(
                value: _selectedForecastRange,
                items: ['7 Days', '14 Days', '30 Days'],
                onChanged: (value) {
                  setState(() {
                    _selectedForecastRange = value!;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingLarge),

          // Forecast Summary Cards
          const Text(
            'Forecast Summary',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildForecastSummaryCards(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Weather and Holidays Calendar
          const Text(
            'Weather & Events Calendar',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildWeatherCalendar(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Forecast Trend Chart (Projected vs Actual)
          const Text(
            'Projected vs Actual Sales',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildProjectedVsActualChart(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Confidence Interval Chart
          const Text(
            'Forecast Confidence Levels',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildConfidenceChart(),
          const SizedBox(height: AppConstants.paddingLarge),

          // AI Insights (inline below charts)
          const Text(
            'AI Insights',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildInlineInsights(),
        ],
      ),
    );
  }

  /// Insights tab with AI recommendations
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
  /// Date range dropdown widget
  Widget _buildDateRangeDropdown({
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppConstants.darkSecondary,
        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
        border: Border.all(color: AppConstants.dividerColor),
      ),
      child: DropdownButton<String>(
        value: value,
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item, style: AppConstants.bodySmall),
          );
        }).toList(),
        onChanged: onChanged,
        underline: const SizedBox(),
        dropdownColor: AppConstants.darkSecondary,
        style: AppConstants.bodySmall.copyWith(color: AppConstants.textPrimary),
        icon: Icon(Icons.arrow_drop_down, color: AppConstants.textSecondary, size: 20),
      ),
    );
  }

  /// Forecast Summary Cards
  Widget _buildForecastSummaryCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Predicted Total Sales',
                '₱58,450',
                '+15.2%',
                Icons.trending_up,
                AppConstants.successGreen,
              ),
            ),
            const SizedBox(width: AppConstants.paddingMedium),
            Expanded(
              child: _buildSummaryCard(
                'Predicted Top Item',
                'Pasta Carbonara',
                '145 orders',
                Icons.restaurant,
                AppConstants.primaryOrange,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.paddingMedium),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Predicted Peak Hours',
                '12PM - 2PM',
                'Lunch Rush',
                Icons.access_time,
                Colors.blue,
              ),
            ),
            const SizedBox(width: AppConstants.paddingMedium),
            Expanded(
              child: _buildSummaryCard(
                'Recommended Action',
                'Stock Up Pasta',
                'Low inventory',
                Icons.inventory,
                AppConstants.warningYellow,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.dividerColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: AppConstants.paddingSmall),
              Expanded(
                child: Text(
                  title,
                  style: AppConstants.bodySmall.copyWith(
                    color: AppConstants.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingSmall),
          Text(
            value,
            style: AppConstants.headingMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppConstants.bodySmall.copyWith(
              color: AppConstants.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Weather and Events Calendar
  Widget _buildWeatherCalendar() {
    final days = List.generate(7, (index) => DateTime.now().add(Duration(days: index)));
    final weather = ['☀️', '⛅', '🌧️', '☀️', '⛅', '☀️', '🌤️'];
    final events = ['', '', 'Holiday', '', '', 'Weekend', 'Weekend'];

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.dividerColor, width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: days.asMap().entries.map((entry) {
              final index = entry.key;
              final day = entry.value;
              final hasEvent = events[index].isNotEmpty;
              
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasEvent 
                        ? AppConstants.primaryOrange.withOpacity(0.1)
                        : AppConstants.darkSecondary,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                    border: hasEvent 
                        ? Border.all(color: AppConstants.primaryOrange, width: 1)
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][day.weekday % 7],
                        style: AppConstants.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${day.day}',
                        style: AppConstants.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        weather[index],
                        style: const TextStyle(fontSize: 20),
                      ),
                      if (hasEvent) ...[
                        const SizedBox(height: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppConstants.primaryOrange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppConstants.primaryOrange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Holiday/Event',
                style: AppConstants.bodySmall.copyWith(
                  color: AppConstants.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Projected vs Actual Chart
  Widget _buildProjectedVsActualChart() {
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
            drawVerticalLine: true,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppConstants.dividerColor.withOpacity(0.3),
                strokeWidth: 1,
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: AppConstants.dividerColor.withOpacity(0.3),
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
                reservedSize: 50,
                interval: 2000,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '₱${(value / 1000).toStringAsFixed(0)}K',
                    style: AppConstants.bodySmall.copyWith(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                  if (value.toInt() < days.length) {
                    return Text(
                      days[value.toInt()],
                      style: AppConstants.bodySmall.copyWith(fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            // Actual Sales
            LineChartBarData(
              spots: [
                const FlSpot(0, 5200),
                const FlSpot(1, 6100),
                const FlSpot(2, 5800),
                const FlSpot(3, 7200),
                const FlSpot(4, 8100),
                const FlSpot(5, 7500),
                const FlSpot(6, 8900),
              ],
              isCurved: true,
              color: AppConstants.successGreen,
              barWidth: 3,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: false),
            ),
            // Projected Sales
            LineChartBarData(
              spots: [
                const FlSpot(0, 5000),
                const FlSpot(1, 5900),
                const FlSpot(2, 6200),
                const FlSpot(3, 7000),
                const FlSpot(4, 8300),
                const FlSpot(5, 7800),
                const FlSpot(6, 9200),
              ],
              isCurved: true,
              color: AppConstants.primaryOrange,
              barWidth: 3,
              dotData: FlDotData(show: true),
              dashArray: [5, 5], // Dashed line for projected
              belowBarData: BarAreaData(
                show: true,
                color: AppConstants.primaryOrange.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Confidence Chart
  Widget _buildConfidenceChart() {
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
                  final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                  if (value.toInt() < days.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        days[value.toInt()],
                        style: AppConstants.bodySmall,
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                interval: 25,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}%',
                    style: AppConstants.bodySmall.copyWith(fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
          ),
          barGroups: [
            BarChartGroupData(x: 0, barRods: [
              BarChartRodData(toY: 85, color: AppConstants.successGreen, width: 16)
            ]),
            BarChartGroupData(x: 1, barRods: [
              BarChartRodData(toY: 78, color: AppConstants.successGreen, width: 16)
            ]),
            BarChartGroupData(x: 2, barRods: [
              BarChartRodData(toY: 92, color: AppConstants.successGreen, width: 16)
            ]),
            BarChartGroupData(x: 3, barRods: [
              BarChartRodData(toY: 88, color: AppConstants.successGreen, width: 16)
            ]),
            BarChartGroupData(x: 4, barRods: [
              BarChartRodData(toY: 75, color: AppConstants.warningYellow, width: 16)
            ]),
            BarChartGroupData(x: 5, barRods: [
              BarChartRodData(toY: 82, color: AppConstants.successGreen, width: 16)
            ]),
            BarChartGroupData(x: 6, barRods: [
              BarChartRodData(toY: 90, color: AppConstants.successGreen, width: 16)
            ]),
          ],
        ),
      ),
    );
  }

  /// Inline AI Insights
  Widget _buildInlineInsights() {
    final insights = [
      {
        'text': 'Sales are up 12% compared to last week.',
        'icon': Icons.trending_up,
        'color': AppConstants.successGreen,
      },
      {
        'text': 'Expected 25% increase during lunch hours today.',
        'icon': Icons.lightbulb_outline,
        'color': AppConstants.primaryOrange,
      },
      {
        'text': 'Weekend sales projected to reach all-time high.',
        'icon': Icons.celebration,
        'color': AppConstants.warningYellow,
      },
      {
        'text': 'Consider promoting desserts - low stock but high demand expected.',
        'icon': Icons.recommend,
        'color': Colors.blue,
      },
    ];

    return Column(
      children: insights.map((insight) {
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (insight['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                ),
                child: Icon(
                  insight['icon'] as IconData,
                  color: insight['color'] as Color,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppConstants.paddingMedium),
              Expanded(
                child: Text(
                  insight['text'] as String,
                  style: AppConstants.bodyMedium,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Comparison Overlay Modal
  Widget _buildComparisonOverlay() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showComparisonOverlay = false;
        });
      },
      child: Container(
        color: Colors.black.withOpacity(0.6),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping the modal
            child: Container(
              margin: const EdgeInsets.all(AppConstants.paddingLarge),
              padding: const EdgeInsets.all(AppConstants.paddingLarge),
              decoration: BoxDecoration(
                color: AppConstants.darkSecondary,
                borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                border: Border.all(color: AppConstants.dividerColor, width: 1),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Historical vs Forecast',
                          style: AppConstants.headingMedium,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _showComparisonOverlay = false;
                            });
                          },
                          color: AppConstants.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.paddingLarge),
                    
                    // Comparison Table
                    _buildComparisonRow(
                      'Total Sales',
                      '₱45,230',
                      '₱58,450',
                      29.2,
                      true,
                    ),
                    const Divider(color: AppConstants.dividerColor),
                    _buildComparisonRow(
                      'Total Orders',
                      '725',
                      '890',
                      22.8,
                      true,
                    ),
                    const Divider(color: AppConstants.dividerColor),
                    _buildComparisonRow(
                      'Avg. Order Value',
                      '₱62.40',
                      '₱65.67',
                      5.2,
                      true,
                    ),
                    const Divider(color: AppConstants.dividerColor),
                    _buildComparisonRow(
                      'Customer Return Rate',
                      '68%',
                      '72%',
                      5.9,
                      true,
                    ),
                    const Divider(color: AppConstants.dividerColor),
                    _buildComparisonRow(
                      'Peak Hours',
                      '1PM - 3PM',
                      '12PM - 2PM',
                      null,
                      null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonRow(
    String label,
    String historical,
    String forecast,
    double? percentDiff,
    bool? isIncrease,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingMedium),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppConstants.bodyLarge.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Historical',
                  style: AppConstants.bodySmall.copyWith(
                    color: AppConstants.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  historical,
                  style: AppConstants.bodyLarge,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Forecast',
                  style: AppConstants.bodySmall.copyWith(
                    color: AppConstants.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  forecast,
                  style: AppConstants.bodyLarge.copyWith(
                    color: AppConstants.primaryOrange,
                  ),
                ),
              ],
            ),
          ),
          if (percentDiff != null && isIncrease != null)
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  Icon(
                    isIncrease ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isIncrease ? AppConstants.successGreen : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${percentDiff.toStringAsFixed(1)}%',
                    style: AppConstants.bodySmall.copyWith(
                      color: isIncrease ? AppConstants.successGreen : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else
            const Expanded(flex: 1, child: SizedBox()),
        ],
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
