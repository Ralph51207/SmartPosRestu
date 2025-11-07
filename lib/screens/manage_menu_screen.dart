import 'package:flutter/material.dart';
import '../models/menu_item_model.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

/// Manage Menu Screen - Edit categories and dishes
class ManageMenuScreen extends StatefulWidget {
  const ManageMenuScreen({Key? key}) : super(key: key);

  @override
  State<ManageMenuScreen> createState() => _ManageMenuScreenState();
}

class _ManageMenuScreenState extends State<ManageMenuScreen> {
  MenuCategory? _selectedCategory; // null means "All Items"
  final List<MenuItem> _menuItems = [];
  String _searchQuery = '';
  
  // Custom categories storage (label, icon, category)
  final List<Map<String, dynamic>> _customCategories = [
    {'label': 'Main', 'icon': Icons.dinner_dining, 'category': MenuCategory.mainCourse},
    {'label': 'Sides', 'icon': Icons.rice_bowl, 'category': MenuCategory.appetizer},
    {'label': 'Desserts', 'icon': Icons.cake, 'category': MenuCategory.dessert},
    {'label': 'Beverages', 'icon': Icons.local_cafe, 'category': MenuCategory.beverage},
  ];

  @override
  void initState() {
    super.initState();
    _loadMenuItems();
  }

  /// Load menu items
  void _loadMenuItems() {
    setState(() {
      _menuItems.addAll([
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
      ]);
    });
  }

  /// Get filtered menu items
  List<MenuItem> get _filteredItems {
    return _menuItems.where((item) {
      final matchesCategory = _selectedCategory == null || item.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        backgroundColor: AppConstants.darkSecondary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(
              Icons.restaurant_menu,
              color: AppConstants.primaryOrange,
            ),
            const SizedBox(width: AppConstants.paddingSmall),
            const Text(
              'Manage Menu',
              style: AppConstants.headingMedium,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showAddItemDialog,
            tooltip: 'Add New Item',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          _buildSearchBar(),

          // Category tabs
          _buildCategoryTabs(),

          // Menu items list
          Expanded(
            child: _buildMenuList(),
          ),
        ],
      ),
    );
  }

  /// Build search bar
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      color: AppConstants.darkSecondary,
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        style: AppConstants.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Search menu items...',
          hintStyle: AppConstants.bodyMedium.copyWith(
            color: AppConstants.textSecondary,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppConstants.textSecondary,
          ),
          filled: true,
          fillColor: AppConstants.cardBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMedium,
            vertical: AppConstants.paddingSmall,
          ),
        ),
      ),
    );
  }

  /// Build category tabs
  Widget _buildCategoryTabs() {
    return Container(
      height: 100,
      color: AppConstants.darkSecondary,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingMedium,
          vertical: AppConstants.paddingSmall,
        ),
        children: [
          // "All Items" tab (cannot be deleted)
          _buildCategoryTab(
            'All Items',
            Icons.restaurant_menu,
            null, // null means show all categories
            canDelete: false,
          ),
          // Dynamic categories from _customCategories
          ..._customCategories.map((cat) {
            return _buildCategoryTab(
              cat['label'],
              cat['icon'],
              cat['category'],
              canDelete: true,
            );
          }).toList(),
          // Add new category button
          _buildAddCategoryButton(),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(String label, IconData icon, MenuCategory? category, {required bool canDelete}) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      onLongPress: canDelete && category != null
          ? () => _showCategoryOptions(label, icon, category)
          : null,
      child: Stack(
        children: [
          Container(
            width: 80,
            margin: const EdgeInsets.only(right: AppConstants.paddingSmall),
            padding: const EdgeInsets.all(AppConstants.paddingSmall),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppConstants.primaryOrange
                  : AppConstants.cardBackground,
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : AppConstants.textSecondary,
                  size: 32,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? Colors.white : AppConstants.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Edit icon for deletable categories
          if (canDelete && category != null)
            Positioned(
              top: 2,
              right: 6,
              child: GestureDetector(
                onTap: () => _showCategoryOptions(label, icon, category),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Colors.white.withOpacity(0.3)
                        : AppConstants.darkSecondary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.more_vert,
                    size: 16,
                    color: isSelected 
                        ? Colors.white
                        : AppConstants.textPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build add category button
  Widget _buildAddCategoryButton() {
    return GestureDetector(
      onTap: _showAddCategoryDialog,
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: AppConstants.paddingSmall),
        padding: const EdgeInsets.all(AppConstants.paddingSmall),
        decoration: BoxDecoration(
          color: AppConstants.primaryOrange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(
            color: AppConstants.primaryOrange,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              color: AppConstants.primaryOrange,
              size: 30,
            ),
            const SizedBox(height: 4),
            Text(
              'Add',
              style: TextStyle(
                fontSize: 10,
                color: AppConstants.primaryOrange,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.visible,
            ),
            Text(
              'Category',
              style: TextStyle(
                fontSize: 9,
                color: AppConstants.primaryOrange,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Build menu list
  Widget _buildMenuList() {
    if (_filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: AppConstants.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              'No items found',
              style: AppConstants.headingSmall.copyWith(
                color: AppConstants.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        return _buildMenuItem(item);
      },
    );
  }

  /// Build menu item card (editable)
  Widget _buildMenuItem(MenuItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
      color: AppConstants.cardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: InkWell(
        onTap: () => _showEditItemDialog(item),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: Row(
            children: [
              // Item icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppConstants.darkSecondary,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                ),
                child: Icon(
                  _getCategoryIcon(item.category),
                  color: AppConstants.primaryOrange,
                  size: 32,
                ),
              ),
              const SizedBox(width: AppConstants.paddingMedium),

              // Item details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: AppConstants.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Availability toggle
                        Switch(
                          value: item.isAvailable,
                          onChanged: (value) {
                            setState(() {
                              final index = _menuItems.indexOf(item);
                              _menuItems[index] = MenuItem(
                                id: item.id,
                                name: item.name,
                                description: item.description,
                                price: item.price,
                                category: item.category,
                                isAvailable: value,
                                salesCount: item.salesCount,
                              );
                            });
                          },
                          activeColor: AppConstants.successGreen,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: AppConstants.bodySmall.copyWith(
                        color: AppConstants.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          Formatters.formatCurrency(item.price),
                          style: AppConstants.bodyLarge.copyWith(
                            color: AppConstants.primaryOrange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: AppConstants.paddingMedium),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppConstants.darkSecondary,
                            borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                          ),
                          child: Text(
                            item.category.toString().split('.').last,
                            style: AppConstants.bodySmall.copyWith(
                              color: AppConstants.textSecondary,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Edit button
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          color: AppConstants.primaryOrange,
                          onPressed: () => _showEditItemDialog(item),
                        ),
                        // Delete button
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          color: AppConstants.errorRed,
                          onPressed: () => _showDeleteConfirmation(item),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get category icon
  IconData _getCategoryIcon(MenuCategory category) {
    switch (category) {
      case MenuCategory.appetizer:
        return Icons.restaurant;
      case MenuCategory.mainCourse:
        return Icons.dinner_dining;
      case MenuCategory.dessert:
        return Icons.cake;
      case MenuCategory.beverage:
        return Icons.local_cafe;
      case MenuCategory.special:
        return Icons.star;
    }
  }

  /// Show add item dialog
  void _showAddItemDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();
    MenuCategory selectedCategory = MenuCategory.mainCourse;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppConstants.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
          title: const Text('Add New Item', style: AppConstants.headingSmall),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  style: AppConstants.bodyMedium,
                  decoration: InputDecoration(
                    labelText: 'Item Name',
                    labelStyle: AppConstants.bodyMedium.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppConstants.darkSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                TextField(
                  controller: descriptionController,
                  style: AppConstants.bodyMedium,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: AppConstants.bodyMedium.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppConstants.darkSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                TextField(
                  controller: priceController,
                  style: AppConstants.bodyMedium,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Price',
                    labelStyle: AppConstants.bodyMedium.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                    prefixText: '\$ ',
                    filled: true,
                    fillColor: AppConstants.darkSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                DropdownButtonFormField<MenuCategory>(
                  value: selectedCategory,
                  dropdownColor: AppConstants.cardBackground,
                  style: AppConstants.bodyMedium,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    labelStyle: AppConstants.bodyMedium.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppConstants.darkSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: MenuCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(
                        category.toString().split('.').last,
                        style: AppConstants.bodyMedium,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedCategory = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppConstants.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    priceController.text.isNotEmpty) {
                  setState(() {
                    _menuItems.add(
                      MenuItem(
                        id: 'MENU${_menuItems.length + 1}'.padLeft(7, '0'),
                        name: nameController.text,
                        description: descriptionController.text,
                        price: double.tryParse(priceController.text) ?? 0.0,
                        category: selectedCategory,
                        isAvailable: true,
                        salesCount: 0,
                      ),
                    );
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${nameController.text} added successfully'),
                      backgroundColor: AppConstants.successGreen,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryOrange,
              ),
              child: const Text('Add Item'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show edit item dialog
  void _showEditItemDialog(MenuItem item) {
    final nameController = TextEditingController(text: item.name);
    final descriptionController = TextEditingController(text: item.description);
    final priceController = TextEditingController(text: item.price.toString());
    MenuCategory selectedCategory = item.category;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppConstants.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
          title: const Text('Edit Item', style: AppConstants.headingSmall),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  style: AppConstants.bodyMedium,
                  decoration: InputDecoration(
                    labelText: 'Item Name',
                    labelStyle: AppConstants.bodyMedium.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppConstants.darkSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                TextField(
                  controller: descriptionController,
                  style: AppConstants.bodyMedium,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: AppConstants.bodyMedium.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppConstants.darkSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                TextField(
                  controller: priceController,
                  style: AppConstants.bodyMedium,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Price',
                    labelStyle: AppConstants.bodyMedium.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                    prefixText: '\$ ',
                    filled: true,
                    fillColor: AppConstants.darkSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                DropdownButtonFormField<MenuCategory>(
                  value: selectedCategory,
                  dropdownColor: AppConstants.cardBackground,
                  style: AppConstants.bodyMedium,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    labelStyle: AppConstants.bodyMedium.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppConstants.darkSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: MenuCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(
                        category.toString().split('.').last,
                        style: AppConstants.bodyMedium,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedCategory = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppConstants.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    priceController.text.isNotEmpty) {
                  setState(() {
                    final index = _menuItems.indexOf(item);
                    _menuItems[index] = MenuItem(
                      id: item.id,
                      name: nameController.text,
                      description: descriptionController.text,
                      price: double.tryParse(priceController.text) ?? 0.0,
                      category: selectedCategory,
                      isAvailable: item.isAvailable,
                      salesCount: item.salesCount,
                    );
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${nameController.text} updated successfully'),
                      backgroundColor: AppConstants.successGreen,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryOrange,
              ),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show delete confirmation
  void _showDeleteConfirmation(MenuItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
        title: Row(
          children: [
            Icon(Icons.warning, color: AppConstants.errorRed),
            const SizedBox(width: AppConstants.paddingSmall),
            const Text('Delete Item', style: AppConstants.headingSmall),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${item.name}"? This action cannot be undone.',
          style: AppConstants.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppConstants.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _menuItems.remove(item);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${item.name} deleted successfully'),
                  backgroundColor: AppConstants.errorRed,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.errorRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Show category options (Edit/Delete)
  void _showCategoryOptions(String label, IconData icon, MenuCategory category) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusLarge),
        ),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit, color: AppConstants.primaryOrange),
              title: const Text('Edit Category Name', style: AppConstants.bodyMedium),
              onTap: () {
                Navigator.pop(context);
                _showEditCategoryDialog(label, icon, category);
              },
            ),
            ListTile(
              leading: Icon(Icons.palette, color: AppConstants.primaryOrange),
              title: const Text('Change Icon', style: AppConstants.bodyMedium),
              onTap: () {
                Navigator.pop(context);
                _showIconPicker(label, icon, category);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: AppConstants.errorRed),
              title: Text(
                'Delete Category',
                style: AppConstants.bodyMedium.copyWith(color: AppConstants.errorRed),
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteCategoryConfirmation(label, category);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Show add category dialog
  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    IconData selectedIcon = Icons.restaurant;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppConstants.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
          title: const Text('Add New Category', style: AppConstants.headingSmall),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: AppConstants.bodyMedium,
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  labelStyle: AppConstants.bodyMedium.copyWith(
                    color: AppConstants.textSecondary,
                  ),
                  filled: true,
                  fillColor: AppConstants.darkSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              Row(
                children: [
                  Text(
                    'Icon: ',
                    style: AppConstants.bodyMedium.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppConstants.paddingSmall),
                  Container(
                    padding: const EdgeInsets.all(AppConstants.paddingSmall),
                    decoration: BoxDecoration(
                      color: AppConstants.darkSecondary,
                      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                    ),
                    child: Icon(
                      selectedIcon,
                      color: AppConstants.primaryOrange,
                      size: 32,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      // Simple icon picker
                      _showSimpleIconPicker((icon) {
                        setDialogState(() {
                          selectedIcon = icon;
                        });
                      });
                    },
                    child: Text(
                      'Change',
                      style: TextStyle(color: AppConstants.primaryOrange),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppConstants.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  setState(() {
                    // Add new category to the list
                    _customCategories.add({
                      'label': nameController.text,
                      'icon': selectedIcon,
                      'category': MenuCategory.special, // Use 'special' for custom categories
                    });
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Category "${nameController.text}" added successfully'),
                      backgroundColor: AppConstants.successGreen,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryOrange,
              ),
              child: const Text('Add Category'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show edit category dialog
  void _showEditCategoryDialog(String label, IconData icon, MenuCategory category) {
    final nameController = TextEditingController(text: label);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
        title: const Text('Edit Category Name', style: AppConstants.headingSmall),
        content: TextField(
          controller: nameController,
          style: AppConstants.bodyMedium,
          decoration: InputDecoration(
            labelText: 'Category Name',
            labelStyle: AppConstants.bodyMedium.copyWith(
              color: AppConstants.textSecondary,
            ),
            filled: true,
            fillColor: AppConstants.darkSecondary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppConstants.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                setState(() {
                  // Find and update the category in the list
                  final index = _customCategories.indexWhere((cat) => 
                    cat['label'] == label && cat['category'] == category
                  );
                  if (index != -1) {
                    _customCategories[index]['label'] = nameController.text;
                  }
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Category renamed to "${nameController.text}"'),
                    backgroundColor: AppConstants.successGreen,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryOrange,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Show icon picker
  void _showIconPicker(String label, IconData currentIcon, MenuCategory category) {
    _showSimpleIconPicker((icon) {
      setState(() {
        // Find and update the icon in the list
        final index = _customCategories.indexWhere((cat) => 
          cat['label'] == label && cat['category'] == category
        );
        if (index != -1) {
          _customCategories[index]['icon'] = icon;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Icon updated for "$label"'),
          backgroundColor: AppConstants.successGreen,
        ),
      );
    });
  }

  /// Simple icon picker
  void _showSimpleIconPicker(Function(IconData) onIconSelected) {
    final icons = [
      Icons.restaurant,
      Icons.dinner_dining,
      Icons.lunch_dining,
      Icons.breakfast_dining,
      Icons.rice_bowl,
      Icons.ramen_dining,
      Icons.cake,
      Icons.icecream,
      Icons.local_cafe,
      Icons.local_bar,
      Icons.wine_bar,
      Icons.liquor,
      Icons.fastfood,
      Icons.restaurant_menu,
      Icons.soup_kitchen,
      Icons.set_meal,
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
        title: const Text('Select Icon', style: AppConstants.headingSmall),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: icons.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  onIconSelected(icons[index]);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: AppConstants.darkSecondary,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                  ),
                  child: Icon(
                    icons[index],
                    color: AppConstants.primaryOrange,
                    size: 32,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Show delete category confirmation
  void _showDeleteCategoryConfirmation(String label, MenuCategory category) {
    final itemsInCategory = _menuItems.where((item) => item.category == category).length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
        title: Row(
          children: [
            Icon(Icons.warning, color: AppConstants.errorRed),
            const SizedBox(width: AppConstants.paddingSmall),
            const Text('Delete Category', style: AppConstants.headingSmall),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "$label"?',
              style: AppConstants.bodyMedium,
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            if (itemsInCategory > 0)
              Text(
                'Warning: This category has $itemsInCategory item(s). They will need to be reassigned.',
                style: AppConstants.bodySmall.copyWith(
                  color: AppConstants.errorRed,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppConstants.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                // Remove the category from the list
                _customCategories.removeWhere((cat) => 
                  cat['label'] == label && cat['category'] == category
                );
                // If this was the selected category, reset to "All Items"
                if (_selectedCategory == category) {
                  _selectedCategory = null;
                }
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Category "$label" deleted'),
                  backgroundColor: AppConstants.errorRed,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.errorRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
