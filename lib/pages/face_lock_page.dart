import 'package:flutter/material.dart';
import 'package:ttlock_flutter/ttlock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FaceLockPage extends StatefulWidget {
  final String lockData;
  final String lockName;
  final String lockId;

  const FaceLockPage({
    Key ? key,
    required this.lockData,
    required this.lockName,
    required this.lockId,
  }) : super(key: key);

  @override
  State<FaceLockPage> createState() => _FaceLockPageState();
}

class _FaceLockPageState extends State<FaceLockPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _status = '';
  bool _loading = false;
  bool _success = false;

  void _setStatus(String msg, {bool success = false, bool loading = false}) {
    if (mounted) {
      setState(() {
        _status = msg;
        _success = success;
        _loading = loading;
      });
    }
  }

  Future<void> _saveFaceToFirestore(String faceNumber, String name) async {
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

  void _addFace() {
    _setStatus('Initializing face scan...', loading: true);
    final int startDate = DateTime.now().millisecondsSinceEpoch;
    final int endDate = startDate + (365 * 24 * 60 * 60 * 1000);


    TTLock.addFace(
      null,
      startDate,
      endDate,
      widget.lockData,

      //call backs
      // if -> face detected(update state)
      (TTFaceState state, TTFaceErrorCode faceErrorCode) {
        if (state == TTFaceState.canStartAdd) {
          _setStatus('Face detected! Hold still...', loading: true);
        } else if (state == TTFaceState.error) {
          _setStatus(_faceErrorMessage(faceErrorCode), loading: true);
        }
      },

      //
      (String faceNumber) {
        _setStatus('Face scanned! Enter a name...', success: true);
        _showNameDialog(faceNumber);
      },

      //
      (errorCode, errorMsg) {
        _setStatus('Failed: $errorMsg ($errorCode)');
      },
    );
  }

  void _showNameDialog(String faceNumber) {
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool saving = false;
        return StatefulBuilder(
          builder: (ctx, setDlgState) => AlertDialog(
            title: const Text('Name this Face'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 48),
                const SizedBox(height: 12),

                Text(
                  'Face registered!\nID: $faceNumber',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),

                const SizedBox(height: 16),

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
              ],
            ),
            actions: [
              // Skip button
              if (!saving)
                TextButton(
                  onPressed: () async {
                    setDlgState(() => saving = true);
                    await _saveFaceToFirestore(faceNumber, 'Unknown');
                    if (ctx.mounted) Navigator.pop(ctx);
                    _setStatus('Face saved as Unknown.', success: true);
                  },
                  child: const Text('Skip'),
                ),

              // Save button or loading indicator
              saving
                  ? const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: () async {
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

                        // Show loading
                        setDlgState(() => saving = true);

                        // Save to Firestore
                        await _saveFaceToFirestore(faceNumber, name);

                        // Close dialog FIRST then update status
                        if (ctx.mounted) Navigator.pop(ctx);
                        _setStatus('Face saved for $name!', success: true);
                      },
                      child: const Text('Save'),
                    ),
            ],
          ),
        );
      },
    );
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Face Lock'),
        //${widget.lockName} - can be added after "-" line 327
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.delete_sweep),
          //   tooltip: 'Clear All',
          //   onPressed: _loading ? null : _clearAllFaces,
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

          // Face list from Firestore
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
                          final createdAt = data['createdAt'] as int? ?? 0;
                          final date =
                              DateTime.fromMillisecondsSinceEpoch(createdAt);
                          final dateStr =
                              '${date.day}/${date.month}/${date.year}';

                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.indigo,
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                'ID: $faceNumber\nAdded: $dateStr',
                                style: const TextStyle(fontSize: 11),
                              ),
                              isThreeLine: true,

                              // trailing: PopupMenuButton<String>(
                              //   onSelected: (val) {
                              //     if (val == 'rename') {
                              //       _renameFace(faceNumber, name);
                              //     } else if (val == 'delete') {
                              //       _deleteFace(faceNumber, name);
                              //     }
                              //   },
                              //   itemBuilder: (_) => [
                              //     const PopupMenuItem(
                              //       value: 'rename',
                              //       child: Row(children: [
                              //         Icon(Icons.edit, size: 18),
                              //         SizedBox(width: 8),
                              //         Text('Rename'),
                              //       ]),
                              //     ),
                              //     const PopupMenuItem(
                              //       value: 'delete',
                              //       child: Row(children: [
                              //         Icon(Icons.delete,
                              //             size: 18, color: Colors.red),
                              //         SizedBox(width: 8),
                              //         Text('Delete',
                              //             style: TextStyle(color: Colors.red)),
                              //       ]),
                              //     ),
                              //   ],
                              // ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _addFace,
        backgroundColor: _loading ? Colors.grey : Colors.green,
        icon: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.face_retouching_natural_outlined),
        label: Text(_loading ? 'Scanning...' : 'Add Face+'),
      ),
    );
  }
}
