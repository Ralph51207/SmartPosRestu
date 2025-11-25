import 'dart:math' as math;

import '../models/analytics_calendar_model.dart';
import '../models/sales_data_model.dart';
import '../services/transaction_service.dart';

/// Snapshot of historical category performance used as a baseline for
/// generating demand projections.
class HistoricalCategorySnapshot {
  const HistoricalCategorySnapshot({
    required this.name,
    required this.orders,
    required this.revenue,
  });

  final String name;
  final int orders;
  final double revenue;
}

/// Snapshot of historical channel performance.
class HistoricalChannelSnapshot {
  const HistoricalChannelSnapshot({
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

/// Snapshot of a top-selling menu item.
class HistoricalTopSellerSnapshot {
  const HistoricalTopSellerSnapshot({
    required this.name,
    required this.orders,
    required this.revenue,
  });

  final String name;
  final int orders;
  final double revenue;
}

/// Represents a point on the projected or historical series chart.
class ForecastSeriesPoint {
  const ForecastSeriesPoint({
    required this.date,
    required this.revenue,
  });

  final DateTime date;
  final double revenue;
}

/// Forecasted demand for a menu category.
class CategoryDemandProjection {
  const CategoryDemandProjection({
    required this.name,
    required this.historicalOrders,
    required this.predictedOrders,
    required this.revenueShare,
    required this.changePercent,
  });

  final String name;
  final int historicalOrders;
  final int predictedOrders;
  final double revenueShare;
  final double changePercent;
}

/// Forecasted performance for an order channel (dine-in, delivery, etc.).
class ChannelDemandProjection {
  const ChannelDemandProjection({
    required this.name,
    required this.historicalOrders,
    required this.predictedOrders,
    required this.predictedRevenue,
    required this.revenueShare,
    required this.changePercent,
    this.peakLabel,
  });

  final String name;
  final int historicalOrders;
  final int predictedOrders;
  final double predictedRevenue;
  final double revenueShare;
  final double changePercent;
  final String? peakLabel;
}

/// Classification for menu item projections.
enum MenuPredictionStatus {
  star,
  rising,
  declining,
}

/// Forecasted performance for a specific menu item.
class MenuItemPrediction {
  const MenuItemPrediction({
    required this.name,
    required this.historicalOrders,
    required this.predictedOrders,
    required this.changePercent,
    required this.status,
  });

  final String name;
  final int historicalOrders;
  final int predictedOrders;
  final double changePercent;
  final MenuPredictionStatus status;
}

/// Container for all computed forecast artefacts.
class ForecastResult {
  const ForecastResult({
    required this.forecasts,
    required this.projectedSeries,
    required this.actualSeries,
    required this.totalPredictedRevenue,
    required this.totalPredictedOrders,
    required this.averageOrderValue,
    required this.revenueChangePercent,
    required this.orderChangePercent,
    required this.aovChangePercent,
    required this.averageConfidence,
    required this.recentAccuracy,
    required this.accuracyTrend,
    required this.salesAccuracy,
    required this.trafficAccuracy,
    required this.peakAccuracy,
    required this.categoryDemand,
    required this.channelDemand,
    required this.menuPredictions,
  });

  final List<SalesForecast> forecasts;
  final List<ForecastSeriesPoint> projectedSeries;
  final List<ForecastSeriesPoint> actualSeries;
  final double totalPredictedRevenue;
  final int totalPredictedOrders;
  final double averageOrderValue;
  final double? revenueChangePercent;
  final double? orderChangePercent;
  final double? aovChangePercent;
  final double averageConfidence;
  final double recentAccuracy;
  final double accuracyTrend;
  final double salesAccuracy;
  final double trafficAccuracy;
  final double peakAccuracy;
  final List<CategoryDemandProjection> categoryDemand;
  final List<ChannelDemandProjection> channelDemand;
  final List<MenuItemPrediction> menuPredictions;
}

/// Service responsible for producing local AI-style forecasts using historical
/// transactions, calendar impacts, and category/channel breakdowns.
class ForecastService {
  ForecastResult computeForecast({
    required DateTime startDate,
    required int rangeDays,
    required List<TransactionRecord> transactions,
    required List<EventImpact> eventImpacts,
    required DateTime historicalRangeStart,
    required DateTime historicalRangeEnd,
    required double historicalRevenue,
    required int historicalOrders,
    required double historicalAverageOrderValue,
    required List<HistoricalCategorySnapshot> categories,
    required List<HistoricalChannelSnapshot> channels,
    required List<HistoricalTopSellerSnapshot> topSellers,
  }) {
    final normalizedStart = _dateOnly(startDate);
    final normalizedHistoricalStart = _dateOnly(historicalRangeStart);
    final normalizedHistoricalEnd = _dateOnly(historicalRangeEnd);
    final forecastLength = math.max(1, rangeDays);

    final Map<DateTime, _DailyStats> dailyStats = {};
    for (final record in transactions) {
      final day = _dateOnly(record.timestamp);
      final stats = dailyStats.putIfAbsent(day, _DailyStats.new);
      stats.revenue += record.saleAmount;
      stats.orders += 1;
    }

    final Map<int, _WeekdayStats> weekdayStats = {};
    dailyStats.forEach((date, stats) {
      final bucket = weekdayStats.putIfAbsent(date.weekday, _WeekdayStats.new);
      bucket.totalRevenue += stats.revenue;
      bucket.totalOrders += stats.orders;
      bucket.days += 1;
    });

    final historicalEntries = dailyStats.entries
        .where(
          (entry) => !entry.key.isBefore(normalizedHistoricalStart) &&
              !entry.key.isAfter(normalizedHistoricalEnd),
        )
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final selectedActual = historicalEntries.isEmpty
        ? <_ActualDailySnapshot>[]
        : historicalEntries
            .sublist(
              math.max(0, historicalEntries.length - forecastLength),
            )
            .map(
              (entry) => _ActualDailySnapshot(
                date: entry.key,
                revenue: entry.value.revenue,
                orders: entry.value.orders,
              ),
            )
            .toList();

    while (selectedActual.length < forecastLength) {
      final missingIndex = forecastLength - selectedActual.length;
      final padDate = normalizedHistoricalStart.subtract(
        Duration(days: missingIndex),
      );
      selectedActual.insert(
        0,
        _ActualDailySnapshot(date: padDate, revenue: 0, orders: 0),
      );
    }

    final actualSeries = selectedActual
        .map(
          (snapshot) => ForecastSeriesPoint(
            date: snapshot.date,
            revenue: snapshot.revenue,
          ),
        )
        .toList();

    final totalHistoricalDays = dailyStats.length;
    final totalHistoricalRevenue = dailyStats.values.fold<double>(
      0,
      (sum, stats) => sum + stats.revenue,
    );
    final totalHistoricalOrders = dailyStats.values.fold<int>(
      0,
      (sum, stats) => sum + stats.orders,
    );

    final overallAverageRevenue = totalHistoricalDays == 0
        ? historicalRevenue / math.max(1, (historicalOrders == 0 ? 1 : forecastLength))
        : totalHistoricalRevenue / totalHistoricalDays;
    final overallAverageOrders = totalHistoricalDays == 0
        ? historicalOrders / math.max(1, forecastLength)
        : totalHistoricalOrders / totalHistoricalDays;
    final fallbackAverageOrderValue = totalHistoricalOrders == 0
        ? historicalAverageOrderValue
        : totalHistoricalRevenue / totalHistoricalOrders;

    final Map<DateTime, EventImpact> impactMap = {
      for (final impact in eventImpacts)
        _dateOnly(impact.date): impact,
    };

    final List<SalesForecast> forecasts = [];
    final List<ForecastSeriesPoint> projectedSeries = [];
    double predictedRevenueTotal = 0;
    double predictedOrdersTotal = 0;
    double confidenceAccumulator = 0;

    for (var offset = 0; offset < forecastLength; offset += 1) {
      final date = normalizedStart.add(Duration(days: offset));
      final weekday = date.weekday;
      final weekdayStatsEntry = weekdayStats[weekday];

      double baseRevenue = weekdayStatsEntry == null || weekdayStatsEntry.days == 0
          ? overallAverageRevenue
          : weekdayStatsEntry.totalRevenue / weekdayStatsEntry.days;
      double baseOrders = weekdayStatsEntry == null || weekdayStatsEntry.days == 0
          ? overallAverageOrders
          : weekdayStatsEntry.totalOrders / weekdayStatsEntry.days;
      double averageOrderValue = baseOrders <= 0
          ? fallbackAverageOrderValue
          : baseRevenue / math.max(1, baseOrders);

      final impact = impactMap[_dateOnly(date)];
      if (impact?.impactPercent != null) {
        baseRevenue *= (1 + (impact!.impactPercent! / 100));
      }
      if (impact?.expectedSales != null) {
        baseRevenue = (baseRevenue * 0.6) + (impact!.expectedSales! * 0.4);
      }

      double projectedOrders;
      if (impact?.expectedSales != null && averageOrderValue > 0) {
        projectedOrders = impact!.expectedSales! / averageOrderValue;
      } else {
        projectedOrders = averageOrderValue <= 0
            ? baseOrders
            : baseRevenue / averageOrderValue;
      }

      projectedOrders = projectedOrders.isFinite ? projectedOrders : 0;
      baseRevenue = baseRevenue.isFinite ? baseRevenue : 0;

      double confidence = 0.5;
      if (weekdayStatsEntry != null && weekdayStatsEntry.days > 0) {
        final coverage = math.min(1.0, weekdayStatsEntry.days / 6.0);
        confidence += 0.2 * coverage;
        if (weekdayStatsEntry.totalOrders / weekdayStatsEntry.days >= 5) {
          confidence += 0.05;
        }
      } else {
        confidence -= 0.05;
      }
      if (impact != null) {
        confidence += 0.05;
        if ((impact.impactPercent ?? 0).abs() >= 10) {
          confidence += 0.05;
        }
        if ((impact.impactPercent ?? 0) < 0) {
          confidence -= 0.03;
        }
      }
      confidence = confidence.clamp(0.35, 0.95);

      final forecast = SalesForecast(
        date: date,
        predictedRevenue: baseRevenue,
        confidence: confidence,
        insights: impact != null && (impact.recommendation ?? '').isNotEmpty
            ? [impact.recommendation!]
            : const [],
      );

      forecasts.add(forecast);
      projectedSeries.add(ForecastSeriesPoint(date: date, revenue: baseRevenue));
      predictedRevenueTotal += baseRevenue;
      predictedOrdersTotal += projectedOrders;
      confidenceAccumulator += confidence;
    }

    final totalPredictedOrders = predictedOrdersTotal.round();
    final averageOrderValue = predictedOrdersTotal <= 0
        ? historicalAverageOrderValue
        : predictedRevenueTotal / predictedOrdersTotal;

    final revenueChangePercent = _percentChange(
      predictedRevenueTotal,
      historicalRevenue,
    );
    final orderChangePercent = _percentChange(
      predictedOrdersTotal.toDouble(),
      historicalOrders.toDouble(),
    );
    final aovChangePercent = _percentChange(
      averageOrderValue,
      historicalAverageOrderValue,
    );

    final recentActualRevenue = selectedActual.fold<double>(
      0,
      (sum, snapshot) => sum + snapshot.revenue,
    );
    final recentActualOrders = selectedActual.fold<int>(
      0,
      (sum, snapshot) => sum + snapshot.orders,
    );

    double absoluteRevenueError = 0;
    double absoluteOrderError = 0;

    for (var i = 0; i < selectedActual.length; i += 1) {
      final actualPoint = selectedActual[i];
      final weekday = actualPoint.date.weekday;
      final weekdayStatsEntry = weekdayStats[weekday];

      double baselineRevenue = weekdayStatsEntry == null || weekdayStatsEntry.days == 0
          ? overallAverageRevenue
          : weekdayStatsEntry.totalRevenue / weekdayStatsEntry.days;
      double baselineOrders = weekdayStatsEntry == null || weekdayStatsEntry.days == 0
          ? overallAverageOrders
          : weekdayStatsEntry.totalOrders / weekdayStatsEntry.days;

      final impact = impactMap[_dateOnly(actualPoint.date)];
      if (impact?.impactPercent != null) {
        baselineRevenue *= (1 + (impact!.impactPercent! / 100));
      }
      if (impact?.expectedSales != null) {
        baselineRevenue = (baselineRevenue * 0.6) + (impact!.expectedSales! * 0.4);
      }

      if (baselineOrders <= 0 && historicalAverageOrderValue > 0) {
        baselineOrders = baselineRevenue / historicalAverageOrderValue;
      }

      absoluteRevenueError += (actualPoint.revenue - baselineRevenue).abs();
      absoluteOrderError += (actualPoint.orders - baselineOrders).abs();
    }

    final recentAccuracy = recentActualRevenue <= 0
        ? 0.6
        : (1 - (absoluteRevenueError / recentActualRevenue)).clamp(0.0, 1.0);
    final trafficAccuracy = recentActualOrders <= 0
        ? recentAccuracy
        : (1 - (absoluteOrderError / recentActualOrders)).clamp(0.0, 1.0);
    final averageConfidence = forecasts.isEmpty
      ? 0.0
        : confidenceAccumulator / forecasts.length;
    final overallAccuracy = ((recentAccuracy + averageConfidence) / 2).clamp(0.0, 1.0);
    final accuracyTrend = (averageConfidence - recentAccuracy) * 100;

    double peakAccuracy = 0.6;
    if (actualSeries.isNotEmpty && projectedSeries.isNotEmpty) {
      final actualPeak = actualSeries.reduce(
        (a, b) => a.revenue >= b.revenue ? a : b,
      );
      final projectedPeak = projectedSeries.reduce(
        (a, b) => a.revenue >= b.revenue ? a : b,
      );
      final difference = projectedPeak.date.difference(actualPeak.date).inDays.abs();
      if (difference == 0) {
        peakAccuracy = 0.9;
      } else if (difference == 1) {
        peakAccuracy = 0.75;
      } else {
        peakAccuracy = 0.55;
      }
    }

    final totalCategoryRevenue = categories.fold<double>(
      0,
      (sum, category) => sum + category.revenue,
    );
    final categoryDemand = categories.map((category) {
        final orderShare = historicalOrders == 0
          ? (categories.isEmpty ? 0.0 : 1.0 / categories.length)
          : category.orders / historicalOrders;
      final predictedOrders = (orderShare * predictedOrdersTotal).round();
      final revenueShare = totalCategoryRevenue == 0
          ? orderShare
          : category.revenue / totalCategoryRevenue;
      final changePercent = _percentChange(
            predictedOrders.toDouble(),
            category.orders.toDouble(),
          ) ??
          0;
      return CategoryDemandProjection(
        name: category.name,
        historicalOrders: category.orders,
        predictedOrders: predictedOrders,
        revenueShare: revenueShare,
        changePercent: changePercent,
      );
    }).toList()
      ..sort((a, b) => b.predictedOrders.compareTo(a.predictedOrders));

    final channelDemand = channels.map((channel) {
      final predictedOrders = (channel.share * predictedOrdersTotal).round();
      final predictedRevenue = channel.share * predictedRevenueTotal;
      final changePercent = _percentChange(
            predictedOrders.toDouble(),
            channel.orders.toDouble(),
          ) ??
          0;
      return ChannelDemandProjection(
        name: channel.name,
        historicalOrders: channel.orders,
        predictedOrders: predictedOrders,
        predictedRevenue: predictedRevenue,
        revenueShare: channel.share,
        changePercent: changePercent,
        peakLabel: channel.peakLabel,
      );
    }).toList()
      ..sort((a, b) => b.predictedRevenue.compareTo(a.predictedRevenue));

    final ordersMultiplier = historicalOrders == 0
        ? 1.0
        : predictedOrdersTotal / historicalOrders;
    final menuPredictions = topSellers.map((item) {
      final predictedOrders = (item.orders * ordersMultiplier).round();
      final changePercent = _percentChange(
            predictedOrders.toDouble(),
            item.orders.toDouble(),
          ) ??
          0;
      final status = changePercent >= 10
          ? MenuPredictionStatus.rising
          : changePercent <= -10
              ? MenuPredictionStatus.declining
              : MenuPredictionStatus.star;
      return MenuItemPrediction(
        name: item.name,
        historicalOrders: item.orders,
        predictedOrders: predictedOrders,
        changePercent: changePercent,
        status: status,
      );
    }).toList();

    return ForecastResult(
      forecasts: forecasts,
      projectedSeries: projectedSeries,
      actualSeries: actualSeries,
      totalPredictedRevenue: predictedRevenueTotal,
      totalPredictedOrders: totalPredictedOrders,
      averageOrderValue: averageOrderValue,
      revenueChangePercent: revenueChangePercent,
      orderChangePercent: orderChangePercent,
      aovChangePercent: aovChangePercent,
      averageConfidence: averageConfidence,
      recentAccuracy: recentAccuracy,
      accuracyTrend: accuracyTrend,
      salesAccuracy: overallAccuracy,
      trafficAccuracy: trafficAccuracy,
      peakAccuracy: peakAccuracy,
      categoryDemand: categoryDemand,
      channelDemand: channelDemand,
      menuPredictions: menuPredictions,
    );
  }
}

class _DailyStats {
  double revenue = 0;
  int orders = 0;
}

class _WeekdayStats {
  double totalRevenue = 0;
  double totalOrders = 0;
  int days = 0;
}

class _ActualDailySnapshot {
  const _ActualDailySnapshot({
    required this.date,
    required this.revenue,
    required this.orders,
  });

  final DateTime date;
  final double revenue;
  final int orders;
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

double? _percentChange(double current, double previous) {
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
