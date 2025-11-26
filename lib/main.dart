import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/dashboard_screen.dart';
import 'screens/order_management_screen.dart';
import 'screens/table_management_screen.dart';
import 'screens/staff_management_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/manage_menu_screen.dart';
import 'screens/transaction_history_screen.dart';
import 'screens/sales_history_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/expense_service.dart';
import 'services/transaction_service.dart'; // ADD THIS
import 'services/transaction_service.dart';
import 'utils/constants.dart';

/// Main entry point of the SmartServe POS application
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (check if already initialized to avoid duplicate app error)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      print('⚠️ Firebase already initialized');
    } else {
      print('❌ Firebase initialization error: $e');
      rethrow;
    }
  }

  runApp(const SmartServePOS());
}

/// Root application widget
class SmartServePOS extends StatelessWidget {
  const SmartServePOS({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<TransactionService>(
          // ADD THIS
          create: (_) => TransactionService(),
        ),
        Provider<ExpenseService>(create: (_) => ExpenseService()),
      ],
      child: MaterialApp(
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
        home: const AuthWrapper(),
      ),
    );
  }
}

/// Authentication Wrapper
/// Redirects users to login or main app based on auth state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppConstants.darkBackground,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppConstants.primaryOrange),
                  const SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: AppConstants.bodyLarge.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Check if user is authenticated
        if (snapshot.hasData && snapshot.data != null) {
          // User is logged in, show main app
          return const MainNavigationScreen();
        }

        // User is not logged in, show login screen
        return const LoginScreen();
      },
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
      body: IndexedStack(index: _currentIndex, children: _screens),
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
    final authService = Provider.of<AuthService>(context, listen: false);
    final firebaseUser = authService.currentUser;

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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserProfileScreen(),
                        ),
                      );
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
                        MaterialPageRoute(
                          builder: (_) => const TransactionHistoryScreen(),
                        ),
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
                        MaterialPageRoute(
                          builder: (_) => const SalesHistoryScreen(),
                        ),
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
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Footer
            FutureBuilder<Map<String, dynamic>?>(
              future: authService.fetchUserProfile(),
              builder: (context, snapshot) {
                final data = snapshot.data ?? <String, dynamic>{};
                final loadingProfile =
                    snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData;

                final nameSource =
                    (data['username'] as String?) ??
                    (data['displayName'] as String?) ??
                    firebaseUser?.displayName ??
                    firebaseUser?.email ??
                    'SmartServe User';
                final sanitizedName = nameSource.trim().isNotEmpty
                    ? nameSource.trim()
                    : 'SmartServe User';
                final emailSource =
                    (data['email'] as String?) ?? firebaseUser?.email ?? '';
                final sanitizedEmail = emailSource.trim().isNotEmpty
                    ? emailSource.trim()
                    : 'Tap profile to add email';
                final avatarText = sanitizedName.isNotEmpty
                    ? sanitizedName[0].toUpperCase()
                    : 'S';

                return Container(
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
                      CircleAvatar(
                        backgroundColor: AppConstants.primaryOrange,
                        child: loadingProfile
                            ? CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppConstants.darkBackground,
                              )
                            : Text(
                                avatarText,
                                style: AppConstants.bodyLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(width: AppConstants.paddingMedium),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sanitizedName,
                              style: AppConstants.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              sanitizedEmail,
                              style: AppConstants.bodySmall.copyWith(
                                color: AppConstants.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
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
                );
              },
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
      leading: Icon(icon, color: AppConstants.textPrimary, size: 24),
      title: Text(title, style: AppConstants.bodyMedium),
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
            Icon(Icons.info_outline, color: AppConstants.primaryOrange),
            const SizedBox(width: AppConstants.paddingSmall),
            Text(feature, style: AppConstants.headingSmall),
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
            Icon(Icons.logout, color: AppConstants.errorRed),
            const SizedBox(width: AppConstants.paddingSmall),
            const Text('Logout', style: AppConstants.headingSmall),
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
            onPressed: () async {
              Navigator.pop(context);
              final authService = Provider.of<AuthService>(
                context,
                listen: false,
              );
              final result = await authService.signOut();
              if (result['success'] && context.mounted) {
                // Navigate to login screen
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message']),
                    backgroundColor: AppConstants.successGreen,
                  ),
                );
              }
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
