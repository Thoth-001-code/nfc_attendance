import 'package:flutter/material.dart';

import '../database/database_helper.dart';

enum HistoryFilterMode {
  all,
  day,
  month,
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() =>
      _HistoryScreenState();
}

class _HistoryScreenState
    extends State<HistoryScreen> {
  bool _loading = true;

  List<Map<String, dynamic>> _allRows = [];
  List<Map<String, dynamic>> _filteredRows = [];

  HistoryFilterMode _filterMode =
      HistoryFilterMode.all;

  DateTime _selectedDate = DateTime.now();
  DateTime _selectedMonth = DateTime.now();

  int? _selectedEmployeeId;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final rows = await DatabaseHelper.instance
          .getAttendanceHistory();

      if (!mounted) return;

      setState(() {
        _allRows = rows;
        _loading = false;
      });

      _applyFilters();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể tải lịch sử: $e',
          ),
        ),
      );
    }
  }

  void _applyFilters() {
    var rows =
    List<Map<String, dynamic>>.from(_allRows);

    if (_selectedEmployeeId != null) {
      rows = rows.where((row) {
        return row['employeeId'] ==
            _selectedEmployeeId;
      }).toList();
    }

    if (_filterMode ==
        HistoryFilterMode.day) {
      final key = _dateKey(_selectedDate);

      rows = rows.where((row) {
        return row['date'] == key;
      }).toList();
    }

    if (_filterMode ==
        HistoryFilterMode.month) {
      rows = rows.where((row) {
        final value =
            row['date']?.toString() ?? '';

        final date =
        DateTime.tryParse(value);

        if (date == null) {
          return false;
        }

        return date.year ==
            _selectedMonth.year &&
            date.month ==
                _selectedMonth.month;
      }).toList();
    }

    if (!mounted) return;

    setState(() {
      _filteredRows = rows;
    });
  }

  String _dateKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _displayDate(String value) {
    final date = DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _displayTime(dynamic value) {
    if (value == null) {
      return '--';
    }

    final date =
    DateTime.tryParse(value.toString());

    if (date == null) {
      return '--';
    }

    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}:'
        '${date.second.toString().padLeft(2, '0')}';
  }

  String _monthText(DateTime value) {
    return 'Tháng ${value.month}/${value.year}';
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

  String _minutesText(dynamic value) {
    final minutes =
        int.tryParse(value?.toString() ?? '0') ??
            0;

    return '$minutes phút';
  }

  String _workingTimeText(dynamic value) {
    final total =
        int.tryParse(value?.toString() ?? '0') ??
            0;

    final hours = total ~/ 60;
    final minutes = total % 60;

    if (hours == 0) {
      return '$minutes phút';
    }

    return '${hours}h ${minutes.toString().padLeft(2, '0')}p';
  }

  List<DropdownMenuItem<int?>>
  _employeeItems() {
    final employees =
    <int, String>{};

    for (final row in _allRows) {
      final id = row['employeeId'];

      if (id is! int) {
        continue;
      }

      final code =
          row['employeeCode']?.toString() ?? '';

      final name =
          row['fullName']?.toString() ?? '';

      employees[id] = '$code - $name';
    }

    final sorted =
    employees.entries.toList()
      ..sort(
            (a, b) =>
            a.value.compareTo(b.value),
      );

    return [
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('Tất cả nhân viên'),
      ),
      ...sorted.map(
            (entry) => DropdownMenuItem<int?>(
          value: entry.key,
          child: Text(
            entry.value,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];
  }

  Future<void> _chooseDay() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedDate = result;
      _filterMode = HistoryFilterMode.day;
    });

    _applyFilters();
  }

  Future<void> _chooseMonth() async {
    var tempYear = _selectedMonth.year;
    var tempMonth = _selectedMonth.month;

    final result = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            return AlertDialog(
              title:
              const Text('Chọn tháng'),
              content: Column(
                mainAxisSize:
                MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: tempMonth,
                    decoration:
                    const InputDecoration(
                      labelText: 'Tháng',
                    ),
                    items: List.generate(
                      12,
                          (index) =>
                          DropdownMenuItem(
                            value: index + 1,
                            child: Text(
                              'Tháng ${index + 1}',
                            ),
                          ),
                    ),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setDialogState(() {
                        tempMonth = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: tempYear,
                    decoration:
                    const InputDecoration(
                      labelText: 'Năm',
                    ),
                    items: List.generate(
                      11,
                          (index) {
                        final year =
                            DateTime.now().year -
                                5 +
                                index;

                        return DropdownMenuItem(
                          value: year,
                          child: Text(
                            year.toString(),
                          ),
                        );
                      },
                    ),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setDialogState(() {
                        tempYear = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child:
                  const Text('HỦY'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      DateTime(
                        tempYear,
                        tempMonth,
                      ),
                    );
                  },
                  child:
                  const Text('CHỌN'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedMonth = result;
      _filterMode = HistoryFilterMode.month;
    });

    _applyFilters();
  }

  void _showAll() {
    setState(() {
      _filterMode = HistoryFilterMode.all;
    });

    _applyFilters();
  }

  void _clearAllFilters() {
    setState(() {
      _filterMode = HistoryFilterMode.all;
      _selectedEmployeeId = null;
      _selectedDate = DateTime.now();
      _selectedMonth = DateTime.now();
    });

    _applyFilters();
  }

  Widget _filterButton({
    required String text,
    required IconData icon,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    if (selected) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(text),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(text),
    );
  }

  Widget _summaryCard() {
    int working = 0;
    int completed = 0;
    int late = 0;
    int early = 0;

    for (final row in _filteredRows) {
      final status =
      row['status']?.toString();

      if (status == 'WORKING') {
        working++;
      } else {
        completed++;
      }

      if (status == 'LATE' ||
          status == 'LATE_EARLY') {
        late++;
      }

      if (status == 'EARLY_LEAVE' ||
          status == 'LATE_EARLY') {
        early++;
      }
    }

    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Kết quả lọc',
                    style: TextStyle(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${_filteredRows.length} bản ghi',
                  style: const TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                Text('Đã hoàn tất: $completed'),
                Text('Đang làm: $working'),
                Text('Đi trễ: $late'),
                Text('Về sớm: $early'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _attendanceCard(
      Map<String, dynamic> row,
      ) {
    final code =
        row['employeeCode']?.toString() ??
            '--';

    final name =
        row['fullName']?.toString() ?? '--';

    final shiftName =
    row['shiftName']?.toString();

    final shiftStart =
    row['shiftStartTime']?.toString();

    final shiftEnd =
    row['shiftEndTime']?.toString();

    final shiftText =
    shiftName == null
        ? 'Không có dữ liệu ca'
        : shiftStart != null &&
        shiftEnd != null
        ? '$shiftName '
        '($shiftStart - $shiftEnd)'
        : shiftName;

    return Card(
      margin:
      const EdgeInsets.only(
        bottom: 12,
      ),
      child: ExpansionTile(
        leading: const CircleAvatar(
          child: Icon(Icons.badge),
        ),
        title: Text(
          '$code - $name',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${_displayDate(row['date'].toString())}'
              ' • ${_statusText(row['status'])}',
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
            'Ca làm',
            shiftText,
          ),
          _detailRow(
            'Check-in',
            _displayTime(row['checkIn']),
          ),
          _detailRow(
            'Check-out',
            _displayTime(row['checkOut']),
          ),
          _detailRow(
            'Đi trễ',
            _minutesText(
              row['lateMinutes'],
            ),
          ),
          _detailRow(
            'Về sớm',
            _minutesText(
              row['earlyMinutes'],
            ),
          ),
          _detailRow(
            'Tăng ca',
            _minutesText(
              row['overtimeMinutes'],
            ),
          ),
          _detailRow(
            'Tổng làm',
            _workingTimeText(
              row['totalWorkingMinutes'],
            ),
          ),
          _detailRow(
            'Trạng thái',
            _statusText(row['status']),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
        const Text('Lịch sử chấm công'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed:
            _loading ? null : _loadHistory,
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
        onRefresh: _loadHistory,
        child: ListView(
          padding:
          const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<int?>(
              value:
              _selectedEmployeeId,
              isExpanded: true,
              decoration:
              const InputDecoration(
                labelText:
                'Nhân viên',
                border:
                OutlineInputBorder(),
                prefixIcon:
                Icon(Icons.person),
              ),
              items: _employeeItems(),
              onChanged: (value) {
                setState(() {
                  _selectedEmployeeId =
                      value;
                });

                _applyFilters();
              },
            ),

            const SizedBox(height: 14),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _filterButton(
                  text: 'Tất cả',
                  icon:
                  Icons.list_alt,
                  selected:
                  _filterMode ==
                      HistoryFilterMode
                          .all,
                  onPressed: _showAll,
                ),
                _filterButton(
                  text:
                  _filterMode ==
                      HistoryFilterMode
                          .day
                      ? _displayDate(
                    _dateKey(
                      _selectedDate,
                    ),
                  )
                      : 'Theo ngày',
                  icon:
                  Icons.today,
                  selected:
                  _filterMode ==
                      HistoryFilterMode
                          .day,
                  onPressed:
                  _chooseDay,
                ),
                _filterButton(
                  text:
                  _filterMode ==
                      HistoryFilterMode
                          .month
                      ? _monthText(
                    _selectedMonth,
                  )
                      : 'Theo tháng',
                  icon: Icons
                      .calendar_month,
                  selected:
                  _filterMode ==
                      HistoryFilterMode
                          .month,
                  onPressed:
                  _chooseMonth,
                ),
              ],
            ),

            const SizedBox(height: 8),

            Align(
              alignment:
              Alignment.centerRight,
              child: TextButton.icon(
                onPressed:
                _clearAllFilters,
                icon: const Icon(
                  Icons.filter_alt_off,
                ),
                label: const Text(
                  'Xóa bộ lọc',
                ),
              ),
            ),

            _summaryCard(),

            const SizedBox(height: 8),

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
                          .history_toggle_off,
                      size: 70,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Không có dữ liệu chấm công phù hợp',
                      textAlign:
                      TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ..._filteredRows.map(
                _attendanceCard,
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
