// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../services/database_service.dart';
import 'manage_locations.dart';
import 'manage_work_categories.dart';

/// Whitby brand colours
const _whitbyBlue = Color(0xFF003366);
const _textColour = Colors.black87;

class LogWork extends StatefulWidget {
  const LogWork({super.key});

  @override
  State<LogWork> createState() => _LogWorkState();
}

class _LogWorkState extends State<LogWork> {
  String? _selectedLocation;
  String? _selectedWorkType;
  String? _otherWorkTypeDescription;
  List<String> _selectedWorkers = [];

  DateTime? _workDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final List<XFile> _images = [];
  final _summaryController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _workTypes = [];
  List<Map<String, dynamic>> _workers = [];
  bool _isLoadingData = true;
  final DateFormat _dateFormatter = DateFormat('MMMM d, yyyy');
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      await DatabaseService.initializeDefaultData();
      final locations = await DatabaseService.getLocations();
      final workTypes = await DatabaseService.getWorkTypes();
      final workers = await DatabaseService.getWorkers();

      if (mounted) {
        setState(() {
          _locations = locations;
          _workTypes = workTypes;
          _workers = workers.where((w) => w['isActive'] == true).toList();
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  Future<void> _navigateToManageLocations() async {
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ManageLocations()),
    );
    if (result != null && mounted) {
      _loadData();
    }
  }

  Future<void> _navigateToManageWorkCategories() async {
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ManageWorkCategories()),
    );
    if (result != null && mounted) {
      _loadData();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers
  Duration? get _workDuration {
    if (_startTime == null || _endTime == null) return null;
    final start = DateTime(0, 0, 0, _startTime!.hour, _startTime!.minute);
    final end = DateTime(0, 0, 0, _endTime!.hour, _endTime!.minute);
    return end.difference(start).isNegative ? null : end.difference(start);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _workDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _workDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          isStart
              ? (_startTime ?? TimeOfDay.now())
              : (_endTime ?? TimeOfDay.now()),
    );
    if (picked != null) {
      setState(() => isStart ? _startTime = picked : _endTime = picked);
    }
  }

