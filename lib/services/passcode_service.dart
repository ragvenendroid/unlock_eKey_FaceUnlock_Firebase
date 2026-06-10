import 'package:ttlock_flutter/ttlock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PasscodeService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // custom passcode sent through ble to physical device
  static Future<void> createPasscode({
    required String passcode,
    required String lockData,
    required int startDate,
    required int endDate,
    required Function() onSuccess,
    required Function(dynamic errorCode, String errorMsg) onError,
  }) async {
    TTLock.supportFunction(TTLockFunction.managePasscode, lockData, (isSupport) {
      if (!isSupport) {
        onError(null, 'This lock does not support passcode management');
        return;
      }
      TTLock.createCustomPasscode(
        passcode,
        startDate,
        endDate,
        lockData,
        onSuccess,
            (errorCode, errorMsg) => onError(errorCode, errorMsg),
      );
    });
  }

  // delete passcode through ble from physical device
  static Future<void> deletePasscode({
    required String passcode,
    required String lockData,
    required Function() onSuccess,
    required Function(dynamic errorCode, String errorMsg) onError,
  }) async {
    TTLock.supportFunction(TTLockFunction.managePasscode, lockData, (isSupport) {
      if (!isSupport) {
        onError(null, 'This lock does not support passcode management');
        return;
      }
      TTLock.deletePasscode(
        passcode,
        lockData,
        onSuccess,
            (errorCode, errorMsg) => onError(errorCode, errorMsg),
      );
    });
  }

  // saving passcode/info/metadata to firebase
  static Future<void> savePasscodeToFirestore({
    required String lockId,
    required String name,
    required String passcode,
    required int startDate,
    required int endDate,
    required bool isTimed,
  }) async {
    final docId = _db
        .collection('locks')
        .doc(lockId)
        .collection('passcodes')
        .doc()
        .id;

    await _db
        .collection('locks')
        .doc(lockId)
        .collection('passcodes')
        .doc(docId)
        .set({
      'docId': docId,
      'name': name,
      'passcode': passcode,
      'ownerUid': _auth.currentUser!.uid,
      'lockId': lockId,
      'isTimed': isTimed,
      'startDate': startDate,
      'endDate': endDate,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // firestore - delete passcode
  static Future<void> deletePasscodeFromFirestore({
    required String lockId,
    required String docId,
  }) async {
    await _db
        .collection('locks')
        .doc(lockId)
        .collection('passcodes')
        .doc(docId)
        .delete();
  }

  // reading firestore - real-time stream of passcodes
  static Stream<QuerySnapshot> getPasscodesStream(String lockId) {
    return _db
        .collection('locks')
        .doc(lockId)
        .collection('passcodes')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }
}