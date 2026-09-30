class Employee {
  final int? id;
  final String employeeCode;
  final String fullName;
  final String status;

  Employee({
    this.id,
    required this.employeeCode,
    required this.fullName,
    this.status = 'ACTIVE',
  });

  // ==========================================
  // CHUYỂN EMPLOYEE -> MAP ĐỂ LƯU SQLITE
  // ==========================================
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employeeCode': employeeCode,
      'fullName': fullName,
      'status': status,
    };
  }

  // ==========================================
  // CHUYỂN MAP SQLITE -> EMPLOYEE
  // ==========================================
  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] as int?,
      employeeCode: map['employeeCode'] as String,
      fullName: map['fullName'] as String,
      status: map['status'] as String? ?? 'ACTIVE',
    );
  }
}