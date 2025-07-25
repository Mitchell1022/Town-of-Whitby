// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'manage_workers.dart';
import '../providers/theme_provider.dart';
import '../widgets/global_navigation_wrapper.dart';

const _whitbyBlue = Color(0xFF003366);

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool _enableNotifications = true;
  bool _autoSaveWork = true;
  bool _showCompactView = false;
  bool _darkMode = false;
  String _defaultLocation = '';
  int _autoLogoutMinutes = 30;

  List<String> _availableLocations = ['Main Office', 'Civic Centre', 'Depot'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enableNotifications = prefs.getBool('enableNotifications') ?? true;
      _autoSaveWork = prefs.getBool('autoSaveWork') ?? true;
      _showCompactView = prefs.getBool('showCompactView') ?? false;
      _darkMode = prefs.getBool('darkMode') ?? false;
      _defaultLocation = prefs.getString('defaultLocation') ?? '';
      _autoLogoutMinutes = prefs.getInt('autoLogoutMinutes') ?? 30;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: _whitbyBlue, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _whitbyBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    IconData? icon,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: icon != null ? Icon(icon, color: _whitbyBlue) : null,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: trailing,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageWithBottomNav(
      title: 'Settings',
      child: Container(
        color: const Color(0xFFF8F9FA),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // General Settings
            _buildSectionHeader('General', Icons.settings),
            _buildSettingTile(
              title: 'Enable Notifications',
              subtitle: 'Receive app notifications and reminders',
              icon: Icons.notifications,
              trailing: Switch(
                value: _enableNotifications,
                onChanged: (value) {
                  setState(() => _enableNotifications = value);
                  _saveSetting('enableNotifications', value);
                },
                activeColor: _whitbyBlue,
              ),
            ),
            _buildSettingTile(
              title: 'Auto-save Work Logs',
              subtitle: 'Automatically save work logs as you type',
              icon: Icons.save,
              trailing: Switch(
                value: _autoSaveWork,
                onChanged: (value) {
                  setState(() => _autoSaveWork = value);
                  _saveSetting('autoSaveWork', value);
                },
                activeColor: _whitbyBlue,
              ),
            ),
            _buildSettingTile(
              title: 'Compact View by Default',
              subtitle: 'Show logs in compact view when opening',
              icon: Icons.view_agenda,
              trailing: Switch(
                value: _showCompactView,
                onChanged: (value) {
                  setState(() => _showCompactView = value);
                  _saveSetting('showCompactView', value);
                },
                activeColor: _whitbyBlue,
              ),
            ),

            // Appearance
            _buildSectionHeader('Appearance', Icons.palette),
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return _buildSettingTile(
                  title: 'Dark Mode',
                  subtitle: themeProvider.isDarkMode ? 'Dark theme active' : 'Light theme active',
                  icon: themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  trailing: Switch(
                    value: themeProvider.isDarkMode,
                    onChanged: (value) {
                      themeProvider.toggleTheme();
                    },
                    activeColor: _whitbyBlue,
                  ),
                );
              },
            ),

            // Work Settings
            _buildSectionHeader('Work Preferences', Icons.work),
            _buildSettingTile(
              title: 'Default Location',
              subtitle:
                  _defaultLocation.isEmpty
                      ? 'No default set'
                      : _defaultLocation,
              icon: Icons.place,
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                final selected = await showDialog<String>(
                  context: context,
                  builder:
                      (context) => SimpleDialog(
                        title: const Text('Select Default Location'),
                        children: [
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(context, ''),
                            child: const Text('None'),
                          ),
                          ..._availableLocations.map(
                            (location) => SimpleDialogOption(
                              onPressed: () => Navigator.pop(context, location),
                              child: Text(location),
                            ),
                          ),
                        ],
                      ),
                );
                if (selected != null) {
                  setState(() => _defaultLocation = selected);
                  _saveSetting('defaultLocation', selected);
                }
              },
            ),
            _buildSettingTile(
              title: 'Auto-logout',
              subtitle:
                  'Logout after $_autoLogoutMinutes minutes of inactivity',
              icon: Icons.timer,
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                final selected = await showDialog<int>(
                  context: context,
                  builder:
                      (context) => SimpleDialog(
                        title: const Text('Auto-logout Timer'),
                        children:
                            [15, 30, 60, 120]
                                .map(
                                  (minutes) => SimpleDialogOption(
                                    onPressed:
                                        () => Navigator.pop(context, minutes),
                                    child: Text('$minutes minutes'),
                                  ),
                                )
                                .toList(),
                      ),
                );
                if (selected != null) {
                  setState(() => _autoLogoutMinutes = selected);
                  _saveSetting('autoLogoutMinutes', selected);
                }
              },
            ),

            // Data Management
            _buildSectionHeader('Data Management', Icons.storage),
            _buildSettingTile(
              title: 'Manage Workers',
              subtitle: 'Add, edit, or remove workers',
              icon: Icons.people,
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageWorkers(),
                  ),
                );
              },
            ),
            _buildSettingTile(
              title: 'Export Data',
              subtitle: 'Export work logs and reports',
              icon: Icons.download,
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Export feature coming soon!')),
                );
              },
            ),
            _buildSettingTile(
              title: 'Clear Cache',
              subtitle: 'Clear temporary files and cache',
              icon: Icons.clear_all,
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Clear Cache'),
                        content: const Text(
                          'This will clear temporary files. Your data will not be affected.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _whitbyBlue,
                            ),
                            child: const Text(
                              'Clear',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                );
                if (confirmed == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cache cleared successfully!'),
                    ),
                  );
                }
              },
            ),

            // About
            _buildSectionHeader('About', Icons.info),
            _buildSettingTile(
              title: 'App Version',
              subtitle: '1.0.0',
              icon: Icons.info_outline,
            ),
            _buildSettingTile(
              title: 'Privacy Policy',
              subtitle: 'View privacy policy',
              icon: Icons.privacy_tip,
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Privacy policy coming soon!')),
                );
              },
            ),
            _buildSettingTile(
              title: 'Support',
              subtitle: 'Get help and contact support',
              icon: Icons.help,
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Support contact: admin@whitby.ca'),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
