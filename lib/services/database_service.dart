import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DatabaseService {
  static final _firestore = FirebaseFirestore.instance;

  // Location methods
  static Future<List<Map<String, dynamic>>> getLocations() async {
    try {
      final snapshot = await _firestore
          .collection('locations')
          .orderBy('name')
          .get();
      
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        'name': doc.data()['name'] as String,
        'address': doc.data()['address'] as String? ?? '',
        'description': doc.data()['description'] as String? ?? '',
        'createdAt': doc.data()['createdAt'] as Timestamp?,
      }).toList();
    } catch (e) {
      throw Exception('Failed to get locations: $e');
    }
  }

  static Future<void> addLocation({
    required String name,
    String? address,
    String? description,
  }) async {
    try {
      await _firestore.collection('locations').add({
        'name': name.trim(),
        'address': address?.trim() ?? '',
        'description': description?.trim() ?? '',
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to add location: $e');
    }
  }

  static Future<void> deleteLocation(String locationId) async {
    try {
      await _firestore.collection('locations').doc(locationId).delete();
    } catch (e) {
      throw Exception('Failed to delete location: $e');
    }
  }

  // Work Type methods
  static Future<List<Map<String, dynamic>>> getWorkTypes() async {
    try {
      final snapshot = await _firestore
          .collection('work_types')
          .orderBy('name')
          .get();
      
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        'name': doc.data()['name'] as String,
        'description': doc.data()['description'] as String? ?? '',
        'createdAt': doc.data()['createdAt'] as Timestamp?,
      }).toList();
    } catch (e) {
      throw Exception('Failed to get work types: $e');
    }
  }

  static Future<void> addWorkType({
    required String name,
    String? description,
  }) async {
    try {
      await _firestore.collection('work_types').add({
        'name': name.trim(),
        'description': description?.trim() ?? '',
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to add work type: $e');
    }
  }

  static Future<void> deleteWorkType(String workTypeId) async {
    try {
      await _firestore.collection('work_types').doc(workTypeId).delete();
    } catch (e) {
      throw Exception('Failed to delete work type: $e');
    }
  }

  // Worker methods
  static Future<List<Map<String, dynamic>>> getWorkers() async {
    try {
      final snapshot = await _firestore
          .collection('workers')
          .orderBy('name')
          .get();
      
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        'name': doc.data()['name'] as String,
        'email': doc.data()['email'] as String? ?? '',
        'role': doc.data()['role'] as String? ?? '',
        'isActive': doc.data()['isActive'] as bool? ?? true,
        'createdAt': doc.data()['createdAt'] as Timestamp?,
      }).toList();
    } catch (e) {
      throw Exception('Failed to get workers: $e');
    }
  }

  static Future<void> addWorker({
    required String name,
    String? email,
    String? role,
    bool isActive = true,
  }) async {
    try {
      await _firestore.collection('workers').add({
        'name': name.trim(),
        'email': email?.trim() ?? '',
        'role': role?.trim() ?? '',
        'isActive': isActive,
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to add worker: $e');
    }
  }

  static Future<void> updateWorker({
    required String workerId,
    required String name,
    String? email,
    String? role,
    bool? isActive,
  }) async {
    try {
      await _firestore.collection('workers').doc(workerId).update({
        'name': name.trim(),
        'email': email?.trim() ?? '',
        'role': role?.trim() ?? '',
        if (isActive != null) 'isActive': isActive,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to update worker: $e');
    }
  }

  static Future<void> deleteWorker(String workerId) async {
    try {
      await _firestore.collection('workers').doc(workerId).delete();
    } catch (e) {
      throw Exception('Failed to delete worker: $e');
    }
  }

  // Location Activity Analysis methods
  static Future<List<Map<String, dynamic>>> getLocationActivityStatus() async {
    try {
      // Get all locations
      final locations = await getLocations();
      final locationActivityList = <Map<String, dynamic>>[];
      
      for (final location in locations) {
        final locationName = location['name'] as String;
        
        // Get latest work entry for this location
        final latestWorkQuery = await _firestore
            .collection('logs')
            .where('location', isEqualTo: locationName)
            .orderBy('workDate', descending: true)
            .limit(1)
            .get();
        
        // Get total work hours for this location in last 30 days
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
        final recentWorkQuery = await _firestore
            .collection('logs')
            .where('location', isEqualTo: locationName)
            .where('workDate', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
            .get();
        
        // Get total work entries for this location
        final totalWorkQuery = await _firestore
            .collection('logs')
            .where('location', isEqualTo: locationName)
            .get();
        
        DateTime? lastWorkDate;
        String lastWorkType = '';
        int daysSinceLastWork = 0;
        
        if (latestWorkQuery.docs.isNotEmpty) {
          final latestDoc = latestWorkQuery.docs.first.data();
          final workDate = latestDoc['workDate'] as Timestamp?;
          if (workDate != null) {
            lastWorkDate = workDate.toDate();
            daysSinceLastWork = DateTime.now().difference(lastWorkDate).inDays;
            lastWorkType = latestDoc['workType'] as String? ?? '';
          }
        }
        
        // Calculate total hours in last 30 days
        double recentHours = 0;
        for (final doc in recentWorkQuery.docs) {
          final duration = doc.data()['durationMinutes'] as int? ?? 0;
          recentHours += duration / 60.0;
        }
        
        // Determine status and next action
        String status;
        String nextAction;
        Color statusColor;
        
        if (daysSinceLastWork == 0) {
          status = 'Active Today';
          nextAction = 'Continue regular maintenance';
          statusColor = const Color(0xFF4CAF50); // Green
        } else if (daysSinceLastWork <= 7) {
          status = 'Recently Active';
          nextAction = 'Monitor for upcoming needs';
          statusColor = const Color(0xFF8BC34A); // Light Green
        } else if (daysSinceLastWork <= 30) {
          status = 'Moderate Delay';
          nextAction = 'Schedule maintenance check';
          statusColor = const Color(0xFFFF9800); // Orange
        } else if (daysSinceLastWork <= 60) {
          status = 'Attention Needed';
          nextAction = 'Priority maintenance required';
          statusColor = const Color(0xFFFF5722); // Deep Orange
        } else {
          status = 'Critical Delay';
          nextAction = 'Immediate inspection required';
          statusColor = const Color(0xFFF44336); // Red
        }
        
        locationActivityList.add({
          ...location,
          'lastWorkDate': lastWorkDate,
          'lastWorkType': lastWorkType,
          'daysSinceLastWork': daysSinceLastWork,
          'recentHours': recentHours,
          'totalWorkEntries': totalWorkQuery.docs.length,
          'status': status,
          'nextAction': nextAction,
          'statusColor': statusColor,
        });
      }
      
      // Sort by days since last work (most critical first)
      locationActivityList.sort((a, b) => 
          (b['daysSinceLastWork'] as int).compareTo(a['daysSinceLastWork'] as int));
      
      return locationActivityList;
    } catch (e) {
      throw Exception('Failed to get location activity status: $e');
    }
  }

  // Initialize default data if collections are empty
  static Future<void> initializeDefaultData() async {
    try {
      // Check if locations exist
      final locationsSnapshot = await _firestore.collection('locations').limit(1).get();
      if (locationsSnapshot.docs.isEmpty) {
        // Add default locations
        final defaultLocations = ['Main Office', 'Civic Centre', 'Depot'];
        for (final location in defaultLocations) {
          await addLocation(name: location);
        }
      }

      // Check if work types exist
      final workTypesSnapshot = await _firestore.collection('work_types').limit(1).get();
      if (workTypesSnapshot.docs.isEmpty) {
        // Add default work types
        final defaultWorkTypes = ['Planted', 'Weeded', 'Cleaned Up', 'Maintenance'];
        for (final workType in defaultWorkTypes) {
          await addWorkType(name: workType);
        }
      }

      // Check if workers exist
      final workersSnapshot = await _firestore.collection('workers').limit(1).get();
      if (workersSnapshot.docs.isEmpty) {
        // Add default workers
        final defaultWorkers = [
          {'name': 'John Smith', 'role': 'Maintenance Supervisor'},
          {'name': 'Sarah Johnson', 'role': 'Groundskeeper'},
          {'name': 'Mike Davis', 'role': 'General Maintenance'},
        ];
        for (final worker in defaultWorkers) {
          await addWorker(
            name: worker['name']!,
            role: worker['role'],
          );
        }
      }
    } catch (e) {
      throw Exception('Failed to initialize default data: $e');
    }
  }
}