import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
  String _selectedPeriod = 'Daily'; // For chart toggle

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              _buildWelcomeSection(),
              const SizedBox(height: AppConstants.paddingLarge),

              // Key Metrics
              const Text(
                'Today\'s Overview',
                style: AppConstants.headingSmall,
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              _buildMetricsGrid(),
              const SizedBox(height: AppConstants.paddingLarge),

              // Sales Chart
              _buildSalesSection(),
              const SizedBox(height: AppConstants.paddingLarge),

              // AI Recommendations
              const Text(
                'Insights & AI Recommendations',
                style: AppConstants.headingSmall,
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              _buildAIRecommendations(),
              const SizedBox(height: AppConstants.paddingLarge),

              // Top Selling Items
              const Text(
                'Top Selling Items',
                style: AppConstants.headingSmall,
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              _buildTopSellingItems(),
            ],
          ),
        ),
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
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppConstants.paddingMedium,
      crossAxisSpacing: AppConstants.paddingMedium,
      childAspectRatio: 1.3,
      children: [
        StatCard(
          title: 'Total Sales',
          value: '₱12,345',
          icon: Icons.attach_money,
          color: AppConstants.successGreen,
          percentageChange: '+5.2%',
        ),
        StatCard(
          title: 'Total Orders',
          value: '875',
          icon: Icons.shopping_bag,
          color: AppConstants.primaryOrange,
          percentageChange: '-1.8%',
        ),
        StatCard(
          title: 'Avg. Order Value',
          value: '₱14.11',
          icon: Icons.trending_up,
          color: Colors.blue,
          percentageChange: '+0.5%',
        ),
        StatCard(
          title: 'Customer Count',
          value: '520',
          icon: Icons.people,
          color: AppConstants.warningYellow,
          percentageChange: '+3.1%',
        ),
      ],
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
    // Different data based on selected period
    List<FlSpot> spots;
    List<String> labels;
    double interval;
    double maxY;
    
    if (_selectedPeriod == 'Daily') {
      spots = [
        const FlSpot(0, 450),
        const FlSpot(1, 680),
        const FlSpot(2, 820),
        const FlSpot(3, 920),
        const FlSpot(4, 1150),
        const FlSpot(5, 980),
        const FlSpot(6, 750),
      ];
      labels = ['6AM', '9AM', '12PM', '3PM', '6PM', '9PM', '12AM'];
      interval = 200;
      maxY = 1200;
    } else if (_selectedPeriod == 'Weekly') {
      spots = [
        const FlSpot(0, 1200),
        const FlSpot(1, 1500),
        const FlSpot(2, 1350),
        const FlSpot(3, 1800),
        const FlSpot(4, 2100),
        const FlSpot(5, 1950),
        const FlSpot(6, 2450),
      ];
      labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      interval = 500;
      maxY = 2500;
    } else {
      spots = [
        const FlSpot(0, 8500),
        const FlSpot(1, 9200),
        const FlSpot(2, 8800),
        const FlSpot(3, 10500),
      ];
      labels = ['Week 1', 'Week 2', 'Week 3', 'Week 4'];
      interval = 5000;
      maxY = 20000;
    }

    return LineChart(
      LineChartData(
        maxY: maxY,
        minY: 0,
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

  /// AI Recommendations section
  Widget _buildAIRecommendations() {
    final recommendations = [
      {
        'icon': Icons.trending_up,
        'title': 'Peak Hours Alert',
        'description': 'Expected high sales during lunch hours today (12PM - 2PM)',
        'color': AppConstants.successGreen,
      },
      {
        'icon': Icons.inventory_2_outlined,
        'title': 'Stock Reminder',
        'description': 'Popular items running low: Caesar Salad, Iced Coffee',
        'color': AppConstants.warningYellow,
      },
      {
        'icon': Icons.lightbulb_outline,
        'title': 'Recommendation',
        'description': 'Consider adding lunch specials to boost weekday sales',
        'color': Colors.blue,
      },
    ];

    return Column(
      children: recommendations.map((rec) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          decoration: BoxDecoration(
            color: AppConstants.cardBackground,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(
              color: AppConstants.dividerColor,
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(AppConstants.paddingSmall),
                decoration: BoxDecoration(
                  color: (rec['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                ),
                child: Icon(
                  rec['icon'] as IconData,
                  color: rec['color'] as Color,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppConstants.paddingMedium),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec['title'] as String,
                      style: AppConstants.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rec['description'] as String,
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
    final items = [
      {'name': 'Margherita Pizza', 'sales': 45, 'revenue': 675.0},
      {'name': 'Caesar Salad', 'sales': 32, 'revenue': 384.0},
      {'name': 'Pasta Carbonara', 'sales': 28, 'revenue': 476.0},
      {'name': 'Iced Coffee', 'sales': 56, 'revenue': 224.0},
      {'name': 'Tiramisu', 'sales': 22, 'revenue': 198.0},
    ];

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
        itemCount: items.length,
        separatorBuilder: (context, index) => Divider(
          color: AppConstants.dividerColor,
          height: 1,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppConstants.primaryOrange.withOpacity(0.2),
              child: Text(
                '${index + 1}',
                style: AppConstants.bodyMedium.copyWith(
                  color: AppConstants.primaryOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              item['name'] as String,
              style: AppConstants.bodyLarge,
            ),
            subtitle: Text(
              '${item['sales']} sold',
              style: AppConstants.bodySmall,
            ),
            trailing: Text(
              Formatters.formatCurrency(item['revenue'] as double),
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
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      // Refresh data
    });
  }
}