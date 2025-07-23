// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'pages/home.dart';
import 'pages/view_logs.dart';
import 'pages/settings.dart';
import 'pages/add_location.dart';
import 'pages/add_work_type.dart';
import 'pages/add_worker.dart';
import 'pages/location_status.dart';
import 'pages/account_selection.dart';
import 'pages/my_work.dart';
import 'services/account_service.dart';
import 'services/database_service.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Town of Whitby',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF003366),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF003366),
          secondary: const Color(0xFF0066CC),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF003366),
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shadowColor: const Color(0xFF003366).withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF003366), width: 2),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),
          bodyMedium: TextStyle(fontSize: 14, color: Colors.black87),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF003366),
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF003366),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF003366)),
      ),
      home: const _AccountWrapper(),
    );
  }
}

class _AccountWrapper extends StatefulWidget {
  const _AccountWrapper({super.key});

  @override
  State<_AccountWrapper> createState() => _AccountWrapperState();
}

class _AccountWrapperState extends State<_AccountWrapper> {
  bool _hasAccount = false;
  bool _isLoading = true;
  String? _currentWorkerName;

  @override
  void initState() {
    super.initState();
    _checkAccount();
  }

  Future<void> _checkAccount() async {
    try {
      final hasAccount = await AccountService.hasActiveAccount();
      if (hasAccount) {
        final accountId = await AccountService.getCurrentAccountId();
        if (accountId != null) {
          final workers = await DatabaseService.getWorkers();
          final worker = workers.firstWhere(
            (w) => w['id'] == accountId,
            orElse: () => {'name': 'Unknown Worker'},
          );
          if (mounted) {
            setState(() {
              _hasAccount = true;
              _currentWorkerName = worker['name'];
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _hasAccount = false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasAccount = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectAccount() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AccountSelection()),
    );
    if (result == true) {
      _checkAccount();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasAccount) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/whitby_logo.png', height: 100),
                const SizedBox(height: 32),
                const Text(
                  'Welcome to Town of Whitby\nWork Log Portal',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003366),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Please select your worker account to continue',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _selectAccount,
                  icon: const Icon(Icons.person, color: Colors.white),
                  label: const Text(
                    'Select Account',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003366),
                    minimumSize: const Size(200, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _MainNavigationWithAccount(workerName: _currentWorkerName ?? 'Worker');
  }
}

class _MainNavigationWithAccount extends StatefulWidget {
  final String workerName;
  
  const _MainNavigationWithAccount({required this.workerName});

  @override
  State<_MainNavigationWithAccount> createState() => _MainNavigationWithAccountState();
}

class _MainNavigationWithAccountState extends State<_MainNavigationWithAccount> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isDrawerOpen = false;

  final List<Widget> _pages = [const Home(), const ViewLogs(), const MyWork()];

  void _toggleDrawer() {
    if (_isDrawerOpen) {
      Navigator.of(context).pop();
    } else {
      _scaffoldKey.currentState?.openDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: const Color(0xFF003366),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Town of Whitby',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            Text(
              'Logged in as ${widget.workerName}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: _toggleDrawer,
        ),
      ),
      onDrawerChanged: (isOpened) {
        setState(() {
          _isDrawerOpen = isOpened;
        });
      },
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: Color(0xFF003366),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: 16,
                bottom: 12,
              ),
              child: Row(
                children: const [
                  Icon(Icons.menu, size: 36, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'Menu',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_location),
              title: const Text('Add Location'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddLocation()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.build),
              title: const Text('Add Work Type'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddWorkType()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Add Worker'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddWorker()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Location Status'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LocationStatus(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Settings()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Switch Account', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await AccountService.clearCurrentAccount();
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const _AccountWrapper()),
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF003366),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'View Logs'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'My Work'),
        ],
      ),
    );
  }
}
