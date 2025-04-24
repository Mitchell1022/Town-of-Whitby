import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

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
    if (picked != null) {
      setState(() => _workDate = picked);
    }
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
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _pickImagesFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() => _images.addAll(picked));
    }
  }

  Future<void> _takePhotoWithCamera() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() => _images.add(photo));
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  Future<List<String>> _uploadImages() async {
    final storage = FirebaseStorage.instance;
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    final List<String> downloadUrls = [];

    for (var image in _images) {
      try {
        final file = File(image.path);

        if (!file.existsSync()) {
          continue;
        }

        final length = await file.length();
        if (length == 0) {
          continue;
        }

        final ref = storage.ref().child('log_photos/${_uuid.v4()}.jpg');
        final uploadTask = ref.putFile(file, metadata);
        final snapshot = await uploadTask.whenComplete(() => {});

        if (snapshot.state == TaskState.success) {
          final url = await snapshot.ref.getDownloadURL();
          downloadUrls.add(url);
        } else {}
      } catch (e) {
        rethrow;
      }
    }

    return downloadUrls;
  }

  Future<void> _submitForm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Submission'),
            content: const Text(
              'Are you sure you want to submit this work log?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Submit'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

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
      Navigator.of(context).popUntil((route) => route.isFirst);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Work log submitted successfully!')),
      );
    } catch (e) {
      print('Submission error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving log: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Work'),
        leading: const BackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedLocation,
              decoration: const InputDecoration(labelText: 'Location'),
              items:
                  _locations.map((location) {
                    return DropdownMenuItem(
                      value: location,
                      child: Text(location),
                    );
                  }).toList(),
              onChanged: (value) => setState(() => _selectedLocation = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedWorkType,
              decoration: const InputDecoration(labelText: 'Work Type'),
              items:
                  _workTypes.map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
              onChanged:
                  (value) => setState(() {
                    _selectedWorkType = value;
                    if (value != 'Other') _otherWorkTypeDescription = null;
                  }),
            ),
            if (_selectedWorkType == 'Other') ...[
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Please describe the work',
                  border: OutlineInputBorder(),
                ),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                onChanged: (value) => _otherWorkTypeDescription = value,
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.access_time, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Date & Time',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Expanded(child: Divider(thickness: 1, indent: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  onPressed: _pickDate,
                  child: Text(
                    _workDate == null
                        ? 'Select Date'
                        : _dateFormatter.format(_workDate!),
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _pickTime(true),
                  child: Text(
                    _startTime == null
                        ? 'Start Time'
                        : _startTime!.format(context),
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _pickTime(false),
                  child: Text(
                    _endTime == null ? 'End Time' : _endTime!.format(context),
                  ),
                ),
              ],
            ),
            if (_workDuration != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Duration: ${_workDuration!.inHours}h ${_workDuration!.inMinutes.remainder(60)}m',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
            const SizedBox(height: 24),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Workers (comma separated)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.text,
              onChanged: (value) => _workers = value,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImagesFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Add Photos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _takePhotoWithCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_images.isNotEmpty)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(_images.length, (index) {
                  return Stack(
                    alignment: Alignment.topRight,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          File(_images[index].path),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black54,
                          ),
                          padding: const EdgeInsets.all(4),
                          margin: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _submitForm,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
