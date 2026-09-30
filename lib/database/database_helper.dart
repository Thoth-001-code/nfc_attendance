import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/attendance.dart';
import '../models/employee.dart';
import '../models/nfc_card.dart';
import '../models/shift.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'nfc_attendance.db');

    return openDatabase(
      path,
      version: 6,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE Employee (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employeeCode TEXT NOT NULL UNIQUE,
        fullName TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'ACTIVE'
      )
    ''');

    await db.execute('''
      CREATE TABLE NfcCard (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employeeId INTEGER NOT NULL,
        uid TEXT NOT NULL UNIQUE,
        status TEXT NOT NULL DEFAULT 'ACTIVE',
        FOREIGN KEY (employeeId)
          REFERENCES Employee(id)
          ON DELETE CASCADE
      )
    ''');

    await _createShiftTable(db);
    await _seedDefaultShift(db);
    await _createAttendanceTable(db);
  }

  Future<void> _upgradeDB(
      Database db,
      int oldVersion,
      int newVersion,
      ) async {
    if (oldVersion < 2) {
      await db.execute('''
        ALTER TABLE Employee
        ADD COLUMN status TEXT NOT NULL DEFAULT 'ACTIVE'
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE NfcCard (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          employeeId INTEGER NOT NULL UNIQUE,
          uid TEXT NOT NULL UNIQUE,
          status TEXT NOT NULL DEFAULT 'ACTIVE',
          FOREIGN KEY (employeeId)
            REFERENCES Employee(id)
            ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 4) {
      await db.transaction((txn) async {
        await txn.execute(
          'ALTER TABLE NfcCard RENAME TO NfcCard_old',
        );

        await txn.execute('''
          CREATE TABLE NfcCard (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            employeeId INTEGER NOT NULL,
            uid TEXT NOT NULL UNIQUE,
            status TEXT NOT NULL DEFAULT 'ACTIVE',
            FOREIGN KEY (employeeId)
              REFERENCES Employee(id)
              ON DELETE CASCADE
          )
        ''');

        await txn.execute('''
          INSERT INTO NfcCard (
            id,
            employeeId,
            uid,
            status
          )
          SELECT
            id,
            employeeId,
            uid,
            status
          FROM NfcCard_old
        ''');

        await txn.execute('DROP TABLE NfcCard_old');
      });
    }

    // Phase 7-9.
    if (oldVersion < 5) {
      await _createAttendanceTable(db);
    }

    // Phase 10-12.
    if (oldVersion < 6) {
      await _createShiftTable(db);
      await _seedDefaultShift(db);

      // Nếu DB đã ở v5 thì Attendance là schema cũ,
      // cần bổ sung các cột tính công.
      if (oldVersion >= 5) {
        await db.execute(
          'ALTER TABLE Attendance ADD COLUMN shiftId INTEGER',
        );
        await db.execute(
          'ALTER TABLE Attendance '
              'ADD COLUMN lateMinutes INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE Attendance '
              'ADD COLUMN earlyMinutes INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE Attendance '
              'ADD COLUMN overtimeMinutes INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE Attendance '
              'ADD COLUMN totalWorkingMinutes INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute(
          "ALTER TABLE Attendance "
              "ADD COLUMN status TEXT NOT NULL DEFAULT 'WORKING'",
        );
      }
    }
  }

  Future<void> _createShiftTable(
      DatabaseExecutor db,
      ) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Shift (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT NOT NULL,
        breakStart TEXT NOT NULL,
        breakEnd TEXT NOT NULL,
        graceMinutes INTEGER NOT NULL DEFAULT 5,
        isActive INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  Future<void> _seedDefaultShift(
      DatabaseExecutor db,
      ) async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM Shift',
    );

    final count = Sqflite.firstIntValue(result) ?? 0;

    if (count == 0) {
      await db.insert(
        'Shift',
        {
          'name': 'Ca hành chính',
          'startTime': '08:00',
          'endTime': '17:00',
          'breakStart': '12:00',
          'breakEnd': '13:00',
          'graceMinutes': 5,
          'isActive': 1,
        },
      );
    }
  }

  Future<void> _createAttendanceTable(
      DatabaseExecutor db,
      ) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employeeId INTEGER NOT NULL,
        date TEXT NOT NULL,
        checkIn TEXT NOT NULL,
        checkOut TEXT,
        shiftId INTEGER,
        lateMinutes INTEGER NOT NULL DEFAULT 0,
        earlyMinutes INTEGER NOT NULL DEFAULT 0,
        overtimeMinutes INTEGER NOT NULL DEFAULT 0,
        totalWorkingMinutes INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'WORKING',
        FOREIGN KEY (employeeId)
          REFERENCES Employee(id)
          ON DELETE CASCADE,
        UNIQUE(employeeId, date)
      )
    ''');
  }

  // =====================================================
  // EMPLOYEE
  // =====================================================

  Future<int> insertEmployee(Employee employee) async {
    final db = await database;

    return db.insert(
      'Employee',
      {
        'employeeCode': employee.employeeCode,
        'fullName': employee.fullName,
        'status': employee.status,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<Employee>> getEmployees() async {
    final db = await database;

    final result = await db.query(
      'Employee',
      orderBy: 'id DESC',
    );

    return result.map(Employee.fromMap).toList();
  }

  Future<Employee?> getEmployeeById(int id) async {
    final db = await database;

    final result = await db.query(
      'Employee',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return Employee.fromMap(result.first);
  }

  Future<bool> employeeCodeExists(
      String employeeCode, {
        int? excludeId,
      }) async {
    final db = await database;

    List<Map<String, dynamic>> result;

    if (excludeId == null) {
      result = await db.query(
        'Employee',
        where: 'employeeCode = ?',
        whereArgs: [employeeCode],
        limit: 1,
      );
    } else {
      result = await db.query(
        'Employee',
        where: 'employeeCode = ? AND id != ?',
        whereArgs: [employeeCode, excludeId],
        limit: 1,
      );
    }

    return result.isNotEmpty;
  }

  Future<int> updateEmployee(Employee employee) async {
    final db = await database;

    if (employee.id == null) {
      throw Exception('Không tìm thấy ID nhân viên');
    }

    return db.update(
      'Employee',
      {
        'employeeCode': employee.employeeCode,
        'fullName': employee.fullName,
        'status': employee.status,
      },
      where: 'id = ?',
      whereArgs: [employee.id],
    );
  }

  Future<int> deleteEmployee(int id) async {
    final db = await database;

    return db.delete(
      'Employee',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateEmployeeStatus(
      int id,
      String status,
      ) async {
    final db = await database;

    return db.update(
      'Employee',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> countEmployees() async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM Employee
    ''');

    return Sqflite.firstIntValue(result) ?? 0;
  }

  // =====================================================
  // NFC CARD
  // =====================================================

  Future<NfcCard?> getNfcCardByUid(String uid) async {
    final db = await database;

    final result = await db.query(
      'NfcCard',
      where: 'uid = ?',
      whereArgs: [uid],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return NfcCard.fromMap(result.first);
  }

  Future<NfcCard?> getNfcCardByEmployee(
      int employeeId,
      ) async {
    final db = await database;

    final result = await db.query(
      'NfcCard',
      where: 'employeeId = ? AND status = ?',
      whereArgs: [employeeId, 'ACTIVE'],
      orderBy: 'id DESC',
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return NfcCard.fromMap(result.first);
  }

  Future<List<NfcCard>> getNfcCardsByEmployee(
      int employeeId,
      ) async {
    final db = await database;

    final result = await db.query(
      'NfcCard',
      where: 'employeeId = ?',
      whereArgs: [employeeId],
      orderBy: 'id DESC',
    );

    return result.map(NfcCard.fromMap).toList();
  }

  Future<int> assignNfcCard(
      int employeeId,
      String uid,
      ) async {
    final db = await database;

    return db.transaction((txn) async {
      final existingUid = await txn.query(
        'NfcCard',
        where: 'uid = ?',
        whereArgs: [uid],
        limit: 1,
      );

      if (existingUid.isNotEmpty) {
        final existingEmployeeId =
        existingUid.first['employeeId'] as int;

        if (existingEmployeeId != employeeId) {
          throw Exception(
            'Thẻ NFC này đã được gán cho nhân viên khác',
          );
        }

        final existingCardId =
        existingUid.first['id'] as int;

        await txn.update(
          'NfcCard',
          {'status': 'BLOCKED'},
          where:
          'employeeId = ? AND id != ? AND status = ?',
          whereArgs: [
            employeeId,
            existingCardId,
            'ACTIVE',
          ],
        );

        return txn.update(
          'NfcCard',
          {'status': 'ACTIVE'},
          where: 'id = ?',
          whereArgs: [existingCardId],
        );
      }

      await txn.update(
        'NfcCard',
        {'status': 'BLOCKED'},
        where: 'employeeId = ? AND status = ?',
        whereArgs: [employeeId, 'ACTIVE'],
      );

      return txn.insert(
        'NfcCard',
        {
          'employeeId': employeeId,
          'uid': uid,
          'status': 'ACTIVE',
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    });
  }


  Future<int> deleteNfcCardById(int cardId) async {
    final db = await database;

    return db.delete(
      'NfcCard',
      where: 'id = ?',
      whereArgs: [cardId],
    );
  }

  Future<int> blockNfcCard(int cardId) async {
    final db = await database;

    return db.update(
      'NfcCard',
      {'status': 'BLOCKED'},
      where: 'id = ?',
      whereArgs: [cardId],
    );
  }

  Future<void> activateNfcCard(
      int cardId,
      int employeeId,
      ) async {
    final db = await database;

    await db.transaction((txn) async {
      final target = await txn.query(
        'NfcCard',
        where: 'id = ? AND employeeId = ?',
        whereArgs: [cardId, employeeId],
        limit: 1,
      );

      if (target.isEmpty) {
        throw Exception(
          'Không tìm thấy thẻ NFC của nhân viên',
        );
      }

      await txn.update(
        'NfcCard',
        {'status': 'BLOCKED'},
        where:
        'employeeId = ? AND id != ? AND status = ?',
        whereArgs: [
          employeeId,
          cardId,
          'ACTIVE',
        ],
      );

      await txn.update(
        'NfcCard',
        {'status': 'ACTIVE'},
        where: 'id = ?',
        whereArgs: [cardId],
      );
    });
  }

  Future<int> removeNfcCard(int employeeId) async {
    final db = await database;

    return db.delete(
      'NfcCard',
      where: 'employeeId = ? AND status = ?',
      whereArgs: [employeeId, 'ACTIVE'],
    );
  }

  // =====================================================
  // SHIFT - PHASE 10
  // =====================================================

  Future<Shift?> getActiveShift() async {
    final db = await database;

    final result = await db.query(
      'Shift',
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'id DESC',
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return Shift.fromMap(result.first);
  }

  Future<List<Shift>> getShifts() async {
    final db = await database;

    final result = await db.query(
      'Shift',
      orderBy: 'id DESC',
    );

    return result.map(Shift.fromMap).toList();
  }

  Future<int> updateShift(Shift shift) async {
    final db = await database;

    if (shift.id == null) {
      throw Exception('Không tìm thấy ID ca làm');
    }

    return db.update(
      'Shift',
      {
        'name': shift.name,
        'startTime': shift.startTime,
        'endTime': shift.endTime,
        'breakStart': shift.breakStart,
        'breakEnd': shift.breakEnd,
        'graceMinutes': shift.graceMinutes,
        'isActive': shift.isActive ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [shift.id],
    );
  }

  // =====================================================
  // ATTENDANCE - PHASE 7 -> 12
  // =====================================================

  Future<Attendance?> getAttendanceByEmployeeAndDate(
      int employeeId,
      String date,
      ) async {
    final db = await database;

    final result = await db.query(
      'Attendance',
      where: 'employeeId = ? AND date = ?',
      whereArgs: [employeeId, date],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return Attendance.fromMap(result.first);
  }

  Future<int> insertAttendance(
      Attendance attendance,
      ) async {
    final db = await database;

    return db.insert(
      'Attendance',
      {
        'employeeId': attendance.employeeId,
        'date': attendance.date,
        'checkIn': attendance.checkIn.toIso8601String(),
        'checkOut': attendance.checkOut?.toIso8601String(),
        'shiftId': attendance.shiftId,
        'lateMinutes': attendance.lateMinutes,
        'earlyMinutes': attendance.earlyMinutes,
        'overtimeMinutes': attendance.overtimeMinutes,
        'totalWorkingMinutes':
        attendance.totalWorkingMinutes,
        'status': attendance.status,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> completeAttendance({
    required int attendanceId,
    required DateTime checkOut,
    required int earlyMinutes,
    required int overtimeMinutes,
    required int totalWorkingMinutes,
    required String status,
  }) async {
    final db = await database;

    return db.update(
      'Attendance',
      {
        'checkOut': checkOut.toIso8601String(),
        'earlyMinutes': earlyMinutes,
        'overtimeMinutes': overtimeMinutes,
        'totalWorkingMinutes': totalWorkingMinutes,
        'status': status,
      },
      where: 'id = ? AND checkOut IS NULL',
      whereArgs: [attendanceId],
    );
  }

  Future<List<Attendance>> getAttendancesByEmployee(
      int employeeId,
      ) async {
    final db = await database;

    final result = await db.query(
      'Attendance',
      where: 'employeeId = ?',
      whereArgs: [employeeId],
      orderBy: 'date DESC, checkIn DESC',
    );

    return result.map(Attendance.fromMap).toList();
  }

  Future<List<Map<String, dynamic>>>
  getAttendanceHistory() async {
    final db = await database;

    return db.rawQuery('''
      SELECT
        Attendance.id,
        Attendance.employeeId,
        Attendance.date,
        Attendance.checkIn,
        Attendance.checkOut,
        Attendance.shiftId,
        Attendance.lateMinutes,
        Attendance.earlyMinutes,
        Attendance.overtimeMinutes,
        Attendance.totalWorkingMinutes,
        Attendance.status,
        Employee.employeeCode,
        Employee.fullName,
        Shift.name AS shiftName,
        Shift.startTime AS shiftStartTime,
        Shift.endTime AS shiftEndTime
      FROM Attendance
      INNER JOIN Employee
        ON Employee.id = Attendance.employeeId
      LEFT JOIN Shift
        ON Shift.id = Attendance.shiftId
      ORDER BY Attendance.date DESC,
               Attendance.checkIn DESC
    ''');
  }

  // =====================================================
  // PHASE 16 - BACKUP / RESTORE
  // =====================================================

  Future<String> _databaseFilePath() async {
    final databasePath = await getDatabasesPath();
    return join(databasePath, 'nfc_attendance.db');
  }

  Future<Directory> _backupDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(join(root.path, 'database_backups'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _backupTimestamp(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}${two(value.month)}${two(value.day)}_'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}';
  }

  Future<File> createBackup() async {
    final db = await database;
    try {
      await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    } catch (_) {}

    await db.close();
    _database = null;

    try {
      final sourcePath = await _databaseFilePath();
      final source = File(sourcePath);
      if (!await source.exists()) {
        throw Exception('Không tìm thấy database để sao lưu');
      }

      final backupDirectory = await _backupDirectory();
      final backupName =
          'nfc_attendance_${_backupTimestamp(DateTime.now())}.db';
      final backup = File(join(backupDirectory.path, backupName));

      await source.copy(backup.path);
      await _validateBackup(backup.path);
      return backup;
    } finally {
      await database;
    }
  }

  Future<List<File>> getBackups() async {
    final directory = await _backupDirectory();
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) =>
    basename(file.path).startsWith('nfc_attendance_') &&
        extension(file.path).toLowerCase() == '.db')
        .toList();

    files.sort((a, b) =>
        b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  Future<Map<String, int>> getBackupSummary(String backupPath) async {
    final backupDb = await openDatabase(
      backupPath,
      readOnly: true,
      singleInstance: false,
    );

    try {
      Future<int> count(String table) async {
        final result =
        await backupDb.rawQuery('SELECT COUNT(*) AS total FROM $table');
        return Sqflite.firstIntValue(result) ?? 0;
      }

      return {
        'employees': await count('Employee'),
        'cards': await count('NfcCard'),
        'shifts': await count('Shift'),
        'attendances': await count('Attendance'),
      };
    } finally {
      await backupDb.close();
    }
  }

  Future<void> _validateBackup(String backupPath) async {
    final file = File(backupPath);
    if (!await file.exists()) {
      throw Exception('File backup không tồn tại');
    }
    if (await file.length() == 0) {
      throw Exception('File backup rỗng');
    }

    final backupDb = await openDatabase(
      backupPath,
      readOnly: true,
      singleInstance: false,
    );

    try {
      final tables = await backupDb.rawQuery(
        "SELECT name FROM sqlite_master "
            "WHERE type = 'table' "
            "AND name IN ('Employee', 'NfcCard', 'Shift', 'Attendance')",
      );

      final names = tables
          .map((row) => row['name']?.toString())
          .whereType<String>()
          .toSet();

      const requiredTables = {
        'Employee',
        'NfcCard',
        'Shift',
        'Attendance',
      };

      if (!names.containsAll(requiredTables)) {
        throw Exception(
          'Backup không đúng cấu trúc database chấm công NFC',
        );
      }

      final versionResult =
      await backupDb.rawQuery('PRAGMA user_version');
      final version = versionResult.isEmpty
          ? 0
          : (versionResult.first['user_version'] as int? ?? 0);

      if (version <= 0 || version > 6) {
        throw Exception(
          'Phiên bản database backup không hợp lệ: $version',
        );
      }
    } finally {
      await backupDb.close();
    }
  }

  Future<void> restoreBackup(String backupPath) async {
    await _validateBackup(backupPath);

    final activePath = await _databaseFilePath();
    final activeFile = File(activePath);
    final rollbackFile = File('$activePath.before_restore');

    if (_database != null) {
      try {
        await _database!.close();
      } catch (_) {}
      _database = null;
    }

    try {
      if (await rollbackFile.exists()) {
        await rollbackFile.delete();
      }
      if (await activeFile.exists()) {
        await activeFile.copy(rollbackFile.path);
      }

      final wal = File('$activePath-wal');
      final shm = File('$activePath-shm');
      final journal = File('$activePath-journal');

      if (await wal.exists()) await wal.delete();
      if (await shm.exists()) await shm.delete();
      if (await journal.exists()) await journal.delete();

      await File(backupPath).copy(activePath);

      final restoredDb = await database;
      await restoredDb.rawQuery('SELECT COUNT(*) FROM Employee');
      await restoredDb.rawQuery('SELECT COUNT(*) FROM Attendance');

      if (await rollbackFile.exists()) {
        await rollbackFile.delete();
      }
    } catch (e) {
      if (_database != null) {
        try {
          await _database!.close();
        } catch (_) {}
        _database = null;
      }

      if (await rollbackFile.exists()) {
        await rollbackFile.copy(activePath);
        await rollbackFile.delete();
      }

      await database;
      throw Exception('Khôi phục thất bại: $e');
    }
  }

  Future<void> deleteBackup(String backupPath) async {
    final backupDirectory = await _backupDirectory();
    final backupDirectoryPath = canonicalize(backupDirectory.path);
    final targetPath = canonicalize(backupPath);

    if (!isWithin(backupDirectoryPath, targetPath)) {
      throw Exception('Đường dẫn backup không hợp lệ');
    }

    final file = File(backupPath);
    if (await file.exists()) {
      await file.delete();
    }
  }


}
