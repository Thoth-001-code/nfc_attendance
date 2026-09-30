import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

class NfcProtectionResult {
  final String uid;
  final bool isNtag215;
  final bool protected;

  const NfcProtectionResult({
    required this.uid,
    required this.isNtag215,
    required this.protected,
  });
}

class NfcSecurityService {
  NfcSecurityService._();

  // Credentials đã được kiểm thử ở Phase 6.5.
  // Sau này có thể chuyển sang cấu hình riêng nếu cần.
  static const List<int> _password = [0x12, 0x34, 0x56, 0x78];
  static const List<int> _pack = [0xAB, 0xCD];

  static const int _configPage = 0x83;
  static const int _pwdPage = 0x85;
  static const int _packPage = 0x86;
  static const int _protectedFromPage = 0x04;

  static String _uidToHex(Uint8List bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }

  static Future<bool> isNtag215(NfcAAndroid nfcA) async {
    final version = await nfcA.transceive(
      Uint8List.fromList([0x60]),
    );

    return version.length >= 8 && version[6] == 0x11;
  }

  static Future<Uint8List> _readConfig(NfcAAndroid nfcA) async {
    final response = await nfcA.transceive(
      Uint8List.fromList([0x30, _configPage]),
    );

    if (response.length < 8) {
      throw Exception('Không đọc được cấu hình NTAG215');
    }

    return response;
  }

  static Future<bool> _tryAuthenticate(NfcAAndroid nfcA) async {
    try {
      final response = await nfcA.transceive(
        Uint8List.fromList([0x1B, ..._password]),
      );

      return response.length >= 2 &&
          response[0] == _pack[0] &&
          response[1] == _pack[1];
    } catch (_) {
      return false;
    }
  }

  static Future<void> _authenticate(NfcAAndroid nfcA) async {
    final ok = await _tryAuthenticate(nfcA);

    if (!ok) {
      throw Exception(
        'Thẻ đã có mật khẩu khác hoặc không thể xác thực. '
            'Không thể gán thẻ này.',
      );
    }
  }

  /// Chuẩn hóa bảo mật cho một NTAG215 khi gán cho nhân viên.
  ///
  /// Trường hợp thẻ mới:
  ///   PWD -> PACK -> AUTH0 = 04
  ///
  /// Trường hợp thẻ đã do ứng dụng cấu hình:
  ///   PWD_AUTH -> bảo đảm AUTH0 = 04
  ///
  /// Không bật CFGLCK và không thay đổi ACCESS.
  static Future<NfcProtectionResult> protectDiscoveredTag(
      NfcTag tag,
      ) async {
    final androidTag = NfcTagAndroid.from(tag);
    final nfcA = NfcAAndroid.from(tag);

    if (androidTag == null || nfcA == null) {
      throw Exception('Không đọc được thẻ NFC');
    }

    if (!await isNtag215(nfcA)) {
      throw Exception(
        'Thẻ không phải NTAG215. '
            'Hệ thống chỉ cho phép gán thẻ NTAG215.',
      );
    }

    final uid = _uidToHex(androidTag.id);
    var config = await _readConfig(nfcA);

    final page83 = Uint8List.fromList(config.sublist(0, 4));
    final access = config[4];
    final auth0 = page83[3];

    if ((access & 0x40) != 0) {
      throw Exception(
        'Configuration của thẻ đã bị khóa (CFGLCK=1). '
            'Không thể cấu hình thẻ này.',
      );
    }

    // AUTH0 != FF nghĩa là thẻ đang có vùng password protected.
    // Chỉ tiếp tục nếu password hiện tại đúng với hệ thống.
    if (auth0 != 0xFF) {
      await _authenticate(nfcA);
    } else {
      // AUTH0 = FF: chưa có vùng bảo vệ.
      // Ghi credentials chuẩn của hệ thống.
      await nfcA.transceive(
        Uint8List.fromList([0xA2, _pwdPage, ..._password]),
      );

      await nfcA.transceive(
        Uint8List.fromList([
          0xA2,
          _packPage,
          _pack[0],
          _pack[1],
          0x00,
          0x00,
        ]),
      );

      // Xác nhận credentials vừa cấu hình.
      await _authenticate(nfcA);

      // Đọc lại config trước khi ghi AUTH0.
      config = await _readConfig(nfcA);
    }

    final currentPage83 = Uint8List.fromList(config.sublist(0, 4));
    final currentAccess = config[4];

    if ((currentAccess & 0x40) != 0) {
      throw Exception('CFGLCK đang bật. Không thể thay đổi AUTH0.');
    }

    if (currentPage83[3] != _protectedFromPage) {
      final newPage83 = Uint8List.fromList([
        currentPage83[0],
        currentPage83[1],
        currentPage83[2],
        _protectedFromPage,
      ]);

      await nfcA.transceive(
        Uint8List.fromList([
          0xA2,
          _configPage,
          ...newPage83,
        ]),
      );
    }

    return NfcProtectionResult(
      uid: uid,
      isNtag215: true,
      protected: true,
    );
  }
}
