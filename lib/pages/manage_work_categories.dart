// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/custom_button.dart';
import '../widgets/global_navigation_wrapper.dart';

class ManageWorkCategories extends StatefulWidget {
  const ManageWorkCategories({super.key});

  @override
  State<ManageWorkCategories> createState() => _ManageWorkCategoriesState();
}

class _ManageWorkCategoriesState extends State<ManageWorkCategories> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  bool _isAdding = false;
  String? _editingWorkTypeId;

  List<Map<String, dynamic>> _workTypes = [];

  @override
  void initState() {
    super.initState();
    _loadWorkTypes();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkTypes() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('work_types')
          .orderBy('name')
          .get();

      if (mounted) {
        setState(() {
          _workTypes = snapshot.docs.map((doc) {
            return {
              'id': doc.id,
              ...doc.data(),
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading work categories: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveWorkType() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> workTypeData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
      };

      if (_editingWorkTypeId == null) {
        // Adding new work type
        workTypeData['createdAt'] = Timestamp.now();
        await FirebaseFirestore.instance.collection('work_types').add(workTypeData);
      } else {
        // Updating existing work type
        workTypeData['updatedAt'] = Timestamp.now();
        await FirebaseFirestore.instance
            .collection('work_types')
            .doc(_editingWorkTypeId)
            .update(workTypeData);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editingWorkTypeId == null 
              ? 'Work category added successfully!' 
              : 'Work category updated successfully!'),
          backgroundColor: const Color(0xFF003366),
        ),
      );

      _clearForm();
      _loadWorkTypes();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving work category: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteWorkType(String workTypeId, String workTypeName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Work Category'),
        content: Text(
          'Are you sure you want to delete "$workTypeName"? This action cannot be undone.',
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
            .collection('work_types')
            .doc(workTypeId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Work category deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          _loadWorkTypes();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting work category: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _editWorkType(Map<String, dynamic> workType) {
    setState(() {
      _editingWorkTypeId = workType['id'];
      _nameController.text = workType['name'] ?? '';
      _descriptionController.text = workType['description'] ?? '';
      _isAdding = true;
    });
  }

  void _clearForm() {
    _nameController.clear();
    _descriptionController.clear();
    setState(() {
      _editingWorkTypeId = null;
      _isAdding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageWithBottomNav(
      title: 'Manage Work Categories',
      actions: [
        if (!_isAdding)
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => setState(() => _isAdding = true),
            tooltip: 'Add Category',
          ),
      ],
      child: Container(
        color: const Color(0xFFF8F9FA),
        child: _isLoading && _workTypes.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_isAdding) ...[
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildAddForm(),
                    ),
                  ],
                  Expanded(
                    child: _buildWorkTypesList(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildWorkTypesList() {
    if (_workTypes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No work categories found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Add your first work category to get started',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _workTypes.length,
      itemBuilder: (context, index) {
        final workType = _workTypes[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF003366).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.work,
                color: Color(0xFF003366),
                size: 20,
              ),
            ),
            title: Text(
              workType['name'] ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF003366),
              ),
            ),
            subtitle: workType['description']?.toString().isNotEmpty == true
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      workType['description'],
                      style: TextStyle(color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFF0066CC)),
                  onPressed: () => _editWorkType(workType),
                  tooltip: 'Edit category',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteWorkType(workType['id'], workType['name']),
                  tooltip: 'Delete category',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddForm() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF003366).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.work,
                    color: Color(0xFF003366),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _editingWorkTypeId == null ? 'Add New Work Category' : 'Edit Work Category',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF003366),
                        ),
                      ),
                      Text(
                        _editingWorkTypeId == null 
                            ? 'Add a new type of work' 
                            : 'Update category details',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _clearForm,
                ),
              ],
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Category Name *',
                hintText: 'e.g., Landscaping, Snow Removal',
                prefixIcon: Icon(Icons.work_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Category name is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Additional details about this work category',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Cancel',
                    variant: ButtonVariant.outline,
                    onPressed: _isLoading ? null : _clearForm,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: CustomButton(
                    text: _editingWorkTypeId == null ? 'Add Category' : 'Update Category',
                    icon: _editingWorkTypeId == null ? Icons.add : Icons.update,
                    variant: ButtonVariant.primary,
                    isLoading: _isLoading,
                    onPressed: _saveWorkType,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
