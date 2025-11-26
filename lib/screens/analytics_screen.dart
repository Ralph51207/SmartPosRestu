import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/analytics_calendar_model.dart';
import '../models/sales_data_model.dart';
import '../services/analytics_calendar_service.dart';
import '../services/transaction_service.dart';
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
  static const List<String> _dayNames = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
    final ForecastService _forecastService = ForecastService();
    final AnalyticsCalendarService _analyticsCalendarService =
      AnalyticsCalendarService();
    late TabController _tabController;
    List<SalesForecast> _forecasts = [];
    List<ForecastSeriesPoint> _forecastProjectedSeries = [];
    List<ForecastSeriesPoint> _forecastActualSeries = [];
    List<CategoryDemandProjection> _forecastCategoryDemand = [];
    List<ChannelDemandProjection> _forecastChannelDemand = [];
    List<MenuItemPrediction> _forecastMenuPredictions = [];
    List<_ForecastInsight> _forecastInsights = [];
    _ForecastActionRecommendation? _forecastAction;
    double _forecastTotalRevenue = 0;
    int _forecastTotalOrders = 0;
    double _forecastAverageOrderValue = 0;
    double? _forecastRevenueChangePercent;
    double? _forecastOrdersChangePercent;
    double? _forecastAovChangePercent;
    double _forecastAverageConfidence = 0;
    double _forecastRecentAccuracy = 0;
    double _forecastOverallAccuracy = 0;
    double _forecastAccuracyTrend = 0;
    double _forecastTrafficAccuracy = 0;
    double _forecastPeakAccuracy = 0;
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
  final TransactionService _transactionService = TransactionService();
  final NumberFormat _countFormatter = NumberFormat.decimalPattern();
  List<TransactionRecord> _filteredTransactions = [];
  double _totalRevenue = 0;
  int _totalOrders = 0;
  double _averageOrderValue = 0;
  double? _revenueChangePercent;
  double? _orderChangePercent;
  double? _aovChangePercent;
  double _peakHourRevenue = 0;
  String _peakHourWindowLabel = '—';
  List<_DailyRevenuePoint> _dailyRevenuePoints = [];
  double _salesTrendMaxY = 0;
  List<_CategoryBreakdown> _categoryBreakdown = [];
  int _maxCategoryQuantity = 0;
  List<_ChannelBreakdown> _channelBreakdown = [];
  List<_TopSeller> _topSellers = [];
  List<_PaymentBreakdown> _paymentBreakdown = [];
  double _totalPaymentRevenue = 0;
  List<int> _heatmapHours = [];
  List<List<double>> _heatmapValues = [];
  double _heatmapMaxValue = 0;
  String _heatmapSummary = 'No transactions yet.';

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
            final scaffoldState = context
                .findAncestorStateOfType<ScaffoldState>();
            if (scaffoldState != null) {
              scaffoldState.openDrawer();
            }
          },
        ),
        title: Row(
          children: [
            Icon(Icons.analytics, color: AppConstants.primaryOrange),
            const SizedBox(width: AppConstants.paddingSmall),
            const Text('Analytics', style: AppConstants.headingMedium),
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
                          side: const BorderSide(
                            color: AppConstants.primaryOrange,
                          ),
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
                          side: const BorderSide(
                            color: AppConstants.primaryOrange,
                          ),
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
          const Text('Top 10 Best Sellers', style: AppConstants.headingSmall),
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
          const Text('Peak Hours Analysis', style: AppConstants.headingSmall),
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
              border: Border.all(color: AppConstants.dividerColor, width: 1),
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
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusSmall,
                      ),
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
          const Text('Forecast Summary', style: AppConstants.headingSmall),
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
          const Text('AI Insights', style: AppConstants.headingSmall),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildInlineInsights(),
        ],
      ),
    );
  }

  /// Insights tab with AI recommendations
  /// Metrics cards
  Widget _buildMetricsCards() {
    final totalRevenueText = Formatters.formatCurrency(_totalRevenue);
    final totalOrdersText = _countFormatter.format(_totalOrders);
    final averageOrderValueText = Formatters.formatCurrency(_averageOrderValue);
    final peakRevenueText = Formatters.formatCurrency(_peakHourRevenue);
    final peakDetail = _peakHourWindowLabel == '—'
        ? null
        : 'Peak: $_peakHourWindowLabel';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Total Revenue',
                value: totalRevenueText,
                icon: Icons.trending_up,
                color: AppConstants.successGreen,
                percentageChange: _formatDelta(_revenueChangePercent),
              ),
            ),
            const SizedBox(width: AppConstants.paddingMedium),
            Expanded(
              child: StatCard(
                title: 'Total Orders',
                value: totalOrdersText,
                icon: Icons.receipt,
                color: AppConstants.primaryOrange,
                percentageChange: _formatDelta(_orderChangePercent),
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
                value: averageOrderValueText,
                icon: Icons.shopping_cart,
                color: Colors.blue,
                percentageChange: _formatDelta(_aovChangePercent),
              ),
            ),
            const SizedBox(width: AppConstants.paddingMedium),
            Expanded(
              child: StatCard(
                title: 'Peak Hour Revenue',
                value: peakRevenueText,
                icon: Icons.access_time,
                color: AppConstants.warningYellow,
                percentageChange: peakDetail,
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
        await _loadAnalyticsData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.primaryOrange : Colors.transparent,
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
        border: Border.all(color: AppConstants.dividerColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text('Sales Trend', style: AppConstants.headingSmall),
          const SizedBox(height: AppConstants.paddingMedium),
          // Chart
          SizedBox(height: 250, child: _buildSalesTrendChart()),
        ],
      ),
    );
  }

  /// Sales Trend Chart
  Widget _buildSalesTrendChart() {
    if (_dailyRevenuePoints.isEmpty) {
      return Center(
        child: Text(
          'No completed transactions for the selected range yet.',
          style: AppConstants.bodySmall.copyWith(
            color: AppConstants.textSecondary,
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    final labels = <String>[];
    final dateFormat = DateFormat('MMMd');
    for (var i = 0; i < _dailyRevenuePoints.length; i++) {
      final point = _dailyRevenuePoints[i];
      spots.add(FlSpot(i.toDouble(), point.revenue));
      labels.add(dateFormat.format(point.date));
    }

    final maxY = _salesTrendMaxY <= 0 ? 1000.0 : _salesTrendMaxY;
    final yInterval = _computeYAxisInterval(maxY);
    final bottomInterval = spots.length <= 1
        ? 1
        : math.max(1, (spots.length / 6).ceil());

    return LineChart(
      LineChartData(
        maxY: maxY,
        minY: 0,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                AppConstants.darkSecondary.withOpacity(0.95),
            tooltipRoundedRadius: AppConstants.radiusSmall,
            tooltipPadding: const EdgeInsets.all(8),
            tooltipBorder: BorderSide(
              color: AppConstants.primaryOrange,
              width: 1,
            ),
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.round();
                final label = (index >= 0 && index < labels.length)
                    ? labels[index]
                    : 'Day ${index + 1}';
                return LineTooltipItem(
                  '$label\n',
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
                      text: Formatters.formatCurrency(spot.y),
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
          horizontalInterval: yInterval,
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
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                if (value == 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    Formatters.formatCurrency(value),
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
              interval: bottomInterval.toDouble(),
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
    final revenueDelta = _formatDelta(_forecastRevenueChangePercent);
    final ordersDelta = _formatDelta(_forecastOrdersChangePercent);
    final aovDelta = _formatDelta(_forecastAovChangePercent);

    final revenueColor = _deltaColor(_forecastRevenueChangePercent);
    final ordersColor = _deltaColor(_forecastOrdersChangePercent);
    final aovColor = _deltaColor(_forecastAovChangePercent);

    final action = _forecastAction;
    final visuals = _insightVisualForKind(action?.kind ?? _ForecastInsightKind.general);
    final actionPriorityColor = _priorityColor(action?.priority ?? _ForecastInsightPriority.medium);

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Predicted Revenue',
                  Formatters.formatCurrency(_forecastTotalRevenue),
                  revenueDelta != null
                      ? '$revenueDelta vs historical'
                      : 'No baseline available',
                  Icons.trending_up,
                  revenueColor,
                ),
              ),
              const SizedBox(width: AppConstants.paddingMedium),
              Expanded(
                child: _buildSummaryCard(
                  'Predicted Orders',
                  _countFormatter.format(_forecastTotalOrders),
                  ordersDelta != null
                      ? '$ordersDelta vs historical'
                      : 'No baseline available',
                  Icons.receipt_long,
                  ordersColor,
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
                  Formatters.formatCurrency(_forecastAverageOrderValue),
                  aovDelta != null
                      ? '$aovDelta vs historical'
                      : 'No baseline available',
                  Icons.shopping_cart_checkout,
                  aovColor,
                ),
              ),
              const SizedBox(width: AppConstants.paddingMedium),
              Expanded(
                child: _buildSummaryCard(
                  'Recommended Action',
                  action?.title ?? 'Stay proactive',
                  action?.subtitle ??
                      'Use the calendar + demand widgets to align staffing and promotions.',
                  visuals.icon,
                  actionPriorityColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
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

      final hasRangeOverlap = _monthOverlapsForecastRange(
        _selectedCalendarMonth,
      );
      final calendar =
          _calendarMonth ??
          WeatherCalendarMonth(month: _selectedCalendarMonth, days: const []);

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
        children: List.generate((daysInMonth + startingWeekday) ~/ 7 + 1, (
          weekIndex,
        ) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: List.generate(7, (dayIndex) {
                final dayNumber =
                    weekIndex * 7 + dayIndex - startingWeekday + 1;

                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 70));
                }

                final currentDate = DateTime(
                  _selectedCalendarMonth.year,
                  _selectedCalendarMonth.month,
                  dayNumber,
                );
                final isToday =
                    currentDate.year == now.year &&
                    currentDate.month == now.month &&
                    currentDate.day == now.day;
                final isInForecastRange = _isWithinSelectedForecastRange(
                  currentDate,
                );
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
                            fontWeight: isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
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
                icon: Icon(
                  Icons.chevron_left,
                  color: AppConstants.primaryOrange,
                ),
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
                icon: Icon(
                  Icons.chevron_right,
                  color: AppConstants.primaryOrange,
                ),
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
            children: ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'].map((
              day,
            ) {
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
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
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
              const Text(
                'Loading event impacts...',
                style: AppConstants.bodySmall,
              ),
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
              border: Border.all(color: color.withOpacity(0.3), width: 1),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
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
                        Icon(Icons.lightbulb_outline, size: 16, color: color),
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
    if (_forecastCategoryDemand.isEmpty) {
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
            const Text(
              'No category projections yet',
              style: AppConstants.bodyLarge,
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              'Run analytics with recent transactions to forecast category demand.',
              style: AppConstants.bodySmall.copyWith(
                color: AppConstants.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    const List<Color> palette = <Color>[
      AppConstants.primaryOrange,
      Colors.blue,
      AppConstants.successGreen,
      Colors.pink,
      AppConstants.warningYellow,
      Colors.purple,
      Colors.teal,
    ];

    final maxPredicted = _forecastCategoryDemand.fold<int>(
      0,
      (maxValue, item) => math.max(maxValue, item.predictedOrders),
    );
    final maxValue = maxPredicted == 0 ? 1 : maxPredicted;

    Color _categoryColor(int index) =>
        palette[index % palette.length];

    IconData _categoryIcon(String name) {
      final lower = name.toLowerCase();
      if (lower.contains('drink') || lower.contains('bev')) {
        return Icons.local_cafe;
      }
      if (lower.contains('dessert') || lower.contains('sweet')) {
        return Icons.cake;
      }
      if (lower.contains('app') || lower.contains('starter')) {
        return Icons.fastfood;
      }
      if (lower.contains('side')) {
        return Icons.food_bank;
      }
      return Icons.restaurant;
    }

    String _changeLabel(double value) {
      final formatted = _formatDelta(value);
      if (formatted == null) {
        return '0%';
      }
      if (formatted == 'New') {
        return 'New';
      }
      return formatted;
    }

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.dividerColor, width: 1),
      ),
      child: Column(
        children: [
          ..._forecastCategoryDemand.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            final color = _categoryColor(index);
            final changeLabel = _changeLabel(category.changePercent);
            final isIncrease =
                !category.changePercent.isNaN && category.changePercent >= 0;
            final percentage = category.predictedOrders / maxValue;

            return Padding(
              padding: const EdgeInsets.only(
                bottom: AppConstants.paddingMedium,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _categoryIcon(category.name),
                          color: color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppConstants.paddingSmall),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.name,
                              style: AppConstants.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Historical: ${category.historicalOrders} orders',
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
                            '${category.predictedOrders} orders',
                            style: AppConstants.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: (isIncrease
                                      ? AppConstants.successGreen
                                      : AppConstants.errorRed)
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isIncrease
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  size: 12,
                                  color: isIncrease
                                      ? AppConstants.successGreen
                                      : AppConstants.errorRed,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  changeLabel,
                                  style: AppConstants.bodySmall.copyWith(
                                    color: isIncrease
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
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: percentage.clamp(0.0, 1.0),
                      minHeight: 10,
                      color: color,
                      backgroundColor: AppConstants.dividerColor,
                    ),
                  ),
                ],
              ),
            );
          }),
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
                      bottomLeft: isFirst
                          ? const Radius.circular(8)
                          : Radius.zero,
                      topRight: isLast ? const Radius.circular(8) : Radius.zero,
                      bottomRight: isLast
                          ? const Radius.circular(8)
                          : Radius.zero,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppConstants.successGreen.withOpacity(
                                  0.2,
                                ),
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
                  final isNegative = (itemMap['trend'] as String).startsWith(
                    '-',
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(AppConstants.paddingSmall),
                    decoration: BoxDecoration(
                      color: AppConstants.darkSecondary,
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusSmall,
                      ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
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
    if (_forecastProjectedSeries.isEmpty && _forecastActualSeries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: AppConstants.cardBackground,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(color: AppConstants.dividerColor, width: 1),
        ),
        child: Text(
          'Forecast chart will appear once analytics and projections are available.',
          style: AppConstants.bodySmall.copyWith(
            color: AppConstants.textSecondary,
          ),
        ),
      );
    }

    final projected = List<ForecastSeriesPoint>.from(_forecastProjectedSeries);
    final actual = List<ForecastSeriesPoint>.from(_forecastActualSeries);
    final labelSeries = projected.isNotEmpty ? projected : actual;
    final dateFormatter = DateFormat('MMMd');

    final spotsProjected = projected
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.revenue))
        .toList();
    final spotsActual = actual
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.revenue))
        .toList();

    final maxRevenue = _niceCeiling([
      ...projected.map((point) => point.revenue),
      ...actual.map((point) => point.revenue),
    ].fold<double>(0, math.max));
    final yInterval = _computeYAxisInterval(maxRevenue);

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
                maxY: maxRevenue <= 0 ? 100 : maxRevenue,
                minY: 0,
                // Interactive tooltips for forecast chart
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        AppConstants.darkSecondary.withOpacity(0.95),
                    tooltipRoundedRadius: AppConstants.radiusSmall,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipBorder: BorderSide(
                      color: AppConstants.primaryOrange,
                      width: 1,
                    ),
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((spot) {
                        final isActual = spot.barIndex == 0;
                        final series = isActual ? actual : projected;
                        final index = spot.x.toInt().clamp(0, series.length - 1);
                        final dateLabel = dateFormatter.format(series[index].date);
                        return LineTooltipItem(
                          '$dateLabel\n',
                          AppConstants.bodySmall.copyWith(
                            color: AppConstants.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            TextSpan(
                              text: '${isActual ? "Actual" : "Projected"}: ',
                              style: AppConstants.bodySmall.copyWith(
                                color: isActual
                                    ? AppConstants.successGreen
                                    : AppConstants.primaryOrange,
                              ),
                            ),
                            TextSpan(
                              text: Formatters.formatCurrency(spot.y),
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
                      interval: yInterval,
                      getTitlesWidget: (value, meta) {
                        final label = value <= 0
                            ? '₱0'
                            : '₱${Formatters.formatCompactNumber(value)}';
                        return Text(
                          label,
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
                        final index = value.toInt();
                        if (index >= 0 && index < labelSeries.length) {
                          return Text(
                            dateFormatter.format(labelSeries[index].date),
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
                    spots: spotsActual,
                    isCurved: true,
                    color: AppConstants.successGreen,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                  ),
                  // Projected Sales
                  LineChartBarData(
                    spots: spotsProjected,
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
    final overallPercent = (_forecastOverallAccuracy * 100).clamp(0, 100);
    final overallBar = _forecastOverallAccuracy.clamp(0.0, 1.0).toDouble();
    final trendText = _formatDelta(_forecastAccuracyTrend);
    final trendColor = _deltaColor(_forecastAccuracyTrend);
    final recentPercent = (_forecastRecentAccuracy * 100).clamp(0, 100);
    final recentBar = _forecastRecentAccuracy.clamp(0.0, 1.0).toDouble();
    final salesPercent = (_forecastOverallAccuracy * 100).clamp(0, 100);
    final trafficPercent = (_forecastTrafficAccuracy * 100).clamp(0, 100);
    final peakPercent = (_forecastPeakAccuracy * 100).clamp(0, 100);

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
                          '${overallPercent.toStringAsFixed(1)}%',
                          style: AppConstants.headingMedium.copyWith(
                            color: AppConstants.successGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (trendText != null)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: trendColor.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              trendText,
                              style: AppConstants.bodySmall.copyWith(
                                color: trendColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: overallBar,
                      backgroundColor: AppConstants.dividerColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppConstants.successGreen,
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
                      'Recent Fit',
                      style: AppConstants.bodySmall.copyWith(
                        color: AppConstants.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${recentPercent.toStringAsFixed(1)}%',
                      style: AppConstants.headingMedium.copyWith(
                        color: AppConstants.successGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: recentBar,
                      backgroundColor: AppConstants.dividerColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppConstants.successGreen,
                      ),
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
              _buildAccuracyMetric(
                'Sales',
                '${salesPercent.toStringAsFixed(0)}%',
                AppConstants.primaryOrange,
              ),
              _buildAccuracyMetric(
                'Traffic',
                '${trafficPercent.toStringAsFixed(0)}%',
                Colors.blue,
              ),
              _buildAccuracyMetric(
                'Peak Hours',
                '${peakPercent.toStringAsFixed(0)}%',
                AppConstants.warningYellow,
              ),
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
    final palette = [
      AppConstants.primaryOrange,
      Colors.blue,
      AppConstants.successGreen,
      Colors.pink,
      AppConstants.warningYellow,
      Colors.purple,
      Colors.teal,
    ];

    if (_categoryBreakdown.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: AppConstants.cardBackground,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(color: AppConstants.dividerColor, width: 1),
        ),
        child: Text(
          'No category sales recorded for the selected range.',
          style: AppConstants.bodySmall.copyWith(
            color: AppConstants.textSecondary,
          ),
        ),
      );
    }

    final maxValue = _maxCategoryQuantity.clamp(1, 1 << 30);

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.dividerColor, width: 1),
      ),
      child: Column(
        children: [
          ..._categoryBreakdown.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            final color = palette[index % palette.length];
            final percentage = maxValue == 0
                ? 0.0
                : category.quantity / maxValue;
            return Padding(
              padding: const EdgeInsets.only(
                bottom: AppConstants.paddingMedium,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.restaurant, color: color, size: 20),
                      ),
                      const SizedBox(width: AppConstants.paddingSmall),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.name,
                              style: AppConstants.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              Formatters.formatCurrency(category.revenue),
                              style: AppConstants.bodySmall.copyWith(
                                color: AppConstants.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${_countFormatter.format(category.quantity)} items',
                        style: AppConstants.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
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
                      valueColor: AlwaysStoppedAnimation<Color>(color),
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
    if (_channelBreakdown.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: AppConstants.cardBackground,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(color: AppConstants.dividerColor, width: 1),
        ),
        child: Text(
          'No order channel data for the selected range.',
          style: AppConstants.bodySmall.copyWith(
            color: AppConstants.textSecondary,
          ),
        ),
      );
    }

    final palette = [
      AppConstants.primaryOrange,
      Colors.blue,
      AppConstants.successGreen,
      Colors.purple,
      Colors.teal,
      AppConstants.warningYellow,
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
            children: _channelBreakdown.asMap().entries.map((entry) {
              final index = entry.key;
              final channel = entry.value;
              final color = palette[index % palette.length];
              final share = channel.share;
              final flexValue = (share <= 0)
                  ? 1
                  : share.isFinite
                  ? share * 100
                  : 1;
              final flex = flexValue.clamp(1, 100).round();
              final isFirst = index == 0;
              final isLast = index == _channelBreakdown.length - 1;

              return Expanded(
                flex: flex,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.only(
                      topLeft: isFirst ? const Radius.circular(8) : Radius.zero,
                      bottomLeft: isFirst
                          ? const Radius.circular(8)
                          : Radius.zero,
                      topRight: isLast ? const Radius.circular(8) : Radius.zero,
                      bottomRight: isLast
                          ? const Radius.circular(8)
                          : Radius.zero,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${(share * 100).clamp(0, 100).toStringAsFixed(0)}%',
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
          ..._channelBreakdown.asMap().entries.map((entry) {
            final index = entry.key;
            final channel = entry.value;
            final color = palette[index % palette.length];
            final icon = _channelIcon(channel.name);
            final peakText = channel.peakLabel == null
                ? 'Peak time unavailable'
                : 'Peak: ${channel.peakLabel}';
            final sharePercent = (channel.share * 100).clamp(0, 100);

            return Container(
              margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              decoration: BoxDecoration(
                color: AppConstants.darkSecondary,
                borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                border: Border.all(color: color.withOpacity(0.3), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: AppConstants.paddingMedium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          channel.name,
                          style: AppConstants.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_countFormatter.format(channel.orders)} orders • ${Formatters.formatCurrency(channel.revenue)}',
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
                              peakText,
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${sharePercent.toStringAsFixed(1)}%',
                        style: AppConstants.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Formatters.formatCurrency(channel.revenue),
                        style: AppConstants.bodySmall.copyWith(
                          color: AppConstants.textSecondary,
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

  /// Top Selling Items
  Widget _buildTopSellingItems() {
    if (_topSellers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: AppConstants.cardBackground,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(color: AppConstants.dividerColor, width: 1),
        ),
        child: Text(
          'No item performance data for the selected range.',
          style: AppConstants.bodySmall.copyWith(
            color: AppConstants.textSecondary,
          ),
        ),
      );
    }

    final maxSold = _topSellers
        .fold<int>(0, (max, item) => math.max(max, item.quantity))
        .clamp(1, 1 << 30);

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
                child: Text('Item', style: AppConstants.bodySmall),
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
          ..._topSellers.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final percentage = maxSold == 0 ? 0.0 : item.quantity / maxSold;

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
                              ? Border.all(
                                  color: AppConstants.primaryOrange,
                                  width: 1,
                                )
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
                          item.name,
                          style: AppConstants.bodyMedium.copyWith(
                            fontWeight: index < 3
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      // Quantity
                      Expanded(
                        flex: 2,
                        child: Text(
                          _countFormatter.format(item.quantity),
                          style: AppConstants.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Revenue
                      Expanded(
                        flex: 2,
                        child: Text(
                          Formatters.formatCurrency(item.revenue),
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
                      index < 3
                          ? AppConstants.primaryOrange
                          : AppConstants.successGreen,
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
    if (_paymentBreakdown.isEmpty || _totalPaymentRevenue <= 0) {
      return Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: AppConstants.cardBackground,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(color: AppConstants.dividerColor, width: 1),
        ),
        child: Text(
          'No payment method data for the selected range.',
          style: AppConstants.bodySmall.copyWith(
            color: AppConstants.textSecondary,
          ),
        ),
      );
    }

    final palette = [
      AppConstants.successGreen,
      Colors.blue,
      AppConstants.primaryOrange,
      AppConstants.warningYellow,
      Colors.purple,
      Colors.teal,
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
          // Pie chart representation using stacked bars
          Row(
            children: _paymentBreakdown.asMap().entries.map((entry) {
              final index = entry.key;
              final data = entry.value;
              final color = palette[index % palette.length];
              final percentage = _totalPaymentRevenue == 0
                  ? 0.0
                  : (data.amount / _totalPaymentRevenue);
              final isFirst = index == 0;
              final isLast = index == _paymentBreakdown.length - 1;

              return Expanded(
                flex: (percentage * 100).toInt(),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: isFirst
                        ? const BorderRadius.horizontal(
                            left: Radius.circular(8),
                          )
                        : isLast
                        ? const BorderRadius.horizontal(
                            right: Radius.circular(8),
                          )
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '${(percentage * 100).clamp(0, 100).toStringAsFixed(0)}%',
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
          ..._paymentBreakdown.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            final color = palette[index % palette.length];
            final amount = data.amount;
            final percentage = _totalPaymentRevenue == 0
                ? 0.0
                : (amount / _totalPaymentRevenue) * 100;
            return Padding(
              padding: const EdgeInsets.only(
                bottom: AppConstants.paddingMedium,
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(data.method, style: AppConstants.bodyMedium),
                  ),
                  Text(
                    '${_countFormatter.format(data.count)} orders',
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: AppConstants.bodySmall.copyWith(
                        color: color,
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
    if (_heatmapHours.isEmpty || _heatmapValues.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: AppConstants.cardBackground,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(color: AppConstants.dividerColor, width: 1),
        ),
        child: Text(
          'No hourly sales activity recorded for the selected range.',
          style: AppConstants.bodySmall.copyWith(
            color: AppConstants.textSecondary,
          ),
        ),
      );
    }

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxValue = _heatmapMaxValue <= 0 ? 1 : _heatmapMaxValue;

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
              ...days
                  .map(
                    (day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: AppConstants.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ],
          ),
          const SizedBox(height: 8),
          // Heatmap grid
          ...List.generate(_heatmapHours.length, (hourIndex) {
            final hour = _heatmapHours[hourIndex];
            final hourLabel = _formatHourLabel(hour);

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
                    final value = _heatmapValues[hourIndex][dayIndex];
                    final intensity = maxValue == 0 ? 0.0 : value / maxValue;

                    return Expanded(
                      child: Tooltip(
                        message:
                            '${days[dayIndex]} ${_formatHourRange(hour)}\n${Formatters.formatCurrency(value)}',
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
              border: Border.all(
                color: AppConstants.primaryOrange.withOpacity(0.3),
              ),
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
                    _heatmapSummary,
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
    if (_forecastInsights.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: AppConstants.cardBackground,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(color: AppConstants.dividerColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppConstants.primaryOrange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.insights_outlined,
                color: AppConstants.primaryOrange,
                size: 20,
              ),
            ),
            const SizedBox(width: AppConstants.paddingMedium),
            Expanded(
              child: Text(
                'Run a forecast to surface staffing, inventory, and promo recommendations tailored to this range.',
                style: AppConstants.bodyMedium.copyWith(
                  color: AppConstants.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _forecastInsights.map((insight) {
        final visual = _insightVisualForKind(insight.kind);
        final priorityColor = _priorityColor(insight.priority);
        final priorityLabel = _priorityLabel(insight.priority);
        final borderColor = insight.priority == _ForecastInsightPriority.high
            ? AppConstants.primaryOrange.withOpacity(0.5)
            : AppConstants.dividerColor;

        return Container(
          margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          decoration: BoxDecoration(
            color: AppConstants.cardBackground,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(color: borderColor, width: 1),
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
                      color: visual.accentColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      visual.icon,
                      color: visual.accentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppConstants.paddingMedium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.text,
                          style: AppConstants.bodyMedium.copyWith(
                            color: AppConstants.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppConstants.paddingSmall),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: priorityColor.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Priority: $priorityLabel',
                            style: AppConstants.bodySmall.copyWith(
                              color: priorityColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (insight.actionLabel != null) ...[
                const SizedBox(height: AppConstants.paddingSmall),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${insight.actionLabel} workflow coming soon!',
                          ),
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
                      insight.actionLabel!,
                      style: AppConstants.bodySmall.copyWith(
                        color: AppConstants.primaryOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
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
          const Text('Key Insights', style: AppConstants.headingSmall),
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
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusSmall,
                        ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (metric['isIncrease'] as bool
                                        ? AppConstants.successGreen
                                        : Colors.red)
                                    .withOpacity(0.2),
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
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusSmall,
                        ),
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
                            style: AppConstants.bodySmall.copyWith(
                              fontSize: 10,
                            ),
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
                            style: AppConstants.bodySmall.copyWith(
                              fontSize: 10,
                            ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isIncrease
                                    ? AppConstants.successGreen
                                    : Colors.red)
                                .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isIncrease
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: isIncrease
                                ? AppConstants.successGreen
                                : Colors.red,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${change.abs().toStringAsFixed(0)}%',
                            style: AppConstants.bodySmall.copyWith(
                              color: isIncrease
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
                          topLeft: isFirst
                              ? const Radius.circular(6)
                              : Radius.zero,
                          bottomLeft: isFirst
                              ? const Radius.circular(6)
                              : Radius.zero,
                          topRight: isLast
                              ? const Radius.circular(6)
                              : Radius.zero,
                          bottomRight: isLast
                              ? const Radius.circular(6)
                              : Radius.zero,
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
                          topLeft: isFirst
                              ? const Radius.circular(6)
                              : Radius.zero,
                          bottomLeft: isFirst
                              ? const Radius.circular(6)
                              : Radius.zero,
                          topRight: isLast
                              ? const Radius.circular(6)
                              : Radius.zero,
                          bottomRight: isLast
                              ? const Radius.circular(6)
                              : Radius.zero,
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
        'description':
            'Revenue forecast shows a 29.2% increase, driven by upcoming events and weather patterns.',
      },
      {
        'icon': Icons.restaurant,
        'color': AppConstants.primaryOrange,
        'title': 'Main Course Surge',
        'description':
            'Main Course category expected to grow by 21%, suggesting increased demand for full meals.',
      },
      {
        'icon': Icons.delivery_dining,
        'color': Colors.blue,
        'title': 'Channel Consistency',
        'description':
            'Order channel distribution remains stable at 65-25-10, with growth across all channels.',
      },
      {
        'icon': Icons.lightbulb_outline,
        'color': AppConstants.warningYellow,
        'title': 'Recommended Actions',
        'description':
            'Stock up on Pasta ingredients. Add 2 servers for peak hours. Promote comfort food during rainy days.',
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
    if (_startDate == null)
      return 'Showing: ${Formatters.formatDate(DateTime.now())}';
    if (_endDate == null)
      return 'Showing: ${Formatters.formatDate(_startDate!)}';
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
      final rangeDays = _selectedRangeInDays();
      final transactionsFuture = _transactionService.fetchTransactions();

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
        fallbackRangeDays: rangeDays,
      );
      final impactsFuture = _analyticsCalendarService.fetchImpacts(
        start: monthStart,
        end: monthEnd,
        fallbackRangeDays: rangeDays,
      );

      final transactions = await transactionsFuture;
      final calendar = await calendarFuture;
      final impacts = await impactsFuture;
      final analyticsSnapshot = _calculateHistoricalAnalytics(transactions);
      final resolvedRange = _resolveActiveDateRange();

      final categorySnapshots = analyticsSnapshot.categoryBreakdown
          .map(
            (category) => HistoricalCategorySnapshot(
              name: category.name,
              orders: category.quantity,
              revenue: category.revenue,
            ),
          )
          .toList();
      final channelSnapshots = analyticsSnapshot.channelBreakdown
          .map(
            (channel) => HistoricalChannelSnapshot(
              name: channel.name,
              orders: channel.orders,
              revenue: channel.revenue,
              share: channel.share,
              peakLabel: channel.peakLabel,
            ),
          )
          .toList();
      final topSellerSnapshots = analyticsSnapshot.topSellers
          .map(
            (seller) => HistoricalTopSellerSnapshot(
              name: seller.name,
              orders: seller.quantity,
              revenue: seller.revenue,
            ),
          )
          .toList();

      final forecastRangeStart = resolvedRange.previousStart;
      final forecastRangeEnd = resolvedRange.end;
      final transactionsForForecast = transactions.where((record) {
        final day = _dateOnly(record.timestamp);
        return !day.isBefore(forecastRangeStart) &&
            !day.isAfter(forecastRangeEnd);
      }).toList();
      final forecastInputTransactions =
          transactionsForForecast.isNotEmpty ? transactionsForForecast : transactions;

      final forecastResult = _forecastService.computeForecast(
        startDate: now,
        rangeDays: rangeDays,
        transactions: forecastInputTransactions,
        eventImpacts: impacts,
        historicalRangeStart: resolvedRange.start,
        historicalRangeEnd: resolvedRange.end,
        historicalRevenue: analyticsSnapshot.totalRevenue,
        historicalOrders: analyticsSnapshot.totalOrders,
        historicalAverageOrderValue: analyticsSnapshot.averageOrderValue,
        categories: categorySnapshots,
        channels: channelSnapshots,
        topSellers: topSellerSnapshots,
      );

      final insightResult = _generateForecastInsights(
        forecastResult: forecastResult,
        impacts: impacts,
        categorySnapshots: categorySnapshots,
        topSellerSnapshots: topSellerSnapshots,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _forecasts = forecastResult.forecasts;
        _forecastProjectedSeries = forecastResult.projectedSeries;
        _forecastActualSeries = forecastResult.actualSeries;
        _forecastCategoryDemand = forecastResult.categoryDemand;
        _forecastChannelDemand = forecastResult.channelDemand;
        _forecastMenuPredictions = forecastResult.menuPredictions;
        _forecastTotalRevenue = forecastResult.totalPredictedRevenue;
        _forecastTotalOrders = forecastResult.totalPredictedOrders;
        _forecastAverageOrderValue = forecastResult.averageOrderValue;
        _forecastRevenueChangePercent = forecastResult.revenueChangePercent;
        _forecastOrdersChangePercent = forecastResult.orderChangePercent;
        _forecastAovChangePercent = forecastResult.aovChangePercent;
        _forecastAverageConfidence = forecastResult.averageConfidence;
        _forecastRecentAccuracy = forecastResult.recentAccuracy;
        _forecastOverallAccuracy = forecastResult.salesAccuracy;
        _forecastAccuracyTrend = forecastResult.accuracyTrend;
        _forecastTrafficAccuracy = forecastResult.trafficAccuracy;
        _forecastPeakAccuracy = forecastResult.peakAccuracy;
        _forecastAction = insightResult.action;
        _forecastInsights = insightResult.insights;
        _calendarMonth = calendar;
        _eventImpacts = impacts;
        _applyAnalyticsSnapshot(analyticsSnapshot);
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

  _ForecastInsightResult _generateForecastInsights({
    required ForecastResult forecastResult,
    required List<EventImpact> impacts,
    required List<HistoricalCategorySnapshot> categorySnapshots,
    required List<HistoricalTopSellerSnapshot> topSellerSnapshots,
  }) {
    final insights = <_ForecastInsight>[];
    _ForecastActionRecommendation? action;

    if (forecastResult.projectedSeries.isNotEmpty) {
      final strongestDay = forecastResult.projectedSeries.reduce(
        (a, b) => a.revenue >= b.revenue ? a : b,
      );
      final revenueLabel = Formatters.formatCurrency(strongestDay.revenue);
      final dateLabel = DateFormat('EEE, MMM d').format(strongestDay.date);
      insights.add(
        _ForecastInsight(
          text:
              'Peak demand expected on $dateLabel with projected revenue of $revenueLabel. Staff 2 extra team members for lunch and dinner.',
          priority: _ForecastInsightPriority.high,
          kind: _ForecastInsightKind.staffing,
          actionLabel: 'Adjust Staffing',
        ),
      );
      action ??= _ForecastActionRecommendation(
        title: 'Boost staffing on $dateLabel',
        subtitle: 'Forecast peak ~ $revenueLabel. Add coverage for 11AM-2PM & 6-9PM.',
        kind: _ForecastInsightKind.staffing,
        priority: _ForecastInsightPriority.high,
      );
    }

    final upcomingImpacts = impacts
      .where((impact) => _isWithinSelectedForecastRange(impact.date))
        .where((impact) => (impact.impactPercent ?? 0).abs() >= 6)
        .toList()
      ..sort(
        (a, b) => (b.impactPercent ?? 0).abs().compareTo(
          (a.impactPercent ?? 0).abs(),
        ),
      );

    if (upcomingImpacts.isNotEmpty) {
      final leadImpact = upcomingImpacts.first;
      final dateLabel = DateFormat('EEE, MMM d').format(leadImpact.date);
      final percentLabel = _formatDelta(leadImpact.impactPercent) ?? '0%';
      final isPositive = (leadImpact.impactPercent ?? 0) >= 0;
      final insightText = isPositive
          ? 'Expect a $percentLabel lift on $dateLabel due to ${leadImpact.eventName}. Promote bundles and prep popular items early.'
          : '$percentLabel headwind on $dateLabel from ${leadImpact.eventName}. Prepare delivery promos and keep comfort food ready.';
      insights.add(
        _ForecastInsight(
          text: insightText,
          priority:
              isPositive ? _ForecastInsightPriority.high : _ForecastInsightPriority.high,
          kind: isPositive
              ? _ForecastInsightKind.inventory
              : _ForecastInsightKind.promo,
          actionLabel: isPositive ? 'Plan Specials' : 'Launch Promo',
        ),
      );
      action ??= _ForecastActionRecommendation(
        title: isPositive
            ? 'Prep for ${leadImpact.eventName}'
            : 'Mitigate ${leadImpact.eventName}',
        subtitle: isPositive
            ? 'Stock signature dishes before $dateLabel; forecast boost $percentLabel.'
            : 'Schedule rainy-day offer for $dateLabel to offset $percentLabel dip.',
        kind:
            isPositive ? _ForecastInsightKind.inventory : _ForecastInsightKind.promo,
        priority: _ForecastInsightPriority.high,
      );
    }

    final categoryGrowth = forecastResult.categoryDemand
        .where((category) => !category.changePercent.isNaN)
        .toList()
      ..sort((a, b) => b.changePercent.compareTo(a.changePercent));

    if (categoryGrowth.isNotEmpty) {
      final leader = categoryGrowth.first;
      final changeLabel = _formatDelta(leader.changePercent) ?? '+0%';
      insights.add(
        _ForecastInsight(
          text:
              '${leader.name} demand projected at ${leader.predictedOrders} orders ($changeLabel). Ensure prep and line capacity by midday.',
          priority: _ForecastInsightPriority.medium,
          kind: _ForecastInsightKind.inventory,
          actionLabel: 'Update Prep List',
        ),
      );
      if (leader.changePercent > 0) {
        action ??= _ForecastActionRecommendation(
          title: 'Stock up ${leader.name}',
          subtitle:
              'Forecast ${leader.predictedOrders} orders ($changeLabel). Order ingredients ahead of weekend.',
          kind: _ForecastInsightKind.inventory,
          priority: _ForecastInsightPriority.medium,
        );
      }
    }

    final menuTrends = forecastResult.menuPredictions
        .where((item) => item.status == MenuPredictionStatus.rising)
        .toList()
      ..sort((a, b) => b.changePercent.compareTo(a.changePercent));
    if (menuTrends.isNotEmpty) {
      final rising = menuTrends.first;
      final changeLabel = _formatDelta(rising.changePercent) ?? '+0%';
      insights.add(
        _ForecastInsight(
          text:
              '${rising.name} projected at ${rising.predictedOrders} orders ($changeLabel). Feature it on the specials board.',
          priority: _ForecastInsightPriority.medium,
          kind: _ForecastInsightKind.promo,
          actionLabel: 'Promote Item',
        ),
      );
    } else if (forecastResult.menuPredictions.isNotEmpty) {
      final declining = forecastResult.menuPredictions
          .where((item) => item.status == MenuPredictionStatus.declining)
          .toList();
      if (declining.isNotEmpty) {
        final item = declining.first;
        final changeLabel = _formatDelta(item.changePercent) ?? '0%';
        insights.add(
          _ForecastInsight(
            text:
                '${item.name} may soften to ${item.predictedOrders} orders ($changeLabel). Consider a combo to lift interest.',
            priority: _ForecastInsightPriority.low,
            kind: _ForecastInsightKind.promo,
            actionLabel: 'Create Combo',
          ),
        );
      }
    }

    if (insights.isEmpty) {
      insights.add(
        const _ForecastInsight(
          text: 'Forecast ready. Use the calendar and demand widgets to tailor staffing and promos.',
          priority: _ForecastInsightPriority.low,
          kind: _ForecastInsightKind.general,
        ),
      );
    }

    action ??= _ForecastActionRecommendation(
      title: 'Refresh weekend prep list',
      subtitle:
          'Forecast totals exceed historical average. Align staffing, mise en place, and promos to capture demand.',
      kind: _ForecastInsightKind.general,
      priority: _ForecastInsightPriority.medium,
    );

    return _ForecastInsightResult(
      action: action!,
      insights: List<_ForecastInsight>.unmodifiable(insights),
    );
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
    for (
      var current = first;
      !current.isAfter(last);
      current = current.add(const Duration(days: 1))
    ) {
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

  _HistoricalAnalyticsSnapshot _calculateHistoricalAnalytics(
    List<TransactionRecord> allTransactions,
  ) {
    final range = _resolveActiveDateRange();
    final filtered = <TransactionRecord>[];
    final previous = <TransactionRecord>[];

    for (final record in allTransactions) {
      final day = _dateOnly(record.timestamp);
      if (!day.isBefore(range.start) && !day.isAfter(range.end)) {
        filtered.add(record);
      } else if (!day.isBefore(range.previousStart) &&
          !day.isAfter(range.previousEnd)) {
        previous.add(record);
      }
    }

    final totalRevenue = filtered.fold<double>(
      0.0,
      (sum, record) => sum + record.saleAmount,
    );
    final totalOrders = filtered.length;
    final averageOrderValue = totalOrders == 0
        ? 0.0
        : totalRevenue / totalOrders;

    final previousRevenue = previous.fold<double>(
      0.0,
      (sum, record) => sum + record.saleAmount,
    );
    final previousOrders = previous.length;
    final previousAverageOrderValue = previousOrders == 0
        ? 0.0
        : previousRevenue / previousOrders;

    final revenueChangePercent = _percentChange(totalRevenue, previousRevenue);
    final orderChangePercent = _percentChange(
      totalOrders.toDouble(),
      previousOrders.toDouble(),
    );
    final aovChangePercent = _percentChange(
      averageOrderValue,
      previousAverageOrderValue,
    );

    final dailyTotals = <DateTime, double>{};
    for (final record in filtered) {
      final day = _dateOnly(record.timestamp);
      dailyTotals[day] = (dailyTotals[day] ?? 0) + record.saleAmount;
    }

    final dailyPoints = <_DailyRevenuePoint>[];
    double maxDailyRevenue = 0;
    for (var i = 0; i < range.lengthInDays; i++) {
      final day = _dateOnly(range.start.add(Duration(days: i)));
      final revenue = dailyTotals[day] ?? 0;
      maxDailyRevenue = math.max(maxDailyRevenue, revenue);
      dailyPoints.add(_DailyRevenuePoint(date: day, revenue: revenue));
    }

    final salesTrendMaxY = maxDailyRevenue <= 0
        ? 0.0
        : _niceCeiling(maxDailyRevenue * 1.1);

    final categoryAggregates = <String, _CategoryAggregate>{};
    final itemAggregates = <String, _TopSellerAggregate>{};
    final paymentAggregates = <String, _PaymentAggregate>{};
    final channelAggregates = <String, _ChannelAccumulator>{};
    final heatmapMatrix = <int, List<double>>{};
    final hourBuckets = <int>{};
    double heatmapMaxValue = 0.0;
    double peakSlotValue = 0.0;
    int? peakSlotHour;
    int? peakSlotDay;

    for (final record in filtered) {
      final revenue = record.saleAmount;
      final dayIndex = (record.timestamp.weekday + 6) % 7;
      final hour = record.timestamp.hour;

      final row = heatmapMatrix.putIfAbsent(
        hour,
        () => List<double>.filled(7, 0.0),
      );
      row[dayIndex] += revenue;
      heatmapMaxValue = math.max(heatmapMaxValue, row[dayIndex]);
      if (row[dayIndex] > peakSlotValue) {
        peakSlotValue = row[dayIndex];
        peakSlotHour = hour;
        peakSlotDay = dayIndex;
      }
      hourBuckets.add(hour);

      final channelName = _resolveChannel(record);
      final channelAcc = channelAggregates.putIfAbsent(
        channelName,
        () => _ChannelAccumulator(),
      );
      channelAcc.revenue += revenue;
      channelAcc.orders += 1;
      final slotKey = '${dayIndex}_$hour';
      final slotValue = (channelAcc.slotTotals[slotKey] ?? 0) + revenue;
      channelAcc.slotTotals[slotKey] = slotValue;
      if (slotValue > channelAcc.bestSlotValue) {
        channelAcc.bestSlotValue = slotValue;
        channelAcc.bestHour = hour;
        channelAcc.bestDayIndex = dayIndex;
      }

      final paymentMethod = record.paymentMethod.trim().isEmpty
          ? 'Unknown'
          : record.paymentMethod.trim();
      final paymentAcc = paymentAggregates.putIfAbsent(
        paymentMethod,
        () => _PaymentAggregate(),
      );
      paymentAcc.count += 1;
      paymentAcc.amount += revenue;

      for (final item in record.items) {
        final rawCategory = (item.categoryLabel ?? item.category)?.trim();
        final categoryName = (rawCategory != null && rawCategory.isNotEmpty)
            ? rawCategory
            : 'Uncategorized';
        final categoryAcc = categoryAggregates.putIfAbsent(
          categoryName,
          () => _CategoryAggregate(),
        );
        categoryAcc.quantity += item.quantity;
        categoryAcc.revenue += item.totalPrice;

        final itemAcc = itemAggregates.putIfAbsent(
          item.name,
          () => _TopSellerAggregate(item.name),
        );
        itemAcc.quantity += item.quantity;
        itemAcc.revenue += item.totalPrice;
      }
    }

    final categoryBreakdown =
        categoryAggregates.entries
            .map(
              (entry) => _CategoryBreakdown(
                name: entry.key,
                quantity: entry.value.quantity,
                revenue: entry.value.revenue,
              ),
            )
            .toList()
          ..sort((a, b) {
            final revenueCompare = b.revenue.compareTo(a.revenue);
            return revenueCompare != 0
                ? revenueCompare
                : b.quantity.compareTo(a.quantity);
          });

    final maxCategoryQuantity = categoryBreakdown.isEmpty
        ? 0
        : categoryBreakdown.map((c) => c.quantity).reduce(math.max);

    final topSellers =
        itemAggregates.values
            .map(
              (value) => _TopSeller(
                name: value.name,
                quantity: value.quantity,
                revenue: value.revenue,
              ),
            )
            .toList()
          ..sort((a, b) {
            final revenueCompare = b.revenue.compareTo(a.revenue);
            return revenueCompare != 0
                ? revenueCompare
                : b.quantity.compareTo(a.quantity);
          });
    if (topSellers.length > 10) {
      topSellers.removeRange(10, topSellers.length);
    }

    final paymentBreakdown =
        paymentAggregates.entries
            .map(
              (entry) => _PaymentBreakdown(
                method: entry.key,
                count: entry.value.count,
                amount: entry.value.amount,
              ),
            )
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));

    final totalPaymentRevenue = paymentBreakdown.fold<double>(
      0.0,
      (sum, item) => sum + item.amount,
    );

    final sortedHours = hourBuckets.toList()..sort();
    final heatmapValues = sortedHours
        .map(
          (hour) => List<double>.from(
            heatmapMatrix[hour] ?? List<double>.filled(7, 0.0),
          ),
        )
        .toList();

    final hasTransactions = filtered.isNotEmpty;
    final heatmapSummary = !hasTransactions
        ? 'No transactions yet.'
        : (peakSlotHour != null && peakSlotValue > 0)
        ? 'Busiest window: ${_dayNames[peakSlotDay ?? 0]} '
              '${_formatHourRange(peakSlotHour!)} '
              '(${Formatters.formatCurrency(peakSlotValue)})'
        : 'No significant peak detected in this range.';

    final channelBreakdown = channelAggregates.entries.map((entry) {
      final acc = entry.value;
      final share = totalRevenue <= 0
          ? 0.0
          : (acc.revenue / totalRevenue).clamp(0.0, 1.0);
      String? peakLabel;
      if (acc.bestHour != null && acc.bestSlotValue > 0) {
        final dayName = _dayNames[acc.bestDayIndex ?? 0];
        peakLabel = '$dayName ${_formatHourRange(acc.bestHour!)}';
      }
      return _ChannelBreakdown(
        name: entry.key,
        orders: acc.orders,
        revenue: acc.revenue,
        share: share,
        peakLabel: peakLabel,
      );
    }).toList()..sort((a, b) => b.revenue.compareTo(a.revenue));

    final peakHourRevenue = (peakSlotHour != null && peakSlotValue > 0)
        ? peakSlotValue
        : 0.0;
    final peakHourWindowLabel = (peakSlotHour != null && peakSlotValue > 0)
        ? '${_dayNames[peakSlotDay ?? 0]} ${_formatHourRange(peakSlotHour!)}'
        : '—';

    return _HistoricalAnalyticsSnapshot(
      filteredTransactions: filtered,
      totalRevenue: totalRevenue,
      totalOrders: totalOrders,
      averageOrderValue: averageOrderValue,
      revenueChangePercent: revenueChangePercent,
      orderChangePercent: orderChangePercent,
      aovChangePercent: aovChangePercent,
      dailyRevenuePoints: dailyPoints,
      salesTrendMaxY: salesTrendMaxY,
      categoryBreakdown: categoryBreakdown,
      maxCategoryQuantity: maxCategoryQuantity,
      channelBreakdown: channelBreakdown,
      topSellers: topSellers,
      paymentBreakdown: paymentBreakdown,
      totalPaymentRevenue: totalPaymentRevenue,
      heatmapHours: sortedHours,
      heatmapValues: heatmapValues,
      heatmapMaxValue: heatmapMaxValue,
      heatmapSummary: heatmapSummary,
      peakHourRevenue: peakHourRevenue,
      peakHourWindowLabel: peakHourWindowLabel,
    );
  }

  void _applyAnalyticsSnapshot(_HistoricalAnalyticsSnapshot snapshot) {
    _filteredTransactions = snapshot.filteredTransactions;
    _totalRevenue = snapshot.totalRevenue;
    _totalOrders = snapshot.totalOrders;
    _averageOrderValue = snapshot.averageOrderValue;
    _revenueChangePercent = snapshot.revenueChangePercent;
    _orderChangePercent = snapshot.orderChangePercent;
    _aovChangePercent = snapshot.aovChangePercent;
    _dailyRevenuePoints = snapshot.dailyRevenuePoints;
    _salesTrendMaxY = snapshot.salesTrendMaxY;
    _categoryBreakdown = snapshot.categoryBreakdown;
    _maxCategoryQuantity = snapshot.maxCategoryQuantity;
    _channelBreakdown = snapshot.channelBreakdown;
    _topSellers = snapshot.topSellers;
    _paymentBreakdown = snapshot.paymentBreakdown;
    _totalPaymentRevenue = snapshot.totalPaymentRevenue;
    _heatmapHours = snapshot.heatmapHours;
    _heatmapValues = snapshot.heatmapValues;
    _heatmapMaxValue = snapshot.heatmapMaxValue;
    _heatmapSummary = snapshot.heatmapSummary;
    _peakHourRevenue = snapshot.peakHourRevenue;
    _peakHourWindowLabel = snapshot.peakHourWindowLabel;
  }

  _ResolvedDateRange _resolveActiveDateRange() {
    final today = DateTime.now();
    DateTime start = _startDate ?? today.subtract(const Duration(days: 6));
    DateTime end = _endDate ?? _startDate ?? today;

    start = _dateOnly(start);
    end = _dateOnly(end);

    if (start.isAfter(end)) {
      final temp = start;
      start = end;
      end = temp;
    }

    final lengthInDays = end.difference(start).inDays + 1;
    final previousEnd = start.subtract(const Duration(days: 1));
    final previousStart = previousEnd.subtract(
      Duration(days: lengthInDays - 1),
    );

    return _ResolvedDateRange(
      start: start,
      end: end,
      previousStart: _dateOnly(previousStart),
      previousEnd: _dateOnly(previousEnd),
      lengthInDays: lengthInDays,
    );
  }

  double? _percentChange(double current, double previous) {
    if (current.isNaN || previous.isNaN) {
      return null;
    }
    if (current.isInfinite || previous.isInfinite) {
      return null;
    }
    if (previous.abs() < 0.0001) {
      if (current.abs() < 0.0001) {
        return 0;
      }
      return double.nan;
    }
    final delta = ((current - previous) / previous) * 100;
    if (delta.isNaN || delta.isInfinite) {
      return null;
    }
    return delta;
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  double _niceCeiling(double value) {
    if (value <= 0) {
      return 0;
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
      return 100;
    }
    final target = maxY / 5;
    final magnitude = math
        .pow(10, (math.log(target) / math.ln10).floor())
        .toDouble();
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
    return interval <= 0 ? 1 : interval;
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

  Color _deltaColor(double? percent) {
    if (percent == null || percent.isNaN || percent.abs() < 0.05) {
      return AppConstants.textSecondary;
    }
    if (percent > 0) {
      return AppConstants.successGreen;
    }
    if (percent < 0) {
      return AppConstants.errorRed;
    }
    return AppConstants.textSecondary;
  }

  Color _priorityColor(_ForecastInsightPriority priority) {
    switch (priority) {
      case _ForecastInsightPriority.high:
        return AppConstants.errorRed;
      case _ForecastInsightPriority.medium:
        return AppConstants.warningYellow;
      case _ForecastInsightPriority.low:
        return AppConstants.textSecondary;
    }
  }

  String _priorityLabel(_ForecastInsightPriority priority) {
    switch (priority) {
      case _ForecastInsightPriority.high:
        return 'High';
      case _ForecastInsightPriority.medium:
        return 'Medium';
      case _ForecastInsightPriority.low:
        return 'Low';
    }
  }

  _ForecastInsightVisual _insightVisualForKind(_ForecastInsightKind kind) {
    switch (kind) {
      case _ForecastInsightKind.staffing:
        return const _ForecastInsightVisual(
          icon: Icons.people_alt,
          accentColor: AppConstants.primaryOrange,
        );
      case _ForecastInsightKind.inventory:
        return const _ForecastInsightVisual(
          icon: Icons.inventory_2,
          accentColor: AppConstants.successGreen,
        );
      case _ForecastInsightKind.promo:
        return const _ForecastInsightVisual(
          icon: Icons.campaign,
          accentColor: Colors.lightBlue,
        );
      case _ForecastInsightKind.general:
      default:
        return const _ForecastInsightVisual(
          icon: Icons.insights,
          accentColor: AppConstants.primaryOrange,
        );
    }
  }

  String _formatHourLabel(int hour) {
    final time = DateTime(0, 1, 1, hour);
    return DateFormat('h a').format(time);
  }

  String _formatHourRange(int hour) {
    final start = DateTime(0, 1, 1, hour);
    final end = start.add(const Duration(hours: 1));
    final startLabel = DateFormat('h a').format(start);
    final endLabel = DateFormat('h a').format(end);
    return '$startLabel - $endLabel';
  }

  String _normalizeChannelName(String value) {
    final lower = value.trim().toLowerCase();
    if (lower.isEmpty) {
      return 'Dine-In';
    }
    if (lower.contains('dine') || lower.contains('table')) {
      return 'Dine-In';
    }
    if (lower.contains('take') ||
        lower.contains('to-go') ||
        lower.contains('carry')) {
      return 'Takeout';
    }
    if (lower.contains('deliver')) {
      return 'Delivery';
    }
    if (lower.contains('pickup') || lower.contains('pick-up')) {
      return 'Pickup';
    }
    if (lower.contains('online') ||
        lower.contains('web') ||
        lower.contains('app')) {
      return 'Online';
    }
    if (lower.contains('curb') || lower.contains('drive')) {
      return 'Curbside';
    }
    if (lower.contains('walk')) {
      return 'Walk-In';
    }
    if (lower.contains('kiosk')) {
      return 'Kiosk';
    }
    return value.trim();
  }

  String _resolveChannel(TransactionRecord record) {
    final metadata = record.metadata ?? {};
    final candidates = <String?>[
      metadata['channel']?.toString(),
      metadata['orderChannel']?.toString(),
      metadata['orderType']?.toString(),
      metadata['source']?.toString(),
      record.tableNumber,
    ];
    for (final candidate in candidates) {
      if (candidate == null) {
        continue;
      }
      final normalized = _normalizeChannelName(candidate);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return 'Dine-In';
  }

  IconData _channelIcon(String channelName) {
    final lower = channelName.toLowerCase();
    if (lower.contains('dine')) {
      return Icons.restaurant_menu;
    }
    if (lower.contains('take')) {
      return Icons.shopping_bag;
    }
    if (lower.contains('deliver')) {
      return Icons.delivery_dining;
    }
    if (lower.contains('pickup')) {
      return Icons.storefront;
    }
    if (lower.contains('online') || lower.contains('app')) {
      return Icons.smartphone;
    }
    if (lower.contains('curb') || lower.contains('drive')) {
      return Icons.directions_car;
    }
    if (lower.contains('walk')) {
      return Icons.directions_walk;
    }
    if (lower.contains('kiosk')) {
      return Icons.point_of_sale;
    }
    return Icons.receipt_long;
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

class _ResolvedDateRange {
  const _ResolvedDateRange({
    required this.start,
    required this.end,
    required this.previousStart,
    required this.previousEnd,
    required this.lengthInDays,
  });

  final DateTime start;
  final DateTime end;
  final DateTime previousStart;
  final DateTime previousEnd;
  final int lengthInDays;
}

class _HistoricalAnalyticsSnapshot {
  _HistoricalAnalyticsSnapshot({
    required List<TransactionRecord> filteredTransactions,
    required this.totalRevenue,
    required this.totalOrders,
    required this.averageOrderValue,
    required this.revenueChangePercent,
    required this.orderChangePercent,
    required this.aovChangePercent,
    required List<_DailyRevenuePoint> dailyRevenuePoints,
    required this.salesTrendMaxY,
    required List<_CategoryBreakdown> categoryBreakdown,
    required this.maxCategoryQuantity,
    required List<_ChannelBreakdown> channelBreakdown,
    required List<_TopSeller> topSellers,
    required List<_PaymentBreakdown> paymentBreakdown,
    required this.totalPaymentRevenue,
    required List<int> heatmapHours,
    required List<List<double>> heatmapValues,
    required this.heatmapMaxValue,
    required this.heatmapSummary,
    required this.peakHourRevenue,
    required this.peakHourWindowLabel,
  }) : filteredTransactions = List<TransactionRecord>.unmodifiable(
         filteredTransactions,
       ),
       dailyRevenuePoints = List<_DailyRevenuePoint>.unmodifiable(
         dailyRevenuePoints,
       ),
       categoryBreakdown = List<_CategoryBreakdown>.unmodifiable(
         categoryBreakdown,
       ),
       channelBreakdown = List<_ChannelBreakdown>.unmodifiable(
         channelBreakdown,
       ),
       topSellers = List<_TopSeller>.unmodifiable(topSellers),
       paymentBreakdown = List<_PaymentBreakdown>.unmodifiable(
         paymentBreakdown,
       ),
       heatmapHours = List<int>.unmodifiable(heatmapHours),
       heatmapValues = List<List<double>>.unmodifiable(
         heatmapValues.map((row) => List<double>.unmodifiable(row)),
       );

  final List<TransactionRecord> filteredTransactions;
  final double totalRevenue;
  final int totalOrders;
  final double averageOrderValue;
  final double? revenueChangePercent;
  final double? orderChangePercent;
  final double? aovChangePercent;
  final List<_DailyRevenuePoint> dailyRevenuePoints;
  final double salesTrendMaxY;
  final List<_CategoryBreakdown> categoryBreakdown;
  final int maxCategoryQuantity;
  final List<_ChannelBreakdown> channelBreakdown;
  final List<_TopSeller> topSellers;
  final List<_PaymentBreakdown> paymentBreakdown;
  final double totalPaymentRevenue;
  final List<int> heatmapHours;
  final List<List<double>> heatmapValues;
  final double heatmapMaxValue;
  final String heatmapSummary;
  final double peakHourRevenue;
  final String peakHourWindowLabel;
}

class _DailyRevenuePoint {
  const _DailyRevenuePoint({required this.date, required this.revenue});

  final DateTime date;
  final double revenue;
}

class _CategoryBreakdown {
  const _CategoryBreakdown({
    required this.name,
    required this.quantity,
    required this.revenue,
  });

  final String name;
  final int quantity;
  final double revenue;
}

class _ChannelBreakdown {
  const _ChannelBreakdown({
    required this.name,
    required this.orders,
    required this.revenue,
    required this.share,
    this.peakLabel,
  });

  final String name;
  final int orders;
  final double revenue;
  final double share;
  final String? peakLabel;
}

class _TopSeller {
  const _TopSeller({
    required this.name,
    required this.quantity,
    required this.revenue,
  });

  final String name;
  final int quantity;
  final double revenue;
}

class _PaymentBreakdown {
  const _PaymentBreakdown({
    required this.method,
    required this.count,
    required this.amount,
  });

  final String method;
  final int count;
  final double amount;
}

class _CategoryAggregate {
  int quantity = 0;
  double revenue = 0;
}

class _TopSellerAggregate {
  _TopSellerAggregate(this.name);

  final String name;
  int quantity = 0;
  double revenue = 0;
}

class _PaymentAggregate {
  int count = 0;
  double amount = 0;
}

class _ChannelAccumulator {
  double revenue = 0;
  int orders = 0;
  final Map<String, double> slotTotals = <String, double>{};
  double bestSlotValue = 0;
  int? bestHour;
  int? bestDayIndex;
}

enum _ForecastInsightPriority {
  low,
  medium,
  high,
}

enum _ForecastInsightKind {
  general,
  staffing,
  inventory,
  promo,
}

class _ForecastInsight {
  const _ForecastInsight({
    required this.text,
    required this.priority,
    required this.kind,
    this.actionLabel,
  });

  final String text;
  final _ForecastInsightPriority priority;
  final _ForecastInsightKind kind;
  final String? actionLabel;
}

class _ForecastActionRecommendation {
  const _ForecastActionRecommendation({
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.priority,
  });

  final String title;
  final String subtitle;
  final _ForecastInsightKind kind;
  final _ForecastInsightPriority priority;
}

class _ForecastInsightResult {
  const _ForecastInsightResult({
    required this.action,
    required this.insights,
  });

  final _ForecastActionRecommendation action;
  final List<_ForecastInsight> insights;
}

class _ForecastInsightVisual {
  const _ForecastInsightVisual({
    required this.icon,
    required this.accentColor,
  });

  final IconData icon;
  final Color accentColor;
}
