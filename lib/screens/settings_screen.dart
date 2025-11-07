import 'package:flutter/material.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _darkMode = true;
  bool _soundEffects = true;
  bool _autoBackup = false;
  String _language = 'English';
  String _currency = 'PHP (₱)';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        backgroundColor: AppConstants.darkSecondary,
        title: const Text('Settings', style: AppConstants.headingSmall),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        children: [
          // General Section
          _buildSectionHeader('General'),
          _buildSettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Enable notifications',
            trailing: Switch(
              value: _notifications,
              onChanged: (v) => setState(() => _notifications = v),
              activeColor: AppConstants.primaryOrange,
            ),
          ),
          _buildSettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Dark mode',
            trailing: Switch(
              value: _darkMode,
              onChanged: (v) => setState(() => _darkMode = v),
              activeColor: AppConstants.primaryOrange,
            ),
          ),
          _buildSettingsTile(
            icon: Icons.volume_up_outlined,
            title: 'Sound effects',
            trailing: Switch(
              value: _soundEffects,
              onChanged: (v) => setState(() => _soundEffects = v),
              activeColor: AppConstants.primaryOrange,
            ),
          ),
          _buildSettingsTile(
            icon: Icons.language_outlined,
            title: 'Language',
            subtitle: _language,
            trailing: const Icon(Icons.chevron_right, color: AppConstants.textSecondary),
            onTap: () => _showLanguageDialog(),
          ),
          _buildSettingsTile(
            icon: Icons.attach_money,
            title: 'Currency',
            subtitle: _currency,
            trailing: const Icon(Icons.chevron_right, color: AppConstants.textSecondary),
            onTap: () => _showCurrencyDialog(),
          ),

          const SizedBox(height: AppConstants.paddingLarge),

          // Data & Storage Section
          _buildSectionHeader('Data & Storage'),
          _buildSettingsTile(
            icon: Icons.backup_outlined,
            title: 'Auto backup',
            subtitle: 'Backup data daily',
            trailing: Switch(
              value: _autoBackup,
              onChanged: (v) => setState(() => _autoBackup = v),
              activeColor: AppConstants.primaryOrange,
            ),
          ),
          _buildSettingsTile(
            icon: Icons.cloud_upload_outlined,
            title: 'Backup now',
            subtitle: 'Last backup: 2 days ago',
            trailing: const Icon(Icons.chevron_right, color: AppConstants.textSecondary),
            onTap: () => _showBackupDialog(),
          ),
          _buildSettingsTile(
            icon: Icons.cloud_download_outlined,
            title: 'Restore data',
            trailing: const Icon(Icons.chevron_right, color: AppConstants.textSecondary),
            onTap: () => _showRestoreDialog(),
          ),
          _buildSettingsTile(
            icon: Icons.storage_outlined,
            title: 'Clear cache',
            subtitle: '45 MB',
            trailing: const Icon(Icons.chevron_right, color: AppConstants.textSecondary),
            onTap: () => _showClearCacheDialog(),
          ),

          const SizedBox(height: AppConstants.paddingLarge),

          // Payment Section
          _buildSectionHeader('Payment'),
          _buildSettingsTile(
            icon: Icons.payment_outlined,
            title: 'Payment methods',
            subtitle: 'Manage payment options',
            trailing: const Icon(Icons.chevron_right, color: AppConstants.textSecondary),
            onTap: () {
              // TODO: Navigate to payment methods
            },
          ),
          _buildSettingsTile(
            icon: Icons.receipt_outlined,
            title: 'Receipt settings',
            subtitle: 'Customize receipt format',
            trailing: const Icon(Icons.chevron_right, color: AppConstants.textSecondary),
            onTap: () {
              // TODO: Navigate to receipt settings
            },
          ),
          _buildSettingsTile(
            icon: Icons.print_outlined,
            title: 'Printer settings',
            subtitle: 'Configure thermal printer',
            trailing: const Icon(Icons.chevron_right, color: AppConstants.textSecondary),
            onTap: () {
              // TODO: Navigate to printer settings
            },
          ),

          const SizedBox(height: AppConstants.paddingLarge),

          // Security Section
          _buildSectionHeader('Security'),
          _buildSettingsTile(
            icon: Icons.lock_outline,
            title: 'Change PIN',
            trailing: const Icon(Icons.chevron_right, color: AppConstants.textSecondary),
            onTap: () => _showChangePINDialog(),
          ),
          _buildSettingsTile(
            icon: Icons.fingerprint_outlined,
            title: 'Biometric login',
            trailing: const Icon(Icons.chevron_right, color: AppConstants.textSecondary),
            onTap: () {
              // TODO: Configure biometric
            },
          ),
          _buildSettingsTile(
            icon: Icons.admin_panel_settings_outlined,
            title: 'User permissions',
            subtitle: 'Manage staff access',
            trailing: const Icon(Icons.chevron_right, color: AppConstants.textSecondary),
            onTap: () {
              // TODO: Navigate to permissions
            },
          ),

          const SizedBox(height: AppConstants.paddingLarge),

          // About Section
          _buildSectionHeader('About'),
          _buildSettingsTile(
            icon: Icons.info_outline,
            title: 'About SmartPOS',
            subtitle: 'Version 1.0.0',
            trailing: const Icon(Icons.chevron_right, color: AppConstants.textSecondary),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: AppConstants.appName,
                applicationVersion: '1.0.0',
                applicationIcon: Icon(
                  Icons.restaurant,
                  size: 48,
                  color: AppConstants.primaryOrange,
                ),
                children: const [
                  Text('Smart POS system for restaurants.\nManage orders, tables, and staff efficiently.'),
                ],
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.help_outline,
            title: 'Help & Support',
            trailing: const Icon(Icons.chevron_right, color: AppConstants.textSecondary),
            onTap: () {
              // TODO: Navigate to help
            },
          ),
          _buildSettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            trailing: const Icon(Icons.chevron_right, color: AppConstants.textSecondary),
            onTap: () {
              // TODO: Show privacy policy
            },
          ),
          _buildSettingsTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            trailing: const Icon(Icons.chevron_right, color: AppConstants.textSecondary),
            onTap: () {
              // TODO: Show terms
            },
          ),

          const SizedBox(height: AppConstants.paddingLarge),

          // Logout
          _buildSettingsTile(
            icon: Icons.logout,
            title: 'Sign out',
            titleColor: AppConstants.errorRed,
            trailing: const Icon(Icons.chevron_right, color: AppConstants.errorRed),
            onTap: () => _showLogoutDialog(),
          ),

          const SizedBox(height: AppConstants.paddingLarge),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppConstants.paddingSmall,
        bottom: AppConstants.paddingSmall,
        top: AppConstants.paddingSmall,
      ),
      child: Text(
        title.toUpperCase(),
        style: AppConstants.bodySmall.copyWith(
          color: AppConstants.primaryOrange,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingSmall),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.dividerColor),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppConstants.primaryOrange),
        title: Text(
          title,
          style: AppConstants.bodyLarge.copyWith(
            color: titleColor,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: AppConstants.bodySmall.copyWith(
                  color: AppConstants.textSecondary,
                ),
              )
            : null,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.cardBackground,
        title: const Text('Select Language', style: AppConstants.headingSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption('English'),
            _buildLanguageOption('Filipino'),
            _buildLanguageOption('Spanish'),
            _buildLanguageOption('Chinese'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String language) {
    return RadioListTile<String>(
      title: Text(language, style: AppConstants.bodyMedium),
      value: language,
      groupValue: _language,
      activeColor: AppConstants.primaryOrange,
      onChanged: (value) {
        setState(() => _language = value!);
        Navigator.pop(context);
      },
    );
  }

  void _showCurrencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.cardBackground,
        title: const Text('Select Currency', style: AppConstants.headingSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCurrencyOption('PHP (₱)'),
            _buildCurrencyOption('USD (\$)'),
            _buildCurrencyOption('EUR (€)'),
            _buildCurrencyOption('JPY (¥)'),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyOption(String currency) {
    return RadioListTile<String>(
      title: Text(currency, style: AppConstants.bodyMedium),
      value: currency,
      groupValue: _currency,
      activeColor: AppConstants.primaryOrange,
      onChanged: (value) {
        setState(() => _currency = value!);
        Navigator.pop(context);
      },
    );
  }

  void _showBackupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.cardBackground,
        title: const Text('Backup Data', style: AppConstants.headingSmall),
        content: const Text(
          'Do you want to backup your data now?',
          style: AppConstants.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Backup completed successfully'),
                  backgroundColor: AppConstants.successGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryOrange,
            ),
            child: const Text('Backup'),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.cardBackground,
        title: const Text('Restore Data', style: AppConstants.headingSmall),
        content: const Text(
          'This will restore data from your last backup. Current data will be replaced.',
          style: AppConstants.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data restored successfully'),
                  backgroundColor: AppConstants.successGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.warningYellow,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.cardBackground,
        title: const Text('Clear Cache', style: AppConstants.headingSmall),
        content: const Text(
          'This will clear 45 MB of cached data. This action cannot be undone.',
          style: AppConstants.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared successfully'),
                  backgroundColor: AppConstants.successGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.errorRed,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showChangePINDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.cardBackground,
        title: const Text('Change PIN', style: AppConstants.headingSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Current PIN',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New PIN',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm New PIN',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('PIN changed successfully'),
                  backgroundColor: AppConstants.successGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryOrange,
            ),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.cardBackground,
        title: const Text('Sign Out', style: AppConstants.headingSmall),
        content: const Text(
          'Are you sure you want to sign out?',
          style: AppConstants.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement logout logic
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.errorRed,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}