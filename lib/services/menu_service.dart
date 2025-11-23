import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/menu_item_model.dart';

/// Menu Service
/// Handles CRUD operations for menu items in Firebase Realtime Database
class MenuService {
  static const String _databaseUrl =
      'https://smart-restaurant-pos-default-rtdb.asia-southeast1.firebasedatabase.app';

  final FirebaseDatabase _databaseInstance = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: _databaseUrl,
  );

  DatabaseReference get _menuRef => _databaseInstance.ref('menu');

  /// Get all menu items as a stream
  Stream<List<MenuItem>> getMenuItemsStream() {
    print('📡 Setting up menu items stream listener...');
    return _menuRef.onValue.map((event) {
      print('📡 Received data event from Firebase');
      print('📡 Event snapshot exists: ${event.snapshot.exists}');
      print('📡 Event snapshot value type: ${event.snapshot.value.runtimeType}');
      
      final menuMap = event.snapshot.value as Map<dynamic, dynamic>?;
      if (menuMap == null) {
        print('⚠️ No menu data found in Firebase (menuMap is null)');
        return <MenuItem>[];
      }

      print('📡 Found ${menuMap.length} menu items in Firebase');
      print('📡 Menu IDs: ${menuMap.keys.toList()}');
      
      return menuMap.entries.map((entry) {
        final itemData = Map<String, dynamic>.from(entry.value as Map);
        return MenuItem.fromJson(itemData);
      }).toList();
    });
  }

  /// Get a single menu item by ID
  Future<MenuItem?> getMenuItemById(String itemId) async {
    try {
      final snapshot = await _menuRef.child(itemId).get();
      if (snapshot.exists) {
        final itemData = Map<String, dynamic>.from(snapshot.value as Map);
        return MenuItem.fromJson(itemData);
      }
      return null;
    } catch (e) {
      print('Error fetching menu item: $e');
      return null;
    }
  }

  /// Get menu items by category
  Future<List<MenuItem>> getMenuItemsByCategory(MenuCategory category) async {
    try {
        final snapshot = await _menuRef
          .orderByChild('category')
          .equalTo(category.toString().split('.').last)
          .get();

      if (snapshot.exists) {
        final menuMap = snapshot.value as Map<dynamic, dynamic>;
        return menuMap.entries.map((entry) {
          final itemData = Map<String, dynamic>.from(entry.value as Map);
          return MenuItem.fromJson(itemData);
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching menu by category: $e');
      return [];
    }
  }

  /// Get available menu items only
  Future<List<MenuItem>> getAvailableMenuItems() async {
    try {
        final snapshot = await _menuRef
          .orderByChild('isAvailable')
          .equalTo(true)
          .get();

      if (snapshot.exists) {
        final menuMap = snapshot.value as Map<dynamic, dynamic>;
        return menuMap.entries.map((entry) {
          final itemData = Map<String, dynamic>.from(entry.value as Map);
          return MenuItem.fromJson(itemData);
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching available menu items: $e');
      return [];
    }
  }

  /// Create a new menu item
  Future<Map<String, dynamic>> createMenuItem(MenuItem item) async {
    try {
      print('📝 Creating menu item: ${item.name} with ID: ${item.id}');
      print('📝 Data to save: ${item.toJson()}');
      print('📝 Database URL: https://smart-restaurant-pos-default-rtdb.asia-southeast1.firebasedatabase.app');
      
      await _menuRef.child(item.id).set(item.toJson());
      
      print('✅ Menu item created successfully in Firebase');

      return {
        'success': true,
        'message': 'Menu item created successfully',
        'itemId': item.id,
      };
    } catch (e) {
      print('❌ Error creating menu item: $e');
      return {
        'success': false,
        'error': 'Failed to create menu item: ${e.toString()}',
      };
    }
  }

  /// Update menu item
  Future<Map<String, dynamic>> updateMenuItem(MenuItem item) async {
    try {
      await _menuRef.child(item.id).update(item.toJson());

      return {
        'success': true,
        'message': 'Menu item updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to update menu item: ${e.toString()}',
      };
    }
  }

  /// Update menu item availability
  Future<Map<String, dynamic>> updateItemAvailability(
    String itemId,
    bool isAvailable,
  ) async {
    try {
      await _menuRef.child(itemId).update({
        'isAvailable': isAvailable,
      });

      return {
        'success': true,
        'message': 'Item availability updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to update availability: ${e.toString()}',
      };
    }
  }

  /// Increment sales count for a menu item
  Future<void> incrementSalesCount(String itemId) async {
    try {
      final snapshot = await _menuRef.child(itemId).child('salesCount').get();
      final currentCount = (snapshot.value as int?) ?? 0;
      
      await _menuRef.child(itemId).update({
        'salesCount': currentCount + 1,
      });
    } catch (e) {
      print('Error incrementing sales count: $e');
    }
  }

  /// Delete a menu item
  Future<Map<String, dynamic>> deleteMenuItem(String itemId) async {
    try {
      await _menuRef.child(itemId).remove();

      return {
        'success': true,
        'message': 'Menu item deleted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to delete menu item: ${e.toString()}',
      };
    }
  }

  /// Get top-selling items
  Future<List<MenuItem>> getTopSellingItems({int limit = 5}) async {
    try {
        final snapshot = await _menuRef
          .orderByChild('salesCount')
          .limitToLast(limit)
          .get();

      if (snapshot.exists) {
        final menuMap = snapshot.value as Map<dynamic, dynamic>;
        final items = menuMap.entries.map((entry) {
          final itemData = Map<String, dynamic>.from(entry.value as Map);
          return MenuItem.fromJson(itemData);
        }).toList();

        // Sort by sales count descending
        items.sort((a, b) => b.salesCount.compareTo(a.salesCount));
        return items;
      }
      return [];
    } catch (e) {
      print('Error fetching top-selling items: $e');
      return [];
    }
  }

  /// Search menu items by name
  Future<List<MenuItem>> searchMenuItems(String query) async {
    try {
      final snapshot = await _menuRef.get();
      if (!snapshot.exists) return [];

      final menuMap = snapshot.value as Map<dynamic, dynamic>;
      final allItems = menuMap.entries.map((entry) {
        final itemData = Map<String, dynamic>.from(entry.value as Map);
        return MenuItem.fromJson(itemData);
      }).toList();

      // Filter by name containing query (case-insensitive)
      return allItems.where((item) {
        return item.name.toLowerCase().contains(query.toLowerCase()) ||
            item.description.toLowerCase().contains(query.toLowerCase());
      }).toList();
    } catch (e) {
      print('Error searching menu items: $e');
      return [];
    }
  }

  /// Get menu statistics
  Future<Map<String, dynamic>> getMenuStatistics() async {
    try {
      final snapshot = await _menuRef.get();
      if (!snapshot.exists) {
        return {
          'totalItems': 0,
          'availableItems': 0,
          'unavailableItems': 0,
          'totalSales': 0,
          'averagePrice': 0.0,
        };
      }

      final menuMap = snapshot.value as Map<dynamic, dynamic>;
      final items = menuMap.entries.map((entry) {
        final itemData = Map<String, dynamic>.from(entry.value as Map);
        return MenuItem.fromJson(itemData);
      }).toList();

      final totalItems = items.length;
      final availableItems = items.where((i) => i.isAvailable).length;
      final totalSales = items.fold(0, (sum, item) => sum + item.salesCount);
      final averagePrice = items.fold(0.0, (sum, item) => sum + item.price) /
          (totalItems > 0 ? totalItems : 1);

      return {
        'totalItems': totalItems,
        'availableItems': availableItems,
        'unavailableItems': totalItems - availableItems,
        'totalSales': totalSales,
        'averagePrice': averagePrice,
      };
    } catch (e) {
      print('Error calculating menu statistics: $e');
      return {
        'totalItems': 0,
        'availableItems': 0,
        'unavailableItems': 0,
        'totalSales': 0,
        'averagePrice': 0.0,
      };
    }
  }

  /// Initialize sample menu items (for first-time setup)
  Future<void> initializeSampleMenu() async {
    final sampleItems = [
      MenuItem(
        id: 'item_1',
        name: 'Classic Burger',
        description: 'Juicy beef patty with fresh vegetables',
        price: 250.0,
        category: MenuCategory.mainCourse,
        isAvailable: true,
      ),
      MenuItem(
        id: 'item_2',
        name: 'Caesar Salad',
        description: 'Fresh romaine lettuce with caesar dressing',
        price: 180.0,
        category: MenuCategory.appetizer,
        isAvailable: true,
      ),
      MenuItem(
        id: 'item_3',
        name: 'Chocolate Cake',
        description: 'Rich chocolate cake with vanilla ice cream',
        price: 150.0,
        category: MenuCategory.dessert,
        isAvailable: true,
      ),
      MenuItem(
        id: 'item_4',
        name: 'Iced Coffee',
        description: 'Cold brew coffee with milk',
        price: 120.0,
        category: MenuCategory.beverage,
        isAvailable: true,
      ),
    ];

    for (final item in sampleItems) {
      await createMenuItem(item);
    }
  }
}
