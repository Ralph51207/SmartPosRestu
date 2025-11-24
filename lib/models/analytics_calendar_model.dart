import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the weather and event details for a specific calendar day.
class WeatherDay {
  WeatherDay({
    required this.date,
    required this.weatherIcon,
    required this.condition,
    this.highTemp,
    this.lowTemp,
    this.eventName,
    this.eventType,
    this.notes,
  });

  final DateTime date;
  final String weatherIcon;
  final String condition;
  final int? highTemp;
  final int? lowTemp;
  final String? eventName;
  final String? eventType;
  final String? notes;

  /// Convenience flag to determine if the day has an event associated with it.
  bool get hasEvent => (eventName?.trim().isNotEmpty ?? false);

  /// Normalised key used to map to a display emoji/icon.
  String get iconKey => weatherIcon.isNotEmpty ? weatherIcon : condition.toLowerCase();

  /// Emoji representation used by the UI calendar.
  String get emoji => _WeatherIconMapper.emojiFor(iconKey);

  factory WeatherDay.fromFirestore(String key, Map<String, dynamic> data) {
    final dateString = (data['date'] as String?) ?? key;
    final timestamp = data['dateTimestamp'];
    DateTime? parsedDate;

    if (timestamp is Timestamp) {
      parsedDate = timestamp.toDate();
    } else if (dateString != null) {
      parsedDate = DateTime.tryParse(dateString);
    }

    parsedDate ??= DateTime.now();

    return WeatherDay(
      date: parsedDate,
      weatherIcon: (data['weatherIcon'] as String?) ?? (data['icon'] as String?) ?? '',
      condition: (data['condition'] as String?) ?? 'Unknown',
      highTemp: (data['highTemp'] as num?)?.toInt(),
      lowTemp: (data['lowTemp'] as num?)?.toInt(),
      eventName: data['eventName'] as String?,
      eventType: data['eventType'] as String?,
      notes: data['notes'] as String?,
    );
  }
}

/// Container for all weather days within a specific month.
class WeatherCalendarMonth {
  WeatherCalendarMonth({
    required DateTime month,
    required List<WeatherDay> days,
  })  : month = DateTime(month.year, month.month),
        _daysByNumber = {
          for (final day in days) day.date.day: day,
        };

  final DateTime month;
  final Map<int, WeatherDay> _daysByNumber;

  /// Returns the weather details for a specific day in the month.
  WeatherDay? dayForNumber(int day) => _daysByNumber[day];

  /// Exposes a sorted list of weather days for convenience.
  List<WeatherDay> get days {
    final list = _daysByNumber.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  bool get isEmpty => _daysByNumber.isEmpty;
}

/// Represents the aggregated impact of events and weather on sales.
class EventImpact {
  EventImpact({
    required this.date,
    required this.eventName,
    required this.weatherIcon,
    required this.condition,
    this.eventType,
    this.impactPercent,
    this.expectedSales,
    this.recommendation,
    this.severity,
  });

  final DateTime date;
  final String eventName;
  final String weatherIcon;
  final String condition;
  final String? eventType;
  final double? impactPercent;
  final double? expectedSales;
  final String? recommendation;
  final String? severity;

  bool get hasPositiveImpact => (impactPercent ?? 0) >= 0;

  String get emoji => _WeatherIconMapper.emojiFor(weatherIcon);

  factory EventImpact.fromFirestore(Map<String, dynamic> data) {
    DateTime? parsedDate;
    final rawDate = data['date'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate);
    }
    parsedDate ??= DateTime.now();

    return EventImpact(
      date: parsedDate,
      eventName: (data['eventName'] as String?) ?? 'Event',
      weatherIcon: (data['weatherIcon'] as String?) ?? (data['icon'] as String?) ?? '',
      condition: (data['condition'] as String?) ?? 'Unknown',
      eventType: data['eventType'] as String?,
      impactPercent: (data['impactPercent'] as num?)?.toDouble(),
      expectedSales: (data['expectedSales'] as num?)?.toDouble(),
      recommendation: data['recommendation'] as String?,
      severity: data['severity'] as String?,
    );
  }
}

/// Helper that maps weather icon keywords to emojis used in the UI.
class _WeatherIconMapper {
  static final Map<String, String> _emojiMap = {
    'sunny': '☀️',
    'clear': '☀️',
    'partly_cloudy': '⛅',
    'partly-cloudy': '⛅',
    'partly cloudy': '⛅',
    'cloudy': '☁️',
    'overcast': '☁️',
    'rain': '🌧️',
    'rainy': '🌧️',
    'showers': '🌧️',
    'storm': '⛈️',
    'thunderstorm': '⛈️',
    'snow': '❄️',
    'wind': '💨',
    'windy': '💨',
    'fog': '🌫️',
    'hail': '🌨️',
  };

  static String emojiFor(String? key) {
    if (key == null || key.trim().isEmpty) {
      return '–';
    }
    final normalised = key.trim().toLowerCase();
    return _emojiMap[normalised] ?? '🌡️';
  }
}
