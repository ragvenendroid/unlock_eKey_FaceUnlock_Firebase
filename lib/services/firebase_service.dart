import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/lock_model.dart';
import '../models/ekey_model.dart';

class FirebaseService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  // ─── AUTH ────────────────────────────────────────────────────────────────

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<User?> register(String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    // Save user profile to Firestore
    await _db.collection('users').doc(result.user!.uid).set({
      'uid': result.user!.uid,
      'email': email.trim(),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    return result.user;
  }

  static Future<User?> login(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    return result.user;
  }

  static Future<void> logout() => _auth.signOut();

  // ─── LOCKS ───────────────────────────────────────────────────────────────

  /// Save lock to Firestore after BLE initialization
  static Future<void> saveLock(LockModel lock) async {
    await _db.collection('locks').doc(lock.lockId).set(lock.toMap());
  }

  /// Update lockData when lock is re-initialized
  static Future<void> updateLockData(
      String lockId, String newLockData) async {
    await _db
        .collection('locks')
        .doc(lockId)
        .update({'lockData': newLockData});
  }

  /// Stream of locks owned by current user
  static Stream<List<LockModel>> getMyLocks() {
    return _db
        .collection('locks')
        .where('ownerUid', isEqualTo: currentUser!.uid)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => LockModel.fromMap(d.data())).toList());
  }

  // ─── EKEYS ───────────────────────────────────────────────────────────────

  /// User1 sends ekey to User2 — stores lockData in Firestore
  static Future<void> sendEkey({
    required LockModel lock,
    required String guestEmail,
    required String keyType,
    required int startDate,
    required int endDate,
  }) async {
    final user = currentUser!;
    final ekeyId = _db.collection('ekeys').doc().id;

    final ekey = EkeyModel(
      ekeyId: ekeyId,
      lockId: lock.lockId,
      lockMac: lock.lockMac,
      lockData: lock.lockData, // share owner's lockData
      lockName: lock.lockName,
      ownerUid: user.uid,
      ownerEmail: user.email!,
      guestEmail: guestEmail.trim().toLowerCase(),
      keyType: keyType,
      status: 'active',
      startDate: startDate,
      endDate: endDate,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    await _db.collection('ekeys').doc(ekeyId).set(ekey.toMap());
  }

  // Ekeys sent by current user (owner view)
  static Stream<List<EkeyModel>> getSentEkeys(String lockId) {
    return _db
        .collection('ekeys')
        .where('ownerUid', isEqualTo: currentUser!.uid)
        .where('lockId', isEqualTo: lockId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => EkeyModel.fromMap(d.data())).toList());
  }

  /// Ekeys received by current user (guest view)
  static Stream<List<EkeyModel>> getReceivedEkeys() {
    final email = currentUser!.email!.trim().toLowerCase();
    return _db
        .collection('ekeys')
        .where('guestEmail', isEqualTo: email)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => EkeyModel.fromMap(d.data())).toList());
  }

  /// Revoke an ekey (owner only)
  static Future<void> revokeEkey(String ekeyId) async {
    await _db
        .collection('ekeys')
        .doc(ekeyId)
        .update({'status': 'revoked'});
  }
}
