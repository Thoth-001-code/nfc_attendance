import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

class NfcSecurityScreen extends StatefulWidget {
  const NfcSecurityScreen({super.key});

  @override
  State<NfcSecurityScreen> createState() => _NfcSecurityScreenState();
}

class _NfcSecurityScreenState extends State<NfcSecurityScreen> {
  bool _isScanning = false;

  String _status = 'Sẵn sàng';
  String _uid = '-';
  String _tagType = '-';
  String _securityStatus = 'Chưa kiểm tra';

  // =====================================================
  // CẤU HÌNH BẢO MẬT HIỆN TẠI
  //
  // Đây là PWD/PACK đã dùng trong giai đoạn test.
  // Phase tích hợp sau nên chuyển việc sinh/lưu secret ra service/config
  // thay vì để cố định trong UI.
  // =====================================================
  static const List<int> _password = [0x12, 0x34, 0x56, 0x78];
  static const List<int> _pack = [0xAB, 0xCD];

  static const int _configPage = 0x83;
  static const int _auth0ProtectedFromPage = 0x04;
  static const int _auth0Disabled = 0xFF;

  String _uidToHex(Uint8List bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }

  String _hexByte(int value) {
    return value.toRadixString(16).padLeft(2, '0').toUpperCase();
  }

  Future<bool> _isNtag215(NfcAAndroid nfcA) async {
    final version = await nfcA.transceive(
      Uint8List.fromList([0x60]),
    );

    return version.length >= 8 && version[6] == 0x11;
  }

  Future<Uint8List> _readConfig(NfcAAndroid nfcA) async {
    final response = await nfcA.transceive(
      Uint8List.fromList([0x30, _configPage]),
    );

    if (response.length < 8) {
      throw Exception('Không đọc được cấu hình NTAG215');
    }

    return response;
  }

  Future<void> _authenticate(NfcAAndroid nfcA) async {
    final response = await nfcA.transceive(
      Uint8List.fromList([0x1B, ..._password]),
    );

    if (response.length < 2 ||
        response[0] != _pack[0] ||
        response[1] != _pack[1]) {
      throw Exception('Mật khẩu thẻ không hợp lệ');
    }
  }

  String _buildSecurityStatus(Uint8List config) {
    final auth0 = config[3];
    final access = config[4];

    final prot = (access & 0x80) != 0;
    final cfgLock = (access & 0x40) != 0;
    final authLim = access & 0x07;

    final buffer = StringBuffer();

    if (auth0 == _auth0Disabled) {
      buffer.writeln('Bảo vệ ghi: TẮT');
    } else {
      buffer.writeln('Bảo vệ ghi: BẬT');
      buffer.writeln('Bắt đầu từ Page: $auth0');
    }

    buffer.writeln(
      prot
          ? 'Chế độ: Bảo vệ READ + WRITE'
          : 'Chế độ: Bảo vệ WRITE',
    );

    buffer.writeln(
      cfgLock
          ? 'Khóa cấu hình: ĐÃ KHÓA'
          : 'Khóa cấu hình: Chưa khóa',
    );

    buffer.writeln(
      authLim == 0
          ? 'Giới hạn xác thực sai: Không giới hạn'
          : 'Giới hạn xác thực sai: $authLim',
    );

    buffer.writeln('AUTH0: 0x${_hexByte(auth0)}');
    buffer.writeln('ACCESS: 0x${_hexByte(access)}');

    return buffer.toString().trim();
  }

  Future<bool> _checkNfcAvailability() async {
    final availability = await NfcManager.instance.checkAvailability();

    if (availability != NfcAvailability.enabled) {
      if (!mounted) return false;

      setState(() {
        _status = 'NFC chưa bật hoặc thiết bị không hỗ trợ NFC';
      });

      return false;
    }

    return true;
  }

  // =====================================================
  // KIỂM TRA TRẠNG THÁI BẢO MẬT
  // =====================================================
  Future<void> _scanSecurityStatus() async {
    if (!await _checkNfcAvailability()) return;

    setState(() {
      _isScanning = true;
      _status = 'Đưa thẻ NTAG215 lại gần điện thoại...';
      _uid = '-';
      _tagType = '-';
      _securityStatus = 'Đang kiểm tra...';
    });

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443},
        onDiscovered: (NfcTag tag) async {
          try {
            final androidTag = NfcTagAndroid.from(tag);
            final nfcA = NfcAAndroid.from(tag);

            if (androidTag == null || nfcA == null) {
              throw Exception('Thẻ không hỗ trợ NfcA');
            }

            if (!await _isNtag215(nfcA)) {
              throw Exception('Thẻ này không phải NTAG215');
            }

            final config = await _readConfig(nfcA);
            final uid = _uidToHex(androidTag.id);

            await _stopSession();

            if (!mounted) return;

            setState(() {
              _uid = uid;
              _tagType = 'NTAG215';
              _securityStatus = _buildSecurityStatus(config);
              _status = 'Đã đọc trạng thái bảo mật';
              _isScanning = false;
            });
          } catch (e) {
            await _handleError('Không thể kiểm tra thẻ', e);
          }
        },
      );
    } catch (e) {
      await _handleError('Không thể khởi động NFC', e);
    }
  }

  // =====================================================
  // BẬT WRITE PROTECTION
  //
  // AUTH0 = 0x04
  // PROT/CFGLCK/AUTHLIM không bị thay đổi.
  // =====================================================
  Future<void> _enableProtection() async {
    final confirmed = await _confirm(
      title: 'Bật bảo vệ thẻ',
      message:
      'Sau khi bật, vùng nhớ từ Page 4 trở đi sẽ yêu cầu xác thực '
          'trước khi ghi.\n\n'
          'Hãy giữ thẻ sát điện thoại cho đến khi hoàn tất.',
      confirmText: 'BẬT',
    );

    if (!confirmed || !await _checkNfcAvailability()) return;

    setState(() {
      _isScanning = true;
      _status = 'Đưa thẻ cần bảo vệ lại gần điện thoại...';
      _securityStatus = 'Đang cấu hình bảo mật...';
    });

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443},
        onDiscovered: (NfcTag tag) async {
          try {
            final androidTag = NfcTagAndroid.from(tag);
            final nfcA = NfcAAndroid.from(tag);

            if (androidTag == null || nfcA == null) {
              throw Exception('Thẻ không hỗ trợ NfcA');
            }

            if (!await _isNtag215(nfcA)) {
              throw Exception('Thẻ này không phải NTAG215');
            }

            final config = await _readConfig(nfcA);
            final page83 = Uint8List.fromList(config.sublist(0, 4));
            final auth0 = page83[3];
            final access = config[4];

            if ((access & 0x40) != 0) {
              throw Exception(
                'Cấu hình thẻ đã bị khóa. Không thể thay đổi AUTH0.',
              );
            }

            // Nếu thẻ đã dùng password hiện tại, cần xác thực trước.
            // Nếu AUTH0 = FF, PWD_AUTH vẫn có thể dùng với PWD đã cấu hình.
            await _authenticate(nfcA);

            if (auth0 != _auth0ProtectedFromPage) {
              final newPage83 = Uint8List.fromList([
                page83[0],
                page83[1],
                page83[2],
                _auth0ProtectedFromPage,
              ]);

              await nfcA.transceive(
                Uint8List.fromList([
                  0xA2,
                  _configPage,
                  ...newPage83,
                ]),
              );
            }

            final uid = _uidToHex(androidTag.id);

            await _stopSession();

            if (!mounted) return;

            setState(() {
              _uid = uid;
              _tagType = 'NTAG215';
              _securityStatus =
              'Bảo vệ ghi: BẬT\n'
                  'Bắt đầu từ Page: 4\n'
                  'AUTH0: 0x04\n\n'
                  'Bỏ thẻ khỏi điện thoại rồi quét lại để xác nhận.';
              _status = 'Bật bảo vệ thành công';
              _isScanning = false;
            });
          } catch (e) {
            await _handleError('Không thể bật bảo vệ', e);
          }
        },
      );
    } catch (e) {
      await _handleError('Không thể khởi động NFC', e);
    }
  }

  // =====================================================
  // TẮT WRITE PROTECTION
  //
  // PWD_AUTH -> AUTH0 = FF
  // Không xóa PWD/PACK.
  // =====================================================
  Future<void> _disableProtection() async {
    final confirmed = await _confirm(
      title: 'Tắt bảo vệ thẻ',
      message:
      'Thao tác này sẽ tắt password protection bằng cách đưa '
          'AUTH0 về FF.\n\nPWD và PACK vẫn được giữ nguyên.',
      confirmText: 'TẮT',
    );

    if (!confirmed || !await _checkNfcAvailability()) return;

    setState(() {
      _isScanning = true;
      _status = 'Đưa thẻ cần tắt bảo vệ lại gần điện thoại...';
      _securityStatus = 'Đang tắt bảo vệ...';
    });

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443},
        onDiscovered: (NfcTag tag) async {
          try {
            final androidTag = NfcTagAndroid.from(tag);
            final nfcA = NfcAAndroid.from(tag);

            if (androidTag == null || nfcA == null) {
              throw Exception('Thẻ không hỗ trợ NfcA');
            }

            if (!await _isNtag215(nfcA)) {
              throw Exception('Thẻ này không phải NTAG215');
            }

            await _authenticate(nfcA);

            final config = await _readConfig(nfcA);
            final page83 = Uint8List.fromList(config.sublist(0, 4));
            final access = config[4];

            if ((access & 0x40) != 0) {
              throw Exception(
                'Cấu hình thẻ đã bị khóa. Không thể thay đổi AUTH0.',
              );
            }

            if (page83[3] != _auth0Disabled) {
              final newPage83 = Uint8List.fromList([
                page83[0],
                page83[1],
                page83[2],
                _auth0Disabled,
              ]);

              await nfcA.transceive(
                Uint8List.fromList([
                  0xA2,
                  _configPage,
                  ...newPage83,
                ]),
              );
            }

            final uid = _uidToHex(androidTag.id);

            await _stopSession();

            if (!mounted) return;

            setState(() {
              _uid = uid;
              _tagType = 'NTAG215';
              _securityStatus =
              'Bảo vệ ghi: TẮT\n'
                  'AUTH0: 0xFF\n\n'
                  'PWD/PACK vẫn được giữ nguyên.\n'
                  'Bỏ thẻ khỏi điện thoại rồi quét lại để xác nhận.';
              _status = 'Tắt bảo vệ thành công';
              _isScanning = false;
            });
          } catch (e) {
            await _handleError('Không thể tắt bảo vệ', e);
          }
        },
      );
    } catch (e) {
      await _handleError('Không thể khởi động NFC', e);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    if (!mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<void> _handleError(String message, Object error) async {
    await _stopSession();

    if (!mounted) return;

    setState(() {
      _status = '❌ $message';
      _securityStatus = error.toString();
      _isScanning = false;
    });
  }

  Future<void> _stopSession() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }

  Future<void> _stopScan() async {
    await _stopSession();

    if (!mounted) return;

    setState(() {
      _isScanning = false;
      _status = 'Đã dừng NFC';
    });
  }

  @override
  void dispose() {
    if (_isScanning) {
      NfcManager.instance.stopSession();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảo mật thẻ NFC'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.security,
              size: 88,
            ),
            const SizedBox(height: 16),

            Text(
              _status,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 24),

            _infoBox('UID', _uid),
            _infoBox('Loại thẻ', _tagType),
            _infoBox('Trạng thái bảo mật', _securityStatus),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isScanning ? _stopScan : _scanSecurityStatus,
                icon: Icon(
                  _isScanning ? Icons.stop : Icons.nfc,
                ),
                label: Text(
                  _isScanning ? 'DỪNG NFC' : 'KIỂM TRA BẢO MẬT',
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isScanning ? null : _enableProtection,
                icon: const Icon(Icons.lock),
                label: const Text('BẬT BẢO VỆ THẺ'),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isScanning ? null : _disableProtection,
                icon: const Icon(Icons.lock_open),
                label: const Text('TẮT BẢO VỆ THẺ'),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Bảo vệ NFC chỉ kiểm soát quyền ghi vùng nhớ của NTAG215. '
                  'UID của thẻ vẫn có thể được thiết bị NFC đọc.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBox(String title, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(value),
        ],
      ),
    );
  }
}
