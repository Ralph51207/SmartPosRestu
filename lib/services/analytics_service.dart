import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/sales_data_model.dart';
import '../models/order_model.dart' as order_model;

/// Analytics Service
/// Handles saving and retrieving sales analytics using Firestore
/// Uses Firestore for complex queries and historical data storage
class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _databaseUrl =
      'https://smart-restaurant-pos-default-rtdb.asia-southeast1.firebasedatabase.app';

  final FirebaseDatabase _databaseInstance = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: _databaseUrl,
  );

  DatabaseReference get _ordersRef => _databaseInstance.ref('orders');

  /// Save daily sales summary to Firestore
  Future<Map<String, dynamic>> saveDailySales(SalesData data) async {
    try {
      final dateKey =
          '${data.date.year}-${data.date.month.toString().padLeft(2, '0')}-${data.date.day.toString().padLeft(2, '0')}';

      await _firestore.collection('sales_history').doc(dateKey).set({
        'date': Timestamp.fromDate(data.date),
        'revenue': data.revenue,
        'orderCount': data.orderCount,
        'averageOrderValue': data.averageOrderValue,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Sales data saved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to save sales data: ${e.toString()}',
      };
    }
  }

  /// Get sales history for a date range
  Future<List<SalesData>> getSalesHistory({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('sales_history')
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return SalesData(
          date: (data['date'] as Timestamp).toDate(),
          revenue: (data['revenue'] as num).toDouble(),
          orderCount: data['orderCount'] as int,
          averageOrderValue: (data['averageOrderValue'] as num).toDouble(),
        );
      }).toList();
    } catch (e) {
      print('Error fetching sales history: $e');
      return [];
    }
  }

  /// Cache forecast results in Firestore
  Future<Map<String, dynamic>> cacheForecast(
      List<SalesForecast> forecasts) async {
    try {
      final batch = _firestore.batch();

      for (final forecast in forecasts) {
        final docRef = _firestore
            .collection('forecasts')
            .doc('${forecast.date.millisecondsSinceEpoch}');

        batch.set(docRef, {
          'date': Timestamp.fromDate(forecast.date),
          'predictedRevenue': forecast.predictedRevenue,
          'confidence': forecast.confidence,
          'insights': forecast.insights,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      return {
        'success': true,
        'message': 'Forecasts cached successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to cache forecasts: ${e.toString()}',
      };
    }
  }

  /// Get cached forecasts from Firestore
  Future<List<SalesForecast>> getCachedForecasts({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('forecasts')
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return SalesForecast(
          date: (data['date'] as Timestamp).toDate(),
          predictedRevenue: (data['predictedRevenue'] as num).toDouble(),
          confidence: (data['confidence'] as num).toDouble(),
          insights: List<String>.from(data['insights'] ?? []),
        );
      }).toList();
    } catch (e) {
      print('Error fetching cached forecasts: $e');
      return [];
    }
  }

  /// Aggregate today's sales data from Realtime Database orders
  Future<SalesData?> aggregateTodaysSales() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

        final snapshot = await _ordersRef
          .orderByChild('timestamp')
          .startAt(startOfDay.millisecondsSinceEpoch)
          .endAt(endOfDay.millisecondsSinceEpoch)
          .get();

      if (!snapshot.exists) {
        return SalesData(
          date: today,
          revenue: 0,
          orderCount: 0,
          averageOrderValue: 0,
        );
      }

      final ordersMap = snapshot.value as Map<dynamic, dynamic>;
      final orders = ordersMap.entries
          .map((entry) {
            final orderData = Map<String, dynamic>.from(entry.value as Map);
            return order_model.Order.fromJson(orderData);
          })
          .where((order) => order.status == order_model.OrderStatus.completed)
          .toList();

      final revenue =
          orders.fold(0.0, (sum, order) => sum + order.totalAmount);
      final orderCount = orders.length;
      final averageOrderValue = orderCount > 0 ? revenue / orderCount : 0.0;

      return SalesData(
        date: today,
        revenue: revenue,
        orderCount: orderCount,
        averageOrderValue: averageOrderValue,
      );
    } catch (e) {
      print('Error aggregating today\'s sales: $e');
      return null;
    }
  }

  /// Save analytics cache summary
  Future<void> saveAnalyticsSummary(
    String period,
    Map<String, dynamic> summary,
  ) async {
    try {
      await _firestore
          .collection('analytics_cache')
          .doc(period)
          .set({
        ...summary,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving analytics summary: $e');
    }
  }

  /// Get analytics summary
  Future<Map<String, dynamic>?> getAnalyticsSummary(String period) async {
    try {
      final doc = await _firestore.collection('analytics_cache').doc(period).get();
      
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error fetching analytics summary: $e');
      return null;
    }
  }

  /// Get monthly revenue trend
  Future<List<Map<String, dynamic>>> getMonthlyRevenueTrend(int months) async {
    try {
      final endDate = DateTime.now();
      final startDate = DateTime(endDate.year, endDate.month - months, 1);

      final salesHistory =
          await getSalesHistory(startDate: startDate, endDate: endDate);

      // Group by month
      final monthlyData = <String, double>{};
      for (final sale in salesHistory) {
        final monthKey = '${sale.date.year}-${sale.date.month.toString().padLeft(2, '0')}';
        monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + sale.revenue;
      }

      return monthlyData.entries
          .map((e) => {'month': e.key, 'revenue': e.value})
          .toList()
        ..sort((a, b) => (a['month'] as String).compareTo(b['month'] as String));
    } catch (e) {
      print('Error fetching monthly trend: $e');
      return [];
    }
  }

  /// Clear old forecast cache (older than 7 days)
  Future<void> clearOldForecasts() async {
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

      final snapshot = await _firestore
          .collection('forecasts')
          .where('createdAt',
              isLessThan: Timestamp.fromDate(sevenDaysAgo))
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      print('Error clearing old forecasts: $e');
    }
  }
}
