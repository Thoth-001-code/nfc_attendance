import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

import '../database/database_helper.dart';
import '../models/employee.dart';
import '../services/nfc_security_service.dart';

class EmployeeScreen extends StatefulWidget {
  const EmployeeScreen({
    super.key,
  });

  @override
  State<EmployeeScreen> createState() =>
      _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  // =====================================================
  // CONTROLLER
  // =====================================================

  final TextEditingController _codeController =
  TextEditingController();

  final TextEditingController _nameController =
  TextEditingController();

  // =====================================================
  // DANH SÁCH NHÂN VIÊN
  // =====================================================

  List<Employee> _employees = [];

  bool _isLoading = true;

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {
    super.initState();

    _loadEmployees();
  }

  // =====================================================
  // LOAD NHÂN VIÊN
  // =====================================================

  Future<void> _loadEmployees() async {
    try {
      final data =
      await DatabaseHelper.instance.getEmployees();

      if (!mounted) return;

      setState(() {
        _employees = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint(
        'LỖI LOAD EMPLOYEE: $e',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Lỗi đọc dữ liệu: $e',
      );
    }
  }

  // =====================================================
  // THÔNG BÁO
  // =====================================================

  void _showMessage(
      String message,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // =====================================================
  // THÊM NHÂN VIÊN
  // =====================================================

  Future<void> _addEmployee() async {
    final code =
    _codeController.text.trim().toUpperCase();

    final name =
    _nameController.text.trim();

    if (code.isEmpty || name.isEmpty) {
      _showMessage(
        'Vui lòng nhập đầy đủ thông tin',
      );
      return;
    }

    try {
      // Kiểm tra mã trùng
      final exists =
      await DatabaseHelper.instance
          .employeeCodeExists(
        code,
      );

      if (!mounted) return;

      if (exists) {
        _showMessage(
          'Mã nhân viên $code đã tồn tại',
        );
        return;
      }

      // Tạo nhân viên
      final employee = Employee(
        employeeCode: code,
        fullName: name,
        status: 'ACTIVE',
      );

      // Lưu SQLite
      await DatabaseHelper.instance
          .insertEmployee(
        employee,
      );

      if (!mounted) return;

      _codeController.clear();
      _nameController.clear();

      FocusScope.of(context).unfocus();

      await _loadEmployees();

      if (!mounted) return;

      _showMessage(
        'Thêm nhân viên $code thành công',
      );
    } catch (e) {
      debugPrint(
        'LỖI THÊM NHÂN VIÊN: $e',
      );

      if (!mounted) return;

      _showMessage(
        'Lỗi khi thêm nhân viên: $e',
      );
    }
  }

  // =====================================================
  // SỬA NHÂN VIÊN
  // =====================================================

  Future<void> _showEditDialog(
      Employee employee,
      ) async {
    final result =
    await showDialog<Map<String, String>>(
      context: context,

      builder: (dialogContext) {
        final codeController =
        TextEditingController(
          text: employee.employeeCode,
        );

        final nameController =
        TextEditingController(
          text: employee.fullName,
        );

        return AlertDialog(
          title: const Text(
            'Sửa nhân viên',
          ),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration:
                const InputDecoration(
                  labelText: 'Mã nhân viên',
                  border:
                  OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              TextField(
                controller: nameController,
                decoration:
                const InputDecoration(
                  labelText: 'Họ và tên',
                  border:
                  OutlineInputBorder(),
                ),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();
              },
              child:
              const Text('HỦY'),
            ),

            ElevatedButton(
              onPressed: () {
                final code =
                codeController.text
                    .trim()
                    .toUpperCase();

                final name =
                nameController.text
                    .trim();

                if (code.isEmpty ||
                    name.isEmpty) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Vui lòng nhập đầy đủ thông tin',
                      ),
                    ),
                  );

                  return;
                }

                Navigator.of(
                  dialogContext,
                ).pop({
                  'code': code,
                  'name': name,
                });
              },
              child:
              const Text('LƯU'),
            ),
          ],
        );
      },
    );

    if (result == null) {
      return;
    }

    if (!mounted) return;

    final newCode =
    result['code'];

    final newName =
    result['name'];

    if (newCode == null ||
        newName == null) {
      return;
    }

    try {
      final exists =
      await DatabaseHelper.instance
          .employeeCodeExists(
        newCode,
        excludeId: employee.id,
      );

      if (!mounted) return;

      if (exists) {
        _showMessage(
          'Mã nhân viên $newCode đã tồn tại',
        );
        return;
      }

      final updatedEmployee =
      Employee(
        id: employee.id,
        employeeCode: newCode,
        fullName: newName,
        status: employee.status,
      );

      final rows =
      await DatabaseHelper.instance
          .updateEmployee(
        updatedEmployee,
      );

      if (!mounted) return;

      if (rows == 0) {
        _showMessage(
          'Không tìm thấy nhân viên cần sửa',
        );
        return;
      }

      await _loadEmployees();

      if (!mounted) return;

      _showMessage(
        'Cập nhật nhân viên thành công',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'LỖI UPDATE EMPLOYEE: $e',
      );

      debugPrint(
        'STACK TRACE:\n$stackTrace',
      );

      if (!mounted) return;

      _showMessage(
        'Không thể cập nhật nhân viên: $e',
      );
    }
  }

  // =====================================================
  // GÁN THẺ NFC + BẢO MẬT NTAG215
  // =====================================================

  Future<void> _assignNfcCard(
      Employee employee,
      ) async {
    if (employee.id == null) {
      _showMessage('Không tìm thấy ID nhân viên');
      return;
    }

    if (employee.status != 'ACTIVE') {
      _showMessage(
        'Nhân viên đang bị khóa. '
            'Hãy mở khóa trước khi gán thẻ.',
      );
      return;
    }

    try {
      final availability =
      await NfcManager.instance.checkAvailability();

      if (availability != NfcAvailability.enabled) {
        _showMessage(
          'NFC chưa được bật hoặc thiết bị không hỗ trợ NFC',
        );
        return;
      }

      if (!mounted) return;

      _showMessage(
        'Đưa thẻ NTAG215 của ${employee.fullName} '
            'lại gần điện thoại và giữ nguyên cho đến khi hoàn tất',
      );

      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
        },
        onDiscovered: (NfcTag tag) async {
          try {
            // 1. Kiểm tra NTAG215 + cấu hình PWD/PACK + AUTH0.
            final result =
            await NfcSecurityService.protectDiscoveredTag(tag);

            // 2. Chỉ lưu SQLite sau khi bảo mật vật lý thành công.
            await DatabaseHelper.instance.assignNfcCard(
              employee.id!,
              result.uid,
            );

            await NfcManager.instance.stopSession();

            if (!mounted) return;

            _showMessage(
              'Gán thẻ thành công!\n'
                  '${employee.employeeCode} - ${employee.fullName}\n'
                  'UID: ${result.uid}\n'
                  'Bảo mật NTAG215: ĐÃ BẬT',
            );
          } catch (e) {
            try {
              await NfcManager.instance.stopSession();
            } catch (_) {}

            debugPrint('LỖI GÁN NFC: $e');

            if (!mounted) return;

            final message = e.toString().replaceFirst(
              'Exception: ',
              '',
            );

            _showMessage(message);
          }
        },
      );
    } catch (e) {
      debugPrint('LỖI KHỞI ĐỘNG NFC: $e');

      if (!mounted) return;

      _showMessage(
        'Không thể bắt đầu quét NFC: $e',
      );
    }
  }

  // =====================================================
  // XEM THẺ NFC
  // =====================================================

  Future<void> _checkNfcCard(
      Employee employee,
      ) async {
    if (employee.id == null) {
      _showMessage(
        'Không tìm thấy ID nhân viên',
      );
      return;
    }

    try {
      final card =
      await DatabaseHelper.instance
          .getNfcCardByEmployee(
        employee.id!,
      );

      if (!mounted) return;

      if (card == null) {
        _showMessage(
          '${employee.employeeCode} '
              'chưa có thẻ NFC',
        );
        return;
      }

      await showDialog(
        context: context,

        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Thông tin thẻ NFC',
            ),

            content: Column(
              mainAxisSize:
              MainAxisSize.min,

              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Text(
                  'Nhân viên: '
                      '${employee.fullName}',
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  'Mã NV: '
                      '${employee.employeeCode}',
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  'Employee ID: '
                      '${employee.id}',
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  'Card ID: ${card.id}',
                ),

                const SizedBox(
                  height: 8,
                ),

                const Text(
                  'UID:',
                  style: TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                SelectableText(
                  card.uid,
                  style:
                  const TextStyle(
                    fontSize: 17,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  'Trạng thái thẻ: '
                      '${card.status}',
                ),
              ],
            ),

            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop();
                },
                child:
                const Text(
                  'ĐÓNG',
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint(
        'LỖI KIỂM TRA NFC: $e',
      );

      if (!mounted) return;

      _showMessage(
        'Không thể đọc thông tin thẻ: $e',
      );
    }
  }

  // =====================================================
  // HỦY GÁN THẺ NFC
  // =====================================================

  Future<void> _removeNfcCard(
      Employee employee,
      ) async {
    if (employee.id == null) {
      _showMessage(
        'Không tìm thấy ID nhân viên',
      );
      return;
    }

    try {
      // Kiểm tra nhân viên có thẻ hay không
      final card =
      await DatabaseHelper.instance
          .getNfcCardByEmployee(
        employee.id!,
      );

      if (!mounted) return;

      if (card == null) {
        _showMessage(
          '${employee.employeeCode} '
              'chưa có thẻ NFC',
        );
        return;
      }

      // Hộp thoại xác nhận
      final confirm =
      await showDialog<bool>(
        context: context,

        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Hủy gán thẻ NFC',
            ),

            content: Column(
              mainAxisSize:
              MainAxisSize.min,

              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Text(
                  'Nhân viên: '
                      '${employee.fullName}',
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  'Mã NV: '
                      '${employee.employeeCode}',
                ),

                const SizedBox(
                  height: 8,
                ),

                const Text(
                  'UID:',
                  style: TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                SelectableText(
                  card.uid,
                ),

                const SizedBox(
                  height: 16,
                ),

                const Text(
                  'Bạn có chắc muốn hủy '
                      'gán thẻ này?',
                  style: TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ],
            ),

            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(false);
                },
                child:
                const Text(
                  'HỦY',
                ),
              ),

              ElevatedButton(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(true);
                },
                child:
                const Text(
                  'XÁC NHẬN',
                ),
              ),
            ],
          );
        },
      );

      if (confirm != true) {
        return;
      }

      // Xóa liên kết trong SQLite
      final rows =
      await DatabaseHelper.instance
          .removeNfcCard(
        employee.id!,
      );

      if (!mounted) return;

      if (rows == 0) {
        _showMessage(
          'Không tìm thấy thẻ để hủy',
        );
        return;
      }

      _showMessage(
        'Đã hủy gán thẻ NFC của '
            '${employee.employeeCode}',
      );
    } catch (e) {
      debugPrint(
        'LỖI HỦY GÁN NFC: $e',
      );

      if (!mounted) return;

      _showMessage(
        'Không thể hủy gán thẻ: $e',
      );
    }
  }