  Future<void> _pickImagesFromGallery() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isNotEmpty) setState(() => _images.addAll(picked));
  }

  Future<void> _takePhotoWithCamera() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.camera);
    if (photo != null) setState(() => _images.add(photo));
  }

  void _removeImage(int index) => setState(() => _images.removeAt(index));

  Widget _buildWorkerPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Column(
            children: [
              // Selected workers display
              if (_selectedWorkers.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        _selectedWorkers.map((workerId) {
                          final worker = _workers.firstWhere(
                            (w) => w['id'] == workerId,
                            orElse: () => {'name': 'Unknown Worker'},
                          );
                          return Chip(
                            label: Text(worker['name']),
                            onDeleted: () {
                              setState(() {
                                _selectedWorkers.remove(workerId);
                              });
                            },
                            // ignore: deprecated_member_use
                            backgroundColor: _whitbyBlue.withOpacity(0.1),
                            deleteIconColor: _whitbyBlue,
                          );
                        }).toList(),
                  ),
                ),
                Divider(height: 1, color: Colors.grey[300]),
              ],

              // Add worker button/dropdown
              ListTile(
                leading: Icon(Icons.add, color: _whitbyBlue),
                title: Text(
                  _selectedWorkers.isEmpty
                      ? 'Select Workers'
                      : 'Add More Workers',
                  style: TextStyle(color: _whitbyBlue),
                ),
                onTap: _showWorkerPicker,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showWorkerPicker() async {
    final availableWorkers =
        _workers.where((worker) {
          return !_selectedWorkers.contains(worker['id']);
        }).toList();

    if (availableWorkers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All workers are already selected')),
      );
      return;
    }

    final selected = await showDialog<List<String>>(
      context: context,
      builder:
          (context) => WorkerPickerDialog(
            availableWorkers: availableWorkers,
            selectedWorkers: _selectedWorkers,
          ),
    );

    if (selected != null) {
      setState(() {
        _selectedWorkers = selected;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Upload images to Firebase Storage
  Future<List<String>> _uploadImages() async {
    final storage = FirebaseStorage.instance;
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    final urls = <String>[];

    for (final img in _images) {
      final file = File(img.path);
      if (!file.existsSync() || file.lengthSync() == 0) continue;

      final ref = storage.ref().child('log_photos/${_uuid.v4()}.jpg');
      final snapshot = await ref.putFile(file, metadata).whenComplete(() {});
      if (snapshot.state == TaskState.success) {
        urls.add(await ref.getDownloadURL());
      }
    }
    return urls;
  }

  // ─────────────────────────────────────────────────────────────
  Future<void> _submitForm() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Confirm Submission'),
            content: const Text(
              'Are you sure you want to submit this work log?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text(
                  'Submit',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: _whitbyBlue),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
    );
    if (confirm != true) return;

    if (!mounted) return;
    final currentContext = context;

    try {
      final duration = _workDuration?.inMinutes ?? 0;
      final photoUrls = await _uploadImages();

      final startTimeText =
          _startTime != null
              ? TimeOfDay(
                hour: _startTime!.hour,
                minute: _startTime!.minute,
              ).format(currentContext)
              : null;
      final endTimeText =
          _endTime != null
              ? TimeOfDay(
                hour: _endTime!.hour,
                minute: _endTime!.minute,
              ).format(currentContext)
              : null;

      await FirebaseFirestore.instance.collection('logs').add({
        'location': _selectedLocation,
        'workType':
            _selectedWorkType == 'Other'
                ? _otherWorkTypeDescription
                : _selectedWorkType,
        'summary':
            _summaryController.text.trim().isNotEmpty
                ? _summaryController.text.trim()
                : _selectedWorkType,
        'description': _descriptionController.text.trim(),
        'workers': _selectedWorkers,
        'workDate': _workDate != null ? Timestamp.fromDate(_workDate!) : null,
        'startTime': startTimeText,
        'endTime': endTimeText,
        'durationMinutes': duration,
        'photos': photoUrls,
        'createdAt': Timestamp.now(),
      });

      if (!mounted) return;
      Navigator.popUntil(currentContext, (route) => route.isFirst);
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(content: Text('Work log submitted successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        currentContext,
      ).showSnackBar(SnackBar(content: Text('Error saving log: $e')));
    }
  }

  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme.apply(bodyColor: _textColour);

    InputDecoration inputDecoration(String label) => InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: _textColour),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );

    OutlinedButton timeButton(String label, VoidCallback onPressed) =>
        OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _textColour,
            side: const BorderSide(color: _whitbyBlue),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _whitbyBlue,
        foregroundColor: Colors.white,
        title: const Text('Log Work'),
        leading: const BackButton(),
      ),
      body: Theme(
        data: Theme.of(context).copyWith(textTheme: textTheme),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Location & Work-type ────────────────────────────────
              const _SectionHeader(icon: Icons.place, title: 'Location & Type'),
              const SizedBox(height: 8),
              _isLoadingData
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedLocation,
                        decoration: inputDecoration('Location'),
                        items: [
                          ..._locations.map(
                            (loc) => DropdownMenuItem(
                              value: loc['name'],
                              child: Text(loc['name']),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: '__add_new__',
                            child: Row(
                              children: [
                                Icon(Icons.add, size: 20),
                                SizedBox(width: 8),
                                Text('Add New Location'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == '__add_new__') {
                            _navigateToManageLocations();
                          } else {
                            setState(() => _selectedLocation = v);
                          }
                        },
                      ),
                    ],
                  ),
              const SizedBox(height: 16),
              _isLoadingData
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedWorkType,
                        decoration: inputDecoration('Work Type'),
                        items: [
                          ..._workTypes.map(
                            (workType) => DropdownMenuItem(
                              value: workType['name'],
                              child: Text(workType['name']),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: 'Other',
                            child: Text('Other'),
                          ),
                          const DropdownMenuItem(
                            value: '__add_new__',
                            child: Row(
                              children: [
                                Icon(Icons.add, size: 20),
                                SizedBox(width: 8),
                                Text('Add New Work Type'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == '__add_new__') {
                            _navigateToManageWorkCategories();
                          } else {
                            setState(() {
                              _selectedWorkType = v;
                              if (v != 'Other') {
                                _otherWorkTypeDescription = null;
                              }
                            });
                          }
                        },
                      ),
                    ],
                  ),
              if (_selectedWorkType == 'Other') ...[
                const SizedBox(height: 16),
                TextFormField(
                  decoration: inputDecoration('Please describe the work'),
                  maxLines: null,
                  onChanged: (v) => _otherWorkTypeDescription = v,
                ),
              ],

              // ── Date & Time ────────────────────────────────────────
              const SizedBox(height: 24),
              const _SectionHeader(
                icon: Icons.access_time,
                title: 'Date & Time',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: timeButton(
                      _workDate == null
                          ? 'Select Date'
                          : _dateFormatter.format(_workDate!),
                      _pickDate,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: timeButton(
                      _startTime == null
                          ? 'Start Time'
                          : _startTime!.format(context),
                      () => _pickTime(true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: timeButton(
                      _endTime == null ? 'End Time' : _endTime!.format(context),
                      () => _pickTime(false),
                    ),
                  ),
                ],
              ),
              if (_workDuration != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Duration: ${_workDuration!.inHours}h '
                    '${_workDuration!.inMinutes.remainder(60)}m',
                    style: const TextStyle(color: _textColour),
                  ),
                ),

              // ── Workers ────────────────────────────────────────────
              const SizedBox(height: 24),
              const _SectionHeader(icon: Icons.groups, title: 'Workers'),
              const SizedBox(height: 8),
              _buildWorkerPicker(),

              // ── Work Details ──────────────────────────────────────
              const SizedBox(height: 24),
              const _SectionHeader(
                icon: Icons.description,
                title: 'Work Details',
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _summaryController,
                decoration: inputDecoration(
                  'Work Summary *',
                ).copyWith(hintText: 'Brief description of work completed'),
                maxLength: 100,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: inputDecoration(
                  'Additional Details (Optional)',
                ).copyWith(
                  hintText: 'Detailed description, notes, or observations',
                ),
                maxLines: 3,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
              ),

              // ── Photos ────────────────────────────────────────────
              const SizedBox(height: 24),
              const _SectionHeader(icon: Icons.photo_camera, title: 'Photos'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickImagesFromGallery,
                      icon: const Icon(
                        Icons.photo_library,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Add Photos',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _whitbyBlue,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _takePhotoWithCamera,
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      label: const Text(
                        'Take Photo',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _whitbyBlue,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                ],
              ),
              if (_images.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(_images.length, (i) {
                    return Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_images[i].path),
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _removeImage(i),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            margin: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],

              // ── Submit ────────────────────────────────────────────
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _submitForm,
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text(
                  'Submit',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _whitbyBlue,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// UI helpers
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _whitbyBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium!.copyWith(
            color: _textColour,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Expanded(child: Divider(thickness: 1, indent: 12)),
      ],
    );
  }
}

class WorkerPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> availableWorkers;
  final List<String> selectedWorkers;

  const WorkerPickerDialog({
    super.key,
    required this.availableWorkers,
    required this.selectedWorkers,
  });

  @override
  State<WorkerPickerDialog> createState() => _WorkerPickerDialogState();
}

class _WorkerPickerDialogState extends State<WorkerPickerDialog> {
  late List<String> _tempSelected;

  @override
  void initState() {
    super.initState();
    _tempSelected = List.from(widget.selectedWorkers);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Workers'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.availableWorkers.isEmpty)
              const Text('No workers available to select')
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.availableWorkers.length,
                  itemBuilder: (context, index) {
                    final worker = widget.availableWorkers[index];
                    final workerId = worker['id'] as String;
                    final isSelected = _tempSelected.contains(workerId);

                    return CheckboxListTile(
                      title: Text(worker['name'] ?? 'Unknown'),
                      subtitle:
                          worker['role']?.toString().isNotEmpty == true
                              ? Text(worker['role'])
                              : null,
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _tempSelected.add(workerId);
                          } else {
                            _tempSelected.remove(workerId);
                          }
                        });
                      },
                      activeColor: _whitbyBlue,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _tempSelected),
          style: ElevatedButton.styleFrom(backgroundColor: _whitbyBlue),
          child: const Text('Done', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
