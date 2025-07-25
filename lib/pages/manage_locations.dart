// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/custom_button.dart';
import '../widgets/global_navigation_wrapper.dart';

class ManageLocations extends StatefulWidget {
  const ManageLocations({super.key});

  @override
  State<ManageLocations> createState() => _ManageLocationsState();
}

class _ManageLocationsState extends State<ManageLocations> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  bool _isAdding = false;
  String? _editingLocationId;

  List<Map<String, dynamic>> _locations = [];

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('locations')
          .orderBy('name')
          .get();

      if (mounted) {
        setState(() {
          _locations = snapshot.docs.map((doc) {
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
            content: Text('Error loading locations: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveLocation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> locationData = {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'description': _descriptionController.text.trim(),
      };

      if (_editingLocationId == null) {
        // Adding new location
        locationData['createdAt'] = Timestamp.now();
        await FirebaseFirestore.instance.collection('locations').add(locationData);
      } else {
        // Updating existing location
        locationData['updatedAt'] = Timestamp.now();
        await FirebaseFirestore.instance
            .collection('locations')
            .doc(_editingLocationId)
            .update(locationData);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editingLocationId == null 
              ? 'Location added successfully!' 
              : 'Location updated successfully!'),
          backgroundColor: const Color(0xFF003366),
        ),
      );

      _clearForm();
      _loadLocations();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteLocation(String locationId, String locationName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Location'),
        content: Text(
          'Are you sure you want to delete "$locationName"? This action cannot be undone.',
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
            .collection('locations')
            .doc(locationId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          _loadLocations();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting location: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _editLocation(Map<String, dynamic> location) {
    setState(() {
      _editingLocationId = location['id'];
      _nameController.text = location['name'] ?? '';
      _addressController.text = location['address'] ?? '';
      _descriptionController.text = location['description'] ?? '';
      _isAdding = true;
    });
  }

  void _clearForm() {
    _nameController.clear();
    _addressController.clear();
    _descriptionController.clear();
    setState(() {
      _editingLocationId = null;
      _isAdding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageWithBottomNav(
      title: 'Manage Locations',
      actions: [
        if (!_isAdding)
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => setState(() => _isAdding = true),
            tooltip: 'Add Location',
          ),
      ],
      child: Container(
        color: const Color(0xFFF8F9FA),
        child: _isLoading && _locations.isEmpty
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
                    child: _buildLocationsList(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildLocationsList() {
    if (_locations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No locations found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Add your first location to get started',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _locations.length,
      itemBuilder: (context, index) {
        final location = _locations[index];
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
                Icons.location_on,
                color: Color(0xFF003366),
                size: 20,
              ),
            ),
            title: Text(
              location['name'] ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF003366),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (location['address']?.toString().isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    location['address'],
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
                if (location['description']?.toString().isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    location['description'],
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFF0066CC)),
                  onPressed: () => _editLocation(location),
                  tooltip: 'Edit location',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteLocation(location['id'], location['name']),
                  tooltip: 'Delete location',
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
                    Icons.location_on,
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
                        _editingLocationId == null ? 'Add New Location' : 'Edit Location',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF003366),
                        ),
                      ),
                      Text(
                        _editingLocationId == null 
                            ? 'Add a new work location' 
                            : 'Update location details',
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
                labelText: 'Location Name *',
                hintText: 'e.g., Main Office, Civic Centre',
                prefixIcon: Icon(Icons.business),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Location name is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: 'Street address of the location',
                prefixIcon: Icon(Icons.map),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Additional details about this location',
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
                    text: _editingLocationId == null ? 'Add Location' : 'Update Location',
                    icon: _editingLocationId == null ? Icons.add_location : Icons.update,
                    variant: ButtonVariant.primary,
                    isLoading: _isLoading,
                    onPressed: _saveLocation,
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
