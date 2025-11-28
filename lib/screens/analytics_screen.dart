import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/analytics_calendar_model.dart';
import '../models/menu_item_model.dart';
import '../models/sales_data_model.dart';
import '../services/analytics_calendar_service.dart';
import '../services/menu_service.dart';
import '../services/transaction_service.dart';
import '../services/forecast_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/stat_card.dart';

enum ForecastRangeOption { sevenDays, fourteenDays, thirtyDays }

extension ForecastRangeOptionX on ForecastRangeOption {
  String get label {
    switch (this) {
      case ForecastRangeOption.sevenDays:
        return '7 Days';
      case ForecastRangeOption.fourteenDays:
        return '14 Days';
      case ForecastRangeOption.thirtyDays:
        return '30 Days';
    }
  }

  int get days {
    switch (this) {
      case ForecastRangeOption.sevenDays:
        return 7;
      case ForecastRangeOption.fourteenDays:
        return 14;
      case ForecastRangeOption.thirtyDays:
        return 30;
    }
  }
}

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

  // Forecast window used by calendar + impacts list
  DateTime _forecastRangeStart = DateTime.now();
  DateTime _forecastRangeEnd = DateTime.now();

  // Date range filters
  ForecastRangeOption _selectedForecastRange = ForecastRangeOption.sevenDays;

  // Date range picker
  DateTime? _startDate;
  DateTime? _endDate;

  // Calendar navigation
  DateTime _selectedCalendarMonth = DateTime.now();
  final TransactionService _transactionService = TransactionService();
  final MenuService _menuService = MenuService();
  StreamSubscription<List<TransactionRecord>>? _transactionsSubscription;
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
  // Cached map of available menu items by lowercase name for quick lookup
  final Map<String, MenuItem> _menuItemsByName = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final today = _dateOnly(DateTime.now());
    _forecastRangeStart = today;
    _forecastRangeEnd = today.add(Duration(days: _selectedRangeInDays() - 1));
    // Load initial data and subscribe to live transaction updates so
    // the analytics screen updates automatically when transactions change.
    _loadAnalyticsData();
    _transactionsSubscription = _transactionService
        .watchTransactions()
        .listen((records) => _onTransactionsStream(records), onError: (e) {
      // Keep UI stable but log/show a non-fatal error if needed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction stream error: $e'),
            backgroundColor: AppConstants.errorRed,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _transactionsSubscription?.cancel();
    super.dispose();
  }

  /// Called when the transaction stream emits new data.
  /// Recomputes analytics snapshot and forecast (using cached event impacts)
  /// without refetching calendar/impacts so the UI stays up-to-date.
  Future<void> _onTransactionsStream(List<TransactionRecord> transactions) async {
    try {
      final analyticsSnapshot = _calculateHistoricalAnalytics(transactions);

      // Prepare minimal snapshots needed by the forecasting service
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
        return !day.isBefore(forecastRangeStart) && !day.isAfter(forecastRangeEnd);
      }).toList();
      final forecastInputTransactions =
          transactionsForForecast.isNotEmpty ? transactionsForForecast : transactions;

      final forecastResult = _forecastService.computeForecast(
        startDate: DateTime.now(),
        rangeDays: _selectedRangeInDays(),
        transactions: forecastInputTransactions,
        eventImpacts: _eventImpacts,
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
        impacts: _eventImpacts,
        categorySnapshots: categorySnapshots,
        topSellerSnapshots: topSellerSnapshots,
      );

      if (!mounted) return;
      setState(() {
        _applyAnalyticsSnapshot(analyticsSnapshot);
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
        _isLoading = false;
      });
    } catch (e) {
      // Non-fatal: keep UI usable
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating analytics: $e'),
            backgroundColor: AppConstants.errorRed,
          ),
        );
      }
    }
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

  Widget _buildDateSelectorCard({
    required String title,
    required String subtitle,
  }) {
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
          Text(
            title,
            style: AppConstants.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: AppConstants.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppConstants.bodySmall.copyWith(
              color: AppConstants.textSecondary,
            ),
          ),
          const SizedBox(height: AppConstants.paddingSmall),
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
          const SizedBox(height: AppConstants.paddingSmall),
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
    );
  }

  /// Overview tab with historical data
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateSelectorCard(
            title: 'Historical Range',
            subtitle:
                'Select a single day or span to analyze actual performance metrics.',
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
                        color:
                            AppConstants.primaryOrange.withValues(alpha: 0.2),
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
                      children: ForecastRangeOption.values
                          .map(_buildForecastRangeButton)
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.paddingLarge),

          

          // Forecast Summary Cards
          const Text('Forecast Summary', style: AppConstants.headingSmall),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildForecastSummaryCards(),
          const SizedBox(height: AppConstants.paddingLarge),

          // Forecast Trend Chart removed from AI Forecast tab (moved to Comparison)

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
    final totalRevenueText = Formatters.formatCurrencyNoCents(_totalRevenue);
    final totalOrdersText = _countFormatter.format(_totalOrders);
    final averageOrderValueText = Formatters.formatCurrency(_averageOrderValue);
    final peakRevenueText = Formatters.formatCurrency(_peakHourRevenue);
    final peakDetail = _peakHourWindowLabel == '—'
        ? null
        : 'Peak: $_peakHourWindowLabel';

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
        ),
        const SizedBox(height: AppConstants.paddingMedium),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
        ),
      ],
    );
  }

  /// Forecast Range toggle button
  Widget _buildForecastRangeButton(ForecastRangeOption range) {
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
          range.label,
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
      final calendar = await _analyticsCalendarService.fetchMonth(
        month,
        fallbackRangeDays: _selectedRangeInDays(),
      );
      final impacts = await _analyticsCalendarService.fetchImpacts(
        start: _forecastRangeStart,
        end: _forecastRangeEnd,
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
        clipData: FlClipData.all(),
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
                      text: Formatters.formatCurrencyNoCents(spot.y),
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
          // Use a denser horizontal grid for smoother visual guidance.
          horizontalInterval: yInterval > 1 ? (yInterval / 2) : yInterval,
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
                    Formatters.formatCurrencyNoCents(value),
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
            spots: _sanitizeSpots(spots),
            isCurved: true,
            preventCurveOverShooting: true,
            curveSmoothness: 0.15,
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
                final weatherEmoji = weatherDay?.emoji ?? '–';
                final hasWeather = weatherDay != null &&
                  weatherEmoji.trim().isNotEmpty &&
                  weatherEmoji != '–';

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
                                weatherEmoji,
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
                    'Forecast Range (${_forecastRangeLabel()})',
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
      return _AnalyticsCard(
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
      return _AnalyticsCard(
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

    final rangeLabel = _forecastRangeLabel();

    if (_eventImpacts.isEmpty) {
      return _AnalyticsPlaceholder(
        icon: Icons.event_note,
        message: 'No upcoming events found for $rangeLabel.',
        detail:
            'Add entries in analytics_impacts that cover $rangeLabel to surface projections here.',
      );
    }

    final filteredImpacts = _eventImpacts
        .where((impact) => _isWithinSelectedForecastRange(impact.date))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (filteredImpacts.isEmpty) {
      return _AnalyticsCard(
        child: Column(
          children: [
            Icon(Icons.event_available, color: AppConstants.textSecondary),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              'No impacts detected within $rangeLabel.',
              style: AppConstants.bodySmall.copyWith(
                color: AppConstants.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return _AnalyticsCard(
      child: Column(
        children: filteredImpacts.map((impact) {
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
      return const _AnalyticsPlaceholder(
        icon: Icons.analytics_outlined,
        message: 'No category projections yet',
        detail:
            'Run analytics with recent transactions to forecast category demand.',
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

    return _AnalyticsCard(
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
    // If no predictions available, show the sample/demo content
    if (_forecastMenuPredictions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: AppConstants.cardBackground,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(color: AppConstants.dividerColor, width: 1),
        ),
        child: Column(
          children: [
            Center(
              child: Text(
                'No menu predictions available yet.',
                style: AppConstants.bodySmall.copyWith(
                  color: AppConstants.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Group predictions by status
    final stars = <MenuItemPrediction>[];
    final rising = <MenuItemPrediction>[];
    final declining = <MenuItemPrediction>[];
    for (final p in _forecastMenuPredictions) {
      switch (p.status) {
        case MenuPredictionStatus.star:
          stars.add(p);
          break;
        case MenuPredictionStatus.rising:
          rising.add(p);
          break;
        case MenuPredictionStatus.declining:
          declining.add(p);
          break;
      }
    }

    Widget buildGroup(String title, String subtitle, Color color, List<MenuItemPrediction> list) {
      if (list.isEmpty) return const SizedBox.shrink();
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
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppConstants.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        subtitle,
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
            ...list.map((pred) {
              final nameKey = pred.name.toLowerCase().trim();
              final menuMatch = _menuItemsByName[nameKey];
              final trend = pred.changePercent.isNaN
                  ? '0%'
                  : (pred.changePercent > 0 ? '+${pred.changePercent.toStringAsFixed(0)}%' : '${pred.changePercent.toStringAsFixed(0)}%');
              final isNegative = pred.changePercent < 0;

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
                      color: color,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pred.name, style: AppConstants.bodyMedium),
                          if (menuMatch == null)
                            Text('Not in menu', style: AppConstants.bodySmall.copyWith(color: AppConstants.textSecondary)),
                        ],
                      ),
                    ),
                    Text(
                      '${pred.predictedOrders} orders',
                      style: AppConstants.bodySmall.copyWith(
                        color: AppConstants.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        trend,
                        style: AppConstants.bodySmall.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (menuMatch == null)
                      ElevatedButton(
                        onPressed: () => _createMenuItemFromPrediction(pred),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryOrange,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        ),
                        child: const Text('Add', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              );
            }).toList(),
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
        children: [
          buildGroup('Star Performers', 'High demand expected', AppConstants.successGreen, stars),
          buildGroup('Rising Stars', 'Growing popularity', AppConstants.primaryOrange, rising),
          buildGroup('Declining Items', 'Consider promotion or removal', AppConstants.warningYellow, declining),
        ],
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
                              text: Formatters.formatCurrencyNoCents(spot.y),
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
                  // densify forecast chart horizontal lines
                  horizontalInterval: yInterval > 1 ? (yInterval / 2) : yInterval,
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
                      interval: yInterval,
                      getTitlesWidget: (value, meta) {
                          final label = value <= 0
                              ? '₱0'
                              : '₱${Formatters.formatCompactNumberNoDecimal(value)}';
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
                clipData: FlClipData.all(),
                lineBarsData: [
                  // Actual Sales - mirroring Historical Sales Trend
                  LineChartBarData(
                    spots: _sanitizeSpots(spotsActual),
                    isCurved: true,
                    preventCurveOverShooting: true,
                    curveSmoothness: 0.15,
                    color: AppConstants.successGreen,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                  ),
                  // Projected Sales
                  LineChartBarData(
                    spots: _sanitizeSpots(spotsProjected),
                    isCurved: true,
                    preventCurveOverShooting: true,
                    curveSmoothness: 0.15,
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

    // Normalize channel data into three canonical channels: Dine-In, Takeout, Delivery
    final totalOrders = _channelBreakdown.fold<int>(0, (s, c) => s + c.orders);

    int _ordersForPattern(List<String> patterns) {
      try {
        final item = _channelBreakdown.firstWhere((c) {
          final name = c.name.toLowerCase();
          return patterns.any((p) => name.contains(p));
        });
        return item.orders;
      } catch (e) {
        return 0;
      }
    }

    double _revenueForPattern(List<String> patterns) {
      try {
        final item = _channelBreakdown.firstWhere((c) {
          final name = c.name.toLowerCase();
          return patterns.any((p) => name.contains(p));
        });
        return item.revenue;
      } catch (e) {
        return 0.0;
      }
    }

    String? _peakForPattern(List<String> patterns) {
      try {
        final item = _channelBreakdown.firstWhere((c) {
          final name = c.name.toLowerCase();
          return patterns.any((p) => name.contains(p));
        });
        return item.peakLabel;
      } catch (e) {
        return null;
      }
    }

    final dineOrders = _ordersForPattern(['dine', 'dine-in', 'dine in']);
    final dineRevenue = _revenueForPattern(['dine', 'dine-in', 'dine in']);
    final dinePeak = _peakForPattern(['dine', 'dine-in', 'dine in']);

    final takeoutOrders = _ordersForPattern(['takeout', 'take-away', 'take away']);
    final takeoutRevenue = _revenueForPattern(['takeout', 'take-away', 'take away']);
    final takeoutPeak = _peakForPattern(['takeout', 'take-away', 'take away']);

    final deliveryOrders = _ordersForPattern(['delivery', 'deliver']);
    final deliveryRevenue = _revenueForPattern(['delivery', 'deliver']);
    final deliveryPeak = _peakForPattern(['delivery', 'deliver']);

    final channels = [
      {
        'key': 'Dine-In',
        'orders': dineOrders,
        'revenue': dineRevenue,
        'peak': dinePeak,
        'color': AppConstants.primaryOrange,
        'icon': Icons.restaurant_menu,
      },
      {
        'key': 'Takeout',
        'orders': takeoutOrders,
        'revenue': takeoutRevenue,
        'peak': takeoutPeak,
        'color': Colors.blue,
        'icon': Icons.shopping_bag,
      },
      {
        'key': 'Delivery',
        'orders': deliveryOrders,
        'revenue': deliveryRevenue,
        'peak': deliveryPeak,
        'color': AppConstants.successGreen,
        'icon': Icons.delivery_dining,
      },
    ];

    // Compute shares based only on the three canonical channels so they sum to 100%
    final channelsTotalOrders = (dineOrders + takeoutOrders + deliveryOrders);
    final total = channelsTotalOrders <= 0 ? 1 : channelsTotalOrders;

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.dividerColor, width: 1),
      ),
      child: Column(
        children: [
          // Visual percentage bar (Dine-In / Takeout / Delivery)
          Row(
            children: channels.map((channel) {
              final color = channel['color'] as Color;
              final orders = channel['orders'] as int;
              final share = orders / total;
              final flex = (share * 100).clamp(1, 100).round();
              final isFirst = channel == channels.first;
              final isLast = channel == channels.last;

              return Expanded(
                flex: flex,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.only(
                      topLeft: isFirst ? const Radius.circular(8) : Radius.zero,
                      bottomLeft: isFirst ? const Radius.circular(8) : Radius.zero,
                      topRight: isLast ? const Radius.circular(8) : Radius.zero,
                      bottomRight: isLast ? const Radius.circular(8) : Radius.zero,
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
          ...channels.map((channel) {
            final color = channel['color'] as Color;
            final orders = channel['orders'] as int;
            final revenue = channel['revenue'] as double;
            final peak = channel['peak'] as String?;
            final icon = channel['icon'] as IconData;
            final sharePct = channelsTotalOrders == 0 ? 0.0 : (orders / channelsTotalOrders) * 100;
            final peakText = peak == null ? 'Peak time unavailable' : 'Peak: $peak';

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
                          channel['key'] as String,
                          style: AppConstants.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_countFormatter.format(orders)} orders • ${Formatters.formatCurrency(revenue)}',
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
                        '${sharePct.toStringAsFixed(1)}%',
                        style: AppConstants.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Formatters.formatCurrency(revenue),
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
                          style: AppConstants.bodyMedium,
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
          child: Row(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
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
                        if (insight.actionLabel != null)
                          Text(
                            insight.actionLabel!,
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

          _buildDateSelectorCard(
            title: 'Comparison Range',
            subtitle:
                'Pick a single day or range to compare historical performance against the forecast window.',
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

          // Forecast Accuracy Metrics (moved from Forecast tab)
          _buildForecastAccuracyCard(),
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

  _ComparisonSummary _buildComparisonSummary() {
    final resolvedRange = _resolveActiveDateRange();
    final selectedDays = math.max(1, resolvedRange.lengthInDays);

    final actualTotals = <DateTime, double>{};
    for (final record in _filteredTransactions) {
      final day = _dateOnly(record.timestamp);
      actualTotals[day] = (actualTotals[day] ?? 0) + record.saleAmount;
    }

    final forecastDaysAvailable = _forecastProjectedSeries.length;
    final usedDays = forecastDaysAvailable == 0
        ? selectedDays
        : math.min(selectedDays, forecastDaysAvailable);
    final forecastCoveragePartial =
        forecastDaysAvailable > 0 && forecastDaysAvailable < selectedDays;

    final startOffset = selectedDays - usedDays;
    final historicalSeries = <_DailyRevenuePoint>[];
    for (var i = 0; i < usedDays; i++) {
      final index = startOffset + i;
      final date = _dateOnly(
        resolvedRange.start.add(Duration(days: index)),
      );
      final revenue = actualTotals[date] ?? 0;
      historicalSeries.add(_DailyRevenuePoint(date: date, revenue: revenue));
    }

    final forecastSeries = _forecastProjectedSeries.take(usedDays).toList();

    double forecastRevenue;
    if (forecastDaysAvailable == 0) {
      forecastRevenue = 0;
    } else if (selectedDays <= forecastDaysAvailable) {
      forecastRevenue = _forecastProjectedSeries
          .take(selectedDays)
          .fold<double>(0, (sum, point) => sum + point.revenue);
    } else {
      final availableSum = _forecastProjectedSeries
          .fold<double>(0, (sum, point) => sum + point.revenue);
      final averagePerDay = forecastDaysAvailable == 0
          ? 0
          : availableSum / forecastDaysAvailable;
      forecastRevenue = averagePerDay * selectedDays.toDouble();
    }

    final forecastAov = _forecastAverageOrderValue.isFinite
        ? _forecastAverageOrderValue
        : 0.0;
    int forecastOrders;
    if (forecastAov > 0 && forecastRevenue > 0) {
      forecastOrders = (forecastRevenue / forecastAov).round();
    } else if (_forecastTotalOrders > 0 && forecastDaysAvailable > 0) {
      final avgOrdersPerDay =
          _forecastTotalOrders / forecastDaysAvailable;
      forecastOrders = (avgOrdersPerDay * selectedDays).round();
    } else {
      forecastOrders = 0;
    }

    return _ComparisonSummary(
      selectedDays: selectedDays,
      historicalRevenue: _totalRevenue,
      historicalOrders: _totalOrders,
      historicalAov: _averageOrderValue,
      forecastRevenue: forecastRevenue,
      forecastOrders: forecastOrders,
      forecastAov: forecastAov > 0 ? forecastAov : 0.0,
      historicalSeries: historicalSeries,
      forecastSeries: forecastSeries,
      forecastCoveragePartial: forecastCoveragePartial,
      forecastCoverageShortfall: forecastCoveragePartial
          ? selectedDays - forecastDaysAvailable
          : 0,
    );
  }

  /// Metrics Comparison Cards
  Widget _buildMetricsComparison() {
    final summary = _buildComparisonSummary();

    final revenueDelta = _percentChange(
      summary.forecastRevenue,
      summary.historicalRevenue,
    );
    final ordersDelta = _percentChange(
      summary.forecastOrders.toDouble(),
      summary.historicalOrders.toDouble(),
    );
    final aovDelta = _percentChange(
      summary.forecastAov,
      summary.historicalAov,
    );

    final metrics = [
      {
        'title': 'Total Revenue',
        'historical': Formatters.formatCurrency(summary.historicalRevenue),
        'forecast': Formatters.formatCurrency(summary.forecastRevenue),
        'difference': _formatDelta(revenueDelta) ?? '—',
        'isIncrease': (revenueDelta ?? 0) >= 0,
        'icon': Icons.trending_up,
        'color': AppConstants.successGreen,
      },
      {
        'title': 'Total Orders',
        'historical': summary.historicalOrders.toString(),
        'forecast': summary.forecastOrders.toString(),
        'difference': _formatDelta(ordersDelta) ?? '—',
        'isIncrease': (ordersDelta ?? 0) >= 0,
        'icon': Icons.receipt_long,
        'color': AppConstants.primaryOrange,
      },
      {
        'title': 'Avg. Order Value',
        'historical': Formatters.formatCurrency(summary.historicalAov),
        'forecast': Formatters.formatCurrency(summary.forecastAov),
        'difference': _formatDelta(aovDelta) ?? '—',
        'isIncrease': (aovDelta ?? 0) >= 0,
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
    final summary = _buildComparisonSummary();
    final historicalSeries = summary.historicalSeries;
    final forecastSeries = summary.forecastSeries;

    if (historicalSeries.isEmpty && forecastSeries.isEmpty) {
      return Container(
        height: 300,
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: AppConstants.cardBackground,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(color: AppConstants.dividerColor, width: 1),
        ),
        child: const Center(
          child: Text(
            'No data available for the selected range yet.',
            style: AppConstants.bodyMedium,
          ),
        ),
      );
    }

    final comparisonLength = math.max(
      historicalSeries.length,
      forecastSeries.length,
    );
    final dateFormatter = DateFormat('MMMd');
    final labels = <String>[];
    for (var i = 0; i < comparisonLength; i++) {
      if (i < historicalSeries.length) {
        labels.add(dateFormatter.format(historicalSeries[i].date));
      } else if (i < forecastSeries.length) {
        labels.add(dateFormatter.format(forecastSeries[i].date));
      } else {
        labels.add('Day ${i + 1}');
      }
    }

    final historicalSpots = <FlSpot>[];
    for (var i = 0; i < historicalSeries.length; i++) {
      historicalSpots.add(FlSpot(i.toDouble(), historicalSeries[i].revenue));
    }

    final forecastSpots = <FlSpot>[];
    for (var i = 0; i < forecastSeries.length; i++) {
      forecastSpots.add(FlSpot(i.toDouble(), forecastSeries[i].revenue));
    }

    final combinedValues = <double>[
      ...historicalSeries.map((point) => point.revenue),
      ...forecastSeries.map((point) => point.revenue),
    ];
    final rawMax = combinedValues.isEmpty
        ? 0
        : combinedValues.reduce(math.max);
    final maxY = rawMax <= 0 ? 1000.0 : _niceCeiling(rawMax * 1.1);
    final yInterval = _computeYAxisInterval(maxY);
    final bottomInterval = comparisonLength <= 1
        ? 1
        : math.max(1, (comparisonLength / 6).ceil());

    final chartLines = <LineChartBarData>[];
    if (historicalSpots.isNotEmpty) {
      chartLines.add(
        LineChartBarData(
          spots: _sanitizeSpots(historicalSpots),
          isCurved: true,
          preventCurveOverShooting: true,
          curveSmoothness: 0.15,
          color: AppConstants.successGreen,
          barWidth: 3,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: AppConstants.successGreen.withOpacity(0.1),
          ),
        ),
      );
    }
    if (forecastSpots.isNotEmpty) {
      chartLines.add(
        LineChartBarData(
          spots: _sanitizeSpots(forecastSpots),
          isCurved: true,
          preventCurveOverShooting: true,
          curveSmoothness: 0.15,
          color: AppConstants.primaryOrange,
          barWidth: 3,
          dotData: FlDotData(show: true),
          dashArray: const [5, 5],
          belowBarData: BarAreaData(
            show: true,
            color: AppConstants.primaryOrange.withOpacity(0.1),
          ),
        ),
      );
    }

    final coverageLabel = summary.forecastCoveragePartial
        ? 'Forecast covers ${summary.selectedDays - summary.forecastCoverageShortfall} of ${summary.selectedDays} selected day(s). Extend the AI window for full coverage.'
        : null;

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
          if (coverageLabel != null)
            Padding(
              padding: const EdgeInsets.only(
                bottom: AppConstants.paddingSmall,
              ),
              child: Text(
                coverageLabel,
                style: AppConstants.bodySmall.copyWith(
                  color: AppConstants.warningYellow,
                ),
                textAlign: TextAlign.center,
              ),
            ),
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
                maxY: maxY,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: yInterval,
                  verticalInterval: bottomInterval.toDouble(),
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
                        if (value == 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            Formatters.formatCurrencyNoCents(value),
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
                      interval: bottomInterval.toDouble(),
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index >= 0 && index < labels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              labels[index],
                              style: AppConstants.bodySmall.copyWith(
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                clipData: FlClipData.all(),
                lineBarsData: chartLines,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Category Comparison
  Widget _buildCategoryComparison() {
    final historicalLookup = <String, _CategoryBreakdown>{
      for (final category in _categoryBreakdown)
        category.name.toLowerCase().trim(): category,
    };
    final forecastLookup = <String, CategoryDemandProjection>{
      for (final projection in _forecastCategoryDemand)
        projection.name.toLowerCase().trim(): projection,
    };
    final categoryKeys = <String>{
      ...historicalLookup.keys,
      ...forecastLookup.keys,
    };

    if (categoryKeys.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: AppConstants.cardBackground,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(color: AppConstants.dividerColor, width: 1),
        ),
        child: const Center(
          child: Text(
            'No category data available for this range.',
            style: AppConstants.bodyMedium,
          ),
        ),
      );
    }

    final rows = categoryKeys.map((key) {
      final historical = historicalLookup[key];
      final forecast = forecastLookup[key];
      final displayName = forecast?.name ?? historical?.name ?? key;
      final historicalOrders = historical?.quantity ?? 0;
      final forecastOrders = forecast?.predictedOrders ?? 0;
      final historicalRevenue = historical?.revenue ?? 0;

      double? changePercent;
      if (forecast?.changePercent != null) {
        changePercent = forecast!.changePercent;
      } else if (historicalOrders == 0 && forecastOrders > 0) {
        changePercent = double.nan;
      } else if (historicalOrders > 0) {
        changePercent =
            ((forecastOrders - historicalOrders) / historicalOrders) * 100;
      }

      return _CategoryComparisonRow(
        name: displayName,
        historicalOrders: historicalOrders,
        forecastOrders: forecastOrders,
        historicalRevenue: historicalRevenue,
        changePercent: changePercent,
      );
    }).toList()
      ..sort((a, b) => b.forecastOrders.compareTo(a.forecastOrders));

    final palette = <Color>[
      AppConstants.primaryOrange,
      Colors.blue,
      AppConstants.successGreen,
      Colors.pink,
      AppConstants.warningYellow,
      Colors.purple,
      Colors.teal,
    ];

    IconData iconForCategory(String name) {
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

    final maxOrders = rows.fold<int>(
      1,
      (maxValue, row) => math.max(
        maxValue,
        math.max(row.historicalOrders, row.forecastOrders),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.dividerColor, width: 1),
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          final color = palette[index % palette.length];
          final changeLabel = _formatDelta(row.changePercent) ?? '—';
          final isIncrease =
              row.changePercent == null || row.changePercent!.isNaN
                  ? true
                  : row.changePercent! >= 0;
          final historicalProgress = maxOrders <= 0
              ? 0.0
              : row.historicalOrders / maxOrders;
          final forecastProgress = maxOrders <= 0
              ? 0.0
              : row.forecastOrders / maxOrders;

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
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        iconForCategory(row.name),
                        color: color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppConstants.paddingSmall),
                    Expanded(
                      child: Text(
                        row.name,
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
                        color: (isIncrease
                                ? AppConstants.successGreen
                                : Colors.red)
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            row.changePercent == null ||
                                    row.changePercent!.abs() < 0.05
                                ? Icons.remove
                                : isIncrease
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                            color: row.changePercent == null ||
                                    row.changePercent!.abs() < 0.05
                                ? AppConstants.textSecondary
                                : isIncrease
                                    ? AppConstants.successGreen
                                    : Colors.red,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            changeLabel,
                            style: AppConstants.bodySmall.copyWith(
                              color: row.changePercent == null ||
                                      row.changePercent!.abs() < 0.05
                                  ? AppConstants.textSecondary
                                  : isIncrease
                                      ? AppConstants.successGreen
                                      : Colors.red,
                              fontWeight: row.changePercent == null ||
                                      row.changePercent!.abs() < 0.05
                                  ? FontWeight.normal
                                  : FontWeight.bold,
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
                            'Historical: ${row.historicalOrders} orders',
                            style: AppConstants.bodySmall.copyWith(
                              color: AppConstants.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: historicalProgress.clamp(0.0, 1.0),
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
                            'Forecast: ${row.forecastOrders} orders',
                            style: AppConstants.bodySmall.copyWith(
                              color: AppConstants.primaryOrange,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: forecastProgress.clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: AppConstants.dividerColor,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                color,
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
    final historicalLookup = <String, _ChannelBreakdown>{
      for (final channel in _channelBreakdown)
        channel.name.toLowerCase().trim(): channel,
    };
    final forecastLookup = <String, ChannelDemandProjection>{
      for (final projection in _forecastChannelDemand)
        projection.name.toLowerCase().trim(): projection,
    };
    final channelKeys = <String>{
      ...historicalLookup.keys,
      ...forecastLookup.keys,
    };

    if (channelKeys.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: AppConstants.cardBackground,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(color: AppConstants.dividerColor, width: 1),
        ),
        child: const Center(
          child: Text(
            'No channel data available for this range.',
            style: AppConstants.bodyMedium,
          ),
        ),
      );
    }

    final rows = channelKeys.map((key) {
      final historical = historicalLookup[key];
      final forecast = forecastLookup[key];
      final displayName = forecast?.name ?? historical?.name ?? key;
      final historicalOrders = historical?.orders ?? 0;
      final forecastOrders = forecast?.predictedOrders ?? 0;
      final historicalShare = historical?.share ?? 0;
      final forecastShare = forecast?.revenueShare ??
          (forecastOrders <= 0
              ? 0
              : forecastOrders /
                  math.max(1, _forecastChannelDemand
                      .fold<int>(0, (sum, item) => sum + item.predictedOrders)));
      double? changePercent;
      if (forecast?.changePercent != null) {
        changePercent = forecast!.changePercent;
      } else if (historicalOrders == 0 && forecastOrders > 0) {
        changePercent = double.nan;
      } else if (historicalOrders > 0) {
        changePercent =
            ((forecastOrders - historicalOrders) / historicalOrders) * 100;
      }

      return _ChannelComparisonRow(
        name: displayName,
        historicalOrders: historicalOrders,
        historicalShare: historicalShare.clamp(0.0, 1.0),
        forecastOrders: forecastOrders,
        forecastShare: forecastShare.clamp(0.0, 1.0),
        changePercent: changePercent,
        icon: _channelIcon(displayName),
        historicalPeak: historical?.peakLabel,
        forecastPeak: forecast?.peakLabel,
      );
    }).toList()
      ..sort((a, b) => b.forecastOrders.compareTo(a.forecastOrders));

    final palette = <Color>[
      AppConstants.primaryOrange,
      Colors.blue,
      AppConstants.successGreen,
      Colors.purple,
      Colors.teal,
    ];

    int shareFlex(double share) => math.max(1, (share * 1000).round());
    String shareLabel(double share) => '${(share * 100).round()}%';

    final totalHistoricalOrders = rows.fold<int>(
      0,
      (sum, row) => sum + row.historicalOrders,
    );
    final totalForecastOrders = rows.fold<int>(
      0,
      (sum, row) => sum + row.forecastOrders,
    );

    final totalHistoricalShare = rows.fold<double>(
      0,
      (sum, row) => sum + row.historicalShare,
    );
    final totalForecastShare = rows.fold<double>(
      0,
      (sum, row) => sum + row.forecastShare,
    );

    final maxChannelOrders = rows.fold<int>(
      1,
      (maxValue, row) => math.max(
        maxValue,
        math.max(row.historicalOrders, row.forecastOrders),
      ),
    );

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
                children: rows.asMap().entries.map((entry) {
                  final index = entry.key;
                  final row = entry.value;
                  final color = palette[index % palette.length];
                  final isFirst = index == 0;
                  final isLast = index == rows.length - 1;
                    final rawShare = row.historicalShare > 0
                      ? row.historicalShare
                      : (totalHistoricalOrders <= 0
                        ? 0.0
                        : row.historicalOrders / totalHistoricalOrders);
                    final share = totalHistoricalShare <= 0
                      ? rawShare
                      : rawShare / totalHistoricalShare;
                  return Expanded(
                    flex: shareFlex(share),
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: isFirst ? const Radius.circular(6) : Radius.zero,
                        bottomLeft: isFirst ? const Radius.circular(6) : Radius.zero,
                        topRight: isLast ? const Radius.circular(6) : Radius.zero,
                        bottomRight: isLast ? const Radius.circular(6) : Radius.zero,
                      ),
                      child: Container(
                        height: 30,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.5),
                        ),
                        child: Center(
                          child: share >= 0.05
                              ? FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    shareLabel(share.clamp(0.0, 1.0).toDouble()),
                                    style: AppConstants.bodySmall.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
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
                children: rows.asMap().entries.map((entry) {
                  final index = entry.key;
                  final row = entry.value;
                  final color = palette[index % palette.length];
                  final isFirst = index == 0;
                  final isLast = index == rows.length - 1;
                    final rawShare = row.forecastShare > 0
                      ? row.forecastShare
                      : (totalForecastOrders <= 0
                        ? 0.0
                        : row.forecastOrders / totalForecastOrders);
                    final share = totalForecastShare <= 0
                      ? rawShare
                      : rawShare / totalForecastShare;
                  return Expanded(
                    flex: shareFlex(share),
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: isFirst ? const Radius.circular(6) : Radius.zero,
                        bottomLeft: isFirst ? const Radius.circular(6) : Radius.zero,
                        topRight: isLast ? const Radius.circular(6) : Radius.zero,
                        bottomRight: isLast ? const Radius.circular(6) : Radius.zero,
                      ),
                      child: Container(
                        height: 30,
                        decoration: BoxDecoration(
                          color: color,
                        ),
                        child: Center(
                          child: share >= 0.05
                              ? FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    shareLabel(share.clamp(0.0, 1.0).toDouble()),
                                    style: AppConstants.bodySmall.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
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
            ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            final color = palette[index % palette.length];
            final changeLabel = _formatDelta(row.changePercent) ?? '—';
            final isIncrease =
                row.changePercent == null || row.changePercent!.isNaN
                    ? true
                    : row.changePercent! >= 0;
            final historicalProgress = maxChannelOrders <= 0
                ? 0.0
                : row.historicalOrders / maxChannelOrders;
            final forecastProgress = maxChannelOrders <= 0
                ? 0.0
                : row.forecastOrders / maxChannelOrders;

            // Compute normalized shares (matching the top distribution bars)
            final rawHistShare = row.historicalShare > 0
              ? row.historicalShare
              : (totalHistoricalOrders <= 0
                ? 0.0
                : row.historicalOrders / totalHistoricalOrders);
            final normHistShare = totalHistoricalShare <= 0
              ? rawHistShare
              : rawHistShare / totalHistoricalShare;

            final rawFcastShare = row.forecastShare > 0
              ? row.forecastShare
              : (totalForecastOrders <= 0
                ? 0.0
                : row.forecastOrders / totalForecastOrders);
            final normFcastShare = totalForecastShare <= 0
              ? rawFcastShare
              : rawFcastShare / totalForecastShare;

            return Container(
              margin: const EdgeInsets.only(bottom: AppConstants.paddingSmall),
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
                      Icon(
                        row.icon,
                        color: color,
                        size: 20,
                      ),
                      const SizedBox(width: AppConstants.paddingSmall),
                      Expanded(
                        child: Text(
                          row.name,
                          style: AppConstants.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${row.historicalOrders} → ${row.forecastOrders} orders',
                            style: AppConstants.bodySmall.copyWith(
                              color: AppConstants.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            changeLabel,
                            style: AppConstants.bodySmall.copyWith(
                              color: row.changePercent == null ||
                                      row.changePercent!.abs() < 0.05
                                  ? AppConstants.textSecondary
                                  : isIncrease
                                      ? AppConstants.successGreen
                                      : Colors.red,
                              fontWeight: row.changePercent == null ||
                                      row.changePercent!.abs() < 0.05
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                          if (row.historicalPeak != null ||
                              row.forecastPeak != null)
                            Text(
                              [
                                if (row.historicalPeak != null)
                                  'Hist: ${row.historicalPeak}',
                                if (row.forecastPeak != null)
                                  'Forecast: ${row.forecastPeak}',
                              ].join(' • '),
                              style: AppConstants.bodySmall.copyWith(
                                color: AppConstants.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
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
                              'Historical share: ${shareLabel(normHistShare.clamp(0.0, 1.0).toDouble())}',
                              style: AppConstants.bodySmall.copyWith(
                                color: AppConstants.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: historicalProgress
                                    .clamp(0.0, 1.0)
                                    .toDouble(),
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
                              'Forecast share: ${shareLabel(normFcastShare.clamp(0.0, 1.0).toDouble())}',
                              style: AppConstants.bodySmall.copyWith(
                                color: AppConstants.primaryOrange,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: forecastProgress
                                    .clamp(0.0, 1.0)
                                    .toDouble(),
                                minHeight: 6,
                                backgroundColor: AppConstants.dividerColor,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  color,
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
        ],
      ),
    );
  }

  /// Comparison Insights
  Widget _buildComparisonInsights() {
    final summary = _buildComparisonSummary();
    final revenueDelta = _percentChange(
      summary.forecastRevenue,
      summary.historicalRevenue,
    );
    final ordersDelta = _percentChange(
      summary.forecastOrders.toDouble(),
      summary.historicalOrders.toDouble(),
    );

    final categoryLeader = _forecastCategoryDemand
        .where((category) => !category.changePercent.isNaN)
        .fold<CategoryDemandProjection?>(
          null,
          (current, candidate) => current == null ||
                  candidate.changePercent > current.changePercent
              ? candidate
              : current,
        );

    final channelLeader = _forecastChannelDemand
        .where((channel) => channel.changePercent != null)
        .fold<ChannelDemandProjection?>(
          null,
          (current, candidate) => current == null ||
                  (candidate.changePercent ?? 0) >
                      (current.changePercent ?? 0)
              ? candidate
              : current,
        );

    final decliningCategory = _forecastCategoryDemand
        .where((category) => !category.changePercent.isNaN)
        .fold<CategoryDemandProjection?>(
          null,
          (current, candidate) => current == null ||
                  candidate.changePercent < current.changePercent
              ? candidate
              : current,
        );

    final insights = <_InsightCardData>[];

    if (revenueDelta != null) {
      final revenueLabel = _formatDelta(revenueDelta) ?? '—';
      insights.add(
        _InsightCardData(
          icon: Icons.trending_up,
          color: AppConstants.successGreen,
          title: 'Revenue Outlook',
          description:
              'Forecast revenue is $revenueLabel versus ${Formatters.formatCurrency(summary.historicalRevenue)} historically. Projected total: ${Formatters.formatCurrency(summary.forecastRevenue)}.',
        ),
      );
    }

    if (ordersDelta != null) {
      final ordersLabel = _formatDelta(ordersDelta) ?? '—';
      insights.add(
        _InsightCardData(
          icon: Icons.receipt_long,
          color: AppConstants.primaryOrange,
          title: 'Order Volume',
          description:
              'Orders are tracking $ordersLabel with ${summary.forecastOrders} projected vs ${summary.historicalOrders} historically.',
        ),
      );
    }

    if (categoryLeader != null) {
      final changeLabel = _formatDelta(categoryLeader.changePercent) ?? '—';
      insights.add(
        _InsightCardData(
          icon: Icons.restaurant,
          color: AppConstants.primaryOrange,
          title: '${categoryLeader.name} Momentum',
          description:
              '${categoryLeader.name} is forecast at ${categoryLeader.predictedOrders} orders ($changeLabel) compared to ${categoryLeader.historicalOrders} historically.',
        ),
      );
    }

    if (decliningCategory != null && decliningCategory.changePercent < 0) {
      final changeLabel = _formatDelta(decliningCategory.changePercent) ?? '—';
      insights.add(
        _InsightCardData(
          icon: Icons.warning_amber,
          color: Colors.redAccent,
          title: '${decliningCategory.name} Softening',
          description:
              '${decliningCategory.name} may ease to ${decliningCategory.predictedOrders} orders ($changeLabel). Consider promos to maintain traction.',
        ),
      );
    }

    if (channelLeader != null) {
      final changeLabel =
          _formatDelta(channelLeader.changePercent ?? double.nan) ?? '—';
      insights.add(
        _InsightCardData(
          icon: channelLeader.name.toLowerCase().contains('delivery')
              ? Icons.delivery_dining
              : Icons.storefront,
          color: Colors.blue,
          title: '${channelLeader.name} Opportunities',
          description:
              '${channelLeader.name} is forecasting ${channelLeader.predictedOrders} orders ($changeLabel). Peak window: ${channelLeader.peakLabel ?? 'TBD'}.',
        ),
      );
    }

    if (_forecastAction != null) {
      insights.add(
        _InsightCardData(
          icon: Icons.lightbulb_outline,
          color: AppConstants.warningYellow,
          title: _forecastAction!.title,
          description: _forecastAction!.subtitle,
        ),
      );
    }

    if (insights.isEmpty) {
      insights.add(
        const _InsightCardData(
          icon: Icons.info_outline,
          color: AppConstants.textSecondary,
          title: 'No forecast highlights yet',
          description:
              'Select a different range or refresh data to surface meaningful insights.',
        ),
      );
    }

    return Column(
      children: insights.map((insight) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          decoration: BoxDecoration(
            color: AppConstants.cardBackground,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(
              color: insight.color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: insight.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  insight.icon,
                  color: insight.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppConstants.paddingSmall),
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
        _startDate = _dateOnly(picked.start);
        _endDate = _dateOnly(picked.end);
      });
      await _loadAnalyticsData();
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
        final day = _dateOnly(picked);
        _startDate = day;
        _endDate = null;
      });
      await _loadAnalyticsData();
    }
  }

  /// Clear dates
  void _clearDates() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _loadAnalyticsData();
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

        final forecastWindowStart = _dateOnly(now);
        final forecastWindowEnd =
          forecastWindowStart.add(Duration(days: rangeDays - 1));

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
        start: forecastWindowStart,
        end: forecastWindowEnd,
        fallbackRangeDays: rangeDays,
      );

      final transactions = await transactionsFuture;
      // Load available menu items once so we can link predictions to real menu entries
      try {
        final menuItems = await _menuService.getAvailableMenuItems();
        _menuItemsByName.clear();
        for (final m in menuItems) {
          _menuItemsByName[m.name.toLowerCase().trim()] = m;
        }
      } catch (e) {
        // non-fatal; proceed without menu mapping
        print('Warning: failed to load menu items: $e');
      }
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
        _forecastRangeStart = forecastWindowStart;
        _forecastRangeEnd = forecastWindowEnd;
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

  int _selectedRangeInDays() => _selectedForecastRange.days;

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
    final target = _dateOnly(date);
    return !target.isBefore(_forecastRangeStart) &&
        !target.isAfter(_forecastRangeEnd);
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

  String _forecastRangeLabel() {
    final sameDay = _forecastRangeStart.isAtSameMomentAs(_forecastRangeEnd);
    final sameYear =
        _forecastRangeStart.year == _forecastRangeEnd.year;
    final dateFormat = sameYear
        ? DateFormat('MMM d')
        : DateFormat('MMM d, yyyy');
    final startLabel = dateFormat.format(_forecastRangeStart);
    if (sameDay) {
      return startLabel;
    }
    final endLabel = dateFormat.format(_forecastRangeEnd);
    return '$startLabel – $endLabel';
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
    final allDailyTotals = <DateTime, double>{};

    for (final record in allTransactions) {
      final day = _dateOnly(record.timestamp);
      allDailyTotals[day] = (allDailyTotals[day] ?? 0) + record.saleAmount;
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
    for (var i = 0; i < range.lengthInDays; i++) {
      final day = _dateOnly(range.start.add(Duration(days: i)));
      final revenue = dailyTotals[day] ?? 0;
      dailyPoints.add(_DailyRevenuePoint(date: day, revenue: revenue));
    }

    if (dailyPoints.length == 1) {
      final baseDay = dailyPoints.first.date;
      final today = _dateOnly(DateTime.now());

      final days = baseDay.isAtSameMomentAs(today)
          ? List<DateTime>.generate(7, (index) => baseDay.subtract(Duration(days: 6 - index)))
          : List<DateTime>.generate(7, (index) => baseDay.add(Duration(days: index - 3)));

      dailyPoints
        ..clear()
        ..addAll(
          days.map(
            (day) => _DailyRevenuePoint(
              date: day,
              revenue: allDailyTotals[day] ?? 0,
            ),
          ),
        );
    }

    final double maxDailyRevenue = dailyPoints.fold<double>(
      0,
      (maxValue, point) => math.max(maxValue, point.revenue),
    );

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
    final today = _dateOnly(DateTime.now());
    DateTime start;
    DateTime end;

    if (_startDate == null && _endDate == null) {
      // Default to today when no manual date filter is applied.
      start = today;
      end = today;
    } else {
      start = _dateOnly(_startDate ?? today);
      end = _dateOnly(_endDate ?? _startDate ?? today);
    }

    if (start.isAfter(end)) {
      final temp = start;
      start = end;
      end = temp;
    }

    final lengthInDays = end.difference(start).inDays + 1;
    final previousEnd = start.subtract(const Duration(days: 1));
    final previousStart = previousEnd.subtract(
      Duration(days: math.max(0, lengthInDays - 1)),
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

  /// Ensure spots are sorted by x and contain only finite y values to avoid
  /// curve overshoot or rendering artifacts in `fl_chart`.
  List<FlSpot> _sanitizeSpots(List<FlSpot> spots) {
    final filtered = spots
        .where((s) => s != null && s.x.isFinite && s.y.isFinite && !s.y.isNaN)
        .toList();
    filtered.sort((a, b) => a.x.compareTo(b.x));
    return filtered;
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
      record.orderType,
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

  Future<void> _createMenuItemFromPrediction(
    MenuItemPrediction prediction,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final newId = await _menuService.generateNextMenuId();
      final newItem = MenuItem(
        id: newId,
        name: prediction.name,
        description:
            'Auto-created from AI forecast. Update details in Menu Management.',
        price: _suggestedPriceForPrediction(),
        category: _inferCategoryFromPrediction(prediction.name),
        isAvailable: true,
        salesCount: prediction.historicalOrders,
      );

      final result = await _menuService.createMenuItem(newItem);
      if (result['success'] == true) {
        if (!mounted) {
          return;
        }
        setState(() {
          _menuItemsByName[prediction.name.toLowerCase().trim()] = newItem;
        });
        messenger.showSnackBar(
          SnackBar(content: Text('Added ${prediction.name} to the menu.')),
        );
      } else {
        final error = result['error'] ?? 'Failed to create menu item.';
        messenger.showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: AppConstants.errorRed,
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to create menu item: $e'),
          backgroundColor: AppConstants.errorRed,
        ),
      );
    }
  }

  MenuCategory _inferCategoryFromPrediction(String rawName) {
    final name = rawName.toLowerCase();
    if (_nameContains(name, const ['coffee', 'tea', 'juice', 'latte', 'shake', 'soda', 'brew', 'smoothie'])) {
      return MenuCategory.beverage;
    }
    if (_nameContains(name, const ['cake', 'ice cream', 'dessert', 'pudding', 'pie', 'sweet', 'brownie', 'cookie'])) {
      return MenuCategory.dessert;
    }
    if (_nameContains(name, const ['salad', 'soup', 'starter', 'fries', 'bites'])) {
      return MenuCategory.appetizer;
    }
    if (_nameContains(name, const ['special', 'seasonal'])) {
      return MenuCategory.special;
    }
    return MenuCategory.mainCourse;
  }

  bool _nameContains(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle)) {
        return true;
      }
    }
    return false;
  }

  double _suggestedPriceForPrediction() {
    final candidates = <double>[
      if (_forecastAverageOrderValue > 0) _forecastAverageOrderValue,
      if (_averageOrderValue > 0) _averageOrderValue,
      if (_forecastTotalOrders > 0)
        _forecastTotalRevenue / math.max(1, _forecastTotalOrders),
      if (_totalOrders > 0) _totalRevenue / math.max(1, _totalOrders),
    ].where((value) => value.isFinite && value > 0).toList();

    if (candidates.isNotEmpty) {
      return double.parse(candidates.first.toStringAsFixed(2));
    }
    return 100.0;
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

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({
    required this.child,
    this.padding,
    this.margin,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.dividerColor, width: 1),
      ),
      child: child,
    );
  }
}

class _AnalyticsPlaceholder extends StatelessWidget {
  const _AnalyticsPlaceholder({
    required this.message,
    this.detail,
    this.icon,
  });

  final String message;
  final String? detail;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return _AnalyticsCard(
      child: Column(
        children: [
          if (icon != null)
            Icon(
              icon,
              color: AppConstants.textSecondary,
            ),
          if (icon != null)
            const SizedBox(height: AppConstants.paddingSmall),
          Text(
            message,
            style: AppConstants.bodySmall.copyWith(
              color: AppConstants.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (detail != null) ...[
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              detail!,
              style: AppConstants.bodySmall.copyWith(
                color: AppConstants.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
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

class _ComparisonSummary {
  const _ComparisonSummary({
    required this.selectedDays,
    required this.historicalRevenue,
    required this.historicalOrders,
    required this.historicalAov,
    required this.forecastRevenue,
    required this.forecastOrders,
    required this.forecastAov,
    required this.historicalSeries,
    required this.forecastSeries,
    required this.forecastCoveragePartial,
    required this.forecastCoverageShortfall,
  });

  final int selectedDays;
  final double historicalRevenue;
  final int historicalOrders;
  final double historicalAov;
  final double forecastRevenue;
  final int forecastOrders;
  final double forecastAov;
  final List<_DailyRevenuePoint> historicalSeries;
  final List<ForecastSeriesPoint> forecastSeries;
  final bool forecastCoveragePartial;
  final int forecastCoverageShortfall;
}

class _CategoryComparisonRow {
  const _CategoryComparisonRow({
    required this.name,
    required this.historicalOrders,
    required this.forecastOrders,
    required this.historicalRevenue,
    required this.changePercent,
  });

  final String name;
  final int historicalOrders;
  final int forecastOrders;
  final double historicalRevenue;
  final double? changePercent;
}

class _ChannelComparisonRow {
  const _ChannelComparisonRow({
    required this.name,
    required this.historicalOrders,
    required this.historicalShare,
    required this.forecastOrders,
    required this.forecastShare,
    required this.changePercent,
    required this.icon,
    this.historicalPeak,
    this.forecastPeak,
  });

  final String name;
  final int historicalOrders;
  final double historicalShare;
  final int forecastOrders;
  final double forecastShare;
  final double? changePercent;
  final IconData icon;
  final String? historicalPeak;
  final String? forecastPeak;
}

class _InsightCardData {
  const _InsightCardData({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
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

enum _ForecastInsightPriority { high, medium, low }

enum _ForecastInsightKind { staffing, inventory, promo, general }

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
