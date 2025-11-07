import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/order_management_screen.dart';
import 'screens/table_management_screen.dart';
import 'screens/staff_management_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/manage_menu_screen.dart';
import 'screens/transaction_history_screen.dart';
import 'screens/sales_history_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/constants.dart';

/// Main entry point of the SmartServe POS application
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // TODO: Initialize Firebase
  // await Firebase.initializeApp();
  
  runApp(const SmartServePOS());
}

/// Root application widget
class SmartServePOS extends StatelessWidget {
  const SmartServePOS({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Dark theme configuration
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppConstants.darkBackground,
        primaryColor: AppConstants.primaryOrange,
        colorScheme: ColorScheme.dark(
          primary: AppConstants.primaryOrange,
          secondary: AppConstants.accentOrange,
          surface: AppConstants.cardBackground,
          error: AppConstants.errorRed,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppConstants.darkSecondary,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppConstants.textPrimary),
          titleTextStyle: AppConstants.headingMedium,
        ),
        cardTheme: CardThemeData(
          color: AppConstants.cardBackground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryOrange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingLarge,
              vertical: AppConstants.paddingMedium,
            ),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AppConstants.primaryOrange,
          foregroundColor: Colors.white,
        ),
        textTheme: const TextTheme(
          headlineLarge: AppConstants.headingLarge,
          headlineMedium: AppConstants.headingMedium,
          headlineSmall: AppConstants.headingSmall,
          bodyLarge: AppConstants.bodyLarge,
          bodyMedium: AppConstants.bodyMedium,
          bodySmall: AppConstants.bodySmall,
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

/// Main navigation screen with bottom navigation bar
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // List of screens for navigation
  final List<Widget> _screens = const [
    DashboardScreen(),
    OrderManagementScreen(),
    TableManagementScreen(),
    StaffManagementScreen(),
    AnalyticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
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
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingSmall,
              vertical: AppConstants.paddingSmall,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.dashboard, 'Dashboard'),
                _buildNavItem(1, Icons.receipt_long, 'Orders'),
                _buildNavItem(2, Icons.table_restaurant, 'Tables'),
                _buildNavItem(3, Icons.people, 'Staff'),
                _buildNavItem(4, Icons.analytics, 'Analytics'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build navigation item
  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    
    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingMedium,
          vertical: AppConstants.paddingSmall,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppConstants.primaryOrange.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppConstants.primaryOrange
                  : AppConstants.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? AppConstants.primaryOrange
                    : AppConstants.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build side drawer menu
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppConstants.darkBackground,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.all(AppConstants.paddingLarge),
              decoration: BoxDecoration(
                color: AppConstants.darkSecondary,
                border: Border(
                  bottom: BorderSide(
                    color: AppConstants.dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                    color: AppConstants.textPrimary,
                  ),
                  const SizedBox(width: AppConstants.paddingSmall),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConstants.appName,
                        style: AppConstants.headingMedium.copyWith(
                          color: AppConstants.primaryOrange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Restaurant Management',
                        style: AppConstants.bodySmall.copyWith(
                          color: AppConstants.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: AppConstants.paddingMedium,
                ),
                children: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.person_outline,
                    title: 'User Profile',
                    onTap: () {
                      Navigator.pop(context);
                      _showComingSoonDialog(context, 'User Profile');
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.restaurant_menu_outlined,
                    title: 'Manage Menu',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManageMenuScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.payment_outlined,
                    title: 'Transaction History',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.bar_chart,
                    title: 'Sales History',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SalesHistoryScreen()),
                      );
                    },
                  ),
                  const Divider(color: AppConstants.dividerColor, height: 32),
                  _buildDrawerItem(
                    context,
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(AppConstants.paddingLarge),
              decoration: BoxDecoration(
                color: AppConstants.darkSecondary,
                border: Border(
                  top: BorderSide(
                    color: AppConstants.dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppConstants.primaryOrange,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: AppConstants.paddingMedium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Admin User',
                          style: AppConstants.bodyMedium,
                        ),
                        Text(
                          'admin@smartserve.com',
                          style: AppConstants.bodySmall.copyWith(
                            color: AppConstants.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () {
                      Navigator.pop(context);
                      _showLogoutDialog(context);
                    },
                    color: AppConstants.errorRed,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build drawer menu item
  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: AppConstants.textPrimary,
        size: 24,
      ),
      title: Text(
        title,
        style: AppConstants.bodyMedium,
      ),
      onTap: onTap,
      hoverColor: AppConstants.primaryOrange.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingLarge,
        vertical: 4,
      ),
    );
  }

  /// Show coming soon dialog
  void _showComingSoonDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: AppConstants.primaryOrange,
            ),
            const SizedBox(width: AppConstants.paddingSmall),
            Text(
              feature,
              style: AppConstants.headingSmall,
            ),
          ],
        ),
        content: Text(
          'This feature is coming soon! Stay tuned for updates.',
          style: AppConstants.bodyMedium.copyWith(
            color: AppConstants.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: AppConstants.primaryOrange),
            ),
          ),
        ],
      ),
    );
  }

  /// Show logout confirmation dialog
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
        title: Row(
          children: [
            Icon(
              Icons.logout,
              color: AppConstants.errorRed,
            ),
            const SizedBox(width: AppConstants.paddingSmall),
            const Text(
              'Logout',
              style: AppConstants.headingSmall,
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to logout?',
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
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logged out successfully'),
                  backgroundColor: AppConstants.successGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.errorRed,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}