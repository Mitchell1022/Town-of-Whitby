import 'package:flutter/material.dart';

class AddLocation extends StatelessWidget {
  const AddLocation({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Location'),
        leading: BackButton(), // Optional: Flutter auto adds it when possible
      ),
      body: const Center(child: Text('Add Location Form Here')),
    );
  }
}
