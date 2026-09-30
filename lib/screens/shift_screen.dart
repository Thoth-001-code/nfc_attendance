import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/shift.dart';

class ShiftScreen extends StatefulWidget {
  const ShiftScreen({super.key});

  @override
  State<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends State<ShiftScreen> {
  Shift? _shift;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadShift();
  }

  Future<void> _loadShift() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final shift =
      await DatabaseHelper.instance.getActiveShift();

      if (!mounted) return;

      setState(() {
        _shift = shift;
        _loading = false;
      });
    } catch (e) {
      debugPrint('LỖI LOAD SHIFT: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể tải ca làm: $e',
          ),
        ),
      );
    }
  }

  Future<void> _editShift() async {
    final shift = _shift;

    if (shift == null || shift.id == null) {
      return;
    }

    final result = await showDialog<Shift>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _ShiftEditDialog(
          shift: shift,
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await DatabaseHelper.instance.updateShift(result);

      if (!mounted) return;

      await _loadShift();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã cập nhật ca làm',
          ),
        ),
      );
    } catch (e) {
      debugPrint('LỖI UPDATE SHIFT: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể cập nhật ca làm: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _row(
      String label,
      String value,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shift = _shift;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quản lý ca làm',
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : shift == null
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.schedule_outlined,
              size: 72,
            ),
            const SizedBox(height: 16),
            const Text(
              'Không có ca làm ACTIVE',
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadShift,
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'TẢI LẠI',
              ),
            ),
          ],
        ),
      )
          : SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(
                Icons.schedule,
                size: 90,
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding:
                  const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Text(
                        shift.name,
                        style:
                        const TextStyle(
                          fontSize: 20,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      _row(
                        'Giờ vào',
                        shift.startTime,
                      ),
                      _row(
                        'Giờ ra',
                        shift.endTime,
                      ),
                      _row(
                        'Nghỉ',
                        '${shift.breakStart} - '
                            '${shift.breakEnd}',
                      ),
                      _row(
                        'Ân hạn',
                        '${shift.graceMinutes} phút',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                  _saving ? null : _editShift,
                  icon: _saving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(
                    Icons.edit,
                  ),
                  label: Text(
                    _saving
                        ? 'ĐANG LƯU...'
                        : 'CHỈNH SỬA CA',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================
// DIALOG CHỈNH SỬA CA
// Tách riêng StatefulWidget để controller/context có vòng đời
// độc lập và an toàn với showTimePicker.
// =========================================================

class _ShiftEditDialog extends StatefulWidget {
  final Shift shift;

  const _ShiftEditDialog({
    required this.shift,
  });

  @override
  State<_ShiftEditDialog> createState() =>
      _ShiftEditDialogState();
}

class _ShiftEditDialogState
    extends State<_ShiftEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _graceController;

  late String _startTime;
  late String _endTime;
  late String _breakStart;
  late String _breakEnd;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.shift.name,
    );

    _graceController = TextEditingController(
      text: widget.shift.graceMinutes.toString(),
    );

    _startTime = widget.shift.startTime;
    _endTime = widget.shift.endTime;
    _breakStart = widget.shift.breakStart;
    _breakEnd = widget.shift.breakEnd;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _graceController.dispose();
    super.dispose();
  }

  TimeOfDay _parseTime(
      String value,
      ) {
    final parts = value.split(':');

    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  String _timeToText(
      TimeOfDay value,
      ) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  int _minutes(
      String value,
      ) {
    final parts = value.split(':');

    return int.parse(parts[0]) * 60 +
        int.parse(parts[1]);
  }

  Future<void> _chooseTime({
    required String current,
    required void Function(String) onChanged,
  }) async {
    final value = await showTimePicker(
      context: context,
      initialTime: _parseTime(current),
    );

    if (value == null || !mounted) {
      return;
    }

    setState(() {
      onChanged(
        _timeToText(value),
      );
    });
  }

  void _showError(
      String message,
      ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  void _save() {
    final name =
    _nameController.text.trim();

    final grace = int.tryParse(
      _graceController.text.trim(),
    );

    if (name.isEmpty) {
      _showError(
        'Vui lòng nhập tên ca',
      );
      return;
    }

    if (grace == null ||
        grace < 0 ||
        grace > 120) {
      _showError(
        'Ân hạn phải từ 0 đến 120 phút',
      );
      return;
    }

    final start =
    _minutes(_startTime);
    final breakS =
    _minutes(_breakStart);
    final breakE =
    _minutes(_breakEnd);
    final end =
    _minutes(_endTime);

    if (!(start < breakS &&
        breakS < breakE &&
        breakE < end)) {
      _showError(
        'Thời gian phải theo thứ tự: '
            'bắt đầu < bắt đầu nghỉ < '
            'kết thúc nghỉ < kết thúc',
      );
      return;
    }

    final result = Shift(
      id: widget.shift.id,
      name: name,
      startTime: _startTime,
      endTime: _endTime,
      breakStart: _breakStart,
      breakEnd: _breakEnd,
      graceMinutes: grace,
      isActive: true,
    );

    Navigator.of(context).pop(result);
  }

  Widget _timeTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.access_time,
            size: 20,
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Cấu hình ca làm',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration:
              const InputDecoration(
                labelText: 'Tên ca',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            _timeTile(
              label: 'Bắt đầu',
              value: _startTime,
              onTap: () {
                _chooseTime(
                  current: _startTime,
                  onChanged: (value) {
                    _startTime = value;
                  },
                );
              },
            ),

            _timeTile(
              label: 'Kết thúc',
              value: _endTime,
              onTap: () {
                _chooseTime(
                  current: _endTime,
                  onChanged: (value) {
                    _endTime = value;
                  },
                );
              },
            ),

            _timeTile(
              label: 'Bắt đầu nghỉ',
              value: _breakStart,
              onTap: () {
                _chooseTime(
                  current: _breakStart,
                  onChanged: (value) {
                    _breakStart = value;
                  },
                );
              },
            ),

            _timeTile(
              label: 'Kết thúc nghỉ',
              value: _breakEnd,
              onTap: () {
                _chooseTime(
                  current: _breakEnd,
                  onChanged: (value) {
                    _breakEnd = value;
                  },
                );
              },
            ),

            const SizedBox(height: 8),

            TextField(
              controller: _graceController,
              keyboardType:
              TextInputType.number,
              decoration:
              const InputDecoration(
                labelText:
                'Ân hạn đi trễ (phút)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('HỦY'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('LƯU'),
        ),
      ],
    );
  }
}
