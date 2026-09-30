import 'package:flutter/material.dart';

import '../database/database_helper.dart';

enum TodayEmployeeFilter {
  all,
  notCheckedIn,
  working,
  left,
  late,
}

class TodayMonitorScreen extends StatefulWidget {
  const TodayMonitorScreen({super.key});

  @override
  State<TodayMonitorScreen> createState() =>
      _TodayMonitorScreenState();
}

class _TodayMonitorScreenState
    extends State<TodayMonitorScreen> {
  bool _loading = true;

  TodayEmployeeFilter _filter =
      TodayEmployeeFilter.all;

  List<Map<String, dynamic>> _allRows = [];
  List<Map<String, dynamic>> _filteredRows = [];

  int _total = 0;
  int _notCheckedIn = 0;
  int _working = 0;
  int _left = 0;

  @override
  void initState() {
    super.initState();
    _loadToday();
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
        '${date.minute.toString().padLeft(2, '0')}:'
        '${date.second.toString().padLeft(2, '0')}';
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(
      value?.toString() ?? '0',
    ) ??
        0;
  }

  String _workResult(
      Map<String, dynamic> row,
      ) {
    final attendanceStatus =
    row['attendanceStatus']?.toString();

    if (attendanceStatus == null) {
      return '--';
    }

    switch (attendanceStatus) {
      case 'WORKING':
        final late = _asInt(
          row['lateMinutes'],
        );

        return late > 0
            ? 'Đi trễ'
            : 'Đúng giờ';

      case 'COMPLETE':
        return 'Đủ công';

      case 'LATE':
        return 'Đi trễ';

      case 'EARLY_LEAVE':
        return 'Về sớm';

      case 'LATE_EARLY':
        return 'Đi trễ + về sớm';

      default:
        return attendanceStatus;
    }
  }

  String _currentState(
      Map<String, dynamic> row,
      ) {
    if (row['checkIn'] == null) {
      return 'Chưa chấm công';
    }

    if (row['checkOut'] == null) {
      return 'Đang làm';
    }

    return 'Đã về';
  }

  IconData _stateIcon(
      Map<String, dynamic> row,
      ) {
    if (row['checkIn'] == null) {
      return Icons.schedule_outlined;
    }

    if (row['checkOut'] == null) {
      return Icons.work_outline;
    }

    return Icons.home_outlined;
  }

  Future<void> _loadToday() async {
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
        employee.status == 'ACTIVE' &&
            employee.id != null,
      )
          .toList();

      final today = _dateKey(
        DateTime.now(),
      );

      final attendanceByEmployee =
      <int, Map<String, dynamic>>{};

      for (final row in history) {
        if (row['date'] != today) {
          continue;
        }

        final employeeId =
        row['employeeId'];

        if (employeeId is int) {
          attendanceByEmployee[employeeId] =
              row;
        }
      }

      final rows =
      <Map<String, dynamic>>[];

      int notCheckedIn = 0;
      int working = 0;
      int left = 0;

      for (final employee
      in activeEmployees) {
        final employeeId = employee.id!;

        final attendance =
        attendanceByEmployee[employeeId];

        final row =
        <String, dynamic>{
          'employeeId': employeeId,
          'employeeCode':
          employee.employeeCode,
          'fullName': employee.fullName,
          'checkIn':
          attendance?['checkIn'],
          'checkOut':
          attendance?['checkOut'],
          'attendanceStatus':
          attendance?['status'],
          'lateMinutes':
          attendance?['lateMinutes'] ??
              0,
          'earlyMinutes':
          attendance?['earlyMinutes'] ??
              0,
          'overtimeMinutes':
          attendance?[
          'overtimeMinutes'] ??
              0,
          'totalWorkingMinutes':
          attendance?[
          'totalWorkingMinutes'] ??
              0,
        };

        if (attendance == null) {
          notCheckedIn++;
        } else if (
        attendance['checkOut'] ==
            null) {
          working++;
        } else {
          left++;
        }

        rows.add(row);
      }

      // Ưu tiên: đang làm -> chưa chấm công -> đã về.
      rows.sort((a, b) {
        int priority(
            Map<String, dynamic> row,
            ) {
          if (row['checkIn'] == null) {
            return 1;
          }

          if (row['checkOut'] == null) {
            return 0;
          }

          return 2;
        }

        final result =
        priority(a).compareTo(
          priority(b),
        );

        if (result != 0) {
          return result;
        }

        return a['employeeCode']
            .toString()
            .compareTo(
          b['employeeCode']
              .toString(),
        );
      });

      if (!mounted) return;

      setState(() {
        _allRows = rows;
        _total = rows.length;
        _notCheckedIn = notCheckedIn;
        _working = working;
        _left = left;
        _loading = false;
      });

      _applyFilter();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Không thể tải theo dõi hôm nay: $e',
          ),
        ),
      );
    }
  }

  void _applyFilter() {
    var rows =
    List<Map<String, dynamic>>.from(
      _allRows,
    );

    switch (_filter) {
      case TodayEmployeeFilter.all:
        break;

      case TodayEmployeeFilter.notCheckedIn:
        rows = rows
            .where(
              (row) =>
          row['checkIn'] == null,
        )
            .toList();
        break;

      case TodayEmployeeFilter.working:
        rows = rows
            .where(
              (row) =>
          row['checkIn'] != null &&
              row['checkOut'] == null,
        )
            .toList();
        break;

      case TodayEmployeeFilter.left:
        rows = rows
            .where(
              (row) =>
          row['checkOut'] != null,
        )
            .toList();
        break;

      case TodayEmployeeFilter.late:
        rows = rows
            .where(
              (row) =>
          _asInt(
            row['lateMinutes'],
          ) >
              0,
        )
            .toList();
        break;
    }

    if (!mounted) return;

    setState(() {
      _filteredRows = rows;
    });
  }

  void _changeFilter(
      TodayEmployeeFilter value,
      ) {
    setState(() {
      _filter = value;
    });

    _applyFilter();
  }

  Widget _summaryCard({
    required String label,
    required int value,
    required IconData icon,
    required TodayEmployeeFilter filter,
  }) {
    final selected =
        _filter == filter;

    return InkWell(
      onTap: () {
        _changeFilter(filter);
      },
      borderRadius:
      BorderRadius.circular(12),
      child: Card(
        elevation: selected ? 4 : 1,
        child: Padding(
          padding:
          const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 30,
              ),
              const SizedBox(height: 6),
              Text(
                value.toString(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                textAlign:
                TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _employeeCard(
      Map<String, dynamic> row,
      ) {
    final code =
        row['employeeCode']?.toString() ??
            '--';

    final name =
        row['fullName']?.toString() ??
            '--';

    final state =
    _currentState(row);

    final result =
    _workResult(row);

    final late =
    _asInt(row['lateMinutes']);

    final early =
    _asInt(row['earlyMinutes']);

    final overtime =
    _asInt(row['overtimeMinutes']);

    return Card(
      margin:
      const EdgeInsets.only(
        bottom: 10,
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          child: Icon(
            _stateIcon(row),
          ),
        ),
        title: Text(
          '$code - $name',
          style: const TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '$state'
              '${result == '--' ? '' : ' • $result'}',
        ),
        childrenPadding:
        const EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16,
        ),
        children: [
          const Divider(),

          _detailRow(
            'Tình trạng',
            state,
          ),

          _detailRow(
            'Check-in',
            _displayTime(
              row['checkIn'],
            ),
          ),

          _detailRow(
            'Check-out',
            _displayTime(
              row['checkOut'],
            ),
          ),

          _detailRow(
            'Kết quả',
            result,
          ),

          if (late > 0)
            _detailRow(
              'Đi trễ',
              '$late phút',
            ),

          if (early > 0)
            _detailRow(
              'Về sớm',
              '$early phút',
            ),

          if (overtime > 0)
            _detailRow(
              'Tăng ca',
              '$overtime phút',
            ),
        ],
      ),
    );
  }

  Widget _detailRow(
      String label,
      String value,
      ) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required TodayEmployeeFilter value,
  }) {
    return FilterChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) {
        _changeFilter(value);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Theo dõi hôm nay',
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed:
            _loading ? null : _loadToday,
            icon:
            const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
        child:
        CircularProgressIndicator(),
      )
          : RefreshIndicator(
        onRefresh: _loadToday,
        child: ListView(
          padding:
          const EdgeInsets.all(16),
          children: [
            Text(
              'Ngày ${_displayDate(now)}',
              textAlign:
              TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(height: 14),

            GridView(
              shrinkWrap: true,
              physics:
              const NeverScrollableScrollPhysics(),
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 150,
              ),
              children: [
                _summaryCard(
                  label:
                  'Tổng ACTIVE',
                  value: _total,
                  icon: Icons.groups,
                  filter:
                  TodayEmployeeFilter
                      .all,
                ),
                _summaryCard(
                  label:
                  'Chưa chấm công',
                  value:
                  _notCheckedIn,
                  icon: Icons
                      .schedule_outlined,
                  filter:
                  TodayEmployeeFilter
                      .notCheckedIn,
                ),
                _summaryCard(
                  label: 'Đang làm',
                  value: _working,
                  icon:
                  Icons.work_outline,
                  filter:
                  TodayEmployeeFilter
                      .working,
                ),
                _summaryCard(
                  label: 'Đã về',
                  value: _left,
                  icon:
                  Icons.home_outlined,
                  filter:
                  TodayEmployeeFilter
                      .left,
                ),
              ],
            ),

            const SizedBox(height: 16),

            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _filterChip(
                  label: 'Tất cả',
                  value:
                  TodayEmployeeFilter
                      .all,
                ),
                _filterChip(
                  label:
                  'Chưa chấm công',
                  value:
                  TodayEmployeeFilter
                      .notCheckedIn,
                ),
                _filterChip(
                  label: 'Đang làm',
                  value:
                  TodayEmployeeFilter
                      .working,
                ),
                _filterChip(
                  label: 'Đã về',
                  value:
                  TodayEmployeeFilter
                      .left,
                ),
                _filterChip(
                  label: 'Đi trễ',
                  value:
                  TodayEmployeeFilter
                      .late,
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Danh sách nhân viên',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${_filteredRows.length} người',
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (_filteredRows.isEmpty)
              const Padding(
                padding:
                EdgeInsets.symmetric(
                  vertical: 50,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons
                          .person_search_outlined,
                      size: 70,
                    ),
                    SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Không có nhân viên phù hợp',
                      textAlign:
                      TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ..._filteredRows.map(
                _employeeCard,
              ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
