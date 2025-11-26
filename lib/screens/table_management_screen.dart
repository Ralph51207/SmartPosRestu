import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order_model.dart';
import '../models/table_model.dart';
import '../services/transaction_service.dart';
import 'new_order_screen.dart';
import '../services/order_service.dart';
import '../services/table_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/table_card.dart';

/// Table Management screen - View and manage restaurant tables
class TableManagementScreen extends StatefulWidget {
  const TableManagementScreen({super.key});

  @override
  State<TableManagementScreen> createState() => _TableManagementScreenState();
}

class _TableManagementScreenState extends State<TableManagementScreen> {
  final TableService _tableService = TableService();
  final OrderService _orderService = OrderService();
  final List<RestaurantTable> _tables = [];
  final List<Order> _orders = [];
  final Map<String, OrderStatus> _lastOrderStatus = {};
  final Map<String, bool> _tableHighlight = {};
  StreamSubscription<List<RestaurantTable>>? _tablesSubscription;
  StreamSubscription<List<Order>>? _ordersSubscription;
  bool _isLoadingTables = true;
  String? _tablesError;
  TableStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _subscribeToTables();
    _subscribeToOrders();
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
              Icons.table_restaurant,
              color: AppConstants.primaryOrange,
            ),
            const SizedBox(width: AppConstants.paddingSmall),
            const Text(
              'Tables',
              style: AppConstants.headingMedium,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _subscribeToTables();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats bar
          _buildStatsBar(),

          // Tables grid
          Expanded(
            child: _buildTablesGrid(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewTable,
        backgroundColor: AppConstants.primaryOrange,
        icon: const Icon(Icons.add),
        label: const Text('Add Table'),
      ),
    );
  }

  void _subscribeToTables() {
    _tablesSubscription?.cancel();
    setState(() {
      _isLoadingTables = true;
      _tablesError = null;
    });

    _tablesSubscription = _tableService.getTablesStream().listen(
      (tables) {
        if (!mounted) {
          return;
        }
        setState(() {
          _tables
            ..clear()
            ..addAll(_sortTablesByNumber(tables));
          _isLoadingTables = false;
        });
      },
      onError: (error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoadingTables = false;
          _tablesError = error.toString();
        });
      },
    );

    
  }

  void _subscribeToOrders() {
    _ordersSubscription?.cancel();
    _ordersSubscription = _orderService.getOrdersStream().listen(
      (orders) {
        if (!mounted) return;
        // detect status changes for alerts/highlights
        for (final o in orders) {
          final prev = _lastOrderStatus[o.id];
          if (prev != null && prev != o.status) {
            if (o.status == OrderStatus.ready && o.tableNumber.trim().isNotEmpty && o.tableNumber != 'NO_TABLE') {
              final table = _tables.firstWhere(
                (t) => t.tableNumber == o.tableNumber,
                orElse: () => null as RestaurantTable,
              );
              if (table != null) {
                _tableHighlight[table.id] = true;
                // clear highlight after a short delay
                Future.delayed(const Duration(seconds: 4), () {
                  if (mounted) {
                    setState(() {
                      _tableHighlight[table.id] = false;
                    });
                  }
                });
                // show optional chime/notification (simple snackbar)
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Order ${o.id} is READY at Table ${o.tableNumber}')),
                  );
                }
              }
            }
          }
          _lastOrderStatus[o.id] = o.status;
        }

        setState(() {
          _orders
            ..clear()
            ..addAll(orders);
        });
      },
      onError: (_) {
        // Ignore order stream errors here; the Order screen surfaces them.
      },
    );
  }

  @override
  void dispose() {
    _tablesSubscription?.cancel();
    _ordersSubscription?.cancel();
    super.dispose();
  }

  List<RestaurantTable> _sortTablesByNumber(List<RestaurantTable> input) {
    final sorted = List<RestaurantTable>.from(input);
    sorted.sort((a, b) {
      final aValue = int.tryParse(a.tableNumber);
      final bValue = int.tryParse(b.tableNumber);
      if (aValue != null && bValue != null) {
        return aValue.compareTo(bValue);
      }
      return a.tableNumber.compareTo(b.tableNumber);
    });
    return sorted;
  }

  /// Stats bar showing table status counts
  Widget _buildStatsBar() {
    if (_isLoadingTables) {
      return Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        color: AppConstants.darkSecondary,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppConstants.primaryOrange),
            const SizedBox(width: AppConstants.paddingSmall),
            const Text('Loading tables...', style: AppConstants.bodyMedium),
          ],
        ),
      );
    }

    final available = _tables.where((t) => t.status == TableStatus.free).length;
    final occupied = _tables.where((t) => t.status == TableStatus.seated).length;
    final reserved = _tables.where((t) => t.status == TableStatus.waiting).length;
    final cleaning = _tables.where((t) => t.status == TableStatus.occupied_cleaning).length;

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      color: AppConstants.darkSecondary,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Free', available, AppConstants.successGreen),
          _buildStatItem('Seated', occupied, AppConstants.primaryOrange),
          _buildStatItem('Waiting', reserved, AppConstants.warningYellow),
          _buildStatItem('Cleaning', cleaning, AppConstants.textSecondary),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: AppConstants.headingMedium.copyWith(color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppConstants.bodySmall,
        ),
      ],
    );
  }

  /// Tables grid
  Widget _buildTablesGrid() {
    if (_isLoadingTables) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppConstants.primaryOrange),
            const SizedBox(height: AppConstants.paddingMedium),
            const Text('Fetching tables...', style: AppConstants.bodyMedium),
          ],
        ),
      );
    }

    if (_tablesError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppConstants.errorRed,
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              Text(
                'Failed to load tables',
                style: AppConstants.headingSmall.copyWith(
                  color: AppConstants.errorRed,
                ),
              ),
              const SizedBox(height: AppConstants.paddingSmall),
              Text(
                _tablesError!,
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

    final filteredTables = _filterStatus == null
      ? _tables
      : _tables.where((t) => t.status == _filterStatus).toList();

    if (filteredTables.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.table_restaurant,
              size: 80,
              color: AppConstants.textSecondary,
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              'No tables found',
              style: AppConstants.headingSmall.copyWith(
                color: AppConstants.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppConstants.paddingMedium,
        crossAxisSpacing: AppConstants.paddingMedium,
        childAspectRatio: 1,
      ),
      itemCount: filteredTables.length,
      itemBuilder: (context, index) {
        final table = filteredTables[index];
        Order? orderForTable;
        if (table.currentOrderId != null && table.currentOrderId!.isNotEmpty) {
          try {
            orderForTable = _orders.firstWhere((o) => o.id == table.currentOrderId);
          } catch (_) {
            orderForTable = null;
          }
        }
        return AspectRatio(
          aspectRatio: 0.68,
          child: TableCard(
            table: table,
            onTap: () => _showTableOptions(table),
            onPreview: () => _showTablePreview(table, orderForTable),
            itemCount: orderForTable?.items.length ?? 0,
            totalAmount: orderForTable?.totalAmount ?? 0.0,
            highlight: _tableHighlight[table.id] ?? false,
          ),
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
        title: const Text('Filter Tables', style: AppConstants.headingSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<TableStatus?>(
              title: const Text('All Tables', style: AppConstants.bodyMedium),
              value: null,
              groupValue: _filterStatus,
              activeColor: AppConstants.primaryOrange,
              onChanged: (value) {
                setState(() {
                  _filterStatus = value;
                });
                Navigator.pop(context);
              },
            ),
            ...TableStatus.values.map((status) {
              return RadioListTile<TableStatus?>(
                title: Text(
                  status.toString().split('.').last.toUpperCase(),
                  style: AppConstants.bodyMedium,
                ),
                value: status,
                groupValue: _filterStatus,
                activeColor: AppConstants.primaryOrange,
                onChanged: (value) {
                  setState(() {
                    _filterStatus = value;
                  });
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Show table options
  void _showTableOptions(RestaurantTable table) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusLarge),
        ),
      ),
      builder: (context) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Table ${table.tableNumber}',
                  style: AppConstants.headingMedium,
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                // Show order preview if table has an order
                if (table.currentOrderId != null && table.currentOrderId!.isNotEmpty)
                  _buildOptionButton(
                    'Preview Order',
                    Icons.preview,
                    () async {
                      Navigator.pop(context);
                      final order = _findOrderById(table.currentOrderId!);
                      _showTablePreview(table, order);
                    },
                  ),
                _buildOptionButton(
                  'Assign Order',
                  Icons.receipt_long,
                  () async {
                    Navigator.pop(context);
                    await _assignOrder(table);
                  },
                ),
                _buildOptionButton(
                  'Mark as Waiting',
                  Icons.event_seat,
                  () async {
                    Navigator.pop(context);
                    await _updateTableStatus(table, TableStatus.waiting);
                  },
                ),
                _buildOptionButton(
                  'Mark as Cleaning',
                  Icons.cleaning_services,
                  () async {
                    Navigator.pop(context);
                    await _updateTableStatus(table, TableStatus.occupied_cleaning);
                  },
                ),
                _buildOptionButton(
                  'Clear Table',
                  Icons.check_circle,
                  () async {
                    Navigator.pop(context);
                    await _updateTableStatus(table, TableStatus.free);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTablePreview(RestaurantTable table, Order? order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusLarge)),
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
                Text('Table ${table.tableNumber}', style: AppConstants.headingMedium),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            if (order == null) ...[
              Text('No active order', style: AppConstants.bodyMedium),
              const SizedBox(height: AppConstants.paddingMedium),
              _buildOptionButton('Create Order', Icons.add, () async {
                Navigator.pop(context);
                // open new order screen prefilled with table
                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewOrderScreen()));
                // no-op: NewOrderScreen will assign if needed
              }),
            ] else ...[
              Text('Order ${order.id}', style: AppConstants.headingSmall),
              const SizedBox(height: AppConstants.paddingSmall),
              Text('Items: ${order.items.length}', style: AppConstants.bodyMedium),
              Text('Total: ${Formatters.formatCurrency(order.totalAmount)}', style: AppConstants.bodyMedium),
              const SizedBox(height: AppConstants.paddingMedium),
              Row(
                children: [
                  Expanded(child: _buildOptionButton('Add Item', Icons.add, () async {
                    Navigator.pop(context);
                    // open edit order screen or new_order with editing context
                    _showOrderDetails(order);
                  })),
                ],
              ),
              const SizedBox(height: AppConstants.paddingSmall),
              Row(
                children: [
                  Expanded(child: _buildOptionButton('Merge', Icons.merge_type, () async {
                    Navigator.pop(context);
                    // start merge flow (pick target table)
                    await _startMergeFlow(order);
                  })),
                  const SizedBox(width: AppConstants.paddingSmall),
                  Expanded(child: _buildOptionButton('Checkout', Icons.payment, () async {
                    Navigator.pop(context);
                    _showCheckoutDialog(order);
                  })),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton(
    String label,
    IconData icon,
    Future<void> Function() onTap,
  ) {
    return InkWell(
      onTap: () async {
        await onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        margin: const EdgeInsets.only(bottom: AppConstants.paddingSmall),
        decoration: BoxDecoration(
          color: AppConstants.darkSecondary,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppConstants.primaryOrange),
            const SizedBox(width: AppConstants.paddingMedium),
            Text(label, style: AppConstants.bodyLarge),
          ],
        ),
      ),
    );
  }

  /// Add new table
  void _addNewTable() {
    final tableNumberController = TextEditingController();
    final capacityController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppConstants.cardBackground,
          title: Row(
            children: const [
              Icon(Icons.table_restaurant, color: AppConstants.primaryOrange),
              SizedBox(width: AppConstants.paddingSmall),
              Text('Add Table', style: AppConstants.headingSmall),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: tableNumberController,
                  style: AppConstants.bodyLarge,
                  decoration: const InputDecoration(
                    labelText: 'Table Number',
                    hintText: 'e.g. 5 or VIP-1',
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return 'Please enter a table number';
                    }
                    if (_tableNumberExists(trimmed)) {
                      return 'Table number already exists';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                TextFormField(
                  controller: capacityController,
                  style: AppConstants.bodyLarge,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Capacity',
                    hintText: 'Number of seats',
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    final capacity = int.tryParse(trimmed);
                    if (capacity == null || capacity <= 0) {
                      return 'Enter a valid capacity';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) {
                        return;
                      }
                      setDialogState(() {
                        isSubmitting = true;
                      });

                      final tableNumber = tableNumberController.text.trim();
                      final capacity =
                          int.parse(capacityController.text.trim());

                      final newTable = RestaurantTable(
                        id: '',
                        tableNumber: tableNumber,
                        capacity: capacity,
                        status: TableStatus.free,
                      );

                      try {
                        await _tableService.createTable(newTable);
                        if (!mounted) {
                          return;
                        }
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Table $tableNumber added successfully',
                            ),
                            backgroundColor: AppConstants.successGreen,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() {
                          isSubmitting = false;
                        });
                        if (!mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to add table: $e'),
                            backgroundColor: AppConstants.errorRed,
                          ),
                        );
                      }
                    },
              icon: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save Table'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryOrange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Update table status
  Future<void> _updateTableStatus(
    RestaurantTable table,
    TableStatus newStatus,
  ) async {
    try {
      if (newStatus == TableStatus.free) {
        // If clearing to free and table has an order, use atomic detach helper
        if (table.currentOrderId != null && table.currentOrderId!.isNotEmpty) {
          await _orderService.detachOrderFromTableAtomic(table.currentOrderId!);
        } else {
          await _tableService.updateTableStatus(table.id, newStatus);
        }
      } else {
        await _tableService.updateTableStatus(table.id, newStatus);
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Table ${table.tableNumber} updated to ${newStatus.toString().split('.').last}',
          ),
          backgroundColor: AppConstants.successGreen,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update table: $e'),
          backgroundColor: AppConstants.errorRed,
        ),
      );
    }
  }

  bool _tableNumberExists(String number) {
    return _tables.any(
      (table) => table.tableNumber.toLowerCase() == number.toLowerCase(),
    );
  }

  Future<void> _assignOrder(RestaurantTable table) async {
    if (table.status == TableStatus.seated &&
        (table.currentOrderId?.isNotEmpty ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Table ${table.tableNumber} already has an active order. Clear it first to reassign.',
          ),
          backgroundColor: AppConstants.primaryOrange,
        ),
      );
      return;
    }

    final assignableOrders = _availableOrdersForAssignment();
    if (assignableOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No pending orders available for assignment'),
          backgroundColor: AppConstants.primaryOrange,
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusLarge),
        ),
      ),
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assign Order to Table ${table.tableNumber}',
                style: AppConstants.headingMedium,
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: assignableOrders.length,
                  separatorBuilder: (_, __) => const SizedBox(
                    height: AppConstants.paddingSmall,
                  ),
                  itemBuilder: (context, index) {
                    final order = assignableOrders[index];
                    return InkWell(
                      onTap: () async {
                        Navigator.pop(context);
                        await _linkOrderToTable(table, order);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(AppConstants.paddingMedium),
                        decoration: BoxDecoration(
                          color: AppConstants.darkSecondary,
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusMedium),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order ${order.id}',
                                    style: AppConstants.bodyLarge,
                                  ),
                                  const SizedBox(
                                      height: AppConstants.paddingSmall / 2),
                                  Text(
                                    '${Formatters.formatCurrency(order.totalAmount)} • ${Formatters.formatDateTime(order.timestamp)}',
                                    style: AppConstants.bodySmall.copyWith(
                                      color: AppConstants.textSecondary,
                                    ),
                                  ),
                                  if ((order.notes ?? '').isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: AppConstants.paddingSmall / 2,
                                      ),
                                      child: Text(
                                        order.notes!,
                                        style: AppConstants.bodySmall,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppConstants.primaryOrange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                order.status
                                    .toString()
                                    .split('.')
                                    .last
                                    .toUpperCase(),
                                style: AppConstants.bodySmall.copyWith(
                                  color: AppConstants.primaryOrange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Order> _availableOrdersForAssignment() {
    final assignableStatuses = {
      OrderStatus.pending,
      OrderStatus.preparing,
      OrderStatus.ready,
    };

    final orders = _orders.where((order) {
      final hasTable =
          order.tableNumber.trim().isNotEmpty && order.tableNumber != 'NO_TABLE';
      if (hasTable) {
        return false;
      }
      return assignableStatuses.contains(order.status);
    }).toList();

    orders.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return orders;
  }

  Future<void> _linkOrderToTable(
    RestaurantTable table,
    Order order,
  ) async {
    try {
      // Use atomic helper to update both table and order in one operation
      await _orderService.assignOrderToTableAtomic(order.id, table.id);
      // Also update the full order record locally to keep data consistent
      await _orderService.updateOrder(
        order.copyWith(tableNumber: table.tableNumber),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order ${order.id} assigned to Table ${table.tableNumber}',
          ),
          backgroundColor: AppConstants.successGreen,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to assign order: $e'),
          backgroundColor: AppConstants.errorRed,
        ),
      );
    }
  }

  /// Show order details preview with quick actions (lightweight)
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
      builder: (context) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Order ${order.id}', style: AppConstants.headingMedium),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: AppConstants.paddingSmall),
                Text('Items: ${order.items.length}', style: AppConstants.bodyMedium),
                Text('Total: ${Formatters.formatCurrency(order.totalAmount)}', style: AppConstants.bodyMedium),
                const SizedBox(height: AppConstants.paddingMedium),
                Row(
                  children: [
                    Expanded(child: _buildOptionButton('Add Item', Icons.add, () async {
                      Navigator.pop(context);
                      // Open new order screen for adding items (user can create/edit there)
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewOrderScreen()));
                    })),
                  ],
                ),
                const SizedBox(height: AppConstants.paddingSmall),
                Row(
                  children: [
                    Expanded(child: _buildOptionButton('Merge', Icons.merge_type, () async {
                      Navigator.pop(context);
                      await _startMergeFlow(order);
                    })),
                    const SizedBox(width: AppConstants.paddingSmall),
                    Expanded(child: _buildOptionButton('Checkout', Icons.payment, () async {
                      Navigator.pop(context);
                      await _showCheckoutDialog(order);
                    })),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    final occupiedTables = sorted.where((t) => t.currentOrderId != null && t.currentOrderId!.isNotEmpty && t.currentOrderId != order.id).toList();
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
      final mergedTotal = mergedItems.fold<double>(0, (s, it) => s + ((it.totalPrice is num) ? (it.totalPrice as num).toDouble() : double.tryParse(it.totalPrice?.toString() ?? '0') ?? 0));

      final updatedTarget = targetOrder.copyWith(items: mergedItems.cast(), totalAmount: mergedTotal);

      await _orderService.updateOrder(updatedTarget);
      // remove source order and clear its table references
      await _orderService.deleteOrder(order.id);
      await _orderService.detachOrderFromTableAtomic(order.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Merged Order ${order.id} into ${targetOrder.id}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Merge failed: $e')));
    }
  }

  Future<void> _showCheckoutDialog(Order order) async {
    // Simple confirmation dialog for checkout
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.cardBackground,
        title: const Text('Checkout', style: AppConstants.headingSmall),
        content: Text('Complete payment for Order ${order.id} (${Formatters.formatCurrency(order.totalAmount)})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Try to use TransactionService if available
      TransactionService? transactionService;
      try {
        transactionService = Provider.of<TransactionService>(context, listen: false);
      } catch (_) {
        transactionService = null;
      }

      if (transactionService != null) {
        await transactionService.saveCheckout(
          order: order,
          paymentMethod: 'Manual Checkout',
          amountPaid: order.totalAmount,
          change: 0,
          metadata: const {'source': 'table_preview'},
        );
      }

      await _orderService.updateOrderStatus(order.id, OrderStatus.completed);
      if (_shouldReleaseTable(order, OrderStatus.completed)) {
        await _orderService.detachOrderFromTableAtomic(order.id);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order ${order.id} checked out')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checkout failed: $e')));
    }
  }

  Future<void> _detachOrderFromTable(RestaurantTable table) async {
    final orderId = table.currentOrderId;
    if (orderId == null || orderId.isEmpty) {
      return;
    }

    final order = _findOrderById(orderId);
    if (order == null) {
      return;
    }

    if (order.status == OrderStatus.completed ||
        order.status == OrderStatus.cancelled) {
      return;
    }

    try {
      // Use atomic helper to detach order and clear table refs
      await _orderService.detachOrderFromTableAtomic(orderId);
      // Also update full order record to keep data consistent
      await _orderService.updateOrder(
        order.copyWith(tableNumber: 'NO_TABLE'),
      );
    } catch (_) {
      // Failing to detach the table from the order isn't fatal; skip surfacing.
    }
  }

  Order? _findOrderById(String orderId) {
    try {
      return _orders.firstWhere((order) => order.id == orderId);
    } catch (_) {
      return null;
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
}
