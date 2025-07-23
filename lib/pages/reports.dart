// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

const _whitbyBlue = Color(0xFF003366);
const _textColour = Colors.black87;

class Reports extends StatefulWidget {
  const Reports({super.key});

  @override
  State<Reports> createState() => _ReportsState();
}

class _ReportsState extends State<Reports> {
  late Future<_ReportData> _reportFuture;
  DateTimeRange? _dateRange;
  String _selectedTab = 'overview';
  final DateFormat _dateFmt = DateFormat.yMMMd();

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  void _loadReport() {
    setState(() {
      _reportFuture = _generateReport();
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null && picked != _dateRange) {
      setState(() {
        _dateRange = picked;
        _loadReport();
      });
    }
  }

  Future<_ReportData> _generateReport() async {
    var query =
        FirebaseFirestore.instance.collection('logs')
            as Query<Map<String, dynamic>>;

    if (_dateRange != null) {
      query = query
          .where(
            'workDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_dateRange!.start),
          )
          .where(
            'workDate',
            isLessThanOrEqualTo: Timestamp.fromDate(_dateRange!.end),
          );
    }

    // Load workers data for name mapping
    final workers = await DatabaseService.getWorkers();
    final workerMap = <String, String>{};
    for (final worker in workers) {
      workerMap[worker['id']] = worker['name'];
    }

    final logsSnap = await query.get();

    final Map<String, double> hoursByLocation = {};
    final Map<String, int> workTypeCount = {};
    final Map<String, int> entriesByLocation = {};
    final Map<String, List<int>> dailyHours = {};
    final Map<String, Set<String>> workersByLocation = {};
    final Map<String, Map<String, String>> workersNamesByLocation = {};
    final Map<String, double> efficiencyByLocation = {};
    final Map<String, double> hoursByWorker = {};
    final Map<String, Map<String, double>> workerHoursByLocation = {};
    final List<Map<String, dynamic>> recentActivity = [];

    double totalHours = 0;
    int totalEntries = 0;
    int withPhotos = 0;

    for (var doc in logsSnap.docs) {
      final data = doc.data();
      final loc = (data['location'] ?? 'Unknown') as String;
      final mins = (data['durationMinutes'] ?? 0) as int;
      final workType = (data['workType'] ?? 'Unknown') as String;
      final workers = data['workers'] ?? [];
      final photos = (data['photos'] ?? []) as List;
      final date = (data['workDate'] as Timestamp?)?.toDate();

      final hours = mins / 60;

      // Basic stats
      hoursByLocation.update(loc, (v) => v + hours, ifAbsent: () => hours);
      workTypeCount.update(workType, (v) => v + 1, ifAbsent: () => 1);
      entriesByLocation.update(loc, (v) => v + 1, ifAbsent: () => 1);
      totalHours += hours;
      totalEntries++;

      if (photos.isNotEmpty) withPhotos++;

      // Workers by location and hours tracking
      if (workers is List && workers.isNotEmpty) {
        if (!workersByLocation.containsKey(loc)) {
          workersByLocation[loc] = <String>{};
          workersNamesByLocation[loc] = <String, String>{};
          workerHoursByLocation[loc] = <String, double>{};
        }
        for (final workerId in workers.cast<String>()) {
          final workerName = workerMap[workerId] ?? 'Unknown Worker';
          workersByLocation[loc]!.add(workerId);
          workersNamesByLocation[loc]![workerId] = workerName;

          // Track hours per worker
          hoursByWorker.update(
            workerName,
            (v) => v + hours,
            ifAbsent: () => hours,
          );
          workerHoursByLocation[loc]!.update(
            workerName,
            (v) => v + hours,
            ifAbsent: () => hours,
          );
        }
      } else if (workers is String && workers.isNotEmpty) {
        // Handle legacy comma-separated format
        final workerList = workers
            .split(',')
            .map((w) => w.trim())
            .where((w) => w.isNotEmpty);
        if (!workersByLocation.containsKey(loc)) {
          workersByLocation[loc] = <String>{};
          workersNamesByLocation[loc] = <String, String>{};
          workerHoursByLocation[loc] = <String, double>{};
        }
        for (final workerName in workerList) {
          workersByLocation[loc]!.add(workerName);
          workersNamesByLocation[loc]![workerName] = workerName;

          // Track hours per worker
          hoursByWorker.update(
            workerName,
            (v) => v + hours,
            ifAbsent: () => hours,
          );
          workerHoursByLocation[loc]!.update(
            workerName,
            (v) => v + hours,
            ifAbsent: () => hours,
          );
        }
      }

      // Recent activity with enhanced details
      if (recentActivity.length < 10) {
        // Get worker names for this entry
        List<String> entryWorkerNames = [];
        if (workers is List && workers.isNotEmpty) {
          for (final workerId in workers.cast<String>()) {
            entryWorkerNames.add(workerMap[workerId] ?? 'Unknown Worker');
          }
        } else if (workers is String && workers.isNotEmpty) {
          entryWorkerNames =
              workers
                  .split(',')
                  .map((w) => w.trim())
                  .where((w) => w.isNotEmpty)
                  .toList();
        }

        recentActivity.add({
          'workType': workType,
          'location': loc,
          'date': date,
          'hours': hours,
          'workers': entryWorkerNames,
          'description': data['description'] ?? '',
          'photos': photos.length,
          'id': doc.id,
        });
      }

      // Daily hours for trends
      if (date != null) {
        final dayKey = DateFormat('yyyy-MM-dd').format(date);
        if (!dailyHours.containsKey(dayKey)) {
          dailyHours[dayKey] = [];
        }
        dailyHours[dayKey]!.add(mins);
      }
    }

    // Calculate efficiency (hours per entry) by location
    for (final loc in hoursByLocation.keys) {
      final hours = hoursByLocation[loc]!;
      final entries = entriesByLocation[loc] ?? 1;
      efficiencyByLocation[loc] = hours / entries;
    }

    return _ReportData(
      hoursByLocation: hoursByLocation,
      workTypeCount: workTypeCount,
      entriesByLocation: entriesByLocation,
      workersByLocation: workersByLocation,
      workersNamesByLocation: workersNamesByLocation,
      efficiencyByLocation: efficiencyByLocation,
      hoursByWorker: hoursByWorker,
      workerHoursByLocation: workerHoursByLocation,
      dailyHours: dailyHours,
      recentActivity: recentActivity,
      totalHours: totalHours,
      logCount: totalEntries,
      entriesWithPhotos: withPhotos,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: _whitbyBlue,
        foregroundColor: Colors.white,
        title: const Text('Reports & Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _pickDateRange,
            tooltip: 'Filter by date range',
          ),
        ],
      ),
      body: Column(
        children: [
          // Date range indicator
          if (_dateRange != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: _whitbyBlue.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.filter_list, color: _whitbyBlue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Filtered: ${_dateFmt.format(_dateRange!.start)} - ${_dateFmt.format(_dateRange!.end)}',
                    style: TextStyle(
                      color: _whitbyBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _dateRange = null;
                        _loadReport();
                      });
                    },
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ),

          // Tab navigation
          Container(
            color: Colors.white,
            child: Row(
              children: [
                _buildTabButton('overview', 'Overview', Icons.dashboard),
                _buildTabButton('locations', 'Locations', Icons.place),
                _buildTabButton(
                  'productivity',
                  'Productivity',
                  Icons.trending_up,
                ),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<_ReportData>(
              future: _reportFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final report = snapshot.data!;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child:
                      _selectedTab == 'overview'
                          ? _buildOverviewTab(report)
                          : _selectedTab == 'locations'
                          ? _buildLocationsTab(report)
                          : _buildProductivityTab(report),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tabId, String label, IconData icon) {
    final isSelected = _selectedTab == tabId;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = tabId),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? _whitbyBlue : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? _whitbyBlue : Colors.grey[500],
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? _whitbyBlue : Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(_ReportData report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Key metrics cards
        Row(
          children: [
            Expanded(
              child: _metricCard(
                'Total Hours',
                '${report.totalHours.toStringAsFixed(1)}h',
                Icons.access_time,
                _whitbyBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricCard(
                'Total Entries',
                report.logCount.toString(),
                Icons.assignment,
                Colors.green[600]!,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                'Locations Active',
                report.hoursByLocation.length.toString(),
                Icons.place,
                Colors.orange[600]!,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricCard(
                'With Photos',
                '${((report.entriesWithPhotos / report.logCount) * 100).toStringAsFixed(0)}%',
                Icons.camera_alt,
                Colors.purple[600]!,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Top work types
        _sectionHeader('Work Type Breakdown'),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children:
                  (report.workTypeCount.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value)))
                      .take(5)
                      .map(
                        (entry) => _progressBar(
                          entry.key,
                          entry.value,
                          report.workTypeCount.values.reduce(
                            (a, b) => a > b ? a : b,
                          ),
                          Icons.work_outline,
                        ),
                      )
                      .toList(),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Recent activity
        _sectionHeader('Recent Work Entries'),
        const SizedBox(height: 12),
        ...report.recentActivity.map(
          (activity) => _buildEnhancedActivityCard(activity),
        ),
      ],
    );
  }

  Widget _buildLocationsTab(_ReportData report) {
    final sortedLocations =
        report.hoursByLocation.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Location Performance'),
        const SizedBox(height: 16),

        ...sortedLocations.map((entry) {
          final location = entry.key;
          final hours = entry.value;
          final entries = report.entriesByLocation[location] ?? 0;
          final workers = report.workersByLocation[location]?.length ?? 0;
          final efficiency = report.efficiencyByLocation[location] ?? 0;

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
                        child: Icon(Icons.place, color: _whitbyBlue, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              location,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _textColour,
                              ),
                            ),
                            Text(
                              '$entries entries • $workers workers',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${hours.toStringAsFixed(1)}h',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _whitbyBlue,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _miniMetric(
                          'Hours/Entry',
                          efficiency.toStringAsFixed(1),
                          Icons.speed,
                        ),
                      ),
                      Expanded(
                        child: _miniMetric(
                          'Share',
                          '${((hours / report.totalHours) * 100).toStringAsFixed(0)}%',
                          Icons.pie_chart,
                        ),
                      ),
                      Expanded(
                        child: _miniMetric(
                          'Workers',
                          workers.toString(),
                          Icons.people,
                        ),
                      ),
                    ],
                  ),

                  // Show worker names
                  if (report.workersNamesByLocation[location]?.isNotEmpty ==
                      true) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Workers:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _whitbyBlue,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children:
                          report.workersNamesByLocation[location]!.values.map((
                            workerName,
                          ) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                workerName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProductivityTab(_ReportData report) {
    final avgHoursPerEntry =
        report.logCount > 0 ? report.totalHours / report.logCount : 0;
    final photoRate =
        report.logCount > 0
            ? (report.entriesWithPhotos / report.logCount) * 100
            : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Productivity Metrics'),
        const SizedBox(height: 16),

        // Overview cards
        Row(
          children: [
            Expanded(
              child: _metricCard(
                'Avg Hours/Entry',
                avgHoursPerEntry.toStringAsFixed(2),
                Icons.trending_up,
                Colors.blue[600]!,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricCard(
                'Photo Coverage',
                '${photoRate.toStringAsFixed(0)}%',
                Icons.camera_alt,
                Colors.green[600]!,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Efficiency by location (average minutes per entry)
        _sectionHeader('Average Time Per Entry'),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children:
                  (report.efficiencyByLocation.entries.toList()..sort(
                        (a, b) => a.value.compareTo(b.value),
                      )) // Sort by least time first (most efficient)
                      .map(
                        (entry) => _progressBar(
                          entry.key,
                          entry.value * 60, // Convert to minutes for display
                          report.efficiencyByLocation.values.reduce(
                                (a, b) => a > b ? a : b,
                              ) *
                              60,
                          Icons.timer,
                          suffix: ' min/entry',
                        ),
                      )
                      .toList(),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Worker Hours Summary
        if (report.hoursByWorker.isNotEmpty) ...[
          _sectionHeader('Worker Performance'),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children:
                    (report.hoursByWorker.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value)))
                        .map(
                          (entry) => _buildWorkerHoursRow(
                            entry.key,
                            entry.value,
                            report,
                          ),
                        )
                        .toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEnhancedActivityCard(Map<String, dynamic> activity) {
    final workers = activity['workers'] as List<String>? ?? [];
    final hours = activity['hours'] as double? ?? 0.0;
    final photos = activity['photos'] as int? ?? 0;
    final description = activity['description'] as String? ?? '';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with work type and hours
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _whitbyBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.work_outline, color: _whitbyBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity['summary'] ??
                            activity['workType'] ??
                            'Unknown Work Type',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: _whitbyBlue,
                        ),
                      ),
                      Text(
                        activity['location'] ?? 'Unknown Location',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _whitbyBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${hours.toStringAsFixed(1)}h',
                        style: const TextStyle(
                          color: _whitbyBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (activity['date'] != null)
                      Text(
                        DateFormat.MMMd().format(activity['date']),
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Worker details
            if (workers.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.people, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    'Workers (${workers.length}):',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children:
                    workers.map((worker) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person,
                              size: 12,
                              color: Colors.green[700],
                            ),
                            const SizedBox(width: 3),
                            Text(
                              worker,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 8),
            ],

            // Additional details row
            Row(
              children: [
                if (photos > 0) ...[
                  Icon(Icons.camera_alt, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '$photos photo${photos == 1 ? '' : 's'}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                ],
                if (description.isNotEmpty) ...[
                  Icon(Icons.description, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      description,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerHoursRow(
    String workerName,
    double hours,
    _ReportData report,
  ) {
    // Find locations where this worker has worked
    final workerLocations = <String>[];
    for (final entry in report.workerHoursByLocation.entries) {
      if (entry.value.containsKey(workerName)) {
        workerLocations.add(entry.key);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.person, color: Colors.blue[700], size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${workerLocations.length} location${workerLocations.length == 1 ? '' : 's'}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children:
                  workerLocations.take(3).map((location) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        location,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _whitbyBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${hours.toStringAsFixed(1)}h',
              style: const TextStyle(
                color: _whitbyBlue,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: _textColour,
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: _whitbyBlue, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _whitbyBlue,
            fontSize: 16,
          ),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _progressBar(
    String label,
    num value,
    num max,
    IconData icon, {
    String suffix = '',
  }) {
    final percentage = max > 0 ? (value / max) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _whitbyBlue, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '${value.toStringAsFixed(value is double ? 1 : 0)}$suffix',
                style: TextStyle(
                  color: _whitbyBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation(_whitbyBlue),
            minHeight: 8,
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value) => Card(
    elevation: 2,
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      title: Text(label, style: const TextStyle(color: _textColour)),
      trailing: Text(
        value,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: _textColour,
        ),
      ),
    ),
  );
}

class _ReportData {
  final Map<String, double> hoursByLocation;
  final Map<String, int> workTypeCount;
  final Map<String, int> entriesByLocation;
  final Map<String, Set<String>> workersByLocation;
  final Map<String, Map<String, String>> workersNamesByLocation;
  final Map<String, double> efficiencyByLocation;
  final Map<String, double> hoursByWorker;
  final Map<String, Map<String, double>> workerHoursByLocation;
  final Map<String, List<int>> dailyHours;
  final List<Map<String, dynamic>> recentActivity;
  final double totalHours;
  final int logCount;
  final int entriesWithPhotos;

  _ReportData({
    required this.hoursByLocation,
    required this.workTypeCount,
    required this.entriesByLocation,
    required this.workersByLocation,
    required this.workersNamesByLocation,
    required this.efficiencyByLocation,
    required this.hoursByWorker,
    required this.workerHoursByLocation,
    required this.dailyHours,
    required this.recentActivity,
    required this.totalHours,
    required this.logCount,
    required this.entriesWithPhotos,
  });
}
