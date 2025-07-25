// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../widgets/global_navigation_wrapper.dart';

const _whitbyBlue = Color(0xFF003366);

class LocationStatus extends StatefulWidget {
  const LocationStatus({super.key});

  @override
  State<LocationStatus> createState() => _LocationStatusState();
}

class _LocationStatusState extends State<LocationStatus> {
  List<Map<String, dynamic>> _locationData = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';

  final DateFormat _dateFormat = DateFormat.yMMMd();

  @override
  void initState() {
    super.initState();
    _loadLocationData();
  }

  Future<void> _loadLocationData() async {
    try {
      final data = await DatabaseService.getLocationActivityStatus();
      if (mounted) {
        setState(() {
          _locationData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading location data: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredData {
    if (_selectedFilter == 'all') return _locationData;

    switch (_selectedFilter) {
      case 'critical':
        return _locationData
            .where((loc) => (loc['daysSinceLastWork'] as int) > 60)
            .toList();
      case 'attention':
        return _locationData
            .where(
              (loc) =>
                  (loc['daysSinceLastWork'] as int) > 30 &&
                  (loc['daysSinceLastWork'] as int) <= 60,
            )
            .toList();
      case 'moderate':
        return _locationData
            .where(
              (loc) =>
                  (loc['daysSinceLastWork'] as int) > 7 &&
                  (loc['daysSinceLastWork'] as int) <= 30,
            )
            .toList();
      case 'active':
        return _locationData
            .where((loc) => (loc['daysSinceLastWork'] as int) <= 7)
            .toList();
      default:
        return _locationData;
    }
  }

  Widget _buildStatsCard() {
    if (_locationData.isEmpty) return const SizedBox.shrink();

    final totalLocations = _locationData.length;
    final criticalCount =
        _locationData
            .where((loc) => (loc['daysSinceLastWork'] as int) > 60)
            .length;
    final attentionCount =
        _locationData
            .where(
              (loc) =>
                  (loc['daysSinceLastWork'] as int) > 30 &&
                  (loc['daysSinceLastWork'] as int) <= 60,
            )
            .length;
    final moderateCount =
        _locationData
            .where(
              (loc) =>
                  (loc['daysSinceLastWork'] as int) > 7 &&
                  (loc['daysSinceLastWork'] as int) <= 30,
            )
            .length;
    final activeCount =
        _locationData
            .where((loc) => (loc['daysSinceLastWork'] as int) <= 7)
            .length;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    Icons.location_on,
                    color: _whitbyBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location Overview',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: _whitbyBlue,
                        ),
                      ),
                      Text(
                        'Current status of all work locations',
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
                    'Active (≤7 days)',
                    activeCount.toString(),
                    const Color(0xFF4CAF50),
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Moderate (8-30 days)',
                    moderateCount.toString(),
                    const Color(0xFFFF9800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Need Attention',
                    attentionCount.toString(),
                    const Color(0xFFFF5722),
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Critical (>60 days)',
                    criticalCount.toString(),
                    const Color(0xFFF44336),
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
              fontSize: 24,
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

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'all', 'label': 'All Locations', 'color': Colors.grey},
      {
        'key': 'critical',
        'label': 'Critical',
        'color': const Color(0xFFF44336),
      },
      {
        'key': 'attention',
        'label': 'Attention',
        'color': const Color(0xFFFF5722),
      },
      {
        'key': 'moderate',
        'label': 'Moderate',
        'color': const Color(0xFFFF9800),
      },
      {'key': 'active', 'label': 'Active', 'color': const Color(0xFF4CAF50)},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter['key'];

          return FilterChip(
            label: Text(
              filter['label'] as String,
              style: TextStyle(
                color: isSelected ? Colors.white : filter['color'] as Color,
                fontWeight: FontWeight.w500,
              ),
            ),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                _selectedFilter = filter['key'] as String;
              });
            },
            backgroundColor: (filter['color'] as Color).withOpacity(0.1),
            selectedColor: filter['color'] as Color,
            side: BorderSide(
              color: (filter['color'] as Color).withOpacity(0.3),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLocationTable() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.table_chart, color: _whitbyBlue, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Location Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _whitbyBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                headingRowColor: WidgetStateProperty.all(_whitbyBlue.withOpacity(0.1)),
                columns: const [
                  DataColumn(
                    label: Text(
                      'Location',
                      style: TextStyle(fontWeight: FontWeight.w600, color: _whitbyBlue),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Status',
                      style: TextStyle(fontWeight: FontWeight.w600, color: _whitbyBlue),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Days Since',
                      style: TextStyle(fontWeight: FontWeight.w600, color: _whitbyBlue),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Last Work',
                      style: TextStyle(fontWeight: FontWeight.w600, color: _whitbyBlue),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Recent Hours',
                      style: TextStyle(fontWeight: FontWeight.w600, color: _whitbyBlue),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Total Entries',
                      style: TextStyle(fontWeight: FontWeight.w600, color: _whitbyBlue),
                    ),
                  ),
                ],
                rows: _filteredData.map<DataRow>((location) {
                  final daysSince = location['daysSinceLastWork'] as int;
                  final lastWorkDate = location['lastWorkDate'] as DateTime?;
                  final lastWorkType = location['lastWorkType'] as String;
                  final recentHours = location['recentHours'] as double;
                  final totalEntries = location['totalWorkEntries'] as int;
                  final status = location['status'] as String;
                  final statusColor = location['statusColor'] as Color;

                  return DataRow(
                    cells: [
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              location['name'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _whitbyBlue,
                              ),
                            ),
                            if (location['address'].toString().isNotEmpty)
                              Text(
                                location['address'] as String,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          '$daysSince days',
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (lastWorkDate != null)
                              Text(
                                _dateFormat.format(lastWorkDate),
                                style: const TextStyle(fontSize: 12),
                              ),
                            if (lastWorkType.isNotEmpty)
                              Text(
                                lastWorkType,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      DataCell(
                        Text(
                          '${recentHours.toStringAsFixed(1)}h',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      DataCell(
                        Text(
                          totalEntries.toString(),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(Map<String, dynamic> location) {
    final daysSince = location['daysSinceLastWork'] as int;
    final lastWorkDate = location['lastWorkDate'] as DateTime?;
    final lastWorkType = location['lastWorkType'] as String;
    final recentHours = location['recentHours'] as double;
    final totalEntries = location['totalWorkEntries'] as int;
    final status = location['status'] as String;
    final nextAction = location['nextAction'] as String;
    final statusColor = location['statusColor'] as Color;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to location details
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location['name'] as String,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _whitbyBlue,
                          ),
                        ),
                        if (location['address'].toString().isNotEmpty)
                          Text(
                            location['address'] as String,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Last Work: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            lastWorkDate != null
                                ? '${_dateFormat.format(lastWorkDate)} ($daysSince days ago)'
                                : 'No work recorded',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                    if (lastWorkType.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.work, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Last Type: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          Expanded(
                            child: Text(
                              lastWorkType,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Recent Hours: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${recentHours.toStringAsFixed(1)}h (30 days)',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.list_alt, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Total Entries: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            totalEntries.toString(),
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Next action
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: statusColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recommended Action',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            nextAction,
                            style: TextStyle(
                              color: statusColor.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageWithBottomNav(
      title: 'Location Status',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadLocationData,
          tooltip: 'Refresh Data',
        ),
      ],
      child: Container(
        color: const Color(0xFFF8F9FA),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _locationData.isEmpty
            ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No location data available',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
            : Column(
              children: [
                _buildStatsCard(),
                const SizedBox(height: 8),
                _buildFilterChips(),
                const SizedBox(height: 16),
                Expanded(
                  child:
                      _filteredData.isEmpty
                          ? Center(
                            child: Text(
                              'No locations match the selected filter',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          )
                          : SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: _buildLocationTable(),
                          ),
                ),
              ],
            ),
      ),
    );
  }
}
