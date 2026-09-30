import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../database/database_helper.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() =>
      _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool _loading = true;
  bool _exporting = false;

  DateTime _selectedMonth = DateTime.now();
  int? _selectedEmployeeId;

  List<Map<String, dynamic>> _allRows = [];
  List<Map<String, dynamic>> _filteredRows = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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

      _message('Không thể tải dữ liệu: $e');
    }
  }

  void _applyFilters() {
    final rows = _allRows.where((row) {
      final date =
      DateTime.tryParse(
        row['date']?.toString() ?? '',
      );

      if (date == null) {
        return false;
      }

      final sameMonth =
          date.year == _selectedMonth.year &&
              date.month ==
                  _selectedMonth.month;

      final sameEmployee =
          _selectedEmployeeId == null ||
              row['employeeId'] ==
                  _selectedEmployeeId;

      return sameMonth && sameEmployee;
    }).toList();

    if (!mounted) return;

    setState(() {
      _filteredRows = rows;
    });
  }

  String _monthKey() {
    return '${_selectedMonth.year}_'
        '${_selectedMonth.month.toString().padLeft(2, '0')}';
  }

  String _monthText() {
    return 'Tháng ${_selectedMonth.month}/'
        '${_selectedMonth.year}';
  }

  String _displayDate(dynamic value) {
    final date =
    DateTime.tryParse(
      value?.toString() ?? '',
    );

    if (date == null) return '--';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
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

  int _intValue(dynamic value) {
    return int.tryParse(
      value?.toString() ?? '0',
    ) ??
        0;
  }

  String _workingText(dynamic value) {
    final total = _intValue(value);
    final hours = total ~/ 60;
    final minutes = total % 60;

    return '${hours}h '
        '${minutes.toString().padLeft(2, '0')}p';
  }

  List<DropdownMenuItem<int?>>
  _employeeItems() {
    final employees = <int, String>{};

    for (final row in _allRows) {
      final id = row['employeeId'];

      if (id is! int) continue;

      final code =
          row['employeeCode']?.toString() ??
              '';

      final name =
          row['fullName']?.toString() ?? '';

      employees[id] = '$code - $name';
    }

    final entries = employees.entries.toList()
      ..sort(
            (a, b) =>
            a.value.compareTo(b.value),
      );

    return [
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('Tất cả nhân viên'),
      ),
      ...entries.map(
            (entry) =>
            DropdownMenuItem<int?>(
              value: entry.key,
              child: Text(
                entry.value,
                overflow: TextOverflow.ellipsis,
              ),
            ),
      ),
    ];
  }

  Future<void> _chooseMonth() async {
    var year = _selectedMonth.year;
    var month = _selectedMonth.month;

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
                    value: month,
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
                      if (value == null) return;

                      setDialogState(() {
                        month = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    value: year,
                    decoration:
                    const InputDecoration(
                      labelText: 'Năm',
                    ),
                    items: List.generate(
                      11,
                          (index) {
                        final itemYear =
                            DateTime.now().year -
                                5 +
                                index;

                        return DropdownMenuItem(
                          value: itemYear,
                          child: Text(
                            itemYear.toString(),
                          ),
                        );
                      },
                    ),
                    onChanged: (value) {
                      if (value == null) return;

                      setDialogState(() {
                        year = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(
                        dialogContext,
                      ),
                  child:
                  const Text('HỦY'),
                ),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(
                        dialogContext,
                        DateTime(year, month),
                      ),
                  child:
                  const Text('CHỌN'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    setState(() {
      _selectedMonth = result;
    });

    _applyFilters();
  }

  Future<Directory> _reportDirectory() async {
    final root =
    await getApplicationDocumentsDirectory();

    final directory = Directory(
      '${root.path}/reports',
    );

    if (!await directory.exists()) {
      await directory.create(
        recursive: true,
      );
    }

    return directory;
  }

  String _csvEscape(String value) {
    final escaped =
    value.replaceAll('"', '""');

    return '"$escaped"';
  }

  List<String> _rowValues(
      Map<String, dynamic> row,
      ) {
    return [
      _displayDate(row['date']),
      row['employeeCode']?.toString() ??
          '',
      row['fullName']?.toString() ?? '',
      row['shiftName']?.toString() ?? '',
      _displayTime(row['checkIn']),
      _displayTime(row['checkOut']),
      _intValue(row['lateMinutes'])
          .toString(),
      _intValue(row['earlyMinutes'])
          .toString(),
      _intValue(row['overtimeMinutes'])
          .toString(),
      _intValue(
        row['totalWorkingMinutes'],
      ).toString(),
      _statusText(row['status']),
    ];
  }

  static const List<String> _headers = [
    'Ngày',
    'Mã NV',
    'Họ tên',
    'Ca làm',
    'Check-in',
    'Check-out',
    'Đi trễ (phút)',
    'Về sớm (phút)',
    'Tăng ca (phút)',
    'Tổng làm (phút)',
    'Trạng thái',
  ];

  Future<void> _exportCsv() async {
    await _runExport(() async {
      final directory =
      await _reportDirectory();

      final file = File(
        '${directory.path}/'
            'cham_cong_${_monthKey()}.csv',
      );

      final buffer = StringBuffer();

      // BOM giúp Excel nhận UTF-8 tiếng Việt.
      buffer.write('\uFEFF');

      buffer.writeln(
        _headers
            .map(_csvEscape)
            .join(','),
      );

      for (final row in _filteredRows) {
        buffer.writeln(
          _rowValues(row)
              .map(_csvEscape)
              .join(','),
        );
      }

      await file.writeAsString(
        buffer.toString(),
        encoding: utf8,
        flush: true,
      );

      await _openFile(file);
    });
  }

  Future<void> _exportExcel() async {
    await _runExport(() async {
      final excel = xls.Excel.createExcel();

      final sheet = excel['Chấm công'];

      sheet.appendRow(
        _headers
            .map(
              (value) =>
              xls.TextCellValue(value),
        )
            .toList(),
      );

      for (final row in _filteredRows) {
        sheet.appendRow(
          _rowValues(row)
              .map(
                (value) =>
                xls.TextCellValue(value),
          )
              .toList(),
        );
      }

      // Xóa sheet mặc định nếu tồn tại.
      if (excel.tables.containsKey('Sheet1') &&
          excel.tables.length > 1) {
        excel.delete('Sheet1');
      }

      final bytes = excel.save();

      if (bytes == null) {
        throw Exception(
          'Không thể tạo file Excel',
        );
      }

      final directory =
      await _reportDirectory();

      final file = File(
        '${directory.path}/'
            'cham_cong_${_monthKey()}.xlsx',
      );

      await file.writeAsBytes(
        bytes,
        flush: true,
      );

      await _openFile(file);
    });
  }

  Future<pw.Font> _androidPdfFont() async {
    const paths = [
      '/system/fonts/Roboto-Regular.ttf',
      '/system/fonts/NotoSans-Regular.ttf',
    ];

    for (final path in paths) {
      final file = File(path);

      if (await file.exists()) {
        final bytes =
        await file.readAsBytes();

        final data =
        ByteData.sublistView(bytes);

        return pw.Font.ttf(data);
      }
    }

    throw Exception(
      'Không tìm thấy font Unicode hệ thống Android',
    );
  }

  Future<void> _exportPdf() async {
    await _runExport(() async {
      final font = await _androidPdfFont();

      final pdf = pw.Document();

      final employeeText =
      _selectedEmployeeId == null
          ? 'Tất cả nhân viên'
          : _selectedEmployeeLabel();

      pdf.addPage(
        pw.MultiPage(
          pageFormat:
          PdfPageFormat.a4.landscape,
          margin:
          const pw.EdgeInsets.all(24),
          theme: pw.ThemeData.withFont(
            base: font,
            bold: font,
          ),
          build: (context) => [
            pw.Text(
              'BÁO CÁO CHẤM CÔNG',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight:
                pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              '${_monthText()} - '
                  '$employeeText',
            ),
            pw.Text(
              'Số bản ghi: '
                  '${_filteredRows.length}',
            ),
            pw.SizedBox(height: 14),
            pw.TableHelper.fromTextArray(
              headers: _headers,
              data: _filteredRows
                  .map(_rowValues)
                  .toList(),
              headerStyle: pw.TextStyle(
                fontWeight:
                pw.FontWeight.bold,
                fontSize: 7,
              ),
              cellStyle:
              const pw.TextStyle(
                fontSize: 7,
              ),
              headerDecoration:
              const pw.BoxDecoration(
                color:
                PdfColors.grey300,
              ),
              cellAlignment:
              pw.Alignment.centerLeft,
            ),
          ],
        ),
      );

      final directory =
      await _reportDirectory();

      final file = File(
        '${directory.path}/'
            'cham_cong_${_monthKey()}.pdf',
      );

      await file.writeAsBytes(
        await pdf.save(),
        flush: true,
      );

      await _openFile(file);
    });
  }

  String _selectedEmployeeLabel() {
    if (_selectedEmployeeId == null) {
      return 'Tất cả nhân viên';
    }

    for (final row in _allRows) {
      if (row['employeeId'] ==
          _selectedEmployeeId) {
        return '${row['employeeCode']} - '
            '${row['fullName']}';
      }
    }

    return 'Nhân viên';
  }

  Future<void> _runExport(
      Future<void> Function() action,
      ) async {
    if (_exporting) return;

    if (_filteredRows.isEmpty) {
      _message(
        'Không có dữ liệu để xuất báo cáo.',
      );
      return;
    }

    setState(() {
      _exporting = true;
    });

    try {
      await action();
    } catch (e) {
      _message(
        'Xuất báo cáo thất bại: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  Future<void> _openFile(File file) async {
    final result =
    await OpenFilex.open(file.path);

    if (!mounted) return;

    if (result.type != ResultType.done) {
      _message(
        'Đã tạo file:\n${file.path}\n\n'
            'Không tìm thấy ứng dụng phù hợp '
            'để mở file.',
      );
      return;
    }

    _message(
      'Đã xuất file thành công.',
    );
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(text),
      ),
    );
  }

  Widget _summary() {
    var completed = 0;
    var late = 0;
    var early = 0;
    var overtime = 0;
    var totalMinutes = 0;

    for (final row in _filteredRows) {
      if (row['checkOut'] != null) {
        completed++;
      }

      if (_intValue(row['lateMinutes']) >
          0) {
        late++;
      }

      if (_intValue(
        row['earlyMinutes'],
      ) >
          0) {
        early++;
      }

      if (_intValue(
        row['overtimeMinutes'],
      ) >
          0) {
        overtime++;
      }

      totalMinutes += _intValue(
        row['totalWorkingMinutes'],
      );
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
                    'Tổng hợp',
                    style: TextStyle(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${_filteredRows.length} bản ghi',
                ),
              ],
            ),
            const Divider(),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(
                  'Đã hoàn tất: $completed',
                ),
                Text('Đi trễ: $late'),
                Text('Về sớm: $early'),
                Text('Có tăng ca: $overtime'),
                Text(
                  'Tổng giờ: '
                      '${_workingText(totalMinutes)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _exportButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed:
        _exporting ? null : onPressed,
        icon: Icon(icon),
        label: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
        const Text('Báo cáo chấm công'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed:
            _loading ? null : _loadData,
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
          : ListView(
        padding:
        const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: _chooseMonth,
            icon: const Icon(
              Icons.calendar_month,
            ),
            label: Text(_monthText()),
          ),

          const SizedBox(height: 12),

          DropdownButtonFormField<int?>(
            value:
            _selectedEmployeeId,
            isExpanded: true,
            decoration:
            const InputDecoration(
              labelText: 'Nhân viên',
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

          const SizedBox(height: 16),

          _summary(),

          const SizedBox(height: 18),

          if (_exporting)
            const Padding(
              padding:
              EdgeInsets.only(
                bottom: 16,
              ),
              child:
              LinearProgressIndicator(),
            ),

          _exportButton(
            text: 'XUẤT CSV',
            icon:
            Icons.description,
            onPressed: _exportCsv,
          ),

          const SizedBox(height: 10),

          _exportButton(
            text: 'XUẤT EXCEL',
            icon:
            Icons.table_chart,
            onPressed: _exportExcel,
          ),

          const SizedBox(height: 10),

          _exportButton(
            text: 'XUẤT PDF',
            icon:
            Icons.picture_as_pdf,
            onPressed: _exportPdf,
          ),

          const SizedBox(height: 20),

          const Text(
            'Báo cáo gồm: ngày, mã nhân viên, '
                'họ tên, ca làm, check-in, check-out, '
                'đi trễ, về sớm, tăng ca, tổng thời '
                'gian làm và trạng thái.',
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
