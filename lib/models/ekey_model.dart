class EkeyModel {
  final String ekeyId;
  final String lockId;
  final String lockMac;
  final String lockData; // TTLock lockData for BLE — shared from owner
  final String lockName;
  final String ownerUid;
  final String ownerEmail;
  final String guestEmail;
  final String keyType; // 'permanent' | 'timed'
  final String status;  // 'active' | 'revoked'
  final int startDate;
  final int endDate;    // 0 = no expiry
  final int createdAt;

  EkeyModel({
    required this.ekeyId,
    required this.lockId,
    required this.lockMac,
    required this.lockData,
    required this.lockName,
    required this.ownerUid,
    required this.ownerEmail,
    required this.guestEmail,
    required this.keyType,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'ekeyId': ekeyId,
        'lockId': lockId,
        'lockMac': lockMac,
        'lockData': lockData,
        'lockName': lockName,
        'ownerUid': ownerUid,
        'ownerEmail': ownerEmail,
        'guestEmail': guestEmail,
        'keyType': keyType,
        'status': status,
        'startDate': startDate,
        'endDate': endDate,
        'createdAt': createdAt,
      };

  factory EkeyModel.fromMap(Map<String, dynamic> map) => EkeyModel(
        ekeyId: map['ekeyId'] ?? '',
        lockId: map['lockId'] ?? '',
        lockMac: map['lockMac'] ?? '',
        lockData: map['lockData'] ?? '',
        lockName: map['lockName'] ?? 'Lock',
        ownerUid: map['ownerUid'] ?? '',
        ownerEmail: map['ownerEmail'] ?? '',
        guestEmail: map['guestEmail'] ?? '',
        keyType: map['keyType'] ?? 'permanent',
        status: map['status'] ?? 'active',
        startDate: map['startDate'] ?? 0,
        endDate: map['endDate'] ?? 0,
        createdAt: map['createdAt'] ?? 0,
      );

  bool get isExpired =>
      endDate != 0 && DateTime.now().millisecondsSinceEpoch > endDate;
}
