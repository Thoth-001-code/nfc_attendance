import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'attendance_screen.dart';
import 'employee_screen.dart';
import 'history_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  int _selectedIndex = 0;

  final List<Widget> _screens = const [

    // 0
    DashboardScreen(),

    // 1
    AttendanceScreen(),

    // 2
    EmployeeScreen(),

    // 3
    HistoryScreen(),

    // 4
    ReportScreen(),

    // 5
    SettingsScreen(),
  ];

  void _onItemTapped(int index) {

    setState(() {
      _selectedIndex = index;
    });

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      // ===========================
      // NỘI DUNG
      // ===========================
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),

      // ===========================
      // MENU PHÍA DƯỚI
      // ===========================
      bottomNavigationBar: NavigationBar(

        selectedIndex: _selectedIndex,

        onDestinationSelected: _onItemTapped,

        destinations: const [

          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Tổng quan',
          ),

          NavigationDestination(
            icon: Icon(Icons.nfc),
            label: 'Chấm công',
          ),

          NavigationDestination(
            icon: Icon(Icons.people),
            label: 'Nhân viên',
          ),

          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'Lịch sử',
          ),

          NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: 'Báo cáo',
          ),

          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),

        ],
      ),
    );
  }
}