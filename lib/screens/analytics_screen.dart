import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/analytics_calendar_model.dart';
import '../models/sales_data_model.dart';
import '../services/analytics_calendar_service.dart';
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
  final AnalyticsCalendarService _analyticsCalendarService =
      AnalyticsCalendarService();
  late TabController _tabController;
  List<SalesForecast> _forecasts = [];
  List<String> _insights = [];
  bool _isLoading = true;
  WeatherCalendarMonth? _calendarMonth;
  List<EventImpact> _eventImpacts = [];
  bool _isCalendarLoading = true;
  bool _isImpactsLoading = true;
  String? _calendarError;
  String? _impactsError;
  
  // Date range filters
  String _selectedForecastRange = '7 Days';
  
  // Date range picker
  DateTime? _startDate;
  DateTime? _endDate;
  
  // Calendar navigation
  DateTime _selectedCalendarMonth = DateTime.now();

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
            Tab(text: 'Historical'),
            Tab(text: 'AI Forecast'),
            Tab(text: 'Comparison'),
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
                _buildComparisonTab(),
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
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            decoration: BoxDecoration(
              color: AppConstants.cardBackground,
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              border: Border.all(color: AppConstants.dividerColor),
            ),
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
          const SizedBox(height: AppConstants.paddingMedium),
          
          // Key metrics cards
          _buildMetricsCards(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Sales Trend Chart
          _buildSalesTrendSection(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Category Sales Distribution
          const Text(
            'Category Sales Distribution',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildCategorySalesDistribution(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Order Channel Distribution
          const Text(
            'Order Channel Distribution',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildOrderChannelDistribution(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Top 10 Best Sellers
          const Text(
            'Top 10 Best Sellers',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildTopSellingItems(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Payment Method Distribution
          const Text(
            'Payment Method Distribution',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildPaymentMethodDistribution(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Peak Hours Heatmap
          const Text(
            'Peak Hours Analysis',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildPeakHoursHeatmap(),
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
          // AI Forecast header
          Container(
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppConstants.primaryOrange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        color: AppConstants.primaryOrange,
                        size: 20,
                      ),
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
                const SizedBox(height: AppConstants.paddingSmall),
                Text(
                  'Predictions based on weather, holidays, and past trends.',
                  style: AppConstants.bodySmall.copyWith(
                    color: AppConstants.textSecondary,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                // Forecast Range Toggle
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppConstants.darkSecondary,
                      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                      border: Border.all(color: AppConstants.dividerColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildForecastRangeButton('7 Days'),
                        _buildForecastRangeButton('14 Days'),
                        _buildForecastRangeButton('30 Days'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.paddingLarge),

          // Forecast Accuracy Metrics
          _buildForecastAccuracyCard(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Forecast Summary Cards
          const Text(
            'Forecast Summary',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildForecastSummaryCards(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Forecast Trend Chart (Projected vs Actual)
          const Text(
            'Projected vs Actual Sales',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildProjectedVsActualChart(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Weather and Holidays Calendar
          const Text(
            'Weather & Events Calendar',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildWeatherCalendar(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Event and Weather Impact Analysis
          const Text(
            'Event & Weather Impact Analysis',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildEventWeatherImpact(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Demand Forecasting by Category
          const Text(
            'Demand Forecasting by Category',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildCategoryDemandForecast(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Delivery vs Dine-In Forecast
          const Text(
            'Order Channel Forecast',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildOrderChannelForecast(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Menu Item Performance Predictions
          const Text(
            'Menu Item Performance Predictions',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildMenuItemPredictions(),
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
                title: 'Total Orders',
                value: '725',
                icon: Icons.receipt,
                color: AppConstants.primaryOrange,
                percentageChange: '-3.1%',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.paddingMedium),
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Avg. Order Value',
                value: '₱62.40',
                icon: Icons.shopping_cart,
                color: Colors.blue,
                percentageChange: '+5.2%',
              ),
            ),
            const SizedBox(width: AppConstants.paddingMedium),
            Expanded(
              child: StatCard(
                title: 'Peak Hour Revenue',
                value: '₱18,500',
                icon: Icons.access_time,
                color: AppConstants.warningYellow,
                percentageChange: '12-2PM',
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Forecast Range toggle button
  Widget _buildForecastRangeButton(String range) {
    final isSelected = _selectedForecastRange == range;
    return GestureDetector(
      onTap: () async {
        if (_selectedForecastRange == range) {
          return;
        }
        setState(() {
          _selectedForecastRange = range;
        });
        final nowMonth = DateTime.now();
        try {
          await _reloadCalendarForMonth(
            DateTime(nowMonth.year, nowMonth.month, 1),
          );
        } catch (e) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to refresh calendar: $e'),
              backgroundColor: AppConstants.errorRed,
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppConstants.primaryOrange
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
        ),
        child: Text(
          range,
          style: AppConstants.bodySmall.copyWith(
            color: isSelected ? Colors.white : AppConstants.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<void> _reloadCalendarForMonth(DateTime month) async {
    setState(() {
      _selectedCalendarMonth = month;
      _isCalendarLoading = true;
      _isImpactsLoading = true;
      _calendarError = null;
      _impactsError = null;
    });

    try {
      final monthStart = DateTime(month.year, month.month, 1);
      final monthEnd = DateTime(month.year, month.month + 1, 0);

      final calendar = await _analyticsCalendarService.fetchMonth(
        month,
        fallbackRangeDays: _selectedRangeInDays(),
      );
      final impacts = await _analyticsCalendarService.fetchImpacts(
        start: monthStart,
        end: monthEnd,
        fallbackRangeDays: _selectedRangeInDays(),
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _calendarMonth = calendar;
        _eventImpacts = impacts;
        _isCalendarLoading = false;
        _isImpactsLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCalendarLoading = false;
        _isImpactsLoading = false;
        _calendarError = e.toString();
        _impactsError = e.toString();
      });
      rethrow;
    }
  }

  Future<void> _changeCalendarMonth(int offset) async {
    final newMonth = DateTime(
      _selectedCalendarMonth.year,
      _selectedCalendarMonth.month + offset,
      1,
    );
    try {
      await _reloadCalendarForMonth(newMonth);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load calendar data: $e'),
          backgroundColor: AppConstants.errorRed,
        ),
      );
    }
  }

  /// Sales Trend Section
  Widget _buildSalesTrendSection() {
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
          // Header
          const Text(
            'Sales Trend',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          // Chart
          SizedBox(
            height: 250,
            child: _buildSalesTrendChart(),
          ),
        ],
      ),
    );
  }

  /// Sales Trend Chart
  Widget _buildSalesTrendChart() {
    // Sample data for chart - will be replaced with actual date range data
    final spots = [
      const FlSpot(0, 8500),
      const FlSpot(1, 10200),
      const FlSpot(2, 9800),
      const FlSpot(3, 12500),
      const FlSpot(4, 15200),
      const FlSpot(5, 14800),
      const FlSpot(6, 16500),
    ];
    final labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const interval = 2000.0;
    const maxY = 18000.0;

    return LineChart(
      LineChartData(
        maxY: maxY,
        minY: 0,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppConstants.darkSecondary.withOpacity(0.95),
            tooltipRoundedRadius: AppConstants.radiusSmall,
            tooltipPadding: const EdgeInsets.all(8),
            tooltipBorder: BorderSide(color: AppConstants.primaryOrange, width: 1),
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((spot) {
                final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                return LineTooltipItem(
                  '${days[spot.x.toInt()]}\n',
                  AppConstants.bodySmall.copyWith(
                    color: AppConstants.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: 'Sales: ',
                      style: AppConstants.bodySmall.copyWith(
                        color: AppConstants.primaryOrange,
                      ),
                    ),
                    TextSpan(
                      text: '₱${(spot.y / 1000).toStringAsFixed(1)}K',
                      style: AppConstants.bodySmall.copyWith(
                        color: AppConstants.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: interval,
          verticalInterval: 1,
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
                    '₱${(value / 1000).toStringAsFixed(0)}K',
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
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppConstants.primaryOrange,
            barWidth: 3,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppConstants.primaryOrange.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  /// Forecast Summary Cards
  Widget _buildForecastSummaryCards() {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Predicted Revenue',
                  '₱58,450',
                  '+29.2% vs Historical',
                  Icons.trending_up,
                  AppConstants.successGreen,
                ),
              ),
              const SizedBox(width: AppConstants.paddingMedium),
              Expanded(
                child: _buildSummaryCard(
                  'Predicted Orders',
                  '890',
                  '+22.8% vs Historical',
                  Icons.receipt,
                  AppConstants.primaryOrange,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.paddingMedium),
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Predicted Avg. Order',
                  '₱65.67',
                  '+5.2% vs Historical',
                  Icons.shopping_cart,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: AppConstants.paddingMedium),
              Expanded(
                child: _buildSummaryCard(
                  'Recommended Action',
                  'Stock Up Pasta',
                  'Top predicted item',
                  Icons.inventory,
                  AppConstants.warningYellow,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      height: double.infinity,
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
    final firstDayOfMonth = DateTime(
      _selectedCalendarMonth.year,
      _selectedCalendarMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _selectedCalendarMonth.year,
      _selectedCalendarMonth.month + 1,
      0,
    );
    final daysInMonth = lastDayOfMonth.day;
    final startingWeekday = firstDayOfMonth.weekday % 7;
    final now = DateTime.now();

    Widget buildCalendarBody() {
      if (_isCalendarLoading) {
        return SizedBox(
          height: 260,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppConstants.primaryOrange),
                const SizedBox(height: AppConstants.paddingSmall),
                const Text(
                  'Loading calendar...',
                  style: AppConstants.bodySmall,
                ),
              ],
            ),
          ),
        );
      }

      if (_calendarError != null) {
        return SizedBox(
          height: 260,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: AppConstants.errorRed),
                const SizedBox(height: AppConstants.paddingSmall),
                Text(
                  _calendarError!,
                  style: AppConstants.bodySmall.copyWith(
                    color: AppConstants.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.paddingSmall),
                ElevatedButton.icon(
                  onPressed: () => _changeCalendarMonth(0),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryOrange,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final hasRangeOverlap =
          _monthOverlapsForecastRange(_selectedCalendarMonth);
      final calendar = _calendarMonth ?? WeatherCalendarMonth(
        month: _selectedCalendarMonth,
        days: const [],
      );

      if (calendar.isEmpty && hasRangeOverlap) {
        return SizedBox(
          height: 260,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, color: AppConstants.textSecondary),
                const SizedBox(height: AppConstants.paddingSmall),
                const Text(
                  'No calendar data for this month yet.',
                  style: AppConstants.bodySmall,
                ),
                const SizedBox(height: AppConstants.paddingSmall),
                Text(
                  'Add documents under analytics_calendar/<yyyy-MM> in Firestore to populate this view.',
                  style: AppConstants.bodySmall.copyWith(
                    color: AppConstants.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }

      return Column(
        children: List.generate((daysInMonth + startingWeekday) ~/ 7 + 1, (weekIndex) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: List.generate(7, (dayIndex) {
                final dayNumber = weekIndex * 7 + dayIndex - startingWeekday + 1;

                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 70));
                }

                final currentDate = DateTime(
                  _selectedCalendarMonth.year,
                  _selectedCalendarMonth.month,
                  dayNumber,
                );
                final isToday = currentDate.year == now.year &&
                    currentDate.month == now.month &&
                    currentDate.day == now.day;
                final isInForecastRange =
                  _isWithinSelectedForecastRange(currentDate);
                final weatherDay = isInForecastRange
                  ? calendar.dayForNumber(dayNumber)
                  : null;
                final hasEvent = weatherDay?.hasEvent ?? false;
                final hasWeather = weatherDay != null;

                final backgroundColor = isToday
                    ? AppConstants.primaryOrange.withOpacity(0.2)
                    : hasEvent
                        ? AppConstants.primaryOrange.withOpacity(0.12)
                        : isInForecastRange
                            ? AppConstants.successGreen.withOpacity(0.08)
                            : AppConstants.darkSecondary.withOpacity(0.5);

                final borderColor = isToday
                    ? AppConstants.primaryOrange
                    : hasEvent
                        ? AppConstants.primaryOrange
                        : isInForecastRange
                            ? AppConstants.successGreen.withOpacity(0.6)
                            : AppConstants.dividerColor.withOpacity(0.3);

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: borderColor,
                        width: isToday ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$dayNumber',
                          style: AppConstants.bodyMedium.copyWith(
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday
                                ? AppConstants.primaryOrange
                                : AppConstants.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        hasWeather && isInForecastRange
                            ? Text(
                                weatherDay?.emoji ?? '–',
                                style: const TextStyle(fontSize: 16),
                              )
                            : const SizedBox(height: 16),
                        const SizedBox(height: 2),
                        hasEvent && isInForecastRange
                            ? Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppConstants.primaryOrange,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : const SizedBox(height: 6),
                      ],
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      );
    }

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: AppConstants.primaryOrange),
                onPressed: () => _changeCalendarMonth(-1),
                tooltip: 'Previous Month',
              ),
              Text(
                '${_getMonthName(_selectedCalendarMonth.month)} ${_selectedCalendarMonth.year}',
                style: AppConstants.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: AppConstants.primaryOrange),
                onPressed: () => _changeCalendarMonth(1),
                tooltip: 'Next Month',
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingSmall),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppConstants.successGreen.withOpacity(0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppConstants.successGreen,
                        width: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Forecast Range ($_selectedForecastRange)',
                    style: AppConstants.bodySmall.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
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
          const SizedBox(height: AppConstants.paddingMedium),
          Row(
            children: ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'].map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: AppConstants.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          buildCalendarBody(),
        ],
      ),
    );
  }

  /// Helper method to get month name
  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  /// Event and Weather Impact Analysis
  Widget _buildEventWeatherImpact() {
    if (_isImpactsLoading) {
      return Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: AppConstants.cardBackground,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(color: AppConstants.dividerColor, width: 1),
        ),
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppConstants.primaryOrange),
              const SizedBox(height: AppConstants.paddingSmall),
              const Text('Loading event impacts...', style: AppConstants.bodySmall),
            ],
          ),
        ),
      );
    }

    if (_impactsError != null) {
      return Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: AppConstants.cardBackground,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(color: AppConstants.dividerColor, width: 1),
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: AppConstants.errorRed),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              _impactsError!,
              style: AppConstants.bodySmall.copyWith(
                color: AppConstants.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            ElevatedButton.icon(
              onPressed: () => _changeCalendarMonth(0),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryOrange,
              ),
            ),
          ],
        ),
      );
    }

    if (_eventImpacts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: AppConstants.cardBackground,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(color: AppConstants.dividerColor, width: 1),
        ),
        child: Column(
          children: [
            Icon(Icons.event_note, color: AppConstants.textSecondary),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              'No upcoming events found for this month.',
              style: AppConstants.bodySmall.copyWith(
                color: AppConstants.textSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              'Add records in analytics_impacts with a date inside this month to see projections here.',
              style: AppConstants.bodySmall.copyWith(
                color: AppConstants.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.dividerColor, width: 1),
      ),
      child: Column(
        children: _eventImpacts.map((impact) {
          final color = _eventImpactColor(impact);
          final impactPercent = _formatImpactPercent(impact.impactPercent);
          final expectedSales = impact.expectedSales;

          return Container(
            margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            decoration: BoxDecoration(
              color: AppConstants.darkSecondary,
              borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatImpactDate(impact.date),
                            style: AppConstants.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppConstants.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                impact.emoji,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _buildImpactHeadline(impact),
                                  style: AppConstants.bodySmall.copyWith(
                                    color: AppConstants.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            impactPercent,
                            style: AppConstants.bodySmall.copyWith(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          expectedSales != null
                              ? Formatters.formatCurrency(expectedSales)
                              : '—',
                          style: AppConstants.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.paddingSmall),
                if ((impact.recommendation ?? '').isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppConstants.paddingSmall),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: color,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            impact.recommendation!,
                            style: AppConstants.bodySmall.copyWith(
                              color: AppConstants.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Demand Forecasting by Category
  Widget _buildCategoryDemandForecast() {
    final categories = [
      {
        'name': 'Main Course',
        'predicted': 340,
        'historical': 280,
        'change': '+21%',
        'isIncrease': true,
        'color': AppConstants.primaryOrange,
        'icon': Icons.restaurant,
      },
      {
        'name': 'Beverages',
        'predicted': 210,
        'historical': 178,
        'change': '+18%',
        'isIncrease': true,
        'color': Colors.blue,
        'icon': Icons.local_cafe,
      },
      {
        'name': 'Appetizers',
        'predicted': 120,
        'historical': 105,
        'change': '+14%',
        'isIncrease': true,
        'color': AppConstants.successGreen,
        'icon': Icons.fastfood,
      },
      {
        'name': 'Desserts',
        'predicted': 85,
        'historical': 78,
        'change': '+9%',
        'isIncrease': true,
        'color': Colors.pink,
        'icon': Icons.cake,
      },
      {
        'name': 'Sides',
        'predicted': 65,
        'historical': 72,
        'change': '-10%',
        'isIncrease': false,
        'color': AppConstants.warningYellow,
        'icon': Icons.food_bank,
      },
    ];

    final maxValue = 340;

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.dividerColor, width: 1),
      ),
      child: Column(
        children: [
          ...categories.map((category) {
            final percentage = (category['predicted'] as int) / maxValue;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (category['color'] as Color).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          category['icon'] as IconData,
                          color: category['color'] as Color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppConstants.paddingSmall),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category['name'] as String,
                              style: AppConstants.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Historical: ${category['historical']} orders',
                              style: AppConstants.bodySmall.copyWith(
                                color: AppConstants.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${category['predicted']} orders',
                            style: AppConstants.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: category['color'] as Color,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (category['isIncrease'] as bool
                                  ? AppConstants.successGreen
                                  : AppConstants.errorRed)
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  category['isIncrease'] as bool
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  size: 12,
                                  color: category['isIncrease'] as bool
                                      ? AppConstants.successGreen
                                      : AppConstants.errorRed,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  category['change'] as String,
                                  style: AppConstants.bodySmall.copyWith(
                                    color: category['isIncrease'] as bool
                                        ? AppConstants.successGreen
                                        : AppConstants.errorRed,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      minHeight: 8,
                      backgroundColor: AppConstants.dividerColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        category['color'] as Color,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  /// Order Channel Forecast (Delivery vs Dine-In)
  Widget _buildOrderChannelForecast() {
    final channels = [
      {
        'name': 'Dine-In',
        'percentage': 65,
        'orders': 540,
        'revenue': '₱33,800',
        'historical': '470 orders',
        'trend': '+15%',
        'color': AppConstants.primaryOrange,
        'icon': Icons.restaurant_menu,
        'peak': 'Sat-Sun Lunch & Dinner',
      },
      {
        'name': 'Takeout',
        'percentage': 25,
        'orders': 208,
        'revenue': '₱13,000',
        'historical': '181 orders',
        'trend': '+15%',
        'color': Colors.blue,
        'icon': Icons.shopping_bag,
        'peak': 'Weekday Lunch',
      },
      {
        'name': 'Delivery',
        'percentage': 10,
        'orders': 83,
        'revenue': '₱5,200',
        'historical': '74 orders',
        'trend': '+12%',
        'color': AppConstants.successGreen,
        'icon': Icons.delivery_dining,
        'peak': 'Rainy Days, Late Night',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.dividerColor, width: 1),
      ),
      child: Column(
        children: [
          // Visual percentage bar
          Row(
            children: channels.map((channel) {
              final isFirst = channel == channels.first;
              final isLast = channel == channels.last;
              
              return Expanded(
                flex: channel['percentage'] as int,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: channel['color'] as Color,
                    borderRadius: BorderRadius.only(
                      topLeft: isFirst ? const Radius.circular(8) : Radius.zero,
                      bottomLeft: isFirst ? const Radius.circular(8) : Radius.zero,
                      topRight: isLast ? const Radius.circular(8) : Radius.zero,
                      bottomRight: isLast ? const Radius.circular(8) : Radius.zero,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${channel['percentage']}%',
                      style: AppConstants.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppConstants.paddingLarge),
          
          // Channel details
          ...channels.map((channel) {
            return Container(
              margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              decoration: BoxDecoration(
                color: AppConstants.darkSecondary,
                borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                border: Border.all(
                  color: (channel['color'] as Color).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (channel['color'] as Color).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      channel['icon'] as IconData,
                      color: channel['color'] as Color,
                      size: 24,
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
                              channel['name'] as String,
                              style: AppConstants.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppConstants.successGreen.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                channel['trend'] as String,
                                style: AppConstants.bodySmall.copyWith(
                                  color: AppConstants.successGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Predicted: ${channel['orders']} orders • ${channel['revenue']}',
                          style: AppConstants.bodyMedium.copyWith(
                            color: AppConstants.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Historical: ${channel['historical']}',
                          style: AppConstants.bodySmall.copyWith(
                            color: AppConstants.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: AppConstants.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Peak: ${channel['peak']}',
                              style: AppConstants.bodySmall.copyWith(
                                color: AppConstants.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  /// Menu Item Performance Predictions
  Widget _buildMenuItemPredictions() {
    final items = [
      {
        'category': 'Star Performers',
        'description': 'High demand expected',
        'color': AppConstants.successGreen,
        'items': [
          {'name': 'Pasta Carbonara', 'orders': 145, 'trend': '+22%'},
          {'name': 'Grilled Salmon', 'orders': 98, 'trend': '+18%'},
          {'name': 'Crispy Chicken', 'orders': 87, 'trend': '+15%'},
        ],
      },
      {
        'category': 'Rising Stars',
        'description': 'Growing popularity',
        'color': AppConstants.primaryOrange,
        'items': [
          {'name': 'Vegan Bowl', 'orders': 52, 'trend': '+35%'},
          {'name': 'Matcha Latte', 'orders': 48, 'trend': '+28%'},
          {'name': 'Korean BBQ', 'orders': 41, 'trend': '+25%'},
        ],
      },
      {
        'category': 'Declining Items',
        'description': 'Consider promotion or removal',
        'color': AppConstants.warningYellow,
        'items': [
          {'name': 'Fish & Chips', 'orders': 32, 'trend': '-15%'},
          {'name': 'Minestrone Soup', 'orders': 28, 'trend': '-20%'},
          {'name': 'Caesar Wrap', 'orders': 24, 'trend': '-12%'},
        ],
      },
    ];

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.dividerColor, width: 1),
      ),
      child: Column(
        children: items.map((group) {
          return Container(
            margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: group['color'] as Color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group['category'] as String,
                            style: AppConstants.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: group['color'] as Color,
                            ),
                          ),
                          Text(
                            group['description'] as String,
                            style: AppConstants.bodySmall.copyWith(
                              color: AppConstants.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.paddingSmall),
                ...(group['items'] as List).map((item) {
                  final itemMap = item as Map<String, dynamic>;
                  final isNegative = (itemMap['trend'] as String).startsWith('-');
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(AppConstants.paddingSmall),
                    decoration: BoxDecoration(
                      color: AppConstants.darkSecondary,
                      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isNegative ? Icons.trending_down : Icons.trending_up,
                          color: group['color'] as Color,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            itemMap['name'] as String,
                            style: AppConstants.bodyMedium,
                          ),
                        ),
                        Text(
                          '${itemMap['orders']} orders',
                          style: AppConstants.bodySmall.copyWith(
                            color: AppConstants.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (group['color'] as Color).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            itemMap['trend'] as String,
                            style: AppConstants.bodySmall.copyWith(
                              color: group['color'] as Color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        }).toList(),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppConstants.successGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Actual Sales',
                    style: AppConstants.bodySmall.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppConstants.primaryOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Projected Sales',
                    style: AppConstants.bodySmall.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingSmall),
          Expanded(
            child: LineChart(
              LineChartData(
                maxY: 18000,
                minY: 0,
                // Interactive tooltips for forecast chart
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppConstants.darkSecondary.withOpacity(0.95),
                    tooltipRoundedRadius: AppConstants.radiusSmall,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipBorder: BorderSide(color: AppConstants.primaryOrange, width: 1),
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((spot) {
                        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        final isActual = spot.barIndex == 0;
                        return LineTooltipItem(
                          '${days[spot.x.toInt()]}\n',
                          AppConstants.bodySmall.copyWith(
                            color: AppConstants.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            TextSpan(
                              text: '${isActual ? "Actual" : "Projected"}: ',
                              style: AppConstants.bodySmall.copyWith(
                                color: isActual ? AppConstants.successGreen : AppConstants.primaryOrange,
                              ),
                            ),
                            TextSpan(
                              text: '₱${(spot.y / 1000).toStringAsFixed(1)}K',
                              style: AppConstants.bodySmall.copyWith(
                                color: AppConstants.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                ),
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
                  // Actual Sales - mirroring Historical Sales Trend
                  LineChartBarData(
                    spots: [
                      const FlSpot(0, 8500),
                      const FlSpot(1, 10200),
                      const FlSpot(2, 9800),
                      const FlSpot(3, 12500),
                      const FlSpot(4, 15200),
                      const FlSpot(5, 14800),
                      const FlSpot(6, 16500),
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
                      const FlSpot(0, 8200),
                      const FlSpot(1, 9900),
                      const FlSpot(2, 10500),
                      const FlSpot(3, 12200),
                      const FlSpot(4, 15600),
                      const FlSpot(5, 15200),
                      const FlSpot(6, 17200),
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
          ),
        ],
      ),
    );
  }

  /// Forecast Accuracy Card
  Widget _buildForecastAccuracyCard() {
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
              Icon(Icons.verified, color: AppConstants.successGreen, size: 20),
              const SizedBox(width: AppConstants.paddingSmall),
              const Text(
                'Forecast Accuracy Metrics',
                style: AppConstants.headingSmall,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Accuracy',
                      style: AppConstants.bodySmall.copyWith(
                        color: AppConstants.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '87.3%',
                          style: AppConstants.headingMedium.copyWith(
                            color: AppConstants.successGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppConstants.successGreen.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '+2.1%',
                            style: AppConstants.bodySmall.copyWith(
                              color: AppConstants.successGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: 0.873,
                      backgroundColor: AppConstants.dividerColor,
                      valueColor: AlwaysStoppedAnimation<Color>(AppConstants.successGreen),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.paddingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last 7 Days',
                      style: AppConstants.bodySmall.copyWith(
                        color: AppConstants.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '92.1%',
                      style: AppConstants.headingMedium.copyWith(
                        color: AppConstants.successGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: 0.921,
                      backgroundColor: AppConstants.dividerColor,
                      valueColor: AlwaysStoppedAnimation<Color>(AppConstants.successGreen),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          Divider(color: AppConstants.dividerColor),
          const SizedBox(height: AppConstants.paddingSmall),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAccuracyMetric('Sales', '89%', AppConstants.primaryOrange),
              _buildAccuracyMetric('Traffic', '91%', Colors.blue),
              _buildAccuracyMetric('Peak Hours', '85%', AppConstants.warningYellow),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccuracyMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: AppConstants.bodyLarge.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppConstants.bodySmall.copyWith(
            color: AppConstants.textSecondary,
          ),
        ),
      ],
    );
  }

  /// Category Sales Distribution (Historical)
  Widget _buildCategorySalesDistribution() {
    final categories = [
      {
        'name': 'Main Course',
        'actual': 280,
        'revenue': '₱17,500',
        'color': AppConstants.primaryOrange,
        'icon': Icons.restaurant,
      },
      {
        'name': 'Beverages',
        'actual': 178,
        'revenue': '₱8,900',
        'color': Colors.blue,
        'icon': Icons.local_cafe,
      },
      {
        'name': 'Appetizers',
        'actual': 105,
        'revenue': '₱5,250',
        'color': AppConstants.successGreen,
        'icon': Icons.fastfood,
      },
      {
        'name': 'Desserts',
        'actual': 78,
        'revenue': '₱3,900',
        'color': Colors.pink,
        'icon': Icons.cake,
      },
      {
        'name': 'Sides',
        'actual': 72,
        'revenue': '₱2,880',
        'color': AppConstants.warningYellow,
        'icon': Icons.food_bank,
      },
    ];

    final maxValue = 280;

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.dividerColor, width: 1),
      ),
      child: Column(
        children: [
          ...categories.map((category) {
            final percentage = (category['actual'] as int) / maxValue;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (category['color'] as Color).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          category['icon'] as IconData,
                          color: category['color'] as Color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppConstants.paddingSmall),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category['name'] as String,
                              style: AppConstants.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              category['revenue'] as String,
                              style: AppConstants.bodySmall.copyWith(
                                color: AppConstants.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${category['actual']} orders',
                        style: AppConstants.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: category['color'] as Color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      minHeight: 8,
                      backgroundColor: AppConstants.dividerColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        category['color'] as Color,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  /// Order Channel Distribution (Historical)
  Widget _buildOrderChannelDistribution() {
    final channels = [
      {
        'name': 'Dine-In',
        'percentage': 65,
        'orders': 470,
        'revenue': '₱29,400',
        'color': AppConstants.primaryOrange,
        'icon': Icons.restaurant_menu,
        'peak': 'Sat-Sun Lunch & Dinner',
      },
      {
        'name': 'Takeout',
        'percentage': 25,
        'orders': 181,
        'revenue': '₱11,300',
        'color': Colors.blue,
        'icon': Icons.shopping_bag,
        'peak': 'Weekday Lunch',
      },
      {
        'name': 'Delivery',
        'percentage': 10,
        'orders': 74,
        'revenue': '₱4,530',
        'color': AppConstants.successGreen,
        'icon': Icons.delivery_dining,
        'peak': 'Rainy Days, Late Night',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.dividerColor, width: 1),
      ),
      child: Column(
        children: [
          // Visual percentage bar
          Row(
            children: channels.map((channel) {
              final isFirst = channel == channels.first;
              final isLast = channel == channels.last;
              
              return Expanded(
                flex: channel['percentage'] as int,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: channel['color'] as Color,
                    borderRadius: BorderRadius.only(
                      topLeft: isFirst ? const Radius.circular(8) : Radius.zero,
                      bottomLeft: isFirst ? const Radius.circular(8) : Radius.zero,
                      topRight: isLast ? const Radius.circular(8) : Radius.zero,
                      bottomRight: isLast ? const Radius.circular(8) : Radius.zero,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${channel['percentage']}%',
                      style: AppConstants.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppConstants.paddingLarge),
          
          // Channel details
          ...channels.map((channel) {
            return Container(
              margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              decoration: BoxDecoration(
                color: AppConstants.darkSecondary,
                borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                border: Border.all(
                  color: (channel['color'] as Color).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (channel['color'] as Color).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      channel['icon'] as IconData,
                      color: channel['color'] as Color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppConstants.paddingMedium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          channel['name'] as String,
                          style: AppConstants.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${channel['orders']} orders • ${channel['revenue']}',
                          style: AppConstants.bodyMedium.copyWith(
                            color: AppConstants.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: AppConstants.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Peak: ${channel['peak']}',
                              style: AppConstants.bodySmall.copyWith(
                                color: AppConstants.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  /// Top Selling Items
  Widget _buildTopSellingItems() {
    final topItems = [
      {'name': 'Pasta Carbonara', 'sold': 245, 'revenue': 12250.0},
      {'name': 'Grilled Chicken', 'sold': 198, 'revenue': 11880.0},
      {'name': 'Caesar Salad', 'sold': 176, 'revenue': 7040.0},
      {'name': 'Margherita Pizza', 'sold': 165, 'revenue': 9900.0},
      {'name': 'Fish & Chips', 'sold': 142, 'revenue': 8520.0},
      {'name': 'Beef Steak', 'sold': 128, 'revenue': 10240.0},
      {'name': 'Vegetable Soup', 'sold': 115, 'revenue': 3450.0},
      {'name': 'Fried Rice', 'sold': 108, 'revenue': 3240.0},
      {'name': 'Chocolate Cake', 'sold': 95, 'revenue': 3800.0},
      {'name': 'Iced Coffee', 'sold': 87, 'revenue': 2610.0},
    ];

    final maxSold = topItems[0]['sold'] as int;

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.dividerColor, width: 1),
      ),
      child: Column(
        children: [
          // Header Row
          Row(
            children: [
              const Expanded(
                flex: 3,
                child: Text(
                  'Item',
                  style: AppConstants.bodySmall,
                ),
              ),
              const Expanded(
                flex: 2,
                child: Text(
                  'Qty Sold',
                  style: AppConstants.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const Expanded(
                flex: 2,
                child: Text(
                  'Revenue',
                  style: AppConstants.bodySmall,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const Divider(color: AppConstants.dividerColor),
          // Items List
          ...topItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final name = item['name'] as String;
            final sold = item['sold'] as int;
            final revenue = item['revenue'] as double;
            final percentage = (sold / maxSold);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Rank
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: index < 3
                              ? AppConstants.primaryOrange.withOpacity(0.2)
                              : AppConstants.darkSecondary,
                          borderRadius: BorderRadius.circular(12),
                          border: index < 3
                              ? Border.all(color: AppConstants.primaryOrange, width: 1)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: AppConstants.bodySmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: index < 3
                                  ? AppConstants.primaryOrange
                                  : AppConstants.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Item Name
                      Expanded(
                        flex: 3,
                        child: Text(
                          name,
                          style: AppConstants.bodyMedium.copyWith(
                            fontWeight: index < 3 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      // Quantity
                      Expanded(
                        flex: 2,
                        child: Text(
                          '$sold',
                          style: AppConstants.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Revenue
                      Expanded(
                        flex: 2,
                        child: Text(
                          Formatters.formatCurrency(revenue),
                          style: AppConstants.bodyMedium.copyWith(
                            color: AppConstants.successGreen,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Progress Bar
                  LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: AppConstants.dividerColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      index < 3 ? AppConstants.primaryOrange : AppConstants.successGreen,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  /// Payment Method Distribution
  Widget _buildPaymentMethodDistribution() {
    final paymentData = [
      {'method': 'Cash', 'amount': 20353.5, 'count': 425, 'color': AppConstants.successGreen},
      {'method': 'Card', 'amount': 15830.75, 'count': 215, 'color': Colors.blue},
      {'method': 'GCash', 'amount': 6784.25, 'count': 65, 'color': AppConstants.primaryOrange},
      {'method': 'Maya', 'amount': 2261.5, 'count': 20, 'color': AppConstants.warningYellow},
    ];

    final total = paymentData.fold(0.0, (sum, item) => sum + (item['amount'] as double));

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.dividerColor, width: 1),
      ),
      child: Column(
        children: [
          // Pie chart representation using stacked bars
          Row(
            children: paymentData.map((data) {
              final amount = data['amount'] as double;
              final percentage = (amount / total);
              final isFirst = data == paymentData.first;
              final isLast = data == paymentData.last;
              
              return Expanded(
                flex: (percentage * 100).toInt(),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: data['color'] as Color,
                    borderRadius: isFirst
                        ? const BorderRadius.horizontal(left: Radius.circular(8))
                        : isLast
                            ? const BorderRadius.horizontal(right: Radius.circular(8))
                            : null,
                  ),
                  child: Center(
                    child: Text(
                      '${(percentage * 100).toStringAsFixed(0)}%',
                      style: AppConstants.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppConstants.paddingLarge),
          // Payment details
          ...paymentData.map((data) {
            final amount = data['amount'] as double;
            final percentage = (amount / total * 100);
            return Padding(
              padding: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: data['color'] as Color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data['method'] as String,
                      style: AppConstants.bodyMedium,
                    ),
                  ),
                  Text(
                    '${data['count']} orders',
                    style: AppConstants.bodySmall.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppConstants.paddingMedium),
                  Text(
                    Formatters.formatCurrency(amount),
                    style: AppConstants.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (data['color'] as Color).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: AppConstants.bodySmall.copyWith(
                        color: data['color'] as Color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  /// Peak Hours Heatmap
  Widget _buildPeakHoursHeatmap() {
    // Sample data: revenue by hour (0-23) for each day (0-6)
    final heatmapData = [
      [0.5, 1.2, 0.8, 1.5, 2.1, 3.2, 2.8], // 6 AM
      [1.2, 2.1, 1.8, 2.5, 3.2, 4.5, 3.8], // 7 AM
      [2.5, 3.8, 3.2, 4.1, 5.2, 6.8, 5.5], // 8 AM
      [3.8, 5.2, 4.5, 5.8, 6.9, 8.2, 7.1], // 9 AM
      [4.5, 6.1, 5.8, 6.5, 7.8, 9.5, 8.2], // 10 AM
      [5.2, 7.8, 6.9, 8.2, 9.5, 11.2, 10.1], // 11 AM
      [8.5, 12.5, 11.2, 13.5, 15.8, 18.2, 16.5], // 12 PM - Peak lunch
      [9.2, 13.8, 12.5, 14.2, 16.5, 19.5, 17.8], // 1 PM - Peak lunch
      [6.5, 9.2, 8.5, 10.1, 11.5, 13.8, 12.2], // 2 PM
      [4.2, 6.5, 5.8, 7.2, 8.5, 10.1, 9.2], // 3 PM
      [3.5, 5.2, 4.8, 6.1, 7.2, 8.8, 7.5], // 4 PM
      [4.8, 7.2, 6.5, 8.5, 10.2, 12.5, 11.2], // 5 PM
      [7.5, 11.2, 10.5, 13.2, 15.5, 18.8, 17.2], // 6 PM - Peak dinner
      [8.8, 13.5, 12.8, 15.8, 18.2, 21.5, 19.8], // 7 PM - Peak dinner
      [7.2, 10.8, 10.2, 12.5, 14.8, 17.5, 16.2], // 8 PM
      [5.5, 8.2, 7.8, 9.5, 11.2, 13.8, 12.5], // 9 PM
    ];

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxValue = 21.5;

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
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Low',
                style: AppConstants.bodySmall.copyWith(
                  color: AppConstants.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              ...List.generate(5, (i) {
                return Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: _getHeatmapColor(i / 4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
              const SizedBox(width: 8),
              Text(
                'High',
                style: AppConstants.bodySmall.copyWith(
                  color: AppConstants.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          // Day headers
          Row(
            children: [
              const SizedBox(width: 50), // Space for hour labels
              ...days.map((day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: AppConstants.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )).toList(),
            ],
          ),
          const SizedBox(height: 8),
          // Heatmap grid
          ...List.generate(heatmapData.length, (hourIndex) {
            final hour = hourIndex + 6; // Starting from 6 AM
            final hourLabel = hour <= 12 ? '${hour}AM' : '${hour - 12}PM';
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(
                      hourLabel,
                      style: AppConstants.bodySmall.copyWith(
                        color: AppConstants.textSecondary,
                      ),
                    ),
                  ),
                  ...List.generate(7, (dayIndex) {
                    final value = heatmapData[hourIndex][dayIndex];
                    final intensity = value / maxValue;
                    
                    return Expanded(
                      child: Tooltip(
                        message: '${days[dayIndex]} $hourLabel\n₱${value.toStringAsFixed(1)}K',
                        child: Container(
                          height: 24,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: _getHeatmapColor(intensity),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: AppConstants.paddingMedium),
          // Summary
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingSmall),
            decoration: BoxDecoration(
              color: AppConstants.primaryOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
              border: Border.all(color: AppConstants.primaryOrange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: AppConstants.primaryOrange,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Peak hours: 12-2PM (Lunch) & 6-8PM (Dinner). Saturday & Sunday show highest traffic.',
                    style: AppConstants.bodySmall.copyWith(
                      color: AppConstants.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getHeatmapColor(double intensity) {
    if (intensity < 0.2) return AppConstants.successGreen.withOpacity(0.2);
    if (intensity < 0.4) return AppConstants.successGreen.withOpacity(0.4);
    if (intensity < 0.6) return AppConstants.warningYellow.withOpacity(0.6);
    if (intensity < 0.8) return AppConstants.primaryOrange.withOpacity(0.7);
    return AppConstants.errorRed.withOpacity(0.8);
  }

  /// Inline AI Insights
  Widget _buildInlineInsights() {
    final insights = [
      {
        'text': 'Schedule +2 servers for Saturday lunch (12-2PM). Expected 35% traffic increase.',
        'action': 'View Schedule',
        'icon': Icons.people,
        'color': AppConstants.primaryOrange,
        'priority': 'High',
      },
      {
        'text': 'Order 30kg pasta by Thursday. Forecast shows 145 orders this weekend.',
        'action': 'Update Inventory',
        'icon': Icons.inventory_2,
        'color': AppConstants.warningYellow,
        'priority': 'High',
      },
      {
        'text': 'Rain expected Friday. Promote comfort food combos - historically 22% sales boost.',
        'action': 'Create Promo',
        'icon': Icons.campaign,
        'color': Colors.blue,
        'priority': 'Medium',
      },
      {
        'text': 'Dessert demand up 18% but stock low. Add Leche Flan to specials board.',
        'action': 'Add to Menu',
        'icon': Icons.cake,
        'color': AppConstants.successGreen,
        'priority': 'Medium',
      },
      {
        'text': 'Monday typically slow. Run 20% lunch special to boost 11AM-1PM traffic.',
        'action': 'Set Discount',
        'icon': Icons.local_offer,
        'color': Colors.purple,
        'priority': 'Low',
      },
    ];

    return Column(
      children: insights.map((insight) {
        final priority = insight['priority'] as String;
        Color priorityColor = AppConstants.textSecondary;
        if (priority == 'High') priorityColor = AppConstants.errorRed;
        if (priority == 'Medium') priorityColor = AppConstants.warningYellow;
        
        return Container(
          margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          decoration: BoxDecoration(
            color: AppConstants.cardBackground,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(
              color: priority == 'High' 
                  ? AppConstants.primaryOrange.withOpacity(0.5)
                  : AppConstants.dividerColor,
              width: priority == 'High' ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: priorityColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                priority,
                                style: AppConstants.bodySmall.copyWith(
                                  color: priorityColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          insight['text'] as String,
                          style: AppConstants.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.paddingSmall),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${insight['action']} feature coming soon!'),
                        backgroundColor: AppConstants.primaryOrange,
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: AppConstants.primaryOrange,
                  ),
                  label: Text(
                    insight['action'] as String,
                    style: AppConstants.bodySmall.copyWith(
                      color: AppConstants.primaryOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Comparison Overlay Modal
  /// Comparison tab
  Widget _buildComparisonTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            decoration: BoxDecoration(
              color: AppConstants.cardBackground,
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              border: Border.all(color: AppConstants.dividerColor),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.compare_arrows,
                    color: AppConstants.primaryOrange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppConstants.paddingSmall),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Historical vs Forecast Comparison',
                        style: AppConstants.headingSmall,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Compare actual performance with AI predictions',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppConstants.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.paddingLarge),

          // Key Metrics Comparison
          const Text(
            'Key Metrics Comparison',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildMetricsComparison(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Sales Trend Comparison Chart
          const Text(
            'Sales Trend: Historical vs Forecast',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildSalesTrendComparison(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Category Performance Comparison
          const Text(
            'Category Performance Comparison',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildCategoryComparison(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Channel Distribution Comparison
          const Text(
            'Order Channel Distribution',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildChannelComparison(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Insights & Recommendations
          const Text(
            'Key Insights',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildComparisonInsights(),
        ],
      ),
    );
  }

  /// Metrics Comparison Cards
  Widget _buildMetricsComparison() {
    final metrics = [
      {
        'title': 'Total Revenue',
        'historical': '₱45,230',
        'forecast': '₱58,450',
        'difference': '+29.2%',
        'isIncrease': true,
        'icon': Icons.trending_up,
        'color': AppConstants.successGreen,
      },
      {
        'title': 'Total Orders',
        'historical': '725',
        'forecast': '890',
        'difference': '+22.8%',
        'isIncrease': true,
        'icon': Icons.receipt,
        'color': AppConstants.primaryOrange,
      },
      {
        'title': 'Avg. Order Value',
        'historical': '₱62.40',
        'forecast': '₱65.67',
        'difference': '+5.2%',
        'isIncrease': true,
        'icon': Icons.shopping_cart,
        'color': Colors.blue,
      },
    ];

    return Column(
      children: metrics.map((metric) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          decoration: BoxDecoration(
            color: AppConstants.cardBackground,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(color: AppConstants.dividerColor, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  Icon(
                    metric['icon'] as IconData,
                    color: metric['color'] as Color,
                    size: 20,
                  ),
                  const SizedBox(width: AppConstants.paddingSmall),
                  Text(
                    metric['title'] as String,
                    style: AppConstants.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              
              // Values row
              Row(
                children: [
                  // Historical
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(AppConstants.paddingMedium),
                      decoration: BoxDecoration(
                        color: AppConstants.darkSecondary.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                        border: Border.all(
                          color: AppConstants.textSecondary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
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
                            metric['historical'] as String,
                            style: AppConstants.headingSmall.copyWith(
                              color: AppConstants.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Arrow and difference
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        Icon(
                          Icons.arrow_forward,
                          color: AppConstants.primaryOrange,
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (metric['isIncrease'] as bool
                                ? AppConstants.successGreen
                                : Colors.red).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                metric['isIncrease'] as bool
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                color: metric['isIncrease'] as bool
                                    ? AppConstants.successGreen
                                    : Colors.red,
                                size: 12,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                metric['difference'] as String,
                                style: AppConstants.bodySmall.copyWith(
                                  color: metric['isIncrease'] as bool
                                      ? AppConstants.successGreen
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Forecast
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(AppConstants.paddingMedium),
                      decoration: BoxDecoration(
                        color: AppConstants.primaryOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                        border: Border.all(
                          color: AppConstants.primaryOrange.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Forecast',
                            style: AppConstants.bodySmall.copyWith(
                              color: AppConstants.primaryOrange,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            metric['forecast'] as String,
                            style: AppConstants.headingSmall.copyWith(
                              color: AppConstants.primaryOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Sales Trend Comparison Chart
  Widget _buildSalesTrendComparison() {
    final historicalSpots = [
      const FlSpot(0, 8500),
      const FlSpot(1, 10200),
      const FlSpot(2, 9800),
      const FlSpot(3, 12500),
      const FlSpot(4, 15200),
      const FlSpot(5, 14800),
      const FlSpot(6, 16500),
    ];
    
    final forecastSpots = [
      const FlSpot(0, 8200),
      const FlSpot(1, 9900),
      const FlSpot(2, 10500),
      const FlSpot(3, 12200),
      const FlSpot(4, 15600),
      const FlSpot(5, 15200),
      const FlSpot(6, 17200),
    ];
    
    final labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      height: 300,
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.dividerColor, width: 1),
      ),
      child: Column(
        children: [
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppConstants.successGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Historical Sales',
                    style: AppConstants.bodySmall.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppConstants.primaryOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Forecast Sales',
                    style: AppConstants.bodySmall.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          Expanded(
            child: LineChart(
              LineChartData(
                maxY: 18000,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 2000,
                  verticalInterval: 1,
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
                      interval: 2000,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            '₱${(value / 1000).toStringAsFixed(0)}K',
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
                  // Historical line
                  LineChartBarData(
                    spots: historicalSpots,
                    isCurved: true,
                    color: AppConstants.successGreen,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppConstants.successGreen.withOpacity(0.1),
                    ),
                  ),
                  // Forecast line
                  LineChartBarData(
                    spots: forecastSpots,
                    isCurved: true,
                    color: AppConstants.primaryOrange,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    dashArray: [5, 5],
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppConstants.primaryOrange.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Category Comparison
  Widget _buildCategoryComparison() {
    final categories = [
      {
        'name': 'Main Course',
        'historical': 280,
        'forecast': 340,
        'color': AppConstants.primaryOrange,
        'icon': Icons.restaurant,
      },
      {
        'name': 'Beverages',
        'historical': 178,
        'forecast': 210,
        'color': Colors.blue,
        'icon': Icons.local_cafe,
      },
      {
        'name': 'Appetizers',
        'historical': 105,
        'forecast': 120,
        'color': AppConstants.successGreen,
        'icon': Icons.fastfood,
      },
      {
        'name': 'Desserts',
        'historical': 78,
        'forecast': 85,
        'color': Colors.pink,
        'icon': Icons.cake,
      },
      {
        'name': 'Sides',
        'historical': 72,
        'forecast': 65,
        'color': AppConstants.warningYellow,
        'icon': Icons.food_bank,
      },
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
          final historical = category['historical'] as int;
          final forecast = category['forecast'] as int;
          final change = ((forecast - historical) / historical * 100);
          final isIncrease = change > 0;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (category['color'] as Color).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        category['icon'] as IconData,
                        color: category['color'] as Color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppConstants.paddingSmall),
                    Expanded(
                      child: Text(
                        category['name'] as String,
                        style: AppConstants.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isIncrease
                            ? AppConstants.successGreen
                            : Colors.red).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isIncrease ? Icons.arrow_upward : Icons.arrow_downward,
                            color: isIncrease ? AppConstants.successGreen : Colors.red,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${change.abs().toStringAsFixed(0)}%',
                            style: AppConstants.bodySmall.copyWith(
                              color: isIncrease ? AppConstants.successGreen : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.paddingSmall),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Historical: $historical orders',
                            style: AppConstants.bodySmall.copyWith(
                              color: AppConstants.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: historical / 340,
                              minHeight: 6,
                              backgroundColor: AppConstants.dividerColor,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppConstants.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppConstants.paddingMedium),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Forecast: $forecast orders',
                            style: AppConstants.bodySmall.copyWith(
                              color: AppConstants.primaryOrange,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: forecast / 340,
                              minHeight: 6,
                              backgroundColor: AppConstants.dividerColor,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                category['color'] as Color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Channel Comparison
  Widget _buildChannelComparison() {
    final channels = [
      {
        'name': 'Dine-In',
        'historical': 470,
        'forecast': 540,
        'historicalPct': 65,
        'forecastPct': 65,
        'color': AppConstants.primaryOrange,
        'icon': Icons.restaurant_menu,
      },
      {
        'name': 'Takeout',
        'historical': 181,
        'forecast': 208,
        'historicalPct': 25,
        'forecastPct': 25,
        'color': Colors.blue,
        'icon': Icons.shopping_bag,
      },
      {
        'name': 'Delivery',
        'historical': 74,
        'forecast': 83,
        'historicalPct': 10,
        'forecastPct': 10,
        'color': AppConstants.successGreen,
        'icon': Icons.delivery_dining,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.dividerColor, width: 1),
      ),
      child: Column(
        children: [
          // Historical bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Historical Distribution',
                style: AppConstants.bodySmall.copyWith(
                  color: AppConstants.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: channels.map((channel) {
                  final isFirst = channel == channels.first;
                  final isLast = channel == channels.last;
                  
                  return Expanded(
                    flex: channel['historicalPct'] as int,
                    child: Container(
                      height: 30,
                      decoration: BoxDecoration(
                        color: (channel['color'] as Color).withOpacity(0.5),
                        borderRadius: BorderRadius.only(
                          topLeft: isFirst ? const Radius.circular(6) : Radius.zero,
                          bottomLeft: isFirst ? const Radius.circular(6) : Radius.zero,
                          topRight: isLast ? const Radius.circular(6) : Radius.zero,
                          bottomRight: isLast ? const Radius.circular(6) : Radius.zero,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${channel['historicalPct']}%',
                          style: AppConstants.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          
          // Forecast bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Forecast Distribution',
                style: AppConstants.bodySmall.copyWith(
                  color: AppConstants.primaryOrange,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: channels.map((channel) {
                  final isFirst = channel == channels.first;
                  final isLast = channel == channels.last;
                  
                  return Expanded(
                    flex: channel['forecastPct'] as int,
                    child: Container(
                      height: 30,
                      decoration: BoxDecoration(
                        color: channel['color'] as Color,
                        borderRadius: BorderRadius.only(
                          topLeft: isFirst ? const Radius.circular(6) : Radius.zero,
                          bottomLeft: isFirst ? const Radius.circular(6) : Radius.zero,
                          topRight: isLast ? const Radius.circular(6) : Radius.zero,
                          bottomRight: isLast ? const Radius.circular(6) : Radius.zero,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${channel['forecastPct']}%',
                          style: AppConstants.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingLarge),
          
          // Channel details
          ...channels.map((channel) {
            final historical = channel['historical'] as int;
            final forecast = channel['forecast'] as int;
            final change = ((forecast - historical) / historical * 100);
            
            return Container(
              margin: const EdgeInsets.only(bottom: AppConstants.paddingSmall),
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              decoration: BoxDecoration(
                color: AppConstants.darkSecondary,
                borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                border: Border.all(
                  color: (channel['color'] as Color).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    channel['icon'] as IconData,
                    color: channel['color'] as Color,
                    size: 20,
                  ),
                  const SizedBox(width: AppConstants.paddingSmall),
                  Expanded(
                    child: Text(
                      channel['name'] as String,
                      style: AppConstants.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$historical → $forecast orders',
                        style: AppConstants.bodySmall.copyWith(
                          color: AppConstants.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '+${change.toStringAsFixed(0)}%',
                        style: AppConstants.bodySmall.copyWith(
                          color: AppConstants.successGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  /// Comparison Insights
  Widget _buildComparisonInsights() {
    final insights = [
      {
        'icon': Icons.trending_up,
        'color': AppConstants.successGreen,
        'title': 'Strong Growth Projection',
        'description': 'Revenue forecast shows a 29.2% increase, driven by upcoming events and weather patterns.',
      },
      {
        'icon': Icons.restaurant,
        'color': AppConstants.primaryOrange,
        'title': 'Main Course Surge',
        'description': 'Main Course category expected to grow by 21%, suggesting increased demand for full meals.',
      },
      {
        'icon': Icons.delivery_dining,
        'color': Colors.blue,
        'title': 'Channel Consistency',
        'description': 'Order channel distribution remains stable at 65-25-10, with growth across all channels.',
      },
      {
        'icon': Icons.lightbulb_outline,
        'color': AppConstants.warningYellow,
        'title': 'Recommended Actions',
        'description': 'Stock up on Pasta ingredients. Add 2 servers for peak hours. Promote comfort food during rainy days.',
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
            border: Border.all(
              color: (insight['color'] as Color).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (insight['color'] as Color).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  insight['icon'] as IconData,
                  color: insight['color'] as Color,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppConstants.paddingSmall),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight['title'] as String,
                      style: AppConstants.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      insight['description'] as String,
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

  /// Date range text
  String get _dateRangeText {
    if (_startDate == null) return 'Showing: ${Formatters.formatDate(DateTime.now())}';
    if (_endDate == null) return 'Showing: ${Formatters.formatDate(_startDate!)}';
    return 'Showing: ${Formatters.formatDate(_startDate!)} - ${Formatters.formatDate(_endDate!)}';
  }

  /// Pick date range
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

  /// Pick single date
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

  /// Clear dates
  void _clearDates() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  /// Load analytics data
  Future<void> _loadAnalyticsData() async {
    setState(() {
      _isLoading = true;
      _isCalendarLoading = true;
      _isImpactsLoading = true;
      _calendarError = null;
      _impactsError = null;
    });

    try {
      final now = DateTime.now();
      final forecastRange = Duration(days: _selectedRangeInDays());
      final forecastsFuture = _forecastService.getSalesForecast(
        startDate: now,
        endDate: now.add(forecastRange),
      );
      final insightsFuture = _forecastService.getSalesInsights();

      final monthStart = DateTime(
        _selectedCalendarMonth.year,
        _selectedCalendarMonth.month,
        1,
      );
      final monthEnd = DateTime(
        _selectedCalendarMonth.year,
        _selectedCalendarMonth.month + 1,
        0,
      );

      final calendarFuture = _analyticsCalendarService.fetchMonth(
        _selectedCalendarMonth,
        fallbackRangeDays: _selectedRangeInDays(),
      );
      final impactsFuture = _analyticsCalendarService.fetchImpacts(
        start: monthStart,
        end: monthEnd,
        fallbackRangeDays: _selectedRangeInDays(),
      );

      final forecasts = await forecastsFuture;
      final insights = await insightsFuture;
      final calendar = await calendarFuture;
      final impacts = await impactsFuture;

      setState(() {
        _forecasts = forecasts;
        _insights = insights;
        _calendarMonth = calendar;
        _eventImpacts = impacts;
        _isLoading = false;
        _isCalendarLoading = false;
        _isImpactsLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isCalendarLoading = false;
        _isImpactsLoading = false;
        _calendarError ??= e.toString();
        _impactsError ??= e.toString();
      });
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading analytics: $e'),
          backgroundColor: AppConstants.errorRed,
        ),
      );
    }
  }

  int _selectedRangeInDays() {
    switch (_selectedForecastRange) {
      case '14 Days':
        return 14;
      case '30 Days':
        return 30;
      default:
        return 7;
    }
  }

  bool _isWithinSelectedForecastRange(DateTime date) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(Duration(days: _selectedRangeInDays() - 1));
    return !date.isBefore(start) && !date.isAfter(end);
  }

  bool _monthOverlapsForecastRange(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    for (var current = first;
        !current.isAfter(last);
        current = current.add(const Duration(days: 1))) {
      if (_isWithinSelectedForecastRange(current)) {
        return true;
      }
    }
    return false;
  }

  String _formatImpactDate(DateTime date) {
    final formatter = DateFormat('MMM dd (EEEE)');
    return formatter.format(date);
  }

  Color _eventImpactColor(EventImpact impact) {
    final percent = impact.impactPercent;
    if (percent == null) {
      return AppConstants.warningYellow;
    }
    if (percent > 0) {
      return AppConstants.successGreen;
    }
    if (percent < 0) {
      return AppConstants.errorRed;
    }
    return AppConstants.primaryOrange;
  }

  String _formatImpactPercent(double? value) {
    if (value == null) {
      return '—';
    }
    final rounded = value.abs().toStringAsFixed(0);
    if (value > 0) {
      return '+$rounded%';
    }
    if (value < 0) {
      return '-$rounded%';
    }
    return '0%';
  }

  String _buildImpactHeadline(EventImpact impact) {
    final pieces = <String>[];
    if (impact.eventName.trim().isNotEmpty) {
      pieces.add(impact.eventName.trim());
    }
    final eventType = (impact.eventType ?? '').trim();
    if (eventType.isNotEmpty) {
      pieces.add(eventType);
    }
    if (pieces.isEmpty) {
      pieces.add(impact.condition);
    }
    return pieces.join(' • ');
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
