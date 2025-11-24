import '../models/analytics_calendar_model.dart';

class AnalyticsFallbackResult {
  const AnalyticsFallbackResult({
    required this.days,
    required this.impacts,
  });

  final List<WeatherDay> days;
  final List<EventImpact> impacts;
}

class AnalyticsFallback {
  static const int defaultRangeDays = 14;

  static const List<_FallbackPattern> _patterns = [
    _FallbackPattern(
      condition: 'Bright and calm morning across Iloilo',
      icon: 'sunny',
      high: 32,
      low: 25,
      notes: 'Expect lunchtime walk-ins from nearby offices.',
    ),
    _FallbackPattern(
      condition: 'Humid afternoon with intermittent clouds',
      icon: 'partly_cloudy',
      high: 31,
      low: 25,
      notes: 'Suggest chilled drinks promo during mid-afternoon lull.',
    ),
    _FallbackPattern(
      condition: 'Moderate rain showers in the evening',
      icon: 'rainy',
      high: 29,
      low: 24,
      notes: 'Delivery demand likely to increase after 6 PM.',
    ),
    _FallbackPattern(
      condition: 'Windy with scattered clouds',
      icon: 'windy',
      high: 30,
      low: 25,
      notes: 'Patio seating might need securing before dinner.',
    ),
    _FallbackPattern(
      condition: 'Thunderstorm risk around sunset',
      icon: 'storm',
      high: 28,
      low: 24,
      notes: 'Prepare dine-in comfort dishes and hot beverages.',
    ),
  ];

  static List<WeatherDay> generateMonthDays(
    DateTime month, {
    int rangeDays = defaultRangeDays,
  }) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(Duration(days: rangeDays - 1));
    final monthDays = _generateRange(start, end).days;
    return monthDays
        .where((day) =>
            day.date.year == month.year && day.date.month == month.month)
        .toList();
  }

  static List<EventImpact> generateImpacts(
    DateTime start,
    DateTime end, {
    int? rangeDays,
  }) {
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day);
    var effectiveEnd = normalizedEnd;
    if (rangeDays != null && rangeDays > 0) {
      final rangeEnd = normalizedStart.add(Duration(days: rangeDays - 1));
      if (rangeEnd.isBefore(effectiveEnd)) {
        effectiveEnd = rangeEnd;
      }
    }
    return _generateRange(normalizedStart, effectiveEnd).impacts;
  }

  static AnalyticsFallbackResult generateRange(
    DateTime start,
    DateTime end,
  ) {
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day);
    return _generateRange(normalizedStart, normalizedEnd);
  }

  static AnalyticsFallbackResult _generateRange(
    DateTime start,
    DateTime end,
  ) {
    if (end.isBefore(start)) {
      return const AnalyticsFallbackResult(days: <WeatherDay>[], impacts: <EventImpact>[]);
    }

    final days = <WeatherDay>[];
    final impacts = <EventImpact>[];

    var index = 0;
    for (var current = start;
        !current.isAfter(end);
        current = current.add(const Duration(days: 1))) {
      final pattern = _patterns[index % _patterns.length];
      index += 1;

      final isWeekend = current.weekday == DateTime.saturday ||
          current.weekday == DateTime.sunday;
      final hasRain = pattern.icon == 'rainy' || pattern.icon == 'storm';

      final eventName = isWeekend
          ? 'Weekend Family Crowd'
          : (hasRain ? 'Rainy Day Delivery Push' : null);
      final eventType = isWeekend
          ? 'promo'
          : (hasRain ? 'weather' : null);

      days.add(
        WeatherDay(
          date: current,
          weatherIcon: pattern.icon,
          condition: pattern.condition,
          highTemp: pattern.high,
          lowTemp: pattern.low,
          eventName: eventName,
          eventType: eventType,
          notes: pattern.notes,
        ),
      );

      final impactPercent = isWeekend
          ? 18.0
          : (hasRain ? -12.0 : 6.0);
      final expectedSales = isWeekend
          ? 21500.0
          : (hasRain ? 16200.0 : 18500.0);

      impacts.add(
        EventImpact(
          date: current,
          eventName: eventName ?? 'Steady Service',
          weatherIcon: pattern.icon,
          condition: pattern.condition,
          eventType: eventType ?? 'operations',
          impactPercent: impactPercent,
          expectedSales: expectedSales,
          recommendation: isWeekend
              ? 'Staff extra front-of-house and prep family bundle promos.'
              : (hasRain
                  ? 'Promote delivery combos and ensure riders have rain gear.'
                  : 'Upsell cold refreshments during warm hours.'),
          severity: null,
        ),
      );
    }

    return AnalyticsFallbackResult(days: days, impacts: impacts);
  }
}

class _FallbackPattern {
  const _FallbackPattern({
    required this.condition,
    required this.icon,
    required this.high,
    required this.low,
    required this.notes,
  });

  final String condition;
  final String icon;
  final int high;
  final int low;
  final String notes;
}
