import 'package:flutter/material.dart';

class AddWorkType extends StatelessWidget {
  const AddWorkType({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Work Type'),
        leading: BackButton(), // Optional: Flutter auto adds it when possible
      ),
      body: const Center(child: Text('Add Work Type Form Here')),
    );
  }
}
