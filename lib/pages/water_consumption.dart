import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/global_navigation_wrapper.dart';
import '../services/database_service.dart';

const _whitbyBlue = Color(0xFF003366);

class WaterConsumption extends StatefulWidget {
  const WaterConsumption({super.key});

  @override
  State<WaterConsumption> createState() => _WaterConsumptionState();
}

class _WaterConsumptionState extends State<WaterConsumption> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _waterFills = [];
  double _totalLitres = 0;
  double _monthlyTotal = 0;
  int _totalFills = 0;
  double _averagePerFill = 0;
  Map<String, double> _workerTotals = {};
  Map<String, String> _workerNames = {}; // Map worker ID to worker name
  
  final DateFormat _dateFormat = DateFormat.yMMMd();

  @override
  void initState() {
    super.initState();
    _loadWaterConsumptionData();
  }

  Future<void> _loadWaterConsumptionData() async {
    try {
      // Load workers first to get their names
      final workers = await DatabaseService.getWorkers();
      final workerNameMap = <String, String>{};
      for (final worker in workers) {
        workerNameMap[worker['id']] = worker['name'] ?? 'Unknown Worker';
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('water_tank_fills')
          .orderBy('date', descending: true)
          .get();

      if (mounted) {
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        
        double total = 0;
        double monthlySum = 0;
        Map<String, double> workerSums = {};
        List<Map<String, dynamic>> fills = [];

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final timestamp = (data['date'] as Timestamp).toDate();
          final litres = (data['litres'] as num).toDouble();
          final worker = data['worker'] as String;

          fills.add({
            'id': doc.id,
            'date': timestamp,
            'litres': litres,
            'worker': worker,
            'createdAt': data['createdAt'],
          });

          total += litres;

          if (timestamp.isAfter(startOfMonth)) {
            monthlySum += litres;
          }


          workerSums[worker] = (workerSums[worker] ?? 0) + litres;
        }

        setState(() {
          _waterFills = fills;
          _totalLitres = total;
          _monthlyTotal = monthlySum;
          _totalFills = fills.length;
          _averagePerFill = fills.isEmpty ? 0 : total / fills.length;
          _workerTotals = workerSums;
          _workerNames = workerNameMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading water consumption data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStatCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _whitbyBlue,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerChart() {
    if (_workerTotals.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedWorkers = _workerTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxValue = sortedWorkers.first.value;

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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.people, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Water Usage by Worker',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _whitbyBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...sortedWorkers.map((entry) {
              final percentage = maxValue > 0 ? entry.value / maxValue : 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _workerNames[entry.key] ?? entry.key,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${entry.value.toStringAsFixed(0)}L',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage.toDouble(),
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[400]!),
                      minHeight: 8,
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentFills() {
    final recentFills = _waterFills.take(5).toList();

    if (recentFills.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.water_drop_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'No Water Tank Fills Yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start logging water tank fills to see consumption data',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _whitbyBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.history, color: _whitbyBlue, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Recent Tank Fills',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _whitbyBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...recentFills.map((fill) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${(fill['litres'] as double).toStringAsFixed(0)}L',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _whitbyBlue,
                            ),
                          ),
                          Text(
                            _dateFormat.format(fill['date'] as DateTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _workerNames[fill['worker'] as String] ?? (fill['worker'] as String),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageWithBottomNav(
      title: 'Water Consumption',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            setState(() => _isLoading = true);
            _loadWaterConsumptionData();
          },
          tooltip: 'Refresh Data',
        ),
      ],
      child: Container(
        color: const Color(0xFFF8F9FA),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Statistics Cards
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: [
                        _buildStatCard(
                          'Total Consumption',
                          '${_totalLitres.toStringAsFixed(0)}L',
                          'All time total',
                          Icons.water_drop,
                          Colors.blue,
                        ),
                        _buildStatCard(
                          'This Month',
                          '${_monthlyTotal.toStringAsFixed(0)}L',
                          'Current month',
                          Icons.calendar_month,
                          Colors.green,
                        ),
                        _buildStatCard(
                          'Total Fills',
                          _totalFills.toString(),
                          'Tank fill events',
                          Icons.format_list_numbered,
                          Colors.orange,
                        ),
                        _buildStatCard(
                          'Average per Fill',
                          '${_averagePerFill.toStringAsFixed(0)}L',
                          'Per tank fill',
                          Icons.trending_up,
                          Colors.purple,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Worker Chart
                    if (_workerTotals.isNotEmpty) ...[
                      _buildWorkerChart(),
                      const SizedBox(height: 24),
                    ],

                    // Recent Fills
                    _buildRecentFills(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }
}