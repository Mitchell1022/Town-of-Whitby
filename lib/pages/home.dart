import 'package:flutter/material.dart';
import 'package:town_of_whitby/pages/log_work.dart';
import 'add_work_type.dart';
import 'view_logs.dart';
import 'add_location.dart';
import 'reports.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enlarged Whitby logo
          Image.asset('assets/whitby_logo.png', height: 72),

          const SizedBox(height: 16),
          // Larger greeting text
          const Text(
            'Welcome back!',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.work),
            label: const Text('Add Work Entry'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LogWork()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            'Quick Actions',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // ── First row of quick actions ─────────────────────────────
          Row(
            children: [
              Expanded(
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.list),
                    title: const Text('View Logs'),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ViewLogs()),
                        ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on),
                    title: const Text('Add Location'),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddLocation(),
                          ),
                        ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Second row of quick actions ────────────────────────────
          Row(
            children: [
              Expanded(
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.bar_chart),
                    title: const Text('View Reports'),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const Reports()),
                        ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.assignment_add),
                    title: const Text('Add Work Type'),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddWorkType(),
                          ),
                        ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
