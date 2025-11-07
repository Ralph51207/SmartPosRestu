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
          SwitchListTile(
            value: _notifications,
            title: const Text('Enable notifications', style: AppConstants.bodyLarge),
            onChanged: (v) => setState(() => _notifications = v),
            activeColor: AppConstants.primaryOrange,
          ),
          SwitchListTile(
            value: _darkMode,
            title: const Text('Dark mode', style: AppConstants.bodyLarge),
            onChanged: (v) => setState(() => _darkMode = v),
            activeColor: AppConstants.primaryOrange,
          ),
          ListTile(
            leading: const Icon(Icons.payment, color: AppConstants.primaryOrange),
            title: const Text('Payment settings', style: AppConstants.bodyLarge),
            onTap: () {
              // TODO: navigate to payment gateway settings
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline, color: AppConstants.primaryOrange),
            title: const Text('About', style: AppConstants.bodyLarge),
            onTap: () {
              // TODO: show about dialog
            },
          ),
        ],
      ),
    );
  }
}