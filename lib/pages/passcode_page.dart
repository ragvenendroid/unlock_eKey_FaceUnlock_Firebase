import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/passcode_service.dart';

class PasscodePage extends StatefulWidget {
  final String lockId;
  final String lockData;
  final String lockName;

  const PasscodePage({
    Key? key,
    required this.lockId,
    required this.lockData,
    required this.lockName,
  }) : super(key: key);

  @override
  State<PasscodePage> createState() => _PasscodePageState();
}

class _PasscodePageState extends State<PasscodePage> {
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

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final passcodeCtrl = TextEditingController();
    //bool obscure = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool submitting = false;
        return StatefulBuilder(
          builder: (ctx, setDlgState) => AlertDialog(
            title: const Row(
              children: [

                //Icon(Icons.password, color: Colors.red),
                SizedBox(width: 8),
                Text('Add Passcode'),
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
                    labelText: 'Label / Person Name',
                    //hintText: 'e.g. John, Main Door',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 14),

                TextField(
                  controller: passcodeCtrl,
                  keyboardType: TextInputType.number,
                  //obscureText: obscure,
                  maxLength: 9,
                  decoration: InputDecoration(
                    labelText: 'Passcode (4–9 digits)',
                    //hintText: 'e.g. 123456',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    counterText: '',

                    // suffixIcon: IconButton(
                    //   icon: Icon(obscure
                    //       ? Icons.visibility_off
                    //       : Icons.visibility),
                    //   onPressed: () =>
                    //       setDlgState(() => obscure = !obscure),
                    // ),

                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              submitting
                  ? const Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2
                    )
                ),
              ) : ElevatedButton.icon(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  final passcode = passcodeCtrl.text.trim();
                  if (name.isEmpty) {
                    _showSnack('Please enter a name');
                    return;
                  }
                  if (passcode.length < 4 || passcode.length > 9) {
                    _showSnack('Passcode must be 4–9 digits');
                    return;
                  }
                  if (!RegExp(r'^\d+$').hasMatch(passcode)) {
                    _showSnack('Digits only');
                    return;
                  }
                  setDlgState(() => submitting = true);
                  Navigator.pop(ctx);
                  _submit(name: name, passcode: passcode);
                },
                icon: const Icon(Icons.check),
                label: const Text('Submit'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red),
              ),
            ],
          ),
        );
      },
    );
  }

  void _submit({required String name, required String passcode}) {
    _setStatus('Sending passcode to lock...', loading: true);
    final int start = DateTime.now().millisecondsSinceEpoch;
    final int end = start + (365 * 24 * 60 * 60 * 1000);

    // static method/fn call ->
    // 1st fn/method -> PasscodeService.createPasscode() -> send metadata through
    // ble to physical lock(TTLock parameters) after completing successful
    // passcode transfer (onSuccess)
    // 2nd fn/method -> PasscodeService.savePasscodeToFirestore() -> (onSuccess)
    // will start sending metadata to firestore using async await.
    PasscodeService.createPasscode(
      passcode: passcode,
      lockData: widget.lockData,
      startDate: start,
      endDate: end,
      onSuccess: () async {
        await PasscodeService.savePasscodeToFirestore(

          // lockId -> because passcode will save to the particular lock
          lockId: widget.lockId,
          name: name,
          passcode: passcode,
          startDate: start,
          endDate: end,
          isTimed: false,
        );
        _setStatus('Passcode saved for $name!', success: true);
      },
      onError: (errorCode, errorMsg) {
        _setStatus('Failed: $errorMsg ($errorCode)');
      },
    );
  }

  // void _deletePasscode({
  //   required String docId,
  //   required String name,
  //   required String passcode,
  // }) {
  //   showDialog(
  //     context: context,
  //     builder: (ctx) => AlertDialog(
  //       title: const Text('Delete Passcode'),
  //       content: Text('Remove passcode for "$name"?'),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(ctx),
  //           child: const Text('Cancel'),
  //         ),
  //         ElevatedButton(
  //           style:
  //           ElevatedButton.styleFrom(backgroundColor: Colors.red),
  //           onPressed: () async {
  //             Navigator.pop(ctx);
  //             _setStatus('Deleting...', loading: true);
  //             PasscodeService.deletePasscode(
  //               passcode: passcode,
  //               lockData: widget.lockData,
  //               onSuccess: () async {
  //                 await PasscodeService.deletePasscodeFromFirestore(
  //                     lockId: widget.lockId, docId: docId);
  //                 _setStatus('Deleted for $name', success: true);
  //               },
  //               onError: (errorCode, errorMsg) {
  //                 _setStatus('Failed: $errorMsg');
  //               },
  //             );
  //           },
  //           child: const Text('Delete',
  //               style: TextStyle(color: Colors.white)),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 2)));
  }

  // String _formatDateTime(DateTime dt) {
  //   const months = [
  //     '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  //     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  //   ];
  //   final h = dt.hour.toString().padLeft(2, '0');
  //   final m = dt.minute.toString().padLeft(2, '0');
  //   return '${dt.day} ${months[dt.month]} ${dt.year}  $h:$m';
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Passcodes — ${widget.lockName}')),
      body: Column(
        children: [
          // Status bar
          if (_status.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
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
                      _success
                          ? Icons.check_circle
                          : Icons.error_outline,
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

          // Passcode list — permanent only
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: PasscodeService.getPasscodesStream(widget.lockId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final allDocs = snap.data?.docs ?? [];
                final docs = allDocs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return data['isTimed'] != true;
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.password,
                            size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text('No passcodes yet.',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 16)),
                        const SizedBox(height: 8),
                        const Text('Tap + to add one.',
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
                        '${docs.length} passcode(s)',
                        style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w500),
                      ),
                    ),

                    Expanded(
                      child: ListView.separated(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final data =
                          docs[i].data() as Map<String, dynamic>;
                          final docId =
                              data['docId'] as String? ?? '';
                          final name =
                              data['name'] as String? ?? 'Unknown';
                          final passcode =
                              data['passcode'] as String? ?? '';
                          final createdAt =
                              data['createdAt'] as int? ?? 0;
                          final date =
                          DateTime.fromMillisecondsSinceEpoch(
                              createdAt);
                          final dateStr =
                              '${date.day}/${date.month}/${date.year}';

                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.red,
                                child: Text(
                                  name.isNotEmpty
                                      ? name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const Icon(Icons.lock_outline,
                                        size: 12, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      passcode,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 3,
                                      ),
                                    ),
                                  ]),
                                  Text('Added: $dateStr',
                                      style:
                                      const TextStyle(fontSize: 11)),
                                ],
                              ),

                              //isThreeLine: true,
                              // trailing: IconButton(
                              //   icon: const Icon(Icons.delete_outline,
                              //       color: Colors.red),
                              //   onPressed: () => _deletePasscode(
                              //     docId: docId,
                              //     name: name,
                              //     passcode: passcode,
                              //   ),
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
        onPressed: _loading ? null : _showAddDialog,
        backgroundColor: _loading ? Colors.grey : Colors.red,
        icon: _loading
            ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white
            )
        )
            : const Icon(Icons.add),
        label: Text(_loading ? 'Sending...' : 'Add Passcode'),
      ),
    );
  }
}