import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import 'today_monitor_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState
    extends State<DashboardScreen> {
  bool _loading = true;
  DateTime _selectedDate = DateTime.now();

  int _totalActiveEmployees = 0;
  int _present = 0;
  int _absent = 0;
  int _working = 0;
  int _checkedOut = 0;
  int _late = 0;
  int _earlyLeave = 0;
  int _overtime = 0;

  List<Map<String, dynamic>> _todayRows = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  String _dateKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _displayDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  String _displayTime(dynamic value) {
    if (value == null) return '--';

    final date =
    DateTime.tryParse(value.toString());

    if (date == null) return '--';

    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _statusText(dynamic value) {
    switch (value?.toString()) {
      case 'WORKING':
        return 'Đang làm';
      case 'COMPLETE':
        return 'Đủ công';
      case 'LATE':
        return 'Đi trễ';
      case 'EARLY_LEAVE':
        return 'Về sớm';
      case 'LATE_EARLY':
        return 'Đi trễ + về sớm';
      default:
        return value?.toString() ?? '--';
    }
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final employees =
      await DatabaseHelper.instance
          .getEmployees();

      final history =
      await DatabaseHelper.instance
          .getAttendanceHistory();

      final activeEmployees = employees
          .where(
            (employee) =>
        employee.status == 'ACTIVE',
      )
          .toList();

      final activeIds = activeEmployees
          .where((employee) => employee.id != null)
          .map((employee) => employee.id!)
          .toSet();

      final date = _dateKey(_selectedDate);

      // Chỉ tính Attendance của nhân viên ACTIVE.
      final rows = history.where((row) {
        final employeeId = row['employeeId'];

        return row['date'] == date &&
            employeeId is int &&
            activeIds.contains(employeeId);
      }).toList();

      final presentEmployeeIds = rows
          .map((row) => row['employeeId'])
          .whereType<int>()
          .toSet();

      int working = 0;
      int checkedOut = 0;
      int late = 0;
      int early = 0;
      int overtime = 0;

      for (final row in rows) {
        final checkOut = row['checkOut'];
        final status =
            row['status']?.toString() ?? '';

        if (checkOut == null) {
          working++;
        } else {
          checkedOut++;
        }

        if (status == 'LATE' ||
            status == 'LATE_EARLY' ||
            ((row['lateMinutes'] as int?) ?? 0) >
                0) {
          late++;
        }

        if (status == 'EARLY_LEAVE' ||
            status == 'LATE_EARLY' ||
            ((row['earlyMinutes'] as int?) ??
                0) >
                0) {
          early++;
        }

        if (((row['overtimeMinutes'] as int?) ??
            0) >
            0) {
          overtime++;
        }
      }

      final total = activeEmployees.length;
      final present = presentEmployeeIds.length;
      final absent =
      total >= present ? total - present : 0;

      if (!mounted) return;

      setState(() {
        _totalActiveEmployees = total;
        _present = present;
        _absent = absent;
        _working = working;
        _checkedOut = checkedOut;
        _late = late;
        _earlyLeave = early;
        _overtime = overtime;
        _todayRows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể tải Dashboard: $e',
          ),
        ),
      );
    }
  }

  Future<void> _chooseDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (result == null) return;

    setState(() {
      _selectedDate = result;
    });

    await _loadDashboard();
  }

  Widget _statCard({
    required String title,
    required int value,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(icon, size: 34),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _employeeRow(
      Map<String, dynamic> row,
      ) {
    final code =
        row['employeeCode']?.toString() ?? '--';
    final name =
        row['fullName']?.toString() ?? '--';

    return Card(
      margin: const EdgeInsets.only(
        bottom: 8,
      ),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.person),
        ),
        title: Text(
          '$code - $name',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Vào: ${_displayTime(row['checkIn'])}'
              '  •  Ra: ${_displayTime(row['checkOut'])}',
        ),
        trailing: Text(
          _statusText(row['status']),
          textAlign: TextAlign.end,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dashboard chấm công',
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed:
            _loading ? null : _loadDashboard,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
        child:
        CircularProgressIndicator(),
      )
          : RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          padding:
          const EdgeInsets.all(16),
          children: [
            OutlinedButton.icon(
              onPressed: _chooseDate,
              icon: const Icon(
                Icons.calendar_month,
              ),
              label: Text(
                'Ngày ${_displayDate(_selectedDate)}',
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                      const TodayMonitorScreen(),
                    ),
                  );

                  if (mounted) {
                    await _loadDashboard();
                  }
                },
                icon: const Icon(
                  Icons.people_alt_outlined,
                ),
                label: const Text(
                  'XEM NHÂN VIÊN HÔM NAY',
                ),
              ),
            ),

            const SizedBox(height: 12),

            GridView(
              shrinkWrap: true,
              physics:
              const NeverScrollableScrollPhysics(),
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 165,
              ),
              children: [
                _statCard(
                  title:
                  'Nhân viên ACTIVE',
                  value:
                  _totalActiveEmployees,
                  icon: Icons.groups,
                ),
                _statCard(
                  title: 'Có mặt',
                  value: _present,
                  icon:
                  Icons.how_to_reg,
                ),
                _statCard(
                  title: 'Vắng',
                  value: _absent,
                  icon:
                  Icons.person_off,
                ),
                _statCard(
                  title: 'Đi trễ',
                  value: _late,
                  icon:
                  Icons.access_time,
                ),
                _statCard(
                  title: 'Đang làm',
                  value: _working,
                  icon: Icons.work,
                ),
                _statCard(
                  title: 'Đã về',
                  value: _checkedOut,
                  icon:
                  Icons.logout,
                ),
                _statCard(
                  title: 'Về sớm',
                  value: _earlyLeave,
                  icon:
                  Icons.exit_to_app,
                ),
                _statCard(
                  title: 'Có tăng ca',
                  value: _overtime,
                  icon:
                  Icons.more_time,
                ),
              ],
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Nhân viên có mặt',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${_todayRows.length} bản ghi',
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (_todayRows.isEmpty)
              const Padding(
                padding:
                EdgeInsets.symmetric(
                  vertical: 40,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons
                          .event_busy,
                      size: 60,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Ngày này chưa có dữ liệu chấm công',
                      textAlign:
                      TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ..._todayRows.map(
                _employeeRow,
              ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
