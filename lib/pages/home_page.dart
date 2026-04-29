import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/main_navigation_scaffold.dart';
import 'dashboard_page.dart';
import 'statistics_page.dart';
import 'add_transaction_page.dart';
import 'budgets_page.dart';
import 'profile_page.dart';

/// Editorial home shell — no global AppBar; each page renders its own
/// magazine-style header. Bottom navigation stays consistent.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  DateTime? _lastBackPressed;

  // Each element is a generation counter; incrementing forces the page to rebuild
  final List<int> _pageKeys = [0, 0, 0, 0, 0];

  static final List<Widget Function(Key)> _builders = [
    (k) => DashboardPage(key: k),
    (k) => StatisticsPage(key: k),
    (k) => AddTransactionPage(key: k),
    (k) => BudgetsPage(key: k),
    (k) => ProfilePage(key: k),
  ];

  void _onNavigationChanged(int index) {
    if (index == 2) {
      _showAddTransaction();
      return;
    }
    setState(() {
      if (index != _currentIndex) {
        _pageKeys[index]++;
      }
      _currentIndex = index;
    });
  }

  Future<void> _showAddTransaction() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          top: 60,
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: AddTransactionPage(isModal: true),
      ),
    );
    // Refresh the current page after modal closes
    if (mounted) setState(() => _pageKeys[_currentIndex]++);
  }

  Future<bool> _onWillPop() async {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return false;
    }

    final now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tekan sekali lagi untuk keluar'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    SystemNavigator.pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: MainNavigationScaffold(
        currentIndex: _currentIndex,
        onNavigationChanged: _onNavigationChanged,
        floatingActionButton: null,
        child: SafeArea(
          top: true,
          bottom: false,
          child: _builders[_currentIndex](
            ValueKey('page-$_currentIndex-${_pageKeys[_currentIndex]}'),
          ),
        ),
      ),
    );
  }
}
