// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../widgets/custom_button.dart';

const _whitbyBlue = Color(0xFF003366);

class ManageWorkers extends StatefulWidget {
  const ManageWorkers({super.key});

  @override
  State<ManageWorkers> createState() => _ManageWorkersState();
}

class _ManageWorkersState extends State<ManageWorkers> {
  List<Map<String, dynamic>> _workers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkers() async {
    try {
      final workers = await DatabaseService.getWorkers();
      if (mounted) {
        setState(() {
          _workers = workers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading workers: $e')));
      }
    }
  }

  List<Map<String, dynamic>> get _filteredWorkers {
    if (_searchQuery.isEmpty) return _workers;

    final query = _searchQuery.toLowerCase();
    return _workers.where((worker) {
      final name = (worker['name'] ?? '').toString().toLowerCase();
      final role = (worker['role'] ?? '').toString().toLowerCase();
      final email = (worker['email'] ?? '').toString().toLowerCase();

      return name.contains(query) ||
          role.contains(query) ||
          email.contains(query);
    }).toList();
  }

  Future<void> _showAddWorkerDialog([
    Map<String, dynamic>? existingWorker,
  ]) async {
    final nameController = TextEditingController(
      text: existingWorker?['name'] ?? '',
    );
    final emailController = TextEditingController(
      text: existingWorker?['email'] ?? '',
    );
    final roleController = TextEditingController(
      text: existingWorker?['role'] ?? '',
    );
    bool isActive = existingWorker?['isActive'] ?? true;
    bool isLoading = false;

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(
                    existingWorker != null ? 'Edit Worker' : 'Add New Worker',
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name *',
                            hintText: 'e.g., John Smith',
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'john.smith@whitby.ca',
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: roleController,
                          decoration: const InputDecoration(
                            labelText: 'Role/Title',
                            hintText: 'e.g., Maintenance Supervisor',
                            prefixIcon: Icon(Icons.work),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Active Employee'),
                          subtitle: Text(
                            isActive ? 'Currently working' : 'Inactive',
                          ),
                          value: isActive,
                          onChanged:
                              (value) => setDialogState(() => isActive = value),
                          activeColor: _whitbyBlue,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isLoading
                              ? null
                              : () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed:
                          isLoading
                              ? null
                              : () async {
                                if (nameController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Name is required'),
                                    ),
                                  );
                                  return;
                                }

                                setDialogState(() => isLoading = true);

                                try {
                                  if (existingWorker != null) {
                                    await DatabaseService.updateWorker(
                                      workerId: existingWorker['id'],
                                      name: nameController.text.trim(),
                                      email: emailController.text.trim(),
                                      role: roleController.text.trim(),
                                      isActive: isActive,
                                    );
                                  } else {
                                    await DatabaseService.addWorker(
                                      name: nameController.text.trim(),
                                      email: emailController.text.trim(),
                                      role: roleController.text.trim(),
                                      isActive: isActive,
                                    );
                                  }

                                  if (context.mounted) {
                                    Navigator.pop(context, true);
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                } finally {
                                  setDialogState(() => isLoading = false);
                                }
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _whitbyBlue,
                      ),
                      child:
                          isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(
                                existingWorker != null ? 'Update' : 'Add',
                                style: const TextStyle(color: Colors.white),
                              ),
                    ),
                  ],
                ),
          ),
    );

    nameController.dispose();
    emailController.dispose();
    roleController.dispose();

    if (result == true) {
      _loadWorkers();
    }
  }

  Future<void> _deleteWorker(Map<String, dynamic> worker) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Worker'),
            content: Text('Are you sure you want to delete ${worker['name']}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await DatabaseService.deleteWorker(worker['id']);
        _loadWorkers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${worker['name']} deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting worker: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Manage Workers'),
        backgroundColor: _whitbyBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddWorkerDialog(),
            tooltip: 'Add Worker',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search workers...',
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
                  borderSide: BorderSide(color: _whitbyBlue, width: 2),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Workers list
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredWorkers.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No workers added yet'
                                : 'No workers found',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showAddWorkerDialog(),
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text(
                              'Add First Worker',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _whitbyBlue,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredWorkers.length,
                      itemBuilder: (context, index) {
                        final worker = _filteredWorkers[index];
                        final isActive = worker['isActive'] as bool? ?? true;

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor:
                                  isActive
                                      ? _whitbyBlue.withOpacity(0.1)
                                      : Colors.grey.withOpacity(0.1),
                              child: Icon(
                                Icons.person,
                                color: isActive ? _whitbyBlue : Colors.grey,
                              ),
                            ),
                            title: Text(
                              worker['name'] ?? 'Unknown',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isActive ? null : Colors.grey,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (worker['role']?.toString().isNotEmpty ==
                                    true)
                                  Text(
                                    worker['role'],
                                    style: TextStyle(
                                      color:
                                          isActive
                                              ? Colors.grey[600]
                                              : Colors.grey,
                                    ),
                                  ),
                                if (worker['email']?.toString().isNotEmpty ==
                                    true)
                                  Text(
                                    worker['email'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          isActive
                                              ? Colors.grey[500]
                                              : Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Inactive',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _showAddWorkerDialog(worker);
                                    } else if (value == 'delete') {
                                      _deleteWorker(worker);
                                    }
                                  },
                                  itemBuilder:
                                      (context) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, size: 20),
                                              SizedBox(width: 8),
                                              Text('Edit'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete,
                                                size: 20,
                                                color: Colors.red,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Delete',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton:
          _filteredWorkers.isNotEmpty
              ? FloatingActionButton(
                onPressed: () => _showAddWorkerDialog(),
                backgroundColor: _whitbyBlue,
                foregroundColor: Colors.white,
                child: const Icon(Icons.add),
              )
              : null,
    );
  }
}
