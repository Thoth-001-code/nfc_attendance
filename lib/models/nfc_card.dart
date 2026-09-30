class NfcCard {
  final int? id;
  final int employeeId;
  final String uid;
  final String status;

  NfcCard({
    this.id,
    required this.employeeId,
    required this.uid,
    this.status = 'ACTIVE',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employeeId': employeeId,
      'uid': uid,
      'status': status,
    };
  }

  factory NfcCard.fromMap(
      Map<String, dynamic> map,
      ) {
    return NfcCard(
      id: map['id'] as int?,
      employeeId: map['employeeId'] as int,
      uid: map['uid'] as String,
      status: map['status'] as String? ?? 'ACTIVE',
    );
  }
}