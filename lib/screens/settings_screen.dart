import 'dart:io';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  bool _processing = false;
  List<File> _backups = [];

  String _fileName(String filePath) {
    return filePath
        .replaceAll('\\', '/')
        .split('/')
        .last;
  }

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    try {
      final backups = await DatabaseHelper.instance.getBackups();
      if (!mounted) return;
      setState(() {
        _backups = backups;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('Không thể đọc backup: $e');
    }
  }

  String _formatDate(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _createBackup() async {
    if (_processing) return;
    setState(() => _processing = true);

    try {
      final file = await DatabaseHelper.instance.createBackup();
      await _loadBackups();
      _message('Backup thành công:\n${_fileName(file.path)}');
    } catch (e) {
      _message('Backup thất bại: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _showBackupInfo(File file) async {
    try {
      final summary =
      await DatabaseHelper.instance.getBackupSummary(file.path);

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Thông tin bản sao lưu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_fileName(file.path)),
              const SizedBox(height: 12),
              Text('Nhân viên: ${summary['employees']}'),
              Text('Thẻ NFC: ${summary['cards']}'),
              Text('Ca làm: ${summary['shifts']}'),
              Text('Chấm công: ${summary['attendances']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ĐÓNG'),
            ),
          ],
        ),
      );
    } catch (e) {
      _message('Không đọc được backup: $e');
    }
  }

  Future<void> _restoreBackup(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Khôi phục dữ liệu?'),
        content: Text(
          'Toàn bộ dữ liệu hiện tại sẽ được thay bằng:\n\n'
              '${_fileName(file.path)}\n\n'
              'Nếu restore gặp lỗi, ứng dụng sẽ tự trả lại database cũ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('KHÔI PHỤC'),
          ),
        ],
      ),
    );

    if (confirmed != true || _processing) return;
    setState(() => _processing = true);

    try {
      await DatabaseHelper.instance.restoreBackup(file.path);
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Khôi phục thành công'),
          content: const Text(
            'Database đã được khôi phục. Hãy kiểm tra lại '
                'Nhân viên, Lịch sử và Dashboard.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      _message('$e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _deleteBackup(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa backup?'),
        content: Text(_fileName(file.path)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('HỦY'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('XÓA'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await DatabaseHelper.instance.deleteBackup(file.path);
      await _loadBackups();
      _message('Đã xóa backup.');
    } catch (e) {
      _message('Không thể xóa backup: $e');
    }
  }

  Widget _backupCard(File file) {
    final modified = file.lastModifiedSync();
    final size = file.lengthSync();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.storage)),
        title: Text(
          _fileName(file.path),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${_formatDate(modified)}  •  ${_formatSize(size)}',
        ),
        onTap: () => _showBackupInfo(file),
        trailing: PopupMenuButton<String>(
          enabled: !_processing,
          onSelected: (value) {
            if (value == 'restore') {
              _restoreBackup(file);
            } else if (value == 'delete') {
              _deleteBackup(file);
            } else {
              _showBackupInfo(file);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'info',
              child: Text('Xem thông tin'),
            ),
            PopupMenuItem(
              value: 'restore',
              child: Text('Khôi phục'),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text('Xóa backup'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _processing ? null : _loadBackups,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadBackups,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.backup_outlined, size: 52),
                    SizedBox(height: 10),
                    Text(
                      'Backup / Restore SQLite',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Sao lưu toàn bộ nhân viên, thẻ NFC, '
                          'ca làm và lịch sử chấm công.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _processing ? null : _createBackup,
                icon: const Icon(Icons.backup),
                label: const Text('TẠO BẢN SAO LƯU'),
              ),
            ),
            if (_processing) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Các bản sao lưu',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text('${_backups.length} bản'),
              ],
            ),
            const SizedBox(height: 10),
            if (_backups.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 35),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 55),
                    SizedBox(height: 10),
                    Text('Chưa có bản sao lưu'),
                  ],
                ),
              )
            else
              ..._backups.map(_backupCard),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