// =====================================================
// KHÓA / MỞ KHÓA THẺ NFC
// =====================================================

  Future<void> _manageNfcCards(
      Employee employee,
      ) async {
    if (employee.id == null) {
      _showMessage('Không tìm thấy ID nhân viên');
      return;
    }

    try {
      final cards = await DatabaseHelper.instance
          .getNfcCardsByEmployee(employee.id!);

      if (!mounted) return;

      if (cards.isEmpty) {
        _showMessage(
          '${employee.employeeCode} chưa có thẻ NFC',
        );
        return;
      }

      await showDialog(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> reloadCards() async {
                final newCards = await DatabaseHelper.instance
                    .getNfcCardsByEmployee(employee.id!);

                cards
                  ..clear()
                  ..addAll(newCards);

                if (dialogContext.mounted) {
                  setDialogState(() {});
                }
              }

              Future<void> deleteCard(int index) async {
                final card = cards[index];

                final confirm = await showDialog<bool>(
                  context: dialogContext,
                  builder: (confirmContext) {
                    return AlertDialog(
                      title: const Text('Xóa hẳn thẻ NFC?'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nhân viên: ${employee.fullName}',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Mã NV: ${employee.employeeCode}',
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'UID:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(card.uid),
                          const SizedBox(height: 16),
                          const Text(
                            'Thẻ sẽ bị xóa vĩnh viễn khỏi '
                                'database và UID này có thể được '
                                'gán lại cho nhân viên khác.',
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(confirmContext)
                                .pop(false);
                          },
                          child: const Text('HỦY'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(confirmContext)
                                .pop(true);
                          },
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('XÓA HẲN'),
                        ),
                      ],
                    );
                  },
                );

                if (confirm != true) return;

                try {
                  final rows = await DatabaseHelper.instance
                      .deleteNfcCardById(card.id!);

                  if (!mounted) return;

                  if (rows == 0) {
                    _showMessage(
                      'Không tìm thấy thẻ cần xóa',
                    );
                    return;
                  }

                  await reloadCards();

                  if (!mounted) return;

                  _showMessage(
                    'Đã xóa hẳn thẻ ${card.uid}',
                  );

                  // Nếu vừa xóa thẻ cuối cùng thì đóng dialog.
                  if (cards.isEmpty &&
                      dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                } catch (e) {
                  debugPrint('LỖI XÓA THẺ NFC: $e');

                  if (!mounted) return;

                  _showMessage(
                    'Không thể xóa thẻ NFC: $e',
                  );
                }
              }

              return AlertDialog(
                title: Text(
                  'Thẻ NFC - ${employee.employeeCode}',
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: cards.length,
                    itemBuilder: (context, index) {
                      final card = cards[index];
                      final isActive =
                          card.status == 'ACTIVE';

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: Icon(
                              isActive
                                  ? Icons.nfc
                                  : Icons.block,
                            ),
                            title: Text(
                              card.uid,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Trạng thái: '
                                  '${isActive ? "ACTIVE" : "BLOCKED"}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    try {
                                      if (isActive) {
                                        await DatabaseHelper
                                            .instance
                                            .blockNfcCard(
                                          card.id!,
                                        );
                                      } else {
                                        await DatabaseHelper
                                            .instance
                                            .activateNfcCard(
                                          card.id!,
                                          employee.id!,
                                        );
                                      }

                                      if (!mounted) return;

                                      await reloadCards();

                                      if (!mounted) return;

                                      _showMessage(
                                        isActive
                                            ? 'Đã khóa thẻ ${card.uid}'
                                            : 'Đã mở khóa thẻ ${card.uid}',
                                      );
                                    } catch (e) {
                                      debugPrint(
                                        'LỖI THAY ĐỔI '
                                            'TRẠNG THÁI THẺ: $e',
                                      );

                                      if (!mounted) return;

                                      _showMessage(
                                        'Không thể thay đổi '
                                            'trạng thái thẻ',
                                      );
                                    }
                                  },
                                  child: Text(
                                    isActive
                                        ? 'KHÓA'
                                        : 'MỞ KHÓA',
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Xóa hẳn thẻ',
                                  onPressed: () =>
                                      deleteCard(index),
                                  icon: const Icon(
                                    Icons.delete_forever,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('ĐÓNG'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      debugPrint('LỖI LOAD NFC CARD: $e');

      if (!mounted) return;

      _showMessage(
        'Không thể đọc danh sách thẻ: $e',
      );
    }
  }

  // =====================================================
  // KHÓA / MỞ KHÓA NHÂN VIÊN
  // =====================================================

  Future<void> _toggleStatus(
      Employee employee,
      ) async {
    if (employee.id == null) {
      return;
    }

    final newStatus =
    employee.status == 'ACTIVE'
        ? 'BLOCKED'
        : 'ACTIVE';

    try {
      await DatabaseHelper.instance
          .updateEmployeeStatus(
        employee.id!,
        newStatus,
      );

      if (!mounted) return;

      await _loadEmployees();

      if (!mounted) return;

      if (newStatus == 'BLOCKED') {
        _showMessage(
          'Đã khóa ${employee.fullName}',
        );
      } else {
        _showMessage(
          'Đã mở khóa ${employee.fullName}',
        );
      }
    } catch (e) {
      debugPrint(
        'LỖI STATUS: $e',
      );

      if (!mounted) return;

      _showMessage(
        'Không thể thay đổi trạng thái',
      );
    }
  }

  // =====================================================
  // XÓA NHÂN VIÊN
  // =====================================================

  Future<void> _deleteEmployee(
      Employee employee,
      ) async {
    if (employee.id == null) {
      return;
    }

    final confirm =
    await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title:
          const Text(
            'Xóa nhân viên',
          ),

          content: Text(
            'Bạn có chắc muốn xóa '
                '${employee.fullName}?',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child:
              const Text(
                'HỦY',
              ),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child:
              const Text(
                'XÓA',
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      await DatabaseHelper.instance
          .deleteEmployee(
        employee.id!,
      );

      if (!mounted) return;

      await _loadEmployees();

      if (!mounted) return;

      _showMessage(
        'Đã xóa ${employee.fullName}',
      );
    } catch (e) {
      debugPrint(
        'LỖI XÓA: $e',
      );

      if (!mounted) return;

      _showMessage(
        'Không thể xóa nhân viên',
      );
    }
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();

    super.dispose();
  }

  // =====================================================
  // GIAO DIỆN
  // =====================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      appBar: AppBar(
        title:
        const Text(
          'Quản lý nhân viên',
        ),
        centerTitle: true,
      ),

      body: Padding(
        padding:
        const EdgeInsets.all(
          16,
        ),

        child: Column(
          children: [
            // =========================================
            // MÃ NHÂN VIÊN
            // =========================================

            TextField(
              controller:
              _codeController,

              textCapitalization:
              TextCapitalization
                  .characters,

              decoration:
              const InputDecoration(
                labelText:
                'Mã nhân viên',

                hintText:
                'Ví dụ: NV001',

                prefixIcon:
                Icon(
                  Icons.badge,
                ),

                border:
                OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            // =========================================
            // HỌ TÊN
            // =========================================

            TextField(
              controller:
              _nameController,

              decoration:
              const InputDecoration(
                labelText:
                'Họ và tên',

                hintText:
                'Nguyễn Văn A',

                prefixIcon:
                Icon(
                  Icons.person,
                ),

                border:
                OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            // =========================================
            // THÊM NHÂN VIÊN
            // =========================================

            SizedBox(
              width:
              double.infinity,

              child:
              ElevatedButton.icon(
                onPressed:
                _addEmployee,

                icon:
                const Icon(
                  Icons.person_add,
                ),

                label:
                const Text(
                  'THÊM NHÂN VIÊN',
                ),
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            // =========================================
            // TIÊU ĐỀ
            // =========================================

            Row(
              children: [
                const Icon(
                  Icons.people,
                ),

                const SizedBox(
                  width: 8,
                ),

                Text(
                  'Danh sách nhân viên '
                      '(${_employees.length})',

                  style:
                  const TextStyle(
                    fontSize: 18,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ],
            ),

            const Divider(),

            // =========================================
            // DANH SÁCH
            // =========================================

            Expanded(
              child: _isLoading
                  ? const Center(
                child:
                CircularProgressIndicator(),
              )
                  : _employees.isEmpty
                  ? const Center(
                child: Text(
                  'Chưa có nhân viên nào',
                ),
              )
                  : ListView.builder(
                itemCount:
                _employees.length,

                itemBuilder:
                    (
                    context,
                    index,
                    ) {
                  final employee =
                  _employees[
                  index];

                  final isActive =
                      employee.status ==
                          'ACTIVE';

                  return Card(
                    margin:
                    const EdgeInsets
                        .only(
                      bottom: 10,
                    ),

                    child:
                    ListTile(
                      // ICON
                      leading:
                      CircleAvatar(
                        child: Icon(
                          isActive
                              ? Icons
                              .person
                              : Icons
                              .person_off,
                        ),
                      ),

                      // TÊN
                      title: Text(
                        employee
                            .fullName,

                        style:
                        const TextStyle(
                          fontWeight:
                          FontWeight
                              .bold,
                        ),
                      ),

                      // MÃ + STATUS
                      subtitle:
                      Text(
                        'Mã: '
                            '${employee.employeeCode}\n'
                            'Trạng thái: '
                            '${isActive ? "Đang hoạt động" : "Đã khóa"}',
                      ),

                      isThreeLine:
                      true,

                      // =================================
                      // MENU
                      // =================================

                      trailing:
                      PopupMenuButton<
                          String>(
                        onSelected:
                            (value) {
                          // Sửa
                          if (value ==
                              'edit') {
                            _showEditDialog(
                              employee,
                            );
                          }

                          // Gán NFC
                          if (value ==
                              'assign_nfc') {
                            _assignNfcCard(
                              employee,
                            );
                          }

                          // Xem NFC
                          if (value ==
                              'check_nfc') {
                            _checkNfcCard(
                              employee,
                            );
                          }
                          // Khorana
                          if (value == 'manage_nfc') {
                            _manageNfcCards(
                              employee,
                            );
                          }

                          // Hủy gán NFC
                          if (value ==
                              'remove_nfc') {
                            _removeNfcCard(
                              employee,
                            );
                          }

                          // Khóa / mở khóa
                          if (value ==
                              'status') {
                            _toggleStatus(
                              employee,
                            );
                          }

                          // Xóa
                          if (value ==
                              'delete') {
                            _deleteEmployee(
                              employee,
                            );
                          }
                        },

                        itemBuilder:
                            (context) {
                          return [
                            // =============================
                            // SỬA
                            // =============================

                            const PopupMenuItem(
                              value:
                              'edit',

                              child:
                              Row(
                                children: [
                                  Icon(
                                    Icons
                                        .edit,
                                  ),
                                  SizedBox(
                                    width:
                                    10,
                                  ),
                                  Text(
                                    'Sửa',
                                  ),
                                ],
                              ),
                            ),

                            // =============================
                            // GÁN THẺ NFC
                            // =============================

                            const PopupMenuItem(
                              value:
                              'assign_nfc',

                              child:
                              Row(
                                children: [
                                  Icon(
                                    Icons
                                        .nfc,
                                  ),
                                  SizedBox(
                                    width:
                                    10,
                                  ),
                                  Text(
                                    'Gán thẻ NFC',
                                  ),
                                ],
                              ),
                            ),

                            // =============================
                            // XEM THẺ NFC
                            // =============================

                            const PopupMenuItem(
                              value:
                              'check_nfc',

                              child:
                              Row(
                                children: [
                                  Icon(
                                    Icons
                                        .credit_card,
                                  ),
                                  SizedBox(
                                    width:
                                    10,
                                  ),
                                  Text(
                                    'Xem thẻ NFC',
                                  ),
                                ],
                              ),
                            ),
                            // =============================
                            // Kha THẺ NFC
                            // =============================
                            const PopupMenuItem(
                              value: 'manage_nfc',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.security,
                                  ),
                                  SizedBox(
                                    width: 10,
                                  ),
                                  Text(
                                    'Quản lý thẻ NFC',
                                  ),
                                ],
                              ),
                            ),

                            // =============================
                            // HỦY GÁN THẺ NFC
                            // =============================

                            const PopupMenuItem(
                              value:
                              'remove_nfc',

                              child:
                              Row(
                                children: [
                                  Icon(
                                    Icons
                                        .link_off,
                                  ),
                                  SizedBox(
                                    width:
                                    10,
                                  ),
                                  Text(
                                    'Hủy gán thẻ NFC',
                                  ),
                                ],
                              ),
                            ),

                            // =============================
                            // KHÓA / MỞ KHÓA
                            // =============================

                            PopupMenuItem(
                              value:
                              'status',

                              child:
                              Row(
                                children: [
                                  Icon(
                                    isActive
                                        ? Icons
                                        .lock
                                        : Icons
                                        .lock_open,
                                  ),
                                  const SizedBox(
                                    width:
                                    10,
                                  ),
                                  Text(
                                    isActive
                                        ? 'Khóa'
                                        : 'Mở khóa',
                                  ),
                                ],
                              ),
                            ),

                            // =============================
                            // XÓA
                            // =============================

                            const PopupMenuItem(
                              value:
                              'delete',

                              child:
                              Row(
                                children: [
                                  Icon(
                                    Icons
                                        .delete,
                                  ),
                                  SizedBox(
                                    width:
                                    10,
                                  ),
                                  Text(
                                    'Xóa',
                                  ),
                                ],
                              ),
                            ),
                          ];
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}