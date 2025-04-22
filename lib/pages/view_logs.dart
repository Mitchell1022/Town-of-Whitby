import 'package:flutter/material.dart';

class ViewLogs extends StatelessWidget {
  const ViewLogs({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Logs'),
        leading: BackButton(), // Optional: Flutter auto adds it when possible
      ),
      body: const Center(child: Text('Add Method to View Logs')),
    );
  }
}
