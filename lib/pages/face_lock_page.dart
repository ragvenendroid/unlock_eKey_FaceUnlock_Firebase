import 'package:flutter/material.dart';
import 'package:ttlock_flutter/ttlock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FaceLockPage extends StatefulWidget {

  // Widget Parameters
  // These are passed when opening the page.
  final String lockData;
  final String lockName;
  final String lockId;

  // isTimed -> Controls mode:
  // if -> true (Timed Face ON)
  // true = timed dialog, false = normal/Permanent Face
  final bool isTimed;

  const FaceLockPage({
    Key? key,
    required this.lockData,
    required this.lockName,
    required this.lockId,
    this.isTimed = false,
  }) : super(key: key);

  @override
  State<FaceLockPage> createState() => _FaceLockPageState();
}

class _FaceLockPageState extends State<FaceLockPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // State Variables -> These control the status banner.
  // Initializing face scan..., or Face saved successfully
  String _status = '';
  bool _loading = false;
  bool _success = false;

  // _setStatus -> Updates UI status.
  // by changing the State Variables
  // and rebuilds UI
  void _setStatus(String msg, {bool success = false, bool loading = false}) {
    if (mounted) {
      setState(() {
        _status = msg;
        _success = success;
        _loading = loading;
      });
    }
  }

  // Stores metadata -> saved document which is in firebase firestore
  // No biometric data stored -> Only metadata.
  Future<void> _saveFaceToFirestore(
    String faceNumber,
    String name,
    int startDate,
    int endDate,
    bool isTimed,
  ) async {
    await _db
        .collection('locks')
        .doc(widget.lockId)
        .collection('faces')
        .doc(faceNumber)
        .set({
      'faceNumber': faceNumber,
      'name': name,
      'ownerUid': _auth.currentUser!.uid,
      'lockId': widget.lockId,
      'isTimed': isTimed,
      'startDate': startDate,
      'endDate': endDate,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _deleteFaceFromFirestore(String faceNumber) async {
    await _db
        .collection('locks')
        .doc(widget.lockId)
        .collection('faces')
        .doc(faceNumber)
        .delete();
  }

  Future<void> _clearAllFacesFromFirestore() async {
    final snap = await _db
        .collection('locks')
        .doc(widget.lockId)
        .collection('faces')
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  // step 2 -> addFace fn
  // It checks: widget.isTimed == true or widget.isTimed == false
  // a) if true -> widget.isTimed == true
  // Add Face
  //     ↓
  // _showTimedDialog()

  // b) if false -> widget.isTimed == false
  // Add Face
  //     ↓
  // _showNameDialog()
  void _addFace() {
    if (widget.isTimed) {
      _showTimedDialog();
    } else {
      _showNameDialog();
    }
  }

  // ── NORMAL name dialog (permanent) ────────────────────>
  void _showNameDialog() {
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool scanning = false;
        return StatefulBuilder(
          builder: (ctx, setDlgState) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.face, color: Colors.green),
                SizedBox(width: 8),
                Text('Add Face'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Person Name',
                    hintText: 'e.g. John Doe',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                // Container(
                //   padding: const EdgeInsets.all(10),
                //   decoration: BoxDecoration(
                //     color: Colors.green.shade50,
                //     borderRadius: BorderRadius.circular(8),
                //     border: Border.all(color: Colors.green),
                //   ),
                //   child: const Text(
                //     'After tapping Start Scan, stand in front of the lock camera.',
                //     style: TextStyle(fontSize: 12, color: Colors.green),
                //   ),
                // ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: scanning ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              scanning
                  ? const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : ElevatedButton.icon(
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a name'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                          return;
                        }
                        setDlgState(() => scanning = true);
                        Navigator.pop(ctx);

                        // step -> 3
                        // after tapping - Start Scan & Save
                        // the details such as name, startDate, endDate & faceScan at last
                        // go to firebase and ble device
                        _startFaceScan(
                          name: name,
                          startDate: DateTime.now().millisecondsSinceEpoch,
                          endDate: DateTime.now().millisecondsSinceEpoch +
                              (365 * 24 * 60 * 60 * 1000),
                          isTimed: false,
                        );
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Scan & Save'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                    ),
            ],
          ),
        );
      },
    );
  }

  // ── TIMED dialog —> name + start + end datetime ──────────────────────────
  // default time -> 24 hrs
  void _showTimedDialog() {
    final nameCtrl = TextEditingController();
    DateTime startDt = DateTime.now();
    DateTime endDt = DateTime.now().add(const Duration(hours: 24));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool scanning = false;
        return StatefulBuilder(
          builder: (ctx, setDlgState) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.timer, color: Colors.orange),
                SizedBox(width: 8),
                Text('Timed Face '),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Person Name',
                      hintText: 'e.g. John Doe',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Start Date & Time',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await _pickDateTime(ctx, startDt);
                      if (picked != null) setDlgState(() => startDt = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: Colors.indigo),
                        const SizedBox(width: 8),
                        Text(_formatDateTime(startDt),
                            style: const TextStyle(fontSize: 14)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('End Date & Time',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await _pickDateTime(ctx, endDt);
                      if (picked != null) setDlgState(() => endDt = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(_formatDateTime(endDt),
                            style: const TextStyle(fontSize: 14)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Duration: ${_durationText(startDt, endDt)}',
                    style: TextStyle(
                      color: endDt.isAfter(startDt) ? Colors.green : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Container(
                  //   padding: const EdgeInsets.all(10),
                  //   decoration: BoxDecoration(
                  //     color: Colors.orange.shade50,
                  //     borderRadius: BorderRadius.circular(8),
                  //     border: Border.all(color: Colors.orange),
                  //   ),
                  //   child: const Text(
                  //     'After tapping Start Scan, stand in front of the lock camera.',
                  //     style: TextStyle(fontSize: 12, color: Colors.orange),
                  //   ),
                  // ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: scanning ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              scanning
                  ? const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : ElevatedButton.icon(
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a name'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                          return;
                        }
                        if (!endDt.isAfter(startDt)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('End time must be after start time'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                          return;
                        }
                        setDlgState(() => scanning = true);
                        Navigator.pop(ctx);
                        _startFaceScan(
                          name: name,
                          startDate: startDt.millisecondsSinceEpoch,
                          endDate: endDt.millisecondsSinceEpoch,
                          isTimed: true,
                        );
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Scan & Save'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange),
                    ),
            ],
          ),
        );
      },
    );
  }

  // flow ------------------->
  //FAB Click
  //     ↓
  // Dialog Opens
  //     ↓
  // User enters details
  //     ↓
  // Start BLE Face Scan
  //     ↓
  // Face Registered
  //     ↓
  // Save to Firebase
  //     ↓
  // UI Updates Automatically
  void _startFaceScan({
    required String name,
    required int startDate,
    required int endDate,
    required bool isTimed,
  }) {
    _setStatus('Initializing face scan...', loading: true);

    // This sends a BLE command to the physical lock.
    // Lock camera starts.
    // User stands in front.
    TTLock.addFace(
      null,
      startDate,
      endDate,
      widget.lockData,

      // Progress Callback
      (TTFaceState state, TTFaceErrorCode faceErrorCode) {
        if (state == TTFaceState.canStartAdd) {
          _setStatus('Face detected! Hold still...', loading: true);
        } else if (state == TTFaceState.error) {
          _setStatus(_faceErrorMessage(faceErrorCode), loading: true);
        }
      },


      // Success Callback
      // only send -> faceNumber = 12 -> Face #12 enrolled
      (String faceNumber) async {
        // save to firebase
        // Now:
        // await _saveFaceToFirestore(...) runs -> save the user details/metadata to the firebase
        // Only metadata stores -> firebase
        // biometric template stays inside the TTLock lock -> ble device

        // actual async await (industry standards)->
        // means:
        // Wait until Firebase saves metadata
        // Then continue
        // Without await:
        // Show success
        // Before Firebase finishes
        await _saveFaceToFirestore(
            faceNumber, name, startDate, endDate, isTimed);
        _setStatus('Face saved for $name!', success: true);
      },
      (errorCode, errorMsg) {
        _setStatus('Failed: $errorMsg ($errorCode)');
      },
    );
  }

  // ── Pick date then time ────────────────────────────────────────────────
  Future<DateTime?> _pickDateTime(BuildContext ctx, DateTime initial) async {
    final date = await showDatePicker(
      context: ctx,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(minutes: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return null;

    final time = await showTimePicker(
      context: ctx,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  // ── Format datetime for display ───────────────────────────────────────
  String _formatDateTime(DateTime dt) {
    final months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month]} ${dt.year}  $h:$m';
  }

  // ── Duration label ──────────────────────────────
  String _durationText(DateTime start, DateTime end) {
    if (!end.isAfter(start)) return 'Invalid range';
    final diff = end.difference(start);
    if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours % 24}h';
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
    return '${diff.inMinutes}m';
  }

  // ── DELETE FACE ──────────────────────────────────
  void _deleteFace(String faceNumber, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Face'),
        content: Text('Remove face for "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              _setStatus('Deleting face...', loading: true);
              TTLock.deleteFace(
                faceNumber,
                widget.lockData,
                () async {
                  await _deleteFaceFromFirestore(faceNumber);
                  _setStatus('Face deleted for $name', success: true);
                },
                (errorCode, errorMsg) {
                  _setStatus('Failed: $errorMsg ($errorCode)');
                },
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── CLEAR ALL FACES ──────────────────>
  void _clearAllFaces() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Faces'),
        content: const Text('Remove ALL registered faces from the lock?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              _setStatus('Clearing all faces...', loading: true);
              TTLock.clearFace(
                widget.lockData,
                () async {
                  await _clearAllFacesFromFirestore();
                  _setStatus('All faces cleared!', success: true);
                },
                (errorCode, errorMsg) {
                  _setStatus('Failed: $errorMsg ($errorCode)');
                },
              );
            },
            child:
                const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── RENAME ──────>
  void _renameFace(String faceNumber, String currentName) {
    final nameCtrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'New Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              await _db
                  .collection('locks')
                  .doc(widget.lockId)
                  .collection('faces')
                  .doc(faceNumber)
                  .update({'name': name});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Face Error Messages -> Converts TTLock errors into human-friendly messages
  // exam - No face detected. Look at the camera.
  String _faceErrorMessage(TTFaceErrorCode code) {
    switch (code) {
      case TTFaceErrorCode.noFaceDetected:
        return 'No face detected. Look at the camera.';
      case TTFaceErrorCode.tooCloseToTheTop:
        return 'Move face down a little.';
      case TTFaceErrorCode.tooCloseToTheBottom:
        return 'Move face up a little.';
      case TTFaceErrorCode.tooCloseToTheLeft:
        return 'Move face right a little.';
      default:
        return 'Adjust position and try again.';
    }
  }

  // ui only ----->
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isTimed ? 'Timed Face Lock' : 'Face Lock'),
        actions: [
          // delete all faces icon button
          // IconButton(
          // icon: const Icon(Icons.delete_sweep),
          // tooltip: 'Clear All',
          // onPressed: _loading ? null : _clearAllFaces,
          // ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          if (_status.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: _loading
                  ? Colors.blue.shade50
                  : _success
                      ? Colors.green.shade50
                      : Colors.red.shade50,
              child: Row(
                children: [
                  if (_loading)
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    Icon(
                      _success ? Icons.check_circle : Icons.error_outline,
                      size: 16,
                      color: _success ? Colors.green : Colors.red,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _status,
                      style: TextStyle(
                        color: _loading
                            ? Colors.blue.shade800
                            : _success
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // StreamBuilder -> Face list-> Realtime Firestore Updates
          // StreamBuilder Magic -> This continuously listens to Firestore.
          // 1. Whenever a face is added:
          // 2. Firestore updates
          // 3. UI updates automatically
          // 4. No refresh button needed.
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('locks')
                  .doc(widget.lockId)
                  .collection('faces')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final faces = snap.data?.docs ?? [];

                if (faces.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.face, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text('No faces registered yet.',
                            style: TextStyle(color: Colors.grey, fontSize: 16)),
                        const SizedBox(height: 8),
                        const Text('Tap + Add Face to register.',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        '${faces.length} face(s) registered',
                        style: const TextStyle(
                            color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: faces.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final data = faces[i].data() as Map<String, dynamic>;
                          final faceNumber =
                              data['faceNumber'] as String? ?? '';
                          final name = data['name'] as String? ?? 'Unknown';
                          final isTimed = data['isTimed'] as bool? ?? false;
                          final createdAt = data['createdAt'] as int? ?? 0;
                          final endDate = data['endDate'] as int? ?? 0;
                          final date =
                              DateTime.fromMillisecondsSinceEpoch(createdAt);
                          final dateStr =
                              '${date.day}/${date.month}/${date.year}';

                          // Check if timed key is expired
                          final isExpired = isTimed &&
                              endDate > 0 &&
                              DateTime.now().millisecondsSinceEpoch > endDate;

                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isExpired
                                    ? Colors.grey
                                    : isTimed
                                        ? Colors.orange
                                        : Colors.indigo,
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  if (isTimed)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isExpired
                                            ? Colors.grey
                                            : Colors.orange,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isExpired ? 'Expired' : 'Timed',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 10),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ID: $faceNumber',
                                      style: const TextStyle(fontSize: 11)),
                                  Text('Added: $dateStr',
                                      style: const TextStyle(fontSize: 11)),
                                  if (isTimed && endDate > 0)
                                    Text(
                                      'Expires: ${_formatDateTime(DateTime.fromMillisecondsSinceEpoch(endDate))}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isExpired
                                            ? Colors.red
                                            : Colors.orange,
                                      ),
                                    ),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (val) {
                                  if (val == 'rename') {
                                    _renameFace(faceNumber, name);
                                  } else if (val == 'delete') {
                                    _deleteFace(faceNumber, name);
                                  }
                                },
                                itemBuilder: (_) => [
                                  // const PopupMenuItem(
                                  //   value: 'rename',
                                  //   child: Row(children: [
                                  //     Icon(Icons.edit, size: 18),
                                  //     SizedBox(width: 8),
                                  //     Text('Rename'),
                                  //   ]),
                                  // ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(children: [
                                      Icon(Icons.delete,
                                          size: 18, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete',
                                          style: TextStyle(color: Colors.red)),
                                    ]),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      // step -> 1
      // user click floating action button
      // Add Face+ -> Flutter calls: _addFace();
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _addFace,
        backgroundColor: _loading
            ? Colors.grey
            : widget.isTimed
                ? Colors.orange
                : Colors.green,
        icon: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Icon(widget.isTimed
                ? Icons.timer
                : Icons.face_retouching_natural_outlined),
        label: Text(_loading
            ? 'Scanning...'
            : widget.isTimed
                ? 'Add Timed Face'
                : 'Add Face+'),
      ),
    );
  }
}

// how it work's internally -> internal working blocks
// TTLock stores biometrics securely.
// Firestore stores metadata.
// BLE handles enrollment.
// UI updates in real time.

// Flow A to Z ->
// Open Face Page
//         ↓
// Tap Add Face
//         ↓
// Dialog Opens
//         ↓
// Enter Name
//         ↓
// Choose Time (if timed)
//         ↓
// Start Scan
//         ↓
// TTLock.addFace()
//         ↓
// BLE Communication
//         ↓
// Lock Captures Face
//         ↓
// Returns faceNumber
//         ↓
// Save Metadata to Firestore
//         ↓
// StreamBuilder Updates UI
//         ↓
// Face Appears In List

// ble side flow ->
// TTLock Lock stores the actual face biometric.
//
// Firestore stores only:
// - name
// - faceNumber
// - dates
// - owner info

//_startFaceScan(...) -> is basically packing all the information collected
// from the dialog and sending it to the face enrollment function. It doesn't
// scan the face itself; it passes the user's inputs (name, start time,
// end time, timed/permanent flag) to the function that starts the TTLock BLE
// face enrollment process.

// Changing values in Flutter or Firebase afterward does NOT
// reconfigure the face inside the lock.
// You were only changing metadata.
// The physical lock doesn't read Firestore.

//NEW FLOW
//
// Now your flow is:
//
// Tap Add Face
//       ↓
// _showTimedDialog()
//       ↓
// User chooses 2PM-5PM
//       ↓
// _startFaceScan()
//       ↓
// TTLock.addFace(
//        startDate=2PM,
//        endDate=5PM
//      )
//       ↓
// Face Enrolled
//
// Look carefully.
//
// Now the lock receives:
//
// TTLock.addFace(
//   null,
//   2PM,
//   5PM,
//   widget.lockData,
//   ...
// )
//
// BEFORE enrollment.

