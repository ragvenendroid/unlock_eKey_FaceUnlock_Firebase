class LockModel {
  final String lockId;
  final String lockMac;
  final String lockData;
  final String lockName;
  final String ownerUid;
  final String ownerEmail;
  final int createdAt;

  LockModel({
    required this.lockId,
    required this.lockMac,
    required this.lockData,
    required this.lockName,
    required this.ownerUid,
    required this.ownerEmail,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'lockId': lockId,
        'lockMac': lockMac,
        'lockData': lockData,
        'lockName': lockName,
        'ownerUid': ownerUid,
        'ownerEmail': ownerEmail,
        'createdAt': createdAt,
      };

  factory LockModel.fromMap(Map<String, dynamic> map) => LockModel(
        lockId: map['lockId'] ?? '',
        lockMac: map['lockMac'] ?? '',
        lockData: map['lockData'] ?? '',
        lockName: map['lockName'] ?? 'My Lock',
        ownerUid: map['ownerUid'] ?? '',
        ownerEmail: map['ownerEmail'] ?? '',
        createdAt: map['createdAt'] ?? 0,
      );
}
