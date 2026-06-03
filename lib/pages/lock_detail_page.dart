import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ttlock_flutter/ttlock.dart';
import '../models/lock_model.dart';
import '../models/ekey_model.dart';
import '../services/firebase_service.dart';
import 'face_lock_page.dart';
import 'home_page.dart';

class LockDetailPage extends StatefulWidget {
  final LockModel lock;
  const LockDetailPage({Key? key, required this.lock}) : super(key: key);

  @override
  State<LockDetailPage> createState() => _LockDetailPageState();
}

class _LockDetailPageState extends State<LockDetailPage> {
  bool _unlocking = false;
  String _unlockStatus = '';

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  void _resetL() async {

    // Show confirmation first
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Lock'),
        content: const Text(
            'This will reset the lock and remove it from your account. You will need to initialize it again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    _showLoadingDialog();

    TTLock.resetLock(
      widget.lock.lockData,
          () async {

        // ── Delete lock + subcollections from Firestore ──
        try {
          // Delete all faces
          final facesSnap = await FirebaseFirestore.instance
              .collection('locks')
              .doc(widget.lock.lockId)
              .collection('faces')
              .get();
          for (final doc in facesSnap.docs) {
            await doc.reference.delete();
          }

          // Delete all sent ekeys for this lock
          final ekeysSnap = await FirebaseFirestore.instance
              .collection('ekeys')
              .where('lockId', isEqualTo: widget.lock.lockId)
              .get();
          for (final doc in ekeysSnap.docs) {
            await doc.reference.delete();
          }

          // Delete the lock document itself
          await FirebaseFirestore.instance
              .collection('locks')
              .doc(widget.lock.lockId)
              .delete();

        } catch (e) {
          debugPrint('Firestore cleanup error: $e');
        }

        // Close loading dialog
        if (mounted) Navigator.of(context).pop();

        // Go to home
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
                (route) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lock reset successfully. You can now re-initialize it.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
          (errorCode, errorMsg) {
        if (mounted) Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reset Failed: $errorMsg'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  // ── Owner BLE Unlock button ───────────────────────────────────────────────
  void _unlock() {
    setState(() {
      _unlocking = true;
      _unlockStatus = 'Connecting to lock...';
    });

    TTLock.controlLock(
      widget.lock.lockData,
      TTControlAction.unlock,

      //success call back
      (lockTime, electricQuantity, uniqueId, lockData) {
        if (mounted) {
          setState(() {
            _unlocking = false;
            _unlockStatus = 'Unlocked! ';
            //Battery: $electricQuantity%
          });
        }
      },

      //failed call back
      (errorCode, errorMsg) {
        if (mounted) {
          setState(() {
            _unlocking = false;
            _unlockStatus = 'Error: $errorMsg';
          });
        }
      },
    );
  }

  // ── Send Ekey Dialog ────────────────────────────────────────────────────
  void _showSendEkeyDialog() {
    final emailCtrl = TextEditingController();
    String keyType = 'permanent';
    bool sending = false;
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Send Ekey'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Guest's Email",
                  hintText: 'user2@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),

              const SizedBox(height: 16),

              const Text('Key Type:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: keyType,
                decoration: const InputDecoration(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'permanent', child: Text('Permanent')),
                  DropdownMenuItem(value: 'timed', child: Text('Timed (30 days)')),
                ],
                onChanged: (v) => setDlgState(() => keyType = v!),
              ),
              if (dialogError != null) ...[
                const SizedBox(height: 8),
                Text(dialogError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            sending
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: () async {
                      final email = emailCtrl.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        setDlgState(() => dialogError = 'Enter valid email');
                        return;
                      }
                      setDlgState(() {
                        sending = true;
                        dialogError = null;
                      });
                      try {
                        final now = DateTime.now().millisecondsSinceEpoch;
                        await FirebaseService.sendEkey(
                          lock: widget.lock,
                          guestEmail: email,
                          keyType: keyType,
                          startDate: now,
                          endDate: keyType == 'permanent'
                              ? 0
                              : now + (30 * 24 * 60 * 60 * 1000),
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Ekey sent to $email'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDlgState(() {
                          sending = false;
                          dialogError = 'Failed: $e';
                        });
                      }
                    },
                    child: const Text('Send'),
                  ),
          ],
        ),
      ),
    );
  }

// ui only ----->
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.lock.lockName)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // Lock info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.lock, color: Colors.indigo),
                      const SizedBox(width: 8),
                      Text(widget.lock.lockName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ]
                    ),

                    const Divider(height: 20),

                    Text('MAC: ${widget.lock.lockMac}',
                        style: const TextStyle(color: Colors.grey)),
                    Text('ID: ${widget.lock.lockId}',
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Unlock button
            ElevatedButton.icon(
              onPressed: _unlocking ? null : _unlock,
              icon: _unlocking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.lock_open),
              label: Text(_unlocking ? 'Connecting...' : 'Unlock via BLE'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),

            // Unlock status
            if (_unlockStatus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _unlockStatus,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _unlockStatus.contains('Error')
                        ? Colors.red
                        : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Send ekey button
            ElevatedButton.icon(
              onPressed: _showSendEkeyDialog,
              icon: const Icon(Icons.send),
              label: const Text('Send Ekey to User'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),

            const SizedBox(height: 12),

            // Add face & manage lock button
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FaceLockPage(
                    lockData: widget.lock.lockData,
                    lockName: widget.lock.lockName,
                    lockId: widget.lock.lockId,   // ← pass lockId for Firestore
                  ),
                ),
              ),

              icon: const Icon(Icons.face),

              label: const Text('Add Face Lock'),

              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                minimumSize: const Size(double.infinity, 52),
              ),
            ),

            const SizedBox(height: 12),

            // Add Timed Face Lock button ->
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FaceLockPage(
                    lockData: widget.lock.lockData,
                    lockName: widget.lock.lockName,
                    lockId: widget.lock.lockId,
                    isTimed: true,   // ← THIS is the only difference
                  ),
                ),
              ),
              icon: const Icon(Icons.timer),
              label: const Text('Add Timed Face Lock'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                minimumSize: const Size(double.infinity, 52),
              ),
            ),

            const SizedBox(height: 12),

            // reset button -> reset lock fn
            ElevatedButton.icon(
              onPressed: _resetL,
              icon: const Icon(Icons.lock_reset),
              label: const Text('Reset Lock'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            ),

            const SizedBox(height: 20),

            // Sent ekeys list history down below buttons
            const Text(
              'Sent Ekeys History-',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: StreamBuilder<List<EkeyModel>>(
                stream: FirebaseService.getSentEkeys(widget.lock.lockId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final ekeys = snap.data ?? [];
                  if (ekeys.isEmpty) {
                    return const Center(
                      child: Text('No ekeys sent yet.',
                          style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return ListView.separated(
                    itemCount: ekeys.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final ekey = ekeys[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                ekey.status == 'active'
                                    ? Colors.green
                                    : Colors.grey,
                            radius: 18,
                            child: const Icon(Icons.vpn_key,
                                color: Colors.white, size: 18),
                          ),
                          title: Text(ekey.guestEmail,
                              style: const TextStyle(fontSize: 14)),
                          subtitle: Text(
                            '${ekey.keyType}  |  ${ekey.status}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: ekey.status == 'active'
                              ? TextButton(
                                  onPressed: () async {
                                    await FirebaseService.revokeEkey(
                                        ekey.ekeyId);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                        content: Text('Ekey revoked'),
                                        backgroundColor: Colors.orange,
                                      ));
                                    }
                                  },

                                  child: const Text('Revoke',
                                      style: TextStyle(color: Colors.red)),
                                )
                              : const Text('Revoked',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}