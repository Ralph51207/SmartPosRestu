import 'dart:async';

import 'package:flutter/material.dart';

import '../models/menu_item_model.dart';
import '../models/order_model.dart';
import '../services/menu_service.dart';
import '../services/order_service.dart';
import '../services/table_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/add_item_bottom_sheet.dart';

/// New Order Screen - Create a new order with menu items
class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({Key? key}) : super(key: key);

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  MenuCategory? _selectedCategory; // null means "All Items"
  String? _selectedCategoryLabel;
  final MenuService _menuService = MenuService();
  final OrderService _orderService = OrderService();
  final TableService _tableService = TableService();
  StreamSubscription<List<MenuItem>>? _menuSubscription;

  final Map<String, int> _cart = {}; // itemId -> quantity
  final List<MenuItem> _menuItems = [];
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadMenuItems();
  }

  @override
  void dispose() {
    _menuSubscription?.cancel();
    super.dispose();
  }

  /// Load menu items
  void _loadMenuItems() {
    setState(() => _isLoading = true);

    _menuSubscription?.cancel();
    _menuSubscription = _menuService.getMenuItemsStream().listen(
      (items) {
        if (!mounted) return;
        setState(() {
          _menuItems
            ..clear()
            ..addAll(items);
          _isLoading = false;
          _removeInvalidCartItems();
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load menu: $error'),
            backgroundColor: AppConstants.errorRed,
          ),
        );
      },
    );
  }

  void _removeInvalidCartItems() {
    final validIds = _menuItems.map((item) => item.id).toSet();
    _cart.removeWhere((itemId, _) => !validIds.contains(itemId));
  }

  MenuItem? _findMenuItemById(String id) {
    try {
      return _menuItems.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  List<_CategoryFilter> get _categoryFilters {
    final order = {
      MenuCategory.mainCourse: 0,
      MenuCategory.appetizer: 1,
      MenuCategory.dessert: 2,
      MenuCategory.beverage: 3,
      MenuCategory.special: 4,
    };

    final Map<String, _CategoryFilter> filters = {};
    for (final item in _menuItems) {
      if (!item.isAvailable) {
        continue;
      }
      final key = '${item.category.name}|${item.categoryLabel.toLowerCase()}';
      filters.putIfAbsent(
        key,
        () => _CategoryFilter(
          category: item.category,
          label: item.categoryLabel,
          icon: _getCategoryIcon(item.category),
        ),
      );
    }

    final filterList = filters.values.toList()
      ..sort((a, b) {
        final orderDiff = (order[a.category] ?? 99) - (order[b.category] ?? 99);
        if (orderDiff != 0) {
          return orderDiff;
        }
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });

    return filterList;
  }

  /// Get filtered menu items
  List<MenuItem> get _filteredItems {
    return _menuItems.where((item) {
      final matchesCategory = _selectedCategory == null ||
          (item.category == _selectedCategory &&
              (_selectedCategoryLabel == null ||
                  item.categoryLabel == _selectedCategoryLabel));
      final matchesSearch = _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch && item.isAvailable;
    }).toList();
  }

  /// Get total amount
  double get _totalAmount {
    double total = 0;
    _cart.forEach((itemId, quantity) {
      final item = _findMenuItemById(itemId);
      if (item != null) {
        total += item.price * quantity;
      }
    });
    return total;
  }

  /// Get total items count
  int get _totalItems {
    return _cart.values.fold(0, (sum, quantity) => sum + quantity);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        backgroundColor: AppConstants.darkSecondary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Order', style: AppConstants.headingSmall),
            Text(
              'Total Amount',
              style: AppConstants.bodySmall.copyWith(
                color: AppConstants.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: AppConstants.paddingMedium),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.formatCurrency(_totalAmount),
                    style: AppConstants.headingSmall.copyWith(
                      color: AppConstants.primaryOrange,
                    ),
                  ),
                  Text(
                    '$_totalItems items',
                    style: AppConstants.bodySmall,
                  ),
                ],
              ),
            ),
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

          // Complete order button
          if (_cart.isNotEmpty) _buildCompleteOrderButton(),
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
    final categories = _categoryFilters;

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
          _buildCategoryTab(
            'All Items',
            Icons.restaurant_menu,
            null, // null means show all categories
          ),
          ...categories.map(
            (filter) => _buildCategoryTab(
              filter.label,
              filter.icon,
              filter.category,
              categoryLabel: filter.label,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(
    String label,
    IconData icon,
    MenuCategory? category, {
    String? categoryLabel,
  }) {
    final isSelected = category == null
        ? _selectedCategory == null
        : _selectedCategory == category && _selectedCategoryLabel == categoryLabel;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
          _selectedCategoryLabel = category == null ? null : categoryLabel;
        });
      },
      child: Container(
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
              style: AppConstants.bodySmall.copyWith(
                color: isSelected ? Colors.white : AppConstants.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build menu list
  Widget _buildMenuList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppConstants.primaryOrange),
            const SizedBox(height: AppConstants.paddingMedium),
            Text('Loading menu...', style: AppConstants.bodyMedium),
          ],
        ),
      );
    }

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
        final quantity = _cart[item.id] ?? 0;
        return _buildMenuItem(item, quantity);
      },
    );
  }

  /// Build menu item card
  Widget _buildMenuItem(MenuItem item, int quantity) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: quantity > 0
              ? AppConstants.primaryOrange
              : AppConstants.dividerColor,
          width: quantity > 0 ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Item image placeholder
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
                Text(
                  item.name,
                  style: AppConstants.headingSmall,
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
                Text(
                  Formatters.formatCurrency(item.price),
                  style: AppConstants.bodyLarge.copyWith(
                    color: AppConstants.primaryOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.categoryLabel,
                  style: AppConstants.bodySmall.copyWith(
                    color: AppConstants.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Add/Remove buttons
          const SizedBox(width: AppConstants.paddingSmall),
          _buildQuantityControls(item, quantity),
        ],
      ),
    );
  }

  /// Build quantity controls
  Widget _buildQuantityControls(MenuItem item, int quantity) {
    if (quantity == 0) {
      return ElevatedButton.icon(
        onPressed: () => _addItem(item),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryOrange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMedium,
            vertical: AppConstants.paddingSmall,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppConstants.primaryOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
        border: Border.all(
          color: AppConstants.primaryOrange,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _removeItem(item),
            icon: const Icon(Icons.remove, size: 18),
            color: AppConstants.primaryOrange,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              quantity.toString(),
              style: AppConstants.bodyLarge.copyWith(
                color: AppConstants.primaryOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _addItem(item),
            icon: const Icon(Icons.add, size: 18),
            color: AppConstants.primaryOrange,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
        ],
      ),
    );
  }

  /// Build complete order button
  Widget _buildCompleteOrderButton() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.darkSecondary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _showCompleteOrderDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline),
              const SizedBox(width: AppConstants.paddingSmall),
              Text(
                _isSubmitting
                    ? 'Processing order...'
                    : 'Complete Order - ${Formatters.formatCurrency(_totalAmount)}',
                style: AppConstants.headingSmall.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Add item to cart (shows bottom sheet for customization)
  void _addItem(MenuItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddItemBottomSheet(
        item: item,
        currentQuantity: _cart[item.id] ?? 0,
        onAdd: (quantity, notes) {
          setState(() {
            _cart[item.id] = quantity;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${item.name} added to cart'),
              duration: const Duration(seconds: 2),
              backgroundColor: AppConstants.successGreen,
            ),
          );
        },
      ),
    );
  }

  /// Remove item from cart
  void _removeItem(MenuItem item) {
    setState(() {
      if (_cart[item.id] != null) {
        if (_cart[item.id]! > 1) {
          _cart[item.id] = _cart[item.id]! - 1;
        } else {
          _cart.remove(item.id);
        }
      }
    });
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

  /// Show complete order dialog
  void _showCompleteOrderDialog() {
    showDialog<_CompleteOrderResult>(
      context: context,
      barrierDismissible: !_isSubmitting,
      builder: (context) => _CompleteOrderDialog(
        cart: Map<String, int>.from(_cart),
        menuItems: List<MenuItem>.from(_menuItems),
        totalAmount: _totalAmount,
        isSubmitting: _isSubmitting,
        onComplete: _completeOrder,
      ),
    );
  }

  /// Complete order
  Future<void> _completeOrder(_CompleteOrderResult result) async {
    if (_isSubmitting) {
      return;
    }

    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Add at least one item before placing an order.'),
          backgroundColor: AppConstants.errorRed,
        ),
      );
      return;
    }

    final items = <OrderItem>[];
    final missingItemIds = <String>[];

    _cart.forEach((itemId, quantity) {
      final menuItem = _findMenuItemById(itemId);
      if (menuItem == null) {
        missingItemIds.add(itemId);
        return;
      }
      items.add(
        OrderItem(
          id: menuItem.id,
          name: menuItem.name,
          quantity: quantity,
          price: menuItem.price,
          category: menuItem.category.name,
          categoryLabel: menuItem.categoryLabel,
        ),
      );
    });

    if (missingItemIds.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Some menu items are unavailable: ${missingItemIds.join(', ')}'),
          backgroundColor: AppConstants.errorRed,
        ),
      );
      return;
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to build order items. Please try again.'),
          backgroundColor: AppConstants.errorRed,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final orderId = await _orderService.generateNextOrderId();
      final totalAmount = items.fold<double>(0, (sum, item) => sum + item.totalPrice);

      final order = Order(
        id: orderId,
        tableNumber: result.tableNumber,
        items: items,
        totalAmount: totalAmount,
        timestamp: DateTime.now(),
        status: OrderStatus.pending,
        notes: (result.notes?.isEmpty ?? true) ? null : result.notes,
        payNow: result.payNow,
      );

      await _orderService.createOrder(order);

      if (order.tableNumber != 'NO_TABLE') {
        try {
          await _tableService.assignOrderToTableByNumber(order.tableNumber, order.id);
        } catch (e) {
          // Surface warning but keep order creation successful
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order saved, but failed to update table: $e'),
              backgroundColor: AppConstants.warningYellow,
            ),
          );
        }
      }

      if (!mounted) {
        return;
      }

      setState(() => _isSubmitting = false);

      Navigator.pop(context); // Close dialog
      Navigator.pop(context, order); // Close new order screen and return order
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create order: $e'),
          backgroundColor: AppConstants.errorRed,
        ),
      );
    }
  }
}

class _CompleteOrderResult {
  const _CompleteOrderResult({
    required this.tableNumber,
    this.notes,
    required this.payNow,
  });

  final String tableNumber;
  final String? notes;
  final bool payNow;
}

/// Complete Order Dialog
class _CompleteOrderDialog extends StatefulWidget {
  final Map<String, int> cart;
  final List<MenuItem> menuItems;
  final double totalAmount;
  final ValueChanged<_CompleteOrderResult> onComplete;
  final bool isSubmitting;

  const _CompleteOrderDialog({
    required this.cart,
    required this.menuItems,
    required this.totalAmount,
    required this.onComplete,
    this.isSubmitting = false,
  });

  @override
  State<_CompleteOrderDialog> createState() => _CompleteOrderDialogState();
}

class _CategoryFilter {
  const _CategoryFilter({
    required this.category,
    required this.label,
    required this.icon,
  });

  final MenuCategory category;
  final String label;
  final IconData icon;
}

class _CompleteOrderDialogState extends State<_CompleteOrderDialog> {
  String? _selectedTable;
  final _notesController = TextEditingController();
  bool _payNow = true; // true = Pay Now, false = Pay Later
  
  final List<String> _availableTables = [
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '10',
    '11', '12', '13', '14', '15'
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppConstants.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Complete Order',
                    style: AppConstants.headingMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.paddingMedium),

              // Order summary
              const Text('Order Summary', style: AppConstants.headingSmall),
              const SizedBox(height: AppConstants.paddingSmall),
              Container(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                decoration: BoxDecoration(
                  color: AppConstants.darkSecondary,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                ),
                child: Column(
                  children: widget.cart.entries.map((entry) {
                    final item = widget.menuItems.firstWhere(
                      (i) => i.id == entry.key,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${entry.value}x ${item.name}',
                              style: AppConstants.bodyMedium,
                            ),
                          ),
                          Text(
                            Formatters.formatCurrency(item.price * entry.value),
                            style: AppConstants.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: AppConstants.paddingMedium),

              // Subtotal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal:', style: AppConstants.bodyLarge),
                  Text(
                    Formatters.formatCurrency(widget.totalAmount),
                    style: AppConstants.headingSmall.copyWith(
                      color: AppConstants.primaryOrange,
                    ),
                  ),
                ],
              ),
              const Divider(color: AppConstants.dividerColor),

              // Table selection
              const Text('Select Table', style: AppConstants.headingSmall),
              const SizedBox(height: AppConstants.paddingSmall),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // No Table option
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTable = 'NO_TABLE';
                      });
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _selectedTable == 'NO_TABLE'
                            ? AppConstants.primaryOrange
                            : AppConstants.darkSecondary,
                        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                        border: Border.all(
                          color: _selectedTable == 'NO_TABLE'
                              ? AppConstants.primaryOrange
                              : AppConstants.dividerColor,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.block,
                          color: _selectedTable == 'NO_TABLE'
                              ? Colors.white
                              : AppConstants.textSecondary,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                  // Table numbers
                  ..._availableTables.map((table) {
                    final isSelected = _selectedTable == table;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTable = table;
                        });
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppConstants.primaryOrange
                              : AppConstants.darkSecondary,
                          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                          border: Border.all(
                            color: isSelected
                                ? AppConstants.primaryOrange
                                : AppConstants.dividerColor,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            table,
                            style: AppConstants.bodyLarge.copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : AppConstants.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
              const SizedBox(height: AppConstants.paddingMedium),

              // Payment options
              const Text('Payment', style: AppConstants.headingSmall),
              const SizedBox(height: AppConstants.paddingSmall),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _payNow = true;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _payNow
                              ? AppConstants.primaryOrange
                              : AppConstants.darkSecondary,
                          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                          border: Border.all(
                            color: _payNow
                                ? AppConstants.primaryOrange
                                : AppConstants.dividerColor,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.payment,
                              color: _payNow
                                  ? Colors.white
                                  : AppConstants.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pay Now',
                              style: AppConstants.bodyMedium.copyWith(
                                color: _payNow
                                    ? Colors.white
                                    : AppConstants.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _payNow = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_payNow
                              ? AppConstants.primaryOrange
                              : AppConstants.darkSecondary,
                          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                          border: Border.all(
                            color: !_payNow
                                ? AppConstants.primaryOrange
                                : AppConstants.dividerColor,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.schedule,
                              color: !_payNow
                                  ? Colors.white
                                  : AppConstants.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pay Later',
                              style: AppConstants.bodyMedium.copyWith(
                                color: !_payNow
                                    ? Colors.white
                                    : AppConstants.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.paddingMedium),

              // Notes
              const Text('Notes (Optional)', style: AppConstants.headingSmall),
              const SizedBox(height: AppConstants.paddingSmall),
              TextField(
                controller: _notesController,
                maxLines: 3,
                style: AppConstants.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Add notes for this order...',
                  hintStyle: AppConstants.bodyMedium.copyWith(
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
              const SizedBox(height: AppConstants.paddingLarge),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppConstants.textPrimary,
                        side: const BorderSide(
                          color: AppConstants.dividerColor,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppConstants.paddingMedium),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _selectedTable == null || widget.isSubmitting
                          ? null
                          : () {
                              final trimmedNotes = _notesController.text.trim();
                              widget.onComplete(
                                _CompleteOrderResult(
                                  tableNumber: _selectedTable!,
                                  notes: trimmedNotes.isEmpty ? null : trimmedNotes,
                                  payNow: _payNow,
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                        ),
                      ),
                      child: Text(
                        widget.isSubmitting ? 'Placing...' : 'Place Order',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
