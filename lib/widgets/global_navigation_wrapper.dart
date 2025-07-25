import 'package:flutter/material.dart';
import '../pages/home.dart';
import '../pages/view_logs.dart';
import '../pages/my_work.dart';

class PageWithBottomNav extends StatefulWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? appBar;
  
  const PageWithBottomNav({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.leading,
    this.appBar,
  });

  @override
  State<PageWithBottomNav> createState() => _PageWithBottomNavState();
}

class _PageWithBottomNavState extends State<PageWithBottomNav> {
  void _onItemTapped(int index) {
    // Navigate back to main app instead of creating new isolated pages
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.appBar ?? (widget.title != null ? AppBar(
        title: Text(widget.title!),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        actions: widget.actions,
        leading: widget.leading,
      ) : null),
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1, // Always show Home as selected for non-main pages
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF003366),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'View Logs'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'My Work'),
        ],
      ),
    );
  }
}