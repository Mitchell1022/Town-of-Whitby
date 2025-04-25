import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Whitby brand palette
const _whitbyBlue = Color(0xFF003366);
const _textColour = Colors.black87;

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

  final _locations = ['Main Office', 'Civic Centre', 'Depot'];
  final _workTypes = ['Planted', 'Weeded', 'Cleaned Up', 'Other'];

  final DateFormat _dayFmt = DateFormat.EEEE(); // e.g. Monday
  final DateFormat _dateFmt = DateFormat.yMMMd(); // Apr 24, 2025
  final DateFormat _timeFmt = DateFormat.jm(); // 1:30 PM

  final CollectionReference<Map<String, dynamic>> _logsRef = FirebaseFirestore
      .instance
      .collection('logs');

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
          .where('workDate', isGreaterThanOrEqualTo: _dateRange!.start)
          .where('workDate', isLessThanOrEqualTo: _dateRange!.end);
    }
    return query.orderBy('workDate', descending: true).snapshots();
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
  });

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
          Material(
            elevation: 2,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  // Location filter
                  Expanded(
                    child: DropdownButton<String>(
                      value: _locFilter,
                      hint: const Text('Location'),
                      isExpanded: true,
                      onChanged: (v) => setState(() => _locFilter = v),
                      items:
                          [null, ..._locations].map((loc) {
                            return DropdownMenuItem(
                              value: loc,
                              child: Text(loc ?? 'All'),
                            );
                          }).toList(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Work‑type filter
                  Expanded(
                    child: DropdownButton<String>(
                      value: _typeFilter,
                      hint: const Text('Work Type'),
                      isExpanded: true,
                      onChanged: (v) => setState(() => _typeFilter = v),
                      items:
                          [null, ..._workTypes].map((t) {
                            return DropdownMenuItem(
                              value: t,
                              child: Text(t ?? 'All'),
                            );
                          }).toList(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Date range',
                    icon: const Icon(Icons.date_range, color: _whitbyBlue),
                    onPressed: _pickDateRange,
                  ),
                  IconButton(
                    tooltip: 'Clear filters',
                    icon: const Icon(Icons.filter_alt_off, color: _whitbyBlue),
                    onPressed: _resetFilters,
                  ),
                ],
              ),
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
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No logs match the filters.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(8),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data();
                    final date = (data['workDate'] as Timestamp?)?.toDate();
                    final start = data['startTime'] ?? '';
                    final end = data['endTime'] ?? '';

                    // First photo (if any)
                    final List photos = data['photos'] ?? [];
                    final thumbUrl = photos.isNotEmpty ? photos.first : null;

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: InkWell(
                        onTap: () {
                          /* TODO: detail view */
                        },
                        child: Row(
                          children: [
                            if (thumbUrl != null)
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  bottomLeft: Radius.circular(8),
                                ),
                                child: Image.network(
                                  thumbUrl,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else
                              Container(
                                width: 100,
                                height: 100,
                                decoration: const BoxDecoration(
                                  color: Colors.grey,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    bottomLeft: Radius.circular(8),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.white70,
                                ),
                              ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['workType'] ?? 'Unknown Work',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: _textColour,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      data['location'] ?? 'Unknown location',
                                      style: const TextStyle(
                                        color: _textColour,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.today,
                                          size: 16,
                                          color: _whitbyBlue,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          date != null
                                              ? '${_dayFmt.format(date)}, ${_dateFmt.format(date)}'
                                              : 'No date',
                                          style: const TextStyle(
                                            color: _textColour,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.schedule,
                                          size: 16,
                                          color: _whitbyBlue,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$start  •  $end',
                                          style: const TextStyle(
                                            color: _textColour,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
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
