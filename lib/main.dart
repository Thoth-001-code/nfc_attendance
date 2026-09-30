import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const NfcAttendanceApp());
}

class NfcAttendanceApp extends StatelessWidget {
  const NfcAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'NFC Attendance',

      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),

      home: const HomeScreen(),
    );
  }
}