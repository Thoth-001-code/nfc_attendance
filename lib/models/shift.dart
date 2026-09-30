class Shift {
  final int? id;
  final String name;
  final String startTime;
  final String endTime;
  final String breakStart;
  final String breakEnd;
  final int graceMinutes;
  final bool isActive;

  const Shift({
    this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.breakStart,
    required this.breakEnd,
    required this.graceMinutes,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'startTime': startTime,
      'endTime': endTime,
      'breakStart': breakStart,
      'breakEnd': breakEnd,
      'graceMinutes': graceMinutes,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory Shift.fromMap(Map<String, dynamic> map) {
    return Shift(
      id: map['id'] as int?,
      name: map['name'] as String,
      startTime: map['startTime'] as String,
      endTime: map['endTime'] as String,
      breakStart: map['breakStart'] as String,
      breakEnd: map['breakEnd'] as String,
      graceMinutes: (map['graceMinutes'] as int?) ?? 0,
      isActive: ((map['isActive'] as int?) ?? 1) == 1,
    );
  }
}
