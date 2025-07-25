import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/global_navigation_wrapper.dart';
import '../services/database_service.dart';
import 'edit_log.dart';

const _whitbyBlue = Color(0xFF003366);

class LogDetail extends StatefulWidget {
  final Map<String, dynamic> logData;
  final String logId;

  const LogDetail({super.key, required this.logData, required this.logId});

  @override
  State<LogDetail> createState() => _LogDetailState();
}

class _LogDetailState extends State<LogDetail> {
  Map<String, String> _workerNames = {};
  bool _isLoadingWorkers = true;

  @override
  void initState() {
    super.initState();
    _loadWorkerNames();
  }

  Future<void> _loadWorkerNames() async {
    try {
      final workers = await DatabaseService.getWorkers();
      final workerNameMap = <String, String>{};
      for (final worker in workers) {
        workerNameMap[worker['id']] = worker['name'] ?? 'Unknown Worker';
      }
      
      if (mounted) {
        setState(() {
          _workerNames = workerNameMap;
          _isLoadingWorkers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingWorkers = false);
      }
    }
  }

  Future<void> _editLog() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditLog(
            logData: widget.logData,
            logId: widget.logId,
          ),
        ),
      );
      
      // If result is true, the log was updated, so we should refresh or go back
      if (result == true && mounted) {
        Navigator.pop(context, true); // Return true to indicate the log was updated
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening edit page: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteLog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Work Log'),
        content: const Text(
          'Are you sure you want to delete this work log? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('logs')
            .doc(widget.logId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Work log deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return true to indicate deletion
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting work log: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final DateFormat timeFormat = DateFormat.jm();

    // Fix potential timestamp conversion issues
    DateTime? workDate;
    try {
      if (widget.logData['workDate'] is Timestamp) {
        workDate = (widget.logData['workDate'] as Timestamp).toDate();
      } else if (widget.logData['workDate'] is DateTime) {
        workDate = widget.logData['workDate'] as DateTime;
      }
    } catch (e) {
      print('Error parsing work date: $e');
    }

    final startTime = widget.logData['startTime'] as String? ?? '';
    final endTime = widget.logData['endTime'] as String? ?? '';
    final duration = widget.logData['durationMinutes'] as int? ?? 0;
    final photos = widget.logData['photos'] as List? ?? [];
    final workers = widget.logData['workers'] as List? ?? [];
    final summary = widget.logData['summary'] as String? ?? '';
    final workType = widget.logData['workType'] as String? ?? '';
    final location = widget.logData['location'] as String? ?? '';
    final description = widget.logData['description'] as String? ?? '';

    return PageWithBottomNav(
      title: 'Work Log Details',
      actions: [
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.white),
          onPressed: _editLog,
          tooltip: 'Edit Log',
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.white),
          onPressed: _deleteLog,
          tooltip: 'Delete Log',
          ),
        ],
      child: Container(
        color: const Color(0xFFF8F9FA),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Header Card
            Card(
              elevation: 3,
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
                            // ignore: deprecated_member_use
                            color: _whitbyBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.work_outline,
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
                                summary.isNotEmpty ? summary : workType,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: _whitbyBlue,
                                ),
                              ),
                              if (workType.isNotEmpty && summary.isNotEmpty)
                                Text(
                                  'Type: $workType',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        // ignore: deprecated_member_use
                        color: _whitbyBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: _whitbyBlue,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            location,
                            style: const TextStyle(
                              color: _whitbyBlue,
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Date & Time Card
            Card(
              elevation: 2,
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
                        const Icon(
                          Icons.schedule,
                          color: _whitbyBlue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Date & Time',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _whitbyBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoItem(
                            'Date',
                            workDate != null
                                ? dateFormat.format(workDate)
                                : 'Not specified',
                            Icons.calendar_today,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoItem(
                            'Start Time',
                            startTime ?? 'Not specified',
                            Icons.play_arrow,
                          ),
                        ),
                        Expanded(
                          child: _buildInfoItem(
                            'End Time',
                            endTime ?? 'Not specified',
                            Icons.stop,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem(
                      'Duration',
                      '${(duration / 60).toStringAsFixed(1)} hours ($duration minutes)',
                      Icons.timer,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Workers Card
            if (workers.isNotEmpty) ...[
              Card(
                elevation: 2,
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
                          const Icon(
                            Icons.people,
                            color: _whitbyBlue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Workers (${workers.length})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: _whitbyBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            _isLoadingWorkers 
                              ? [const Center(child: CircularProgressIndicator())]
                              : workers.map<Widget>((worker) {
                                final workerId = worker.toString();
                                final workerName = _workerNames[workerId] ?? workerId;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    // ignore: deprecated_member_use
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      // ignore: deprecated_member_use
                                      color: Colors.green.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.person,
                                        size: 16,
                                        color: Colors.green,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        workerName,
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Description Card
            if (description.isNotEmpty) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.description, color: _whitbyBlue, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Additional Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: _whitbyBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          // ignore: deprecated_member_use
                          color: Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          description,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Photos Card
            if (photos.isNotEmpty) ...[
              Card(
                elevation: 2,
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
                          const Icon(
                            Icons.photo_library,
                            color: _whitbyBlue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Photos (${photos.length})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: _whitbyBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1,
                            ),
                        itemCount: photos.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () {
                              _showFullScreenImage(context, photos[index]);
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: photos[index],
                                fit: BoxFit.cover,
                                placeholder:
                                    (context, url) => Container(
                                      // ignore: deprecated_member_use
                                      color: _whitbyBlue.withOpacity(0.1),
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                errorWidget:
                                    (context, url, error) => Container(
                                      // ignore: deprecated_member_use
                                      color: Colors.grey.withOpacity(0.1),
                                      child: const Icon(
                                        Icons.broken_image,
                                        color: Colors.grey,
                                        size: 32,
                                      ),
                                    ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              body: Center(
                child: InteractiveViewer(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder:
                        (context, url) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                    errorWidget:
                        (context, url, error) => const Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.white,
                            size: 64,
                          ),
                        ),
                  ),
                ),
              ),
            ),
      ),
    );
  }
}
