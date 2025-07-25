import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/account_service.dart';
import '../services/database_service.dart';

const _whitbyBlue = Color(0xFF003366);

class MyWork extends StatefulWidget {
  const MyWork({super.key});

  @override
  State<MyWork> createState() => _MyWorkState();
}

class _MyWorkState extends State<MyWork> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _myLogs = [];
  Map<String, dynamic> _timeStats = {};
  bool _isLoading = true;
  String? _currentWorkerId;
  String _currentWorkerName = '';

  final DateFormat _dateFormat = DateFormat.yMMMd();
  final DateFormat _timeFormat = DateFormat.jm();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMyWork();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMyWork() async {
    try {
      _currentWorkerId = await AccountService.getCurrentAccountId();
      if (_currentWorkerId == null) return;

      // Get worker name
      final workers = await DatabaseService.getWorkers();
      final currentWorker = workers.firstWhere(
        (w) => w['id'] == _currentWorkerId,
        orElse: () => {'name': 'Unknown Worker'},
      );
      _currentWorkerName = currentWorker['name'] ?? 'Unknown Worker';

      // Get logs where this worker is included
      final logsSnapshot = await FirebaseFirestore.instance
          .collection('logs')
          .where('workers', arrayContains: _currentWorkerId)
          .get();

      final logs = logsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      // Sort logs by workDate in descending order (most recent first)
      logs.sort((a, b) {
        final aDate = (a['workDate'] as Timestamp?)?.toDate();
        final bDate = (b['workDate'] as Timestamp?)?.toDate();
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      // Calculate time statistics
      final now = DateTime.now();
      final thisWeekStart = now.subtract(Duration(days: now.weekday - 1));
      final thisMonthStart = DateTime(now.year, now.month, 1);

      double totalHours = 0;
      double thisWeekHours = 0;
      double thisMonthHours = 0;
      int totalEntries = logs.length;

      for (final log in logs) {
        final duration = log['durationMinutes'] as int? ?? 0;
        final hours = duration / 60.0;
        totalHours += hours;

        final workDate = (log['workDate'] as Timestamp?)?.toDate();
        if (workDate != null) {
          if (workDate.isAfter(thisWeekStart)) {
            thisWeekHours += hours;
          }
          if (workDate.isAfter(thisMonthStart)) {
            thisMonthHours += hours;
          }
        }
      }

      if (mounted) {
        setState(() {
          _myLogs = logs;
          _timeStats = {
            'totalHours': totalHours,
            'thisWeekHours': thisWeekHours,
            'thisMonthHours': thisMonthHours,
            'totalEntries': totalEntries,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading work data: $e')),
        );
      }
    }
  }

  Widget _buildStatsCard() {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _whitbyBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: _whitbyBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentWorkerName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: _whitbyBlue,
                        ),
                      ),
                      const Text(
                        'Work Summary',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Hours',
                    '${_timeStats['totalHours']?.toStringAsFixed(1) ?? '0.0'}h',
                    _whitbyBlue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'This Week',
                    '${_timeStats['thisWeekHours']?.toStringAsFixed(1) ?? '0.0'}h',
                    const Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'This Month',
                    '${_timeStats['thisMonthHours']?.toStringAsFixed(1) ?? '0.0'}h',
                    const Color(0xFF2196F3),
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Total Entries',
                    '${_timeStats['totalEntries'] ?? 0}',
                    const Color(0xFFFF9800),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkLogCard(Map<String, dynamic> log) {
    final workDate = (log['workDate'] as Timestamp?)?.toDate();
    final duration = log['durationMinutes'] as int? ?? 0;
    final hours = duration / 60.0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log['summary'] ?? log['workType'] ?? 'Work Entry',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _whitbyBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${log['location'] ?? 'Unknown Location'} • ${log['workType'] ?? 'Unknown Type'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _whitbyBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${hours.toStringAsFixed(1)}h',
                    style: const TextStyle(
                      color: _whitbyBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  workDate != null ? _dateFormat.format(workDate) : 'No date',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                if (log['startTime'] != null) ...[
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    '${log['startTime']} - ${log['endTime'] ?? 'Unknown'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
            if (log['description']?.toString().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                log['description'],
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimesheetView() {
    // Group logs by week
    final Map<String, List<Map<String, dynamic>>> weeklyLogs = {};
    
    for (final log in _myLogs) {
      final workDate = (log['workDate'] as Timestamp?)?.toDate();
      if (workDate != null) {
        final weekStart = workDate.subtract(Duration(days: workDate.weekday - 1));
        final weekKey = _dateFormat.format(weekStart);
        
        if (!weeklyLogs.containsKey(weekKey)) {
          weeklyLogs[weekKey] = [];
        }
        weeklyLogs[weekKey]!.add(log);
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: weeklyLogs.keys.length,
      itemBuilder: (context, index) {
        final weekKey = weeklyLogs.keys.elementAt(index);
        final weekLogs = weeklyLogs[weekKey]!;
        
        // Calculate weekly total
        double weeklyHours = 0;
        for (final log in weekLogs) {
          final duration = log['durationMinutes'] as int? ?? 0;
          weeklyHours += duration / 60.0;
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ExpansionTile(
            title: Text(
              'Week of $weekKey',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: _whitbyBlue,
              ),
            ),
            subtitle: Text('${weeklyHours.toStringAsFixed(1)} hours • ${weekLogs.length} entries'),
            children: weekLogs.map((log) => _buildWorkLogCard(log)).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatsCard(),
                TabBar(
                  controller: _tabController,
                  labelColor: _whitbyBlue,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: _whitbyBlue,
                  tabs: const [
                    Tab(text: 'Recent Work'),
                    Tab(text: 'Timesheet'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Recent Work Tab
                      _myLogs.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.work_off, size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    'No work entries found',
                                    style: TextStyle(fontSize: 18, color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(top: 8),
                              itemCount: _myLogs.length,
                              itemBuilder: (context, index) {
                                return _buildWorkLogCard(_myLogs[index]);
                              },
                            ),
                      
                      // Timesheet Tab
                      _myLogs.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.schedule, size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    'No timesheet data available',
                                    style: TextStyle(fontSize: 18, color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : _buildTimesheetView(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}