import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../models/table_model.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/order_card.dart';
import '../widgets/table_card.dart';
import '../services/order_service.dart';
import '../services/table_service.dart';
import '../services/transaction_service.dart';
import 'new_order_screen.dart';

/// Order Management screen - View and manage customer orders
class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  OrderStatus? _selectedFilter; // null means "All"
  final OrderService _orderService = OrderService();
  final TableService _tableService = TableService();
  final List<Order> _orders = [];
  StreamSubscription<List<Order>>? _ordersSubscription;
  bool _isLoadingOrders = true;
  String? _ordersError;

  Timer? _midnightTimer;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    _subscribeToOrders();
    _scheduleMidnightTimer();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _midnightTimer?.cancel();
    super.dispose();
  }

  void _subscribeToOrders() {
    setState(() {
      _isLoadingOrders = true;
      _ordersError = null;
    });

    final todayStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    _ordersSubscription = _orderService
        .getOrdersStream(start: todayStart)
        .listen(
          (orders) {
            if (!mounted) return;
            setState(() {
              _orders
                ..clear()
                ..addAll(orders);
              _isLoadingOrders = false;
            });
          },
          onError: (error) {
            if (!mounted) return;
            setState(() {
              _isLoadingOrders = false;
              _ordersError = error.toString();
            });
          },
        );
  }

  void _scheduleMidnightTimer() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final untilMidnight = tomorrow.difference(now);
    _midnightTimer = Timer(untilMidnight, () {
      if (!mounted) return;
      // Clear today's list at midnight so the UI shows only orders from the new day.
      setState(() {
        _orders.clear();
        _isLoadingOrders = false;
      });
      // Schedule again for the next day
      _scheduleMidnightTimer();
    });
  }

  Future<void> _changeOrderStatus(Order order, OrderStatus newStatus) async {
    final previousStatus = order.status;
    setState(() {
      order.status = newStatus;
    });

    try {
      await _orderService.updateOrderStatus(order.id, newStatus);
      String? tableError;
      if (_shouldReleaseTable(order, newStatus)) {
        tableError = await _clearTableForOrder(order);
      }
      if (newStatus == OrderStatus.completed && mounted) {
        final transactionService = Provider.of<TransactionService>(
          context,
          listen: false,
        );
        final result = await transactionService.saveCheckout(
          order: order,
          paymentMethod: 'Manual Status Update',
          amountPaid: order.totalAmount,
          change: 0,
          metadata: const {'source': 'status_update'},
        );
        if (!result['success'] && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message'] ?? 'Failed to record transaction',
              ),
              backgroundColor: AppConstants.errorRed,
            ),
          );
        }
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order ${order.id} updated to ${newStatus.toString().split('.').last}',
          ),
          backgroundColor: AppConstants.successGreen,
        ),
      );
      if (tableError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to release Table ${order.tableNumber}: $tableError',
            ),
            backgroundColor: AppConstants.errorRed,
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        order.status = previousStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update order status: $e'),
          backgroundColor: AppConstants.errorRed,
        ),
      );
    }
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
            final scaffoldState = context
                .findAncestorStateOfType<ScaffoldState>();
            if (scaffoldState != null) {
              scaffoldState.openDrawer();
            }
          },
        ),
        title: Row(
          children: [
            Icon(Icons.receipt_long, color: AppConstants.primaryOrange),
            const SizedBox(width: AppConstants.paddingSmall),
            const Text('Orders', style: AppConstants.headingMedium),
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
          Expanded(child: _buildOrdersList()),
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
          horizontal: AppConstants.paddingMedium,
        ),
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
                  fontWeight: _selectedFilter == null
                      ? FontWeight.bold
                      : FontWeight.normal,
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
          ...OrderStatus.values.where((s) => s != OrderStatus.preparing).map((
            status,
          ) {
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
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
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
    if (_isLoadingOrders) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppConstants.primaryOrange),
            const SizedBox(height: AppConstants.paddingMedium),
            const Text('Loading orders...', style: AppConstants.bodyMedium),
          ],
        ),
      );
    }

    if (_ordersError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppConstants.errorRed),
              const SizedBox(height: AppConstants.paddingMedium),
              Text(
                'Failed to load orders',
                style: AppConstants.headingSmall.copyWith(
                  color: AppConstants.errorRed,
                ),
              ),
              const SizedBox(height: AppConstants.paddingSmall),
              Text(
                _ordersError!,
                style: AppConstants.bodySmall.copyWith(
                  color: AppConstants.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final filteredOrders = List<Order>.from(
      _selectedFilter == null
          ? _orders
          : _orders.where((order) => order.status == _selectedFilter),
    );

    filteredOrders.sort((a, b) {
      final statusComparison =
          _statusSortPriority(a.status) - _statusSortPriority(b.status);
      if (statusComparison != 0) {
        return statusComparison;
      }
      return b.timestamp.compareTo(a.timestamp);
    });

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
        final order = filteredOrders[index];
        return OrderCard(
          order: order,
          onTap: () => _showOrderDetails(order),
          onAction: (action) => _handleOrderQuickAction(order, action),
        );
      },
    );
  }

  Future<void> _handleOrderQuickAction(Order order, String action) async {
    switch (action) {
      case 'assign':
        await _showCompactTablePicker(
          order,
          allowOccupied: false,
          mode: 'assign',
        );
        break;
      case 'move':
        await _showCompactTablePicker(order, allowOccupied: true, mode: 'move');
        break;
      case 'merge':
        await _startMergeFlow(order);
        break;
      case 'seat':
        await _seatStartOrder(order);
        break;
      case 'checkout':
        _showCheckoutDialog(order);
        break;
      default:
        break;
    }
  }

  Future<void> _showCompactTablePicker(
    Order order, {
    bool allowOccupied = false,
    required String mode,
  }) async {
    // fetch current tables snapshot
    final tables = await _tableService.getTablesStream().first;
    // Sort tables by numeric tableNumber when possible so picker shows same sequence as main grid
    final sortedTables = List<RestaurantTable>.from(tables);
    sortedTables.sort((a, b) {
      final aValue = int.tryParse(a.tableNumber);
      final bValue = int.tryParse(b.tableNumber);
      if (aValue != null && bValue != null) {
        return aValue.compareTo(bValue);
      }
      return a.tableNumber.compareTo(b.tableNumber);
    });
    final candidates = allowOccupied
        ? sortedTables
        : sortedTables.where((t) => t.status == TableStatus.free).toList();

    final picked = await showModalBottomSheet<RestaurantTable>(
      context: context,
      backgroundColor: AppConstants.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusLarge),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.68,
          ),
          itemCount: candidates.length,
          itemBuilder: (context, i) {
            final t = candidates[i];
            return InkWell(
              onTap: () => Navigator.pop(context, t),
              child: AspectRatio(
                aspectRatio: 0.68,
                child: TableCard(table: t, itemCount: 0, totalAmount: 0.0),
              ),
            );
          },
        ),
      ),
    );

    if (picked == null) return;

    try {
      await _orderService.assignOrderToTableAtomic(order.id, picked.id);
      await _orderService.updateOrder(
        order.copyWith(tableNumber: picked.tableNumber),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order ${order.id} ${mode == 'move' ? 'moved' : 'assigned'} to Table ${picked.tableNumber}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to assign table: $e')));
    }
  }

  Future<void> _startMergeFlow(Order order) async {
    // pick a target table that has an order
    final tables = await _tableService.getTablesStream().first;
    final sorted = List<RestaurantTable>.from(tables);
    sorted.sort((a, b) {
      final aValue = int.tryParse(a.tableNumber);
      final bValue = int.tryParse(b.tableNumber);
      if (aValue != null && bValue != null) {
        return aValue.compareTo(bValue);
      }
      return a.tableNumber.compareTo(b.tableNumber);
    });
    final occupiedTables = sorted
        .where((t) => t.currentOrderId != null && t.currentOrderId!.isNotEmpty)
        .toList();
    final picked = await showModalBottomSheet<RestaurantTable>(
      context: context,
      backgroundColor: AppConstants.cardBackground,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: occupiedTables.length,
          itemBuilder: (context, i) {
            final t = occupiedTables[i];
            return ListTile(
              title: Text('Table ${t.tableNumber}'),
              subtitle: Text('${t.currentOrderId}'),
              onTap: () => Navigator.pop(context, t),
            );
          },
        ),
      ),
    );

    if (picked == null) return;

    final targetOrderId = picked.currentOrderId;
    if (targetOrderId == null || targetOrderId.isEmpty) return;
    try {
      final targetOrder = await _orderService.getOrder(targetOrderId);
      if (targetOrder == null) throw 'Target order not found';

      // Merge items (simple append) and totals
      final mergedItems = <dynamic>[];
      mergedItems.addAll(targetOrder.items);
      mergedItems.addAll(order.items);
      final mergedTotal = mergedItems.fold<double>(
        0,
        (s, it) =>
            s +
            ((it.totalPrice is num)
                ? (it.totalPrice as num).toDouble()
                : double.tryParse(it.totalPrice?.toString() ?? '0') ?? 0),
      );

      final updatedTarget = targetOrder.copyWith(
        items: mergedItems.cast(),
        totalAmount: mergedTotal,
      );

      await _orderService.updateOrder(updatedTarget);
      // remove source order and clear its table references
      await _orderService.deleteOrder(order.id);
      await _orderService.detachOrderFromTableAtomic(order.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Merged Order ${order.id} into ${targetOrder.id}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Merge failed: $e')));
    }
  }

  Future<void> _seatStartOrder(Order order) async {
    try {
      if (order.tableNumber.trim().isEmpty || order.tableNumber == 'NO_TABLE') {
        await _showCompactTablePicker(
          order,
          allowOccupied: false,
          mode: 'seat',
        );
      }
      await _orderService.updateOrderStatus(order.id, OrderStatus.preparing);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Order ${order.id} started')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to start order: $e')));
    }
  }

  int _statusSortPriority(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 0;
      case OrderStatus.ready:
        return 1;
      case OrderStatus.preparing:
        // Treat preparing like pending in the order list (hidden as a separate tab)
        return 0;
      case OrderStatus.completed:
        return 3;
      case OrderStatus.cancelled:
        return 4;
    }
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
              title: const Text('ALL', style: AppConstants.bodyMedium),
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
            // Status options (exclude preparing state from this UI)
            ...OrderStatus.values.where((s) => s != OrderStatus.preparing).map((
              status,
            ) {
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
                Text('Order #${order.id}', style: AppConstants.headingMedium),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            // Action list moved here: Assign / Move / Merge / Seat / Checkout
            Container(
              decoration: BoxDecoration(
                color: AppConstants.darkSecondary,
                borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.assignment,
                      color: AppConstants.textPrimary,
                    ),
                    title: const Text('Assign to table'),
                    onTap: () {
                      Navigator.pop(context);
                      _showCompactTablePicker(
                        order,
                        allowOccupied: false,
                        mode: 'assign',
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.open_with,
                      color: AppConstants.textPrimary,
                    ),
                    title: const Text('Move to table'),
                    onTap: () {
                      Navigator.pop(context);
                      _showCompactTablePicker(
                        order,
                        allowOccupied: true,
                        mode: 'move',
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.merge_type,
                      color: AppConstants.textPrimary,
                    ),
                    title: const Text('Merge with table'),
                    onTap: () {
                      Navigator.pop(context);
                      _startMergeFlow(order);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.event_seat,
                      color: AppConstants.textPrimary,
                    ),
                    title: const Text('Seat / Start order'),
                    onTap: () {
                      Navigator.pop(context);
                      _seatStartOrder(order);
                    },
                  ),
                  // Checkout action intentionally removed from quick-actions list
                ],
              ),
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
                        // If orderType indicates takeout/delivery, show that instead of a table label
                        (order is dynamic &&
                                (order.orderType == 'takeout' ||
                                    order.orderType == 'delivery'))
                            ? (order.orderType == 'takeout'
                                  ? 'Takeout'
                                  : 'Delivery')
                            : _formatTableLabel(order.tableNumber),
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

                  // Order-level note (optional)
                  if ((order.notes ?? '').toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.note,
                          size: 16,
                          color: AppConstants.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            order.notes.toString(),
                            style: AppConstants.bodySmall.copyWith(
                              color: AppConstants.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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

                  // Safely read item-level note: try `notes` then `note` on dynamic to avoid compile errors
                  final String itemNote = (() {
                    try {
                      final d = item as dynamic;
                      final n = d.notes ?? d.note;
                      return n?.toString() ?? '';
                    } catch (_) {
                      return '';
                    }
                  })();

                  return Container(
                    margin: const EdgeInsets.only(
                      bottom: AppConstants.paddingSmall,
                    ),
                    padding: const EdgeInsets.all(AppConstants.paddingSmall),
                    decoration: BoxDecoration(
                      color: AppConstants.darkSecondary,
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusSmall,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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

                        // Item-level note (optional) — now using the model field
                        if ((item.notes ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              item.notes!,
                              style: AppConstants.bodySmall.copyWith(
                                color: AppConstants.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
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
                        side: const BorderSide(
                          color: AppConstants.primaryOrange,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMedium,
                          ),
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
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) {
                                return;
                              }
                              _showCheckoutDialog(order);
                            });
                          },
                    icon: const Icon(Icons.payment),
                    label: const Text('Checkout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.successGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppConstants.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusMedium,
                        ),
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
        // Map preparing to pending color so the UI doesn't expose a separate preparing state
        return AppConstants.warningYellow;
      case OrderStatus.ready:
        return AppConstants.primaryOrange;
      case OrderStatus.completed:
        return AppConstants.successGreen;
      case OrderStatus.cancelled:
        return AppConstants.errorRed;
    }
  }

  String _formatTableLabel(String tableNumber) {
    if (tableNumber.trim().isEmpty || tableNumber == 'NO_TABLE') {
      return 'No table';
    }
    return 'Table $tableNumber';
  }

  /// Update order status
  void _updateOrderStatus(Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.cardBackground,
        title: const Text(
          'Update Order Status',
          style: AppConstants.headingSmall,
        ),
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
                if (value == null) {
                  return;
                }
                Navigator.pop(context);
                _changeOrderStatus(order, value);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Show checkout dialog with amount paid and change calculation
  void _showCheckoutDialog(Order order) {
    showDialog<_CheckoutResult>(
      context: context,
      builder: (_) => _CheckoutDialog(order: order),
    ).then((result) {
      if (!mounted || result == null) {
        return;
      }
      _processPayment(
        order,
        result.paymentMethod,
        result.amountPaid,
        result.change,
      );
    });
  }

  /// Process payment and save to Firebase
  void _processPayment(
    Order order,
    String paymentMethod,
    double amountPaid,
    double change,
  ) async {
    print('💳 Processing payment for Order #${order.id}');

    // Get TransactionService
    final transactionService = Provider.of<TransactionService>(
      context,
      listen: false,
    );

    // Update order status
    setState(() {
      order.status = OrderStatus.completed;
    });

    // Save transaction to Firebase
    print('💾 Saving to Firebase...');
    final result = await transactionService.saveCheckout(
      order: order,
      paymentMethod: paymentMethod,
      amountPaid: amountPaid,
      change: change,
      allowOverwrite: true,
      metadata: const {'source': 'checkout'},
    );

    print('📊 Result: $result');

    if (!mounted) return;

    if (result['success']) {
      String? tableError;
      try {
        // Ensure order record (including orderType) is persisted when completing
        await _orderService.updateOrder(order);
        if (_shouldReleaseTable(order, OrderStatus.completed)) {
          tableError = await _clearTableForOrder(order);
        }
        // Also update status field explicitly to keep parity with other flows
        await _orderService.updateOrderStatus(order.id, OrderStatus.completed);
      } catch (e) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update order status: $e'),
            backgroundColor: AppConstants.errorRed,
          ),
        );
      }
      if (tableError != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to release Table ${order.tableNumber}: $tableError',
            ),
            backgroundColor: AppConstants.errorRed,
          ),
        );
      }
      // Show success dialog
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
              Text('Order #${order.id}', style: AppConstants.bodyLarge),
              Text(
                'Table ${order.tableNumber}',
                style: AppConstants.bodyMedium.copyWith(
                  color: AppConstants.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Transaction ID: ${result['transactionId']}',
                style: AppConstants.bodySmall.copyWith(
                  color: AppConstants.successGreen,
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
                        Text('Total:', style: AppConstants.bodyMedium),
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
                          Text('Paid:', style: AppConstants.bodyMedium),
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
                        Text('Payment:', style: AppConstants.bodyMedium),
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
    } else {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: AppConstants.errorRed,
        ),
      );
    }
  }

  /// Create new order
  Future<void> _createNewOrder() async {
    final order = await Navigator.push<Order>(
      context,
      MaterialPageRoute(builder: (context) => const NewOrderScreen()),
    );

    if (order != null && mounted) {
      final tableLabel = _formatTableLabel(order.tableNumber);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order ${order.id} created for $tableLabel'),
          backgroundColor: AppConstants.successGreen,
        ),
      );
    }
  }

  bool _hasTableAssignment(Order order) {
    final trimmed = order.tableNumber.trim();
    return trimmed.isNotEmpty && trimmed != 'NO_TABLE';
  }

  bool _shouldReleaseTable(Order order, OrderStatus status) {
    if (!_hasTableAssignment(order)) {
      return false;
    }
    return status == OrderStatus.completed || status == OrderStatus.cancelled;
  }

  Future<String?> _clearTableForOrder(Order order) async {
    if (!_hasTableAssignment(order)) {
      return null;
    }
    try {
      // Use atomic detach helper to clear any table referencing this order
      await _orderService.detachOrderFromTableAtomic(order.id);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Get payment icon
  IconData _getPaymentIcon(String method) {
    switch (method) {
      case 'Cash':
        return Icons.money;
      case 'Credit Card':
        return Icons.credit_card;
      case 'Debit Card':
        return Icons.payment;
      case 'GCash':
        return Icons.account_balance_wallet;
      case 'PayMaya':
        return Icons.wallet;
      default:
        return Icons.payment;
    }
  }
}

class _CheckoutResult {
  final String paymentMethod;
  final double amountPaid;
  final double change;

  const _CheckoutResult({
    required this.paymentMethod,
    required this.amountPaid,
    required this.change,
  });
}

class _CheckoutDialog extends StatefulWidget {
  final Order order;

  const _CheckoutDialog({required this.order});

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  late final TextEditingController _amountController;
  final List<String> _paymentMethods = const [
    'Cash',
    'Credit Card',
    'Debit Card',
    'GCash',
    'PayMaya',
  ];

  String _selectedPaymentMethod = 'Cash';
  double _amountPaid = 0;
  double _change = 0;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppConstants.cardBackground,
      title: Row(
        children: [
          const Icon(Icons.payment, color: AppConstants.primaryOrange),
          const SizedBox(width: 8),
          const Text('Checkout', style: AppConstants.headingMedium),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOrderSummary(),
              const SizedBox(height: AppConstants.paddingLarge),
              _buildPaymentMethodChips(),
              const SizedBox(height: AppConstants.paddingLarge),
              if (_selectedPaymentMethod == 'Cash') _buildCashSection(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop();
          },
          child: Text(
            'Cancel',
            style: AppConstants.bodyMedium.copyWith(
              color: AppConstants.textSecondary,
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: (_selectedPaymentMethod == 'Cash' && _change < 0)
              ? null
              : () {
                  FocusScope.of(context).unfocus();
                  Navigator.of(context).pop(
                    _CheckoutResult(
                      paymentMethod: _selectedPaymentMethod,
                      amountPaid: _selectedPaymentMethod == 'Cash'
                          ? _amountPaid
                          : widget.order.totalAmount,
                      change: _selectedPaymentMethod == 'Cash' ? _change : 0,
                    ),
                  );
                },
          icon: const Icon(Icons.check_circle),
          label: const Text('Complete Payment'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.successGreen,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppConstants.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppConstants.darkSecondary,
        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order #${widget.order.id}',
            style: AppConstants.bodyLarge.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            widget.order.tableNumber.trim().isEmpty
                ? 'No table'
                : 'Table ${widget.order.tableNumber}',
            style: AppConstants.bodyMedium.copyWith(
              color: AppConstants.textSecondary,
            ),
          ),
          const Divider(color: AppConstants.dividerColor),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount:', style: AppConstants.bodyLarge),
              Text(
                Formatters.formatCurrency(widget.order.totalAmount),
                style: AppConstants.headingMedium.copyWith(
                  color: AppConstants.primaryOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payment Method', style: AppConstants.bodyLarge),
        const SizedBox(height: AppConstants.paddingSmall),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _paymentMethods.map((method) {
            final isSelected = _selectedPaymentMethod == method;
            return ChoiceChip(
              label: Text(method),
              selected: isSelected,
              onSelected: (_) => _handlePaymentMethodChange(method),
              selectedColor: AppConstants.primaryOrange,
              backgroundColor: AppConstants.darkSecondary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppConstants.textPrimary,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCashSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Amount Paid', style: AppConstants.bodyLarge),
        const SizedBox(height: AppConstants.paddingSmall),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'Enter amount',
            prefixText: '₱ ',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
            ),
            filled: true,
            fillColor: AppConstants.darkSecondary,
          ),
          onChanged: (value) {
            final parsed = double.tryParse(value) ?? 0;
            setState(() {
              _amountPaid = parsed;
              _change = _amountPaid - widget.order.totalAmount;
            });
          },
        ),
        const SizedBox(height: AppConstants.paddingMedium),
        const Text('Quick Amount', style: AppConstants.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              <double>[
                50.0,
                100.0,
                200.0,
                500.0,
                1000.0,
                widget.order.totalAmount,
              ].map((amount) {
                return OutlinedButton(
                  onPressed: () => _applyQuickAmount(amount),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppConstants.primaryOrange,
                    side: const BorderSide(color: AppConstants.primaryOrange),
                  ),
                  child: Text(Formatters.formatCurrency(amount)),
                );
              }).toList(),
        ),
        const SizedBox(height: AppConstants.paddingMedium),
        _buildChangeSummary(),
        if (_change < 0) _buildInsufficientBanner(),
      ],
    );
  }

  void _handlePaymentMethodChange(String method) {
    setState(() {
      _selectedPaymentMethod = method;
      if (method != 'Cash') {
        _applyQuickAmount(widget.order.totalAmount, updateTextField: false);
        _amountController.text = widget.order.totalAmount.toStringAsFixed(2);
        _amountController.selection = TextSelection.collapsed(
          offset: _amountController.text.length,
        );
      }
    });
  }

  void _applyQuickAmount(double amount, {bool updateTextField = true}) {
    setState(() {
      _amountPaid = amount;
      _change = _amountPaid - widget.order.totalAmount;
      if (updateTextField) {
        final formatted = amount.toStringAsFixed(2);
        _amountController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    });
  }

  Widget _buildChangeSummary() {
    final isPositive = _change >= 0;
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: (isPositive ? AppConstants.successGreen : AppConstants.errorRed)
            .withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: isPositive ? AppConstants.successGreen : AppConstants.errorRed,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Change', style: AppConstants.bodyLarge),
          Text(
            Formatters.formatCurrency(isPositive ? _change : 0),
            style: AppConstants.headingMedium.copyWith(
              color: isPositive
                  ? AppConstants.successGreen
                  : AppConstants.errorRed,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsufficientBanner() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.warning, color: AppConstants.errorRed, size: 16),
          const SizedBox(width: 4),
          Text(
            'Insufficient amount paid',
            style: AppConstants.bodySmall.copyWith(
              color: AppConstants.errorRed,
            ),
          ),
        ],
      ),
    );
  }
}

class OrderItem {
  final String id;
  final String name;
  final int quantity;
  final double price;
  final double totalPrice;
  final String? notes; // special instructions for this item

  OrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    required this.totalPrice,
    this.notes,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    id: json['id'] as String,
    name: json['name'] as String,
    quantity: (json['quantity'] as num).toInt(),
    price: (json['price'] as num).toDouble(),
    totalPrice: (json['totalPrice'] as num).toDouble(),
    notes: (json['notes'] as String?) ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'price': price,
    'totalPrice': totalPrice,
    'notes': notes ?? '',
  };
}
