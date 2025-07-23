import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/account_service.dart';

const _whitbyBlue = Color(0xFF003366);

class AccountSelection extends StatefulWidget {
  const AccountSelection({super.key});

  @override
  State<AccountSelection> createState() => _AccountSelectionState();
}

class _AccountSelectionState extends State<AccountSelection> {
  List<Map<String, dynamic>> _workers = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }
  
  Future<void> _loadWorkers() async {
    try {
      final workers = await DatabaseService.getWorkers();
      if (mounted) {
        setState(() {
          _workers = workers.where((w) => w['isActive'] == true).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading workers: $e')),
        );
      }
    }
  }
  
  Future<void> _selectAccount(String workerId, String workerName) async {
    try {
      await AccountService.setCurrentAccount(workerId);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Signed in as $workerName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting account: $e')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Select Your Account'),
        backgroundColor: _whitbyBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _workers.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No worker accounts available',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Contact admin to create accounts',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Image.asset('assets/whitby_logo.png', height: 60),
                            const SizedBox(height: 16),
                            const Text(
                              'Choose Your Account',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _whitbyBlue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Select your worker account to continue',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Worker accounts list
                      ...List.generate(_workers.length, (index) {
                        final worker = _workers[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: InkWell(
                              onTap: () => _selectAccount(
                                worker['id'],
                                worker['name'],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: _whitbyBlue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.person,
                                          size: 28,
                                          color: _whitbyBlue,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            worker['name'] ?? 'Unknown',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: _whitbyBlue,
                                            ),
                                          ),
                                          if (worker['role']?.toString().isNotEmpty == true)
                                            Text(
                                              worker['role'],
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}