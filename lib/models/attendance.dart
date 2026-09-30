class Attendance {
  final int? id;
  final int employeeId;
  final String date;
  final DateTime checkIn;
  final DateTime? checkOut;

  final int? shiftId;
  final int lateMinutes;
  final int earlyMinutes;
  final int overtimeMinutes;
  final int totalWorkingMinutes;
  final String status;

  const Attendance({
    this.id,
    required this.employeeId,
    required this.date,
    required this.checkIn,
    this.checkOut,
    this.shiftId,
    this.lateMinutes = 0,
    this.earlyMinutes = 0,
    this.overtimeMinutes = 0,
    this.totalWorkingMinutes = 0,
    this.status = 'WORKING',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employeeId': employeeId,
      'date': date,
      'checkIn': checkIn.toIso8601String(),
      'checkOut': checkOut?.toIso8601String(),
      'shiftId': shiftId,
      'lateMinutes': lateMinutes,
      'earlyMinutes': earlyMinutes,
      'overtimeMinutes': overtimeMinutes,
      'totalWorkingMinutes': totalWorkingMinutes,
      'status': status,
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'] as int?,
      employeeId: map['employeeId'] as int,
      date: map['date'] as String,
      checkIn: DateTime.parse(map['checkIn'] as String),
      checkOut: map['checkOut'] == null
          ? null
          : DateTime.parse(map['checkOut'] as String),
      shiftId: map['shiftId'] as int?,
      lateMinutes: (map['lateMinutes'] as int?) ?? 0,
      earlyMinutes: (map['earlyMinutes'] as int?) ?? 0,
      overtimeMinutes: (map['overtimeMinutes'] as int?) ?? 0,
      totalWorkingMinutes:
      (map['totalWorkingMinutes'] as int?) ?? 0,
      status: (map['status'] as String?) ?? 'WORKING',
    );
  }
}
