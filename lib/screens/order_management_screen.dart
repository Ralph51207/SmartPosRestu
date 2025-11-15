import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/order_card.dart';
import 'new_order_screen.dart';

/// Order Management screen - View and manage customer orders
class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  OrderStatus? _selectedFilter; // null means "All"
  final List<Order> _mockOrders = [];

  @override
  void initState() {
    super.initState();
    _generateMockOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        backgroundColor: AppConstants.darkSecondary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            final scaffoldState = context.findAncestorStateOfType<ScaffoldState>();
            if (scaffoldState != null) {
              scaffoldState.openDrawer();
            }
          },
        ),
        title: Row(
          children: [
            Icon(
              Icons.receipt_long,
              color: AppConstants.primaryOrange,
            ),
            const SizedBox(width: AppConstants.paddingSmall),
            const Text(
              'Orders',
              style: AppConstants.headingMedium,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Status filter tabs
          _buildStatusTabs(),

          // Orders list
          Expanded(
            child: _buildOrdersList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewOrder,
        backgroundColor: AppConstants.primaryOrange,
        icon: const Icon(Icons.add),
        label: const Text('New Order'),
      ),
    );
  }

  /// Status filter tabs
  Widget _buildStatusTabs() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall),
      color: AppConstants.darkSecondary,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMedium),
        children: [
          // "All" filter option
          Padding(
            padding: const EdgeInsets.only(right: AppConstants.paddingSmall),
            child: FilterChip(
              label: Text(
                'ALL',
                style: TextStyle(
                  color: _selectedFilter == null
                      ? Colors.white
                      : AppConstants.textSecondary,
                  fontWeight:
                      _selectedFilter == null ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: _selectedFilter == null,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = null;
                });
              },
              backgroundColor: AppConstants.cardBackground,
              selectedColor: AppConstants.primaryOrange,
              checkmarkColor: Colors.white,
            ),
          ),
          // Status filters
          ...OrderStatus.values.map((status) {
            final isSelected = _selectedFilter == status;
            return Padding(
              padding: const EdgeInsets.only(right: AppConstants.paddingSmall),
              child: FilterChip(
                label: Text(
                  status.toString().split('.').last.toUpperCase(),
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : AppConstants.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = status;
                  });
                },
                backgroundColor: AppConstants.cardBackground,
                selectedColor: AppConstants.primaryOrange,
                checkmarkColor: Colors.white,
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  /// Orders list
  Widget _buildOrdersList() {
    final filteredOrders = _selectedFilter == null
        ? _mockOrders
        : _mockOrders.where((order) => order.status == _selectedFilter).toList();

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: AppConstants.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              _selectedFilter == null
                  ? 'No orders yet'
                  : 'No ${_selectedFilter.toString().split('.').last} orders',
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
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        return OrderCard(
          order: filteredOrders[index],
          onTap: () => _showOrderDetails(filteredOrders[index]),
        );
      },
    );
  }

  /// Show filter dialog
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.cardBackground,
        title: const Text('Filter Orders', style: AppConstants.headingSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "All" option
            RadioListTile<OrderStatus?>(
              title: const Text(
                'ALL',
                style: AppConstants.bodyMedium,
              ),
              value: null,
              groupValue: _selectedFilter,
              activeColor: AppConstants.primaryOrange,
              onChanged: (value) {
                setState(() {
                  _selectedFilter = value;
                });
                Navigator.pop(context);
              },
            ),
            // Status options
            ...OrderStatus.values.map((status) {
              return RadioListTile<OrderStatus?>(
                title: Text(
                  status.toString().split('.').last.toUpperCase(),
                  style: AppConstants.bodyMedium,
                ),
                value: status,
                groupValue: _selectedFilter,
                activeColor: AppConstants.primaryOrange,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value;
                  });
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  /// Show order details
  void _showOrderDetails(Order order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusLarge),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order.id}',
                  style: AppConstants.headingMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            
            // Order Info
            Container(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              decoration: BoxDecoration(
                color: AppConstants.darkSecondary,
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Table:', style: AppConstants.bodyMedium),
                      Text(
                        order.tableNumber,
                        style: AppConstants.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Status:', style: AppConstants.bodyMedium),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(order.status).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getStatusColor(order.status),
                          ),
                        ),
                        child: Text(
                          order.status.toString().split('.').last.toUpperCase(),
                          style: AppConstants.bodySmall.copyWith(
                            color: _getStatusColor(order.status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Time:', style: AppConstants.bodyMedium),
                      Text(
                        Formatters.formatDateTime(order.timestamp),
                        style: AppConstants.bodyMedium.copyWith(
                          color: AppConstants.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppConstants.paddingMedium),
            const Text('Items:', style: AppConstants.headingSmall),
            const SizedBox(height: AppConstants.paddingSmall),
            
            // Items List
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: order.items.length,
                itemBuilder: (context, index) {
                  final item = order.items[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppConstants.paddingSmall),
                    padding: const EdgeInsets.all(AppConstants.paddingSmall),
                    decoration: BoxDecoration(
                      color: AppConstants.darkSecondary,
                      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.quantity}x ${item.name}',
                            style: AppConstants.bodyMedium,
                          ),
                        ),
                        Text(
                          Formatters.formatCurrency(item.totalPrice),
                          style: AppConstants.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: AppConstants.paddingMedium),
            const Divider(color: AppConstants.dividerColor),
            
            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: AppConstants.headingSmall),
                Text(
                  Formatters.formatCurrency(order.totalAmount),
                  style: AppConstants.headingMedium.copyWith(
                    color: AppConstants.primaryOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppConstants.paddingLarge),
            
            // Action Buttons
            Row(
              children: [
                // Update Status Button (if not completed)
                if (order.status != OrderStatus.completed)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _updateOrderStatus(order);
                      },
                      icon: const Icon(Icons.update),
                      label: const Text('Update Status'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppConstants.primaryOrange,
                        side: const BorderSide(color: AppConstants.primaryOrange),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                        ),
                      ),
                    ),
                  ),
                
                if (order.status != OrderStatus.completed)
                  const SizedBox(width: AppConstants.paddingSmall),
                
                // Checkout Button
                Expanded(
                  flex: order.status != OrderStatus.completed ? 1 : 1,
                  child: ElevatedButton.icon(
                    onPressed: order.status == OrderStatus.completed
                        ? null
                        : () {
                            Navigator.pop(context);
                            _showCheckoutDialog(order);
                          },
                    icon: const Icon(Icons.payment),
                    label: const Text('Checkout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.successGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppConstants.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Get status color
  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppConstants.warningYellow;
      case OrderStatus.preparing:
        return Colors.blue;
      case OrderStatus.ready:
        return AppConstants.primaryOrange;
      case OrderStatus.completed:
        return AppConstants.successGreen;
      case OrderStatus.cancelled:
        return AppConstants.errorRed;
    }
  }

  /// Update order status
  void _updateOrderStatus(Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.cardBackground,
        title: const Text('Update Order Status', style: AppConstants.headingSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: OrderStatus.values.map((status) {
            return RadioListTile<OrderStatus>(
              title: Text(
                status.toString().split('.').last.toUpperCase(),
                style: AppConstants.bodyMedium,
              ),
              value: status,
              groupValue: order.status,
              activeColor: AppConstants.primaryOrange,
              onChanged: (value) {
                setState(() {
                  order.status = value!;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Order status updated to ${value.toString().split('.').last}'),
                    backgroundColor: AppConstants.successGreen,
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Show checkout dialog with amount paid and change calculation
  void _showCheckoutDialog(Order order) {
    String selectedPaymentMethod = 'Cash';
    final paymentMethods = ['Cash', 'Credit Card', 'Debit Card', 'GCash', 'PayMaya'];
    final amountPaidController = TextEditingController();
    double amountPaid = 0.0;
    double change = 0.0;
    
    // Preset amount buttons - FIX: Convert to double explicitly
    final presetAmounts = [
      order.totalAmount, // Exact amount
      ((order.totalAmount / 100).ceil() * 100).toDouble(), // Round up to nearest 100
      (((order.totalAmount / 100).ceil() * 100) + 100).toDouble(), // +100
      ((order.totalAmount / 500).ceil() * 500).toDouble(), // Round up to nearest 500
      1000.0,
      500.0,
    ];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppConstants.cardBackground,
          title: Row(
            children: [
              const Icon(Icons.payment, color: AppConstants.primaryOrange),
              const SizedBox(width: 8),
              const Text('Checkout', style: AppConstants.headingSmall),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Summary
                Container(
                  padding: const EdgeInsets.all(AppConstants.paddingMedium),
                  decoration: BoxDecoration(
                    color: AppConstants.darkSecondary,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Order #${order.id}', style: AppConstants.bodyLarge),
                          Text('Table ${order.tableNumber}', style: AppConstants.bodyLarge),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(color: AppConstants.dividerColor),
                      const SizedBox(height: 8),
                      ...order.items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${item.quantity}x ${item.name}',
                                  style: AppConstants.bodySmall,
                                ),
                                Text(
                                  Formatters.formatCurrency(item.totalPrice),
                                  style: AppConstants.bodySmall,
                                ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 8),
                      const Divider(color: AppConstants.dividerColor),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Amount', style: AppConstants.bodyLarge),
                          Text(
                            Formatters.formatCurrency(order.totalAmount),
                            style: AppConstants.headingSmall.copyWith(
                              color: AppConstants.primaryOrange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: AppConstants.paddingLarge),
                
                // Payment Method
                const Text('Payment Method', style: AppConstants.bodyLarge),
                const SizedBox(height: AppConstants.paddingSmall),
                
                ...paymentMethods.map((method) {
                  IconData icon;
                  switch (method) {
                    case 'Cash':
                      icon = Icons.money;
                      break;
                    case 'Credit Card':
                      icon = Icons.credit_card;
                      break;
                    case 'Debit Card':
                      icon = Icons.credit_card;
                      break;
                    case 'GCash':
                      icon = Icons.phone_android;
                      break;
                    case 'PayMaya':
                      icon = Icons.phone_android;
                      break;
                    default:
                      icon = Icons.payment;
                  }
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppConstants.paddingSmall),
                    decoration: BoxDecoration(
                      color: selectedPaymentMethod == method
                          ? AppConstants.primaryOrange.withOpacity(0.2)
                          : AppConstants.darkSecondary,
                      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                      border: Border.all(
                        color: selectedPaymentMethod == method
                            ? AppConstants.primaryOrange
                            : AppConstants.dividerColor,
                        width: selectedPaymentMethod == method ? 2 : 1,
                      ),
                    ),
                    child: RadioListTile<String>(
                      title: Row(
                        children: [
                          Icon(icon, size: 20, color: AppConstants.primaryOrange),
                          const SizedBox(width: 8),
                          Text(method, style: AppConstants.bodyMedium),
                        ],
                      ),
                      value: method,
                      groupValue: selectedPaymentMethod,
                      activeColor: AppConstants.primaryOrange,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedPaymentMethod = value!;
                        });
                      },
                    ),
                  );
                }).toList(),
                
                const SizedBox(height: AppConstants.paddingLarge),
                
                // Amount Paid Section (only for Cash)
                if (selectedPaymentMethod == 'Cash') ...[
                  const Text('Amount Paid', style: AppConstants.bodyLarge),
                  const SizedBox(height: AppConstants.paddingSmall),
                  
                  // Amount Input
                  TextField(
                    controller: amountPaidController,
                    keyboardType: TextInputType.number,
                    style: AppConstants.headingMedium,
                    decoration: InputDecoration(
                      hintText: '0.00',
                      prefixText: '₱ ',
                      hintStyle: AppConstants.headingMedium.copyWith(
                        color: AppConstants.textSecondary,
                      ),
                      filled: true,
                      fillColor: AppConstants.darkSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                        borderSide: const BorderSide(color: AppConstants.dividerColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                        borderSide: const BorderSide(color: AppConstants.dividerColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                        borderSide: const BorderSide(color: AppConstants.primaryOrange, width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        amountPaid = double.tryParse(value) ?? 0.0;
                        change = amountPaid - order.totalAmount;
                      });
                    },
                  ),
                  
                  const SizedBox(height: AppConstants.paddingMedium),
                  
                  // Preset Amount Buttons
                  const Text('Quick Amount', style: AppConstants.bodySmall),
                  const SizedBox(height: AppConstants.paddingSmall),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presetAmounts.map((amount) {
                      return OutlinedButton(
                        onPressed: () {
                          setDialogState(() {
                            amountPaid = amount;
                            change = amountPaid - order.totalAmount;
                            amountPaidController.text = amount.toStringAsFixed(2);
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppConstants.primaryOrange,
                          side: const BorderSide(color: AppConstants.primaryOrange),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: Text(
                          Formatters.formatCurrency(amount),
                          style: AppConstants.bodySmall,
                        ),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: AppConstants.paddingLarge),
                  
                  // Change Display
                  Container(
                    padding: const EdgeInsets.all(AppConstants.paddingMedium),
                    decoration: BoxDecoration(
                      color: change >= 0 
                          ? AppConstants.successGreen.withOpacity(0.1)
                          : AppConstants.errorRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                      border: Border.all(
                        color: change >= 0 
                            ? AppConstants.successGreen
                            : AppConstants.errorRed,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Change',
                          style: AppConstants.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          Formatters.formatCurrency(change > 0 ? change : 0),
                          style: AppConstants.headingMedium.copyWith(
                            color: change >= 0 
                                ? AppConstants.successGreen
                                : AppConstants.errorRed,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  if (change < 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning,
                            color: AppConstants.errorRed,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Insufficient amount paid',
                            style: AppConstants.bodySmall.copyWith(
                              color: AppConstants.errorRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: AppConstants.bodyMedium.copyWith(
                  color: AppConstants.textSecondary,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: (selectedPaymentMethod == 'Cash' && change < 0)
                  ? null
                  : () {
                      Navigator.pop(context);
                      _processPayment(
                        order, 
                        selectedPaymentMethod,
                        selectedPaymentMethod == 'Cash' ? amountPaid : order.totalAmount,
                        selectedPaymentMethod == 'Cash' ? change : 0,
                      );
                    },
              icon: const Icon(Icons.check_circle),
              label: const Text('Complete Payment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.successGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppConstants.textSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Process payment
  void _processPayment(Order order, String paymentMethod, double amountPaid, double change) {
    setState(() {
      order.status = OrderStatus.completed;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.cardBackground,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: AppConstants.successGreen,
              size: 64,
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            const Text(
              'Payment Successful!',
              style: AppConstants.headingMedium,
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              'Order #${order.id}',
              style: AppConstants.bodyLarge,
            ),
            Text(
              'Table ${order.tableNumber}',
              style: AppConstants.bodyMedium.copyWith(
                color: AppConstants.textSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Container(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              decoration: BoxDecoration(
                color: AppConstants.darkSecondary,
                borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Amount:', style: AppConstants.bodyMedium),
                      Text(
                        Formatters.formatCurrency(order.totalAmount),
                        style: AppConstants.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (paymentMethod == 'Cash') ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Amount Paid:', style: AppConstants.bodyMedium),
                        Text(
                          Formatters.formatCurrency(amountPaid),
                          style: AppConstants.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Change:', style: AppConstants.bodyMedium),
                        Text(
                          Formatters.formatCurrency(change),
                          style: AppConstants.bodyLarge.copyWith(
                            color: AppConstants.successGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Divider(color: AppConstants.dividerColor),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Payment Method:', style: AppConstants.bodyMedium),
                      Text(
                        paymentMethod,
                        style: AppConstants.bodyMedium.copyWith(
                          color: AppConstants.primaryOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Print receipt
            },
            child: const Text('Print Receipt'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryOrange,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  /// Create new order
  void _createNewOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NewOrderScreen(),
      ),
    );
  }

  /// Generate mock orders for demonstration
  void _generateMockOrders() {
    _mockOrders.addAll([
      Order(
        id: 'ORD001',
        tableNumber: '5',
        items: [
          OrderItem(
            id: 'ITEM1',
            name: 'Margherita Pizza',
            quantity: 2,
            price: 15.0,
          ),
          OrderItem(
            id: 'ITEM2',
            name: 'Caesar Salad',
            quantity: 1,
            price: 12.0,
          ),
        ],
        totalAmount: 42.0,
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
        status: OrderStatus.pending,
      ),
      Order(
        id: 'ORD002',
        tableNumber: '3',
        items: [
          OrderItem(
            id: 'ITEM3',
            name: 'Pasta Carbonara',
            quantity: 1,
            price: 17.0,
          ),
        ],
        totalAmount: 17.0,
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        status: OrderStatus.preparing,
      ),
      Order(
        id: 'ORD003',
        tableNumber: '8',
        items: [
          OrderItem(
            id: 'ITEM4',
            name: 'Grilled Salmon',
            quantity: 2,
            price: 24.0,
          ),
          OrderItem(
            id: 'ITEM5',
            name: 'Tiramisu',
            quantity: 2,
            price: 9.0,
          ),
        ],
        totalAmount: 66.0,
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        status: OrderStatus.ready,
      ),
    ]);
  }
}
