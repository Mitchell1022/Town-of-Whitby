import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

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
  String? _workers;

  DateTime? _workDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final List<XFile> _images = [];

  final List<String> _locations = ['Main Office', 'Civic Centre', 'Depot'];
  final List<String> _workTypes = ['Planted', 'Weeded', 'Cleaned Up', 'Other'];
  final DateFormat _dateFormatter = DateFormat('MMMM d, yyyy');
  final _uuid = const Uuid();

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

    try {
      final duration = _workDuration?.inMinutes ?? 0;
      final photoUrls = await _uploadImages();
      await FirebaseFirestore.instance.collection('logs').add({
        'location': _selectedLocation,
        'workType':
            _selectedWorkType == 'Other'
                ? _otherWorkTypeDescription
                : _selectedWorkType,
        'description':
            _selectedWorkType == 'Other' ? _otherWorkTypeDescription : null,
        'workers': _workers ?? '',
        'workDate': _workDate != null ? Timestamp.fromDate(_workDate!) : null,
        'startTime': _startTime?.format(context),
        'endTime': _endTime?.format(context),
        'durationMinutes': duration,
        'photos': photoUrls,
        'createdAt': Timestamp.now(),
      });

      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Work log submitted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
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
              DropdownButtonFormField<String>(
                value: _selectedLocation,
                decoration: inputDecoration('Location'),
                items:
                    _locations
                        .map(
                          (loc) =>
                              DropdownMenuItem(value: loc, child: Text(loc)),
                        )
                        .toList(),
                onChanged: (v) => setState(() => _selectedLocation = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedWorkType,
                decoration: inputDecoration('Work Type'),
                items:
                    _workTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                onChanged:
                    (v) => setState(() {
                      _selectedWorkType = v;
                      if (v != 'Other') _otherWorkTypeDescription = null;
                    }),
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
              TextFormField(
                decoration: inputDecoration('Workers (comma separated)'),
                onChanged: (v) => _workers = v,
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
