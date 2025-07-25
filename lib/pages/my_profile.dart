import 'package:flutter/material.dart';
import '../widgets/global_navigation_wrapper.dart';

const _whitbyBlue = Color(0xFF003366);

class MyProfile extends StatelessWidget {
  const MyProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return PageWithBottomNav(
      title: 'My Profile',
      child: Container(
        color: const Color(0xFFF8F9FA),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person,
                  size: 80,
                  color: _whitbyBlue,
                ),
                SizedBox(height: 24),
                Text(
                  'My Profile',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _whitbyBlue,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Profile page coming soon!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}