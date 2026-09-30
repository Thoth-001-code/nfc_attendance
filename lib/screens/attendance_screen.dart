import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

import '../database/database_helper.dart';
import '../models/attendance.dart';
import '../models/shift.dart';
import 'shift_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() =>
      _AttendanceScreenState();
}

class _AttendanceScreenState
    extends State<AttendanceScreen> {
  static const Duration _cooldown =
  Duration(seconds: 10);

  final Map<String, DateTime> _lastScans = {};

  String _status =
      'Nhấn nút để bắt đầu quét NFC';
  String _uid = 'Chưa có thẻ';
  String _employee = '--';
  String _action = '--';
  String _time = '--';
  String _details = '--';

  bool _isScanning = false;
  bool _isProcessing = false;

  String _dateKey(DateTime value) {
    final year =
    value.year.toString().padLeft(4, '0');
    final month =
    value.month.toString().padLeft(2, '0');
    final day =
    value.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String _formatTime(DateTime value) {
    final hour =
    value.hour.toString().padLeft(2, '0');
    final minute =
    value.minute.toString().padLeft(2, '0');
    final second =
    value.second.toString().padLeft(2, '0');

    return '$hour:$minute:$second';
  }

  String _uidToHex(List<int> bytes) {
    return bytes
        .map(
          (byte) => byte
          .toRadixString(16)
          .padLeft(2, '0'),
    )
        .join(':')
        .toUpperCase();
  }

  DateTime _timeOnDate(
      DateTime date,
      String hhmm,
      ) {
    final parts = hhmm.split(':');

    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  int _lateMinutes(
      DateTime checkIn,
      Shift shift,
      ) {
    final shiftStart =
    _timeOnDate(checkIn, shift.startTime);

    final allowedUntil = shiftStart.add(
      Duration(
        minutes: shift.graceMinutes,
      ),
    );

    if (!checkIn.isAfter(allowedUntil)) {
      return 0;
    }

    return checkIn
        .difference(allowedUntil)
        .inMinutes;
  }

  int _earlyMinutes(
      DateTime checkOut,
      Shift shift,
      ) {
    final shiftEnd =
    _timeOnDate(checkOut, shift.endTime);

    if (!checkOut.isBefore(shiftEnd)) {
      return 0;
    }

    return shiftEnd
        .difference(checkOut)
        .inMinutes;
  }

  int _overtimeMinutes(
      DateTime checkOut,
      Shift shift,
      ) {
    final shiftEnd =
    _timeOnDate(checkOut, shift.endTime);

    if (!checkOut.isAfter(shiftEnd)) {
      return 0;
    }

    return checkOut
        .difference(shiftEnd)
        .inMinutes;
  }

  int _workingMinutes(
      DateTime checkIn,
      DateTime checkOut,
      Shift shift,
      ) {
    var total =
        checkOut.difference(checkIn).inMinutes;

    if (total <= 0) {
      return 0;
    }

    final breakStart =
    _timeOnDate(checkIn, shift.breakStart);
    final breakEnd =
    _timeOnDate(checkIn, shift.breakEnd);

    final overlapStart =
    checkIn.isAfter(breakStart)
        ? checkIn
        : breakStart;

    final overlapEnd =
    checkOut.isBefore(breakEnd)
        ? checkOut
        : breakEnd;

    if (overlapEnd.isAfter(overlapStart)) {
      total -= overlapEnd
          .difference(overlapStart)
          .inMinutes;
    }

    return total < 0 ? 0 : total;
  }

  String _finalStatus({
    required int late,
    required int early,
  }) {
    if (late > 0 && early > 0) {
      return 'LATE_EARLY';
    }

    if (late > 0) {
      return 'LATE';
    }

    if (early > 0) {
      return 'EARLY_LEAVE';
    }

    return 'COMPLETE';
  }

  String _statusText(String status) {
    switch (status) {
      case 'LATE':
        return 'Đi trễ';
      case 'EARLY_LEAVE':
        return 'Về sớm';
      case 'LATE_EARLY':
        return 'Đi trễ + về sớm';
      case 'COMPLETE':
        return 'Đủ công';
      default:
        return status;
    }
  }

  Future<void> _safeStopSession() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }

  void _showResult({
    required String status,
    String? uid,
    String? employee,
    String? action,
    String? time,
    String? details,
  }) {
    if (!mounted) return;

    setState(() {
      _status = status;

      if (uid != null) _uid = uid;
      if (employee != null) {
        _employee = employee;
      }
      if (action != null) _action = action;
      if (time != null) _time = time;
      if (details != null) {
        _details = details;
      }

      _isScanning = false;
      _isProcessing = false;
    });
  }

  Future<void> _startNfcScan() async {
    if (_isScanning || _isProcessing) {
      return;
    }

    try {
      final availability =
      await NfcManager.instance
          .checkAvailability();

      if (availability !=
          NfcAvailability.enabled) {
        _showResult(
          status:
          'NFC chưa bật hoặc điện thoại không hỗ trợ NFC',
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _status =
        'Đưa thẻ NFC vào mặt sau điện thoại...';
        _isScanning = true;
        _isProcessing = false;
        _action = '--';
        _time = '--';
        _details = '--';
      });

      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
        },
        onDiscovered: (NfcTag tag) async {
          if (_isProcessing) {
            return;
          }

          _isProcessing = true;

          try {
            final androidTag =
            NfcTagAndroid.from(tag);

            if (androidTag == null) {
              await _safeStopSession();

              _showResult(
                status:
                'Không đọc được thông tin thẻ NFC',
              );
              return;
            }

            final uid =
            _uidToHex(androidTag.id);

            await _safeStopSession();

            if (!mounted) return;

            setState(() {
              _uid = uid;
              _isScanning = false;
              _status =
              'Đang kiểm tra thẻ...';
            });

            await _processAttendance(uid);
          } catch (e) {
            await _safeStopSession();

            _showResult(
              status:
              'Lỗi khi xử lý NFC: $e',
            );
          }
        },
      );
    } catch (e) {
      await _safeStopSession();

      _showResult(
        status:
        'Không thể bắt đầu quét NFC: $e',
      );
    }
  }

  Future<void> _processAttendance(
      String uid,
      ) async {
    try {
      // Phase 12: UID phải tồn tại.
      final card =
      await DatabaseHelper.instance
          .getNfcCardByUid(uid);

      if (card == null) {
        _showResult(
          status: 'THẺ KHÔNG XÁC ĐỊNH',
          uid: uid,
          employee: '--',
          action: 'TỪ CHỐI',
          time: _formatTime(DateTime.now()),
          details:
          'UID chưa được đăng ký trong hệ thống.',
        );
        return;
      }

      // Phase 12: card phải ACTIVE.
      if (card.status != 'ACTIVE') {
        _showResult(
          status: 'THẺ NFC ĐÃ BỊ KHÓA',
          uid: uid,
          employee: '--',
          action: 'TỪ CHỐI',
          time: _formatTime(DateTime.now()),
          details:
          'Trạng thái thẻ: ${card.status}',
        );
        return;
      }

      final employee =
      await DatabaseHelper.instance
          .getEmployeeById(
        card.employeeId,
      );

      if (employee == null) {
        _showResult(
          status:
          'KHÔNG TÌM THẤY NHÂN VIÊN',
          uid: uid,
          employee: '--',
          action: 'TỪ CHỐI',
          time: _formatTime(DateTime.now()),
          details:
          'Thẻ có trong hệ thống nhưng không tìm thấy nhân viên.',
        );
        return;
      }

      final employeeLabel =
          '${employee.employeeCode} - '
          '${employee.fullName}';

      // Phase 12: employee phải ACTIVE.
      if (employee.status != 'ACTIVE') {
        _showResult(
          status:
          'NHÂN VIÊN ĐÃ BỊ KHÓA',
          uid: uid,
          employee: employeeLabel,
          action: 'TỪ CHỐI',
          time: _formatTime(DateTime.now()),
          details:
          'Trạng thái nhân viên: ${employee.status}',
        );
        return;
      }

      // Phase 10: phải có ca ACTIVE.
      final shift =
      await DatabaseHelper.instance
          .getActiveShift();

      if (shift == null) {
        _showResult(
          status:
          'CHƯA CÓ CA LÀM ACTIVE',
          uid: uid,
          employee: employeeLabel,
          action: 'TỪ CHỐI',
          time: _formatTime(DateTime.now()),
          details:
          'Hãy cấu hình ca làm trước khi chấm công.',
        );
        return;
      }

      final now = DateTime.now();

      // Phase 8: chống quét lặp.
      final lastScan = _lastScans[uid];

      if (lastScan != null) {
        final difference =
        now.difference(lastScan);

        if (difference < _cooldown) {
          final remain =
              _cooldown.inSeconds -
                  difference.inSeconds;

          _showResult(
            status:
            'QUÉT QUÁ NHANH - '
                'THỬ LẠI SAU $remain GIÂY',
            uid: uid,
            employee: employeeLabel,
            action: 'BỎ QUA',
            time: _formatTime(now),
            details:
            'Chống quét trùng NFC.',
          );
          return;
        }
      }

      _lastScans[uid] = now;

      final today = _dateKey(now);

      final attendance =
      await DatabaseHelper.instance
          .getAttendanceByEmployeeAndDate(
        employee.id!,
        today,
      );

      // Phase 7 + 10 + 11: Check-in.
      if (attendance == null) {
        final late =
        _lateMinutes(now, shift);

        await DatabaseHelper.instance
            .insertAttendance(
          Attendance(
            employeeId: employee.id!,
            date: today,
            checkIn: now,
            shiftId: shift.id,
            lateMinutes: late,
            status: 'WORKING',
          ),
        );

        _showResult(
          status: 'CHECK-IN THÀNH CÔNG',
          uid: uid,
          employee: employeeLabel,
          action: 'CHECK-IN',
          time: _formatTime(now),
          details:
          'Ca: ${shift.name}\n'
              'Giờ ca: ${shift.startTime} - ${shift.endTime}\n'
              'Đi trễ: $late phút',
        );
        return;
      }

      // Phase 9 + 11: Check-out + tính công.
      if (attendance.checkOut == null) {
        if (attendance.id == null) {
          throw Exception(
            'Attendance không có ID',
          );
        }

        final early =
        _earlyMinutes(now, shift);
        final overtime =
        _overtimeMinutes(now, shift);
        final working =
        _workingMinutes(
          attendance.checkIn,
          now,
          shift,
        );

        final finalStatus =
        _finalStatus(
          late: attendance.lateMinutes,
          early: early,
        );

        final rows =
        await DatabaseHelper.instance
            .completeAttendance(
          attendanceId: attendance.id!,
          checkOut: now,
          earlyMinutes: early,
          overtimeMinutes: overtime,
          totalWorkingMinutes: working,
          status: finalStatus,
        );

        if (rows == 0) {
          throw Exception(
            'Không thể cập nhật Check-out',
          );
        }

        _showResult(
          status:
          'CHECK-OUT THÀNH CÔNG',
          uid: uid,
          employee: employeeLabel,
          action: 'CHECK-OUT',
          time: _formatTime(now),
          details:
          'Đi trễ: ${attendance.lateMinutes} phút\n'
              'Về sớm: $early phút\n'
              'Tăng ca: $overtime phút\n'
              'Tổng làm: $working phút\n'
              'Trạng thái: ${_statusText(finalStatus)}',
        );
        return;
      }

      // Phase 12: không cho ghi lần thứ ba.
      _showResult(
        status:
        'HÔM NAY ĐÃ CHẤM CÔNG ĐẦY ĐỦ',
        uid: uid,
        employee: employeeLabel,
        action: 'BỎ QUA',
        time: _formatTime(now),
        details:
        'Check-in: ${_formatTime(attendance.checkIn)}\n'
            'Check-out: ${_formatTime(attendance.checkOut!)}\n'
            'Trạng thái: ${_statusText(attendance.status)}',
      );
    } catch (e) {
      _showResult(
        status: 'Lỗi chấm công: $e',
        uid: uid,
        action: 'LỖI',
        time: _formatTime(DateTime.now()),
        details:
        'Không ghi thêm dữ liệu chấm công.',
      );
    }
  }

  Future<void> _stopScan() async {
    await _safeStopSession();

    if (!mounted) return;

    setState(() {
      _isScanning = false;
      _isProcessing = false;
      _status = 'Đã dừng quét NFC';
    });
  }

  @override
  void dispose() {
    if (_isScanning) {
      NfcManager.instance.stopSession();
    }

    super.dispose();
  }

  Widget _infoRow(
      String label,
      String value,
      ) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight:
                FontWeight.bold,
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
        const Text('Chấm công NFC'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Quản lý ca làm',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const ShiftScreen(),
                ),
              );
            },
            icon: const Icon(
              Icons.schedule,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
          const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 10),

              Icon(
                _isScanning
                    ? Icons.nfc
                    : Icons.badge_outlined,
                size: 90,
              ),

              const SizedBox(height: 20),

              Text(
                _status,
                textAlign:
                TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(height: 22),

              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey,
                  ),
                  borderRadius:
                  BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    _infoRow(
                      'Nhân viên',
                      _employee,
                    ),
                    _infoRow('UID', _uid),
                    _infoRow(
                      'Thao tác',
                      _action,
                    ),
                    _infoRow(
                      'Thời gian',
                      _time,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey,
                  ),
                  borderRadius:
                  BorderRadius.circular(12),
                ),
                child: Text(
                  _details,
                  textAlign: TextAlign.left,
                ),
              ),

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                child:
                ElevatedButton.icon(
                  onPressed: _isScanning
                      ? _stopScan
                      : _startNfcScan,
                  icon: Icon(
                    _isScanning
                        ? Icons.stop
                        : Icons.nfc,
                  ),
                  label: Text(
                    _isScanning
                        ? 'DỪNG QUÉT'
                        : 'QUÉT THẺ NFC',
                  ),
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Chống quét trùng: 10 giây',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
