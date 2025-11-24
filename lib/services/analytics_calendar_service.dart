import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/analytics_calendar_model.dart';
import '../utils/analytics_fallback.dart';

/// Service responsible for retrieving analytics calendar and event impact data
/// from Firebase. This replaces external API calls for the weather/event widgets.
class AnalyticsCalendarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _calendarCollection =>
      _firestore.collection('analytics_calendar');
  CollectionReference<Map<String, dynamic>> get _impactsCollection =>
      _firestore.collection('analytics_impacts');

  final DateFormat _docIdFormatter = DateFormat('yyyy-MM');

  /// Load the weather calendar document for the specified month.
  Future<WeatherCalendarMonth> fetchMonth(
    DateTime month, {
    int fallbackRangeDays = AnalyticsFallback.defaultRangeDays,
  }) async {
    final normalisedMonth = DateTime(month.year, month.month);
    final docId = _docIdFormatter.format(normalisedMonth);

    final days = <WeatherDay>[];

    try {
      final snapshot = await _calendarCollection.doc(docId).get();
      if (snapshot.exists) {
        final data = snapshot.data();
        final daysRaw = data?['days'];
        if (daysRaw is Map) {
          daysRaw.forEach((key, value) {
            if (value is Map) {
              final map = value.map((k, v) => MapEntry(k.toString(), v));
              days.add(WeatherDay.fromFirestore(key.toString(), map));
            }
          });
        }
      }
    } catch (_) {
      // Ignore errors and fall back to local data.
    }

    if (days.isEmpty) {
      days.addAll(
        AnalyticsFallback.generateMonthDays(
          normalisedMonth,
          rangeDays: fallbackRangeDays,
        ),
      );
    }

    return WeatherCalendarMonth(month: normalisedMonth, days: days);
  }

  /// Load all event/weather impact records that fall within the provided range.
  Future<List<EventImpact>> fetchImpacts({
    required DateTime start,
    required DateTime end,
    int fallbackRangeDays = AnalyticsFallback.defaultRangeDays,
  }) async {
    final startTimestamp = Timestamp.fromDate(
      DateTime(start.year, start.month, start.day),
    );
    final endExclusive = DateTime(end.year, end.month, end.day).add(
      const Duration(days: 1),
    );
    final endTimestamp = Timestamp.fromDate(endExclusive);

    try {
      final query = await _impactsCollection
          .orderBy('date')
          .where('date', isGreaterThanOrEqualTo: startTimestamp)
          .where('date', isLessThan: endTimestamp)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs
            .map((doc) => EventImpact.fromFirestore(doc.data()))
            .toList();
      }
    } catch (_) {
      // Ignore errors and fall back to local data.
    }

    return AnalyticsFallback.generateImpacts(
      start,
      end,
      rangeDays: fallbackRangeDays,
    );
  }
}
