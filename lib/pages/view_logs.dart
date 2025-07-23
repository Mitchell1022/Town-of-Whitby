// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/database_service.dart';
import 'log_detail.dart';

// Whitby brand palette
const _whitbyBlue = Color(0xFF003366);

class ViewLogs extends StatefulWidget {
  const ViewLogs({super.key});

  @override
  State<ViewLogs> createState() => _ViewLogsState();
}

class _ViewLogsState extends State<ViewLogs> {
  // ── Filters ───────────────────────────────────────────────────────────
  String? _locFilter;
  String? _typeFilter;
  DateTimeRange? _dateRange;
  String _searchQuery = '';
  bool _isCompactView = true;

  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _workTypes = [];

  final TextEditingController _searchController = TextEditingController();

  final DateFormat _dayFmt = DateFormat.EEEE(); // e.g. Monday
  final DateFormat _dateFmt = DateFormat.yMMMd(); // Apr 24, 2025
  final DateFormat _timeFmt = DateFormat.jm(); // 1:30 PM

  final CollectionReference<Map<String, dynamic>> _logsRef = FirebaseFirestore
      .instance
      .collection('logs');

  @override
  void initState() {
    super.initState();
    _loadFilterData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFilterData() async {
    try {
      final locations = await DatabaseService.getLocations();
      final workTypes = await DatabaseService.getWorkTypes();

      if (mounted) {
        setState(() {
          _locations = locations;
          _workTypes = workTypes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading filter data: $e')),
        );
      }
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _filteredLogs() {
    var query = _logsRef as Query<Map<String, dynamic>>;
    if (_locFilter != null) {
      query = query.where('location', isEqualTo: _locFilter);
    }
    if (_typeFilter != null) {
      query = query.where('workType', isEqualTo: _typeFilter);
    }
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
    return query.orderBy('createdAt', descending: true).snapshots();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterBySearch(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (_searchQuery.isEmpty) return docs;

    final query = _searchQuery.toLowerCase();
    return docs.where((doc) {
      final data = doc.data();
      final location = (data['location'] ?? '').toString().toLowerCase();
      final workType = (data['workType'] ?? '').toString().toLowerCase();
      final workers = (data['workers'] ?? '').toString().toLowerCase();
      final description = (data['description'] ?? '').toString().toLowerCase();

      return location.contains(query) ||
          workType.contains(query) ||
          workers.contains(query) ||
          description.contains(query);
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  void _resetFilters() => setState(() {
    _locFilter = null;
    _typeFilter = null;
    _dateRange = null;
    _searchQuery = '';
    _searchController.clear();
  });

  Widget _buildLogCard(
    Map<String, dynamic> data,
    bool isCompact,
    String docId,
  ) {
    final date = (data['workDate'] as Timestamp?)?.toDate();
    final start = data['startTime'] ?? '';
    final end = data['endTime'] ?? '';
    final List photos = data['photos'] ?? [];
    final thumbUrl = photos.isNotEmpty ? photos.first : null;
    final duration = data['durationMinutes'] as int? ?? 0;

    if (isCompact) {
      return Card(
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LogDetail(logData: data, logId: docId),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (thumbUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: thumbUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      placeholder:
                          (context, url) => Container(
                            width: 50,
                            height: 50,
                            color: _whitbyBlue.withOpacity(0.1),
                            child: Icon(
                              Icons.image,
                              color: _whitbyBlue.withOpacity(0.3),
                              size: 20,
                            ),
                          ),
                      errorWidget:
                          (context, url, error) => Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey.withOpacity(0.1),
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.grey.withOpacity(0.5),
                              size: 20,
                            ),
                          ),
                    ),
                  )
                else
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _whitbyBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.work_outline,
                      color: _whitbyBlue.withOpacity(0.6),
                      size: 24,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['summary'] ?? data['workType'] ?? 'Unknown Work',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: _whitbyBlue,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data['location'] ?? 'Unknown location',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (date != null)
                      Text(
                        _dateFmt.format(date),
                        style: TextStyle(color: Colors.grey[700], fontSize: 11),
                      ),
                    if (duration > 0)
                      Text(
                        '${(duration / 60).toStringAsFixed(1)}h',
                        style: TextStyle(
                          color: _whitbyBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Expanded view (original design)
    return Card(
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LogDetail(logData: data, logId: docId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
          ),
          child: Row(
            children: [
              if (thumbUrl != null)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: thumbUrl,
                    width: 100,
                    height: 110,
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) => Container(
                          width: 100,
                          height: 110,
                          decoration: BoxDecoration(
                            color: _whitbyBlue.withOpacity(0.1),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                            ),
                          ),
                          child: Icon(
                            Icons.image,
                            color: _whitbyBlue.withOpacity(0.3),
                            size: 32,
                          ),
                        ),
                    errorWidget:
                        (context, url, error) => Container(
                          width: 100,
                          height: 110,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                            ),
                          ),
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.grey.withOpacity(0.5),
                            size: 32,
                          ),
                        ),
                  ),
                )
              else
                Container(
                  width: 100,
                  height: 110,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _whitbyBlue.withOpacity(0.1),
                        _whitbyBlue.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.work_outline,
                    color: _whitbyBlue.withOpacity(0.6),
                    size: 32,
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['summary'] ?? data['workType'] ?? 'Unknown Work',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: _whitbyBlue,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _whitbyBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          data['location'] ?? 'Unknown location',
                          style: TextStyle(
                            color: _whitbyBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              date != null
                                  ? '${_dayFmt.format(date)}, ${_dateFmt.format(date)}'
                                  : 'No date',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$start → $end',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _whitbyBlue,
        foregroundColor: Colors.white,
        title: const Text('View Logs'),
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          // ── Filter bar ──────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.filter_list, color: _whitbyBlue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _whitbyBlue,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    if (_locFilter != null ||
                        _typeFilter != null ||
                        _dateRange != null ||
                        _searchQuery.isNotEmpty)
                      TextButton.icon(
                        onPressed: _resetFilters,
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Clear'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Location filter
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _locFilter,
                            hint: const Text(
                              'Location',
                              style: TextStyle(fontSize: 14),
                            ),
                            isExpanded: true,
                            onChanged: (v) => setState(() => _locFilter = v),
                            items:
                                [
                                  null,
                                  ..._locations.map((l) => l['name'] as String),
                                ].map((loc) {
                                  return DropdownMenuItem<String>(
                                    value: loc,
                                    child: Text(
                                      loc ?? 'All Locations',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Work‑type filter
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _typeFilter,
                            hint: const Text(
                              'Work Type',
                              style: TextStyle(fontSize: 14),
                            ),
                            isExpanded: true,
                            onChanged: (v) => setState(() => _typeFilter = v),
                            items:
                                [
                                  null,
                                  ..._workTypes.map((w) => w['name'] as String),
                                ].map((t) {
                                  return DropdownMenuItem<String>(
                                    value: t,
                                    child: Text(
                                      t ?? 'All Types',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: _whitbyBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        tooltip: 'Date range',
                        icon: Icon(Icons.date_range, color: _whitbyBlue),
                        onPressed: _pickDateRange,
                      ),
                    ),
                  ],
                ),
                if (_dateRange != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _whitbyBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: _whitbyBlue,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_dateFmt.format(_dateRange!.start)} - ${_dateFmt.format(_dateRange!.end)}',
                          style: TextStyle(
                            color: _whitbyBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Search bar
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search logs...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon:
                              _searchQuery.isNotEmpty
                                  ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                  : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
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
                            borderSide: BorderSide(
                              color: _whitbyBlue,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged:
                            (value) => setState(() => _searchQuery = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color:
                            _isCompactView
                                ? _whitbyBlue
                                : _whitbyBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        tooltip:
                            _isCompactView ? 'Expanded view' : 'Compact view',
                        icon: Icon(
                          _isCompactView
                              ? Icons.view_agenda
                              : Icons.view_stream,
                          color: _isCompactView ? Colors.white : _whitbyBlue,
                        ),
                        onPressed:
                            () => setState(
                              () => _isCompactView = !_isCompactView,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Logs list ─────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _filteredLogs(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(child: Text('Error loading logs'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final allDocs = snap.data!.docs;
                final docs = _filterBySearch(allDocs);
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No logs match the filters.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(8),
                  separatorBuilder:
                      (_, __) => SizedBox(height: _isCompactView ? 4 : 8),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data();
                    return _buildLogCard(data, _isCompactView, doc.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
