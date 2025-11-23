import '../models/menu_item_model.dart';
import '../services/menu_service.dart';

/// Seed initial menu data to Firebase
/// Call this once to populate your database with sample menu items
class MenuSeeder {
  final MenuService _menuService = MenuService();

  Future<void> seedMenuData() async {
    final menuItems = [
      // Main Course
      MenuItem(
        id: 'MENU001',
        name: 'Spicy Edamame',
        description: 'Steamed edamame tossed with chili garlic sauce, a classic appetizer',
        price: 7.50,
        category: MenuCategory.mainCourse,
        isAvailable: true,
        salesCount: 145,
      ),
      MenuItem(
        id: 'MENU002',
        name: 'Crispy Spring Rolls',
        description: 'Hand-rolled vegetable spring rolls served with sweet chili dipping',
        price: 9.00,
        category: MenuCategory.mainCourse,
        isAvailable: true,
        salesCount: 134,
      ),
      MenuItem(
        id: 'MENU003',
        name: 'Grilled Salmon',
        description: 'Perfectly seared salmon fillet with lemon asparagus and herbs',
        price: 22.00,
        category: MenuCategory.mainCourse,
        isAvailable: true,
        salesCount: 98,
      ),
      MenuItem(
        id: 'MENU004',
        name: 'Margherita Pizza',
        description: 'Classic Italian pizza with tomato, mozzarella, and fresh basil',
        price: 15.00,
        category: MenuCategory.mainCourse,
        isAvailable: true,
        salesCount: 210,
      ),
      MenuItem(
        id: 'MENU005',
        name: 'Pasta Carbonara',
        description: 'Creamy pasta with bacon, eggs, and parmesan cheese',
        price: 17.00,
        category: MenuCategory.mainCourse,
        isAvailable: true,
        salesCount: 156,
      ),
      
      // Desserts
      MenuItem(
        id: 'MENU006',
        name: 'Cheesecake',
        description: 'Classic New York style cheesecake topped with a homemade berry compote',
        price: 10.00,
        category: MenuCategory.dessert,
        isAvailable: true,
        salesCount: 89,
      ),
      MenuItem(
        id: 'MENU007',
        name: 'Tiramisu',
        description: 'Layers of coffee-soaked ladyfingers, mascarpone and cocoa',
        price: 9.50,
        category: MenuCategory.dessert,
        isAvailable: true,
        salesCount: 76,
      ),
      
      // Beverages
      MenuItem(
        id: 'MENU008',
        name: 'Fresh Orange Juice',
        description: 'Freshly squeezed oranges, pure and refreshing',
        price: 5.00,
        category: MenuCategory.beverage,
        isAvailable: true,
        salesCount: 201,
      ),
      MenuItem(
        id: 'MENU009',
        name: 'Espresso',
        description: 'Rich, intense shot of concentrated coffee',
        price: 3.50,
        category: MenuCategory.beverage,
        isAvailable: true,
        salesCount: 312,
      ),
      MenuItem(
        id: 'MENU010',
        name: 'Iced Latte',
        description: 'Smooth espresso with cold milk over ice',
        price: 5.50,
        category: MenuCategory.beverage,
        isAvailable: true,
        salesCount: 267,
      ),
    ];

    print('🌱 Seeding menu data to Firebase...');
    
    for (var item in menuItems) {
      final result = await _menuService.createMenuItem(item);
      if (result['success']) {
        print('✅ Added: ${item.name}');
      } else {
        print('❌ Failed to add ${item.name}: ${result['error']}');
      }
    }
    
    print('🎉 Menu seeding complete!');
  }
}
