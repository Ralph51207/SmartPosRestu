/// Menu item model representing dishes available in the restaurant
class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final MenuCategory category;
  final String categoryLabel;
  final String? imageUrl;
  final bool isAvailable;
  final int salesCount;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    String? categoryLabel,
    this.imageUrl,
    this.isAvailable = true,
    this.salesCount = 0,
  }) : categoryLabel = categoryLabel ?? MenuCategoryHelper.labelFor(category);

  /// Create a modified copy of this menu item
  MenuItem copyWith({
    String? name,
    String? description,
    double? price,
    MenuCategory? category,
    String? categoryLabel,
    String? imageUrl,
    bool? isAvailable,
    int? salesCount,
  }) {
    return MenuItem(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      categoryLabel: categoryLabel ?? this.categoryLabel,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      salesCount: salesCount ?? this.salesCount,
    );
  }

  /// Convert to JSON for Firebase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category': category.toString().split('.').last,
      'categoryLabel': categoryLabel,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'salesCount': salesCount,
    };
  }

  /// Create from JSON (Firebase)
  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      price: json['price'].toDouble(),
        category: MenuCategoryHelper.fromString(json['category']),
        categoryLabel: json['categoryLabel'] ??
          MenuCategoryHelper.labelForString(json['category']),
      imageUrl: json['imageUrl'],
      isAvailable: json['isAvailable'] ?? true,
      salesCount: json['salesCount'] ?? 0,
    );
  }
}

/// Menu category enum
enum MenuCategory {
  appetizer,
  mainCourse,
  dessert,
  beverage,
  special,
}

/// Helper utilities for working with [MenuCategory]
class MenuCategoryHelper {
  static const Map<MenuCategory, String> _defaultLabels = {
    MenuCategory.appetizer: 'Sides',
    MenuCategory.mainCourse: 'Main',
    MenuCategory.dessert: 'Desserts',
    MenuCategory.beverage: 'Beverages',
    MenuCategory.special: 'Special',
  };

  static MenuCategory fromString(String? value) {
    if (value == null) {
      return MenuCategory.mainCourse;
    }
    return MenuCategory.values.firstWhere(
      (category) => category.toString().split('.').last == value,
      orElse: () => MenuCategory.special,
    );
  }

  static String labelFor(MenuCategory category) {
    return _defaultLabels[category] ?? 'Category';
  }

  static String labelForString(String? value) {
    final category = fromString(value);
    return labelFor(category);
  }
}
