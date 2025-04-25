import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _whitbyBlue = Color(0xFF003366);
const _textColour = Colors.black87;

class Reports extends StatefulWidget {
  const Reports({super.key});

  @override
  State<Reports> createState() => _ReportsState();
}

class _ReportsState extends State<Reports> {
  late Future<_ReportData> _reportFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = _loadReport();
  }

  Future<_ReportData> _loadReport() async {
    final logsSnap = await FirebaseFirestore.instance.collection('logs').get();
    final Map<String, double> hoursByLocation = {};
    final Map<String, int> workTypeCount = {};
    double totalHours = 0;

    for (var doc in logsSnap.docs) {
      final data = doc.data();
      final loc = (data['location'] ?? 'Unknown') as String;
      final mins = (data['durationMinutes'] ?? 0) as int;
      final workType = (data['workType'] ?? 'Unknown') as String;

      hoursByLocation.update(
        loc,
        (v) => v + mins / 60,
        ifAbsent: () => mins / 60,
      );
      workTypeCount.update(workType, (v) => v + 1, ifAbsent: () => 1);
      totalHours += mins / 60;
    }
    return _ReportData(
      hoursByLocation: hoursByLocation,
      workTypeCount: workTypeCount,
      totalHours: totalHours,
      logCount: logsSnap.size,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _whitbyBlue,
        foregroundColor: Colors.white,
        title: const Text('Reports'),
      ),
      body: FutureBuilder<_ReportData>(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statTile(
                  'Total Hours Logged',
                  report.totalHours.toStringAsFixed(1),
                ),
                _statTile('Total Entries', report.logCount.toString()),
                const SizedBox(height: 24),
                Text(
                  'Hours by Location',
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _textColour,
                  ),
                ),
                const SizedBox(height: 8),
                ...report.hoursByLocation.entries.map(
                  (e) => ListTile(
                    leading: Icon(Icons.place, color: _whitbyBlue),
                    title: Text(e.key),
                    trailing: Text('${e.value.toStringAsFixed(1)} h'),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Entries by Work Type',
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _textColour,
                  ),
                ),
                const SizedBox(height: 8),
                ...report.workTypeCount.entries.map(
                  (e) => ListTile(
                    leading: Icon(Icons.work, color: _whitbyBlue),
                    title: Text(e.key),
                    trailing: Text(e.value.toString()),
                  ),
                ),
              ],
            ),
          );
        },
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
  final double totalHours;
  final int logCount;

  _ReportData({
    required this.hoursByLocation,
    required this.workTypeCount,
    required this.totalHours,
    required this.logCount,
  });
}
