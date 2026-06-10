import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/passcode_service.dart';

class PasscodePageTimed extends StatefulWidget {
  final String lockId;
  final String lockData;
  final String lockName;

  const PasscodePageTimed({
    Key? key,
    required this.lockId,
    required this.lockData,
    required this.lockName,
  }) : super(key: key);

  @override
  State<PasscodePageTimed> createState() => _PasscodePageTimedState();
}

class _PasscodePageTimedState extends State<PasscodePageTimed> {
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

  void _showAddTimedDialog() {
    final nameCtrl = TextEditingController();
    final passcodeCtrl = TextEditingController();
    DateTime startDt = DateTime.now();
    DateTime endDt = DateTime.now().add(const Duration(hours: 24));
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
                //Icon(Icons.timer, color: Colors.orange),
                SizedBox(width: 8),
                Text('Timed Passcode'),
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
                      labelText: 'Name',
                      //hintText: 'e.g. John, Main Door',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Passcode
                  TextField(
                    controller: passcodeCtrl,
                    keyboardType: TextInputType.number,
                    //obscureText: obscure,
                    maxLength: 9,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Passcode',
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

                  const SizedBox(height: 20),

                  // Start datetime
                  const Text('Start Date & Time',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13
                      )
                  ),

                  const SizedBox(height: 6),

                  InkWell(
                    onTap: () async {
                      final picked =
                      await _pickDateTime(ctx, startDt);
                      if (picked != null) {
                        setDlgState(() => startDt = picked);
                      }
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
                            style: const TextStyle(fontSize: 13)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // End datetime
                  const Text('End Date & Time',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked =
                      await _pickDateTime(ctx, endDt);
                      if (picked != null) {
                        setDlgState(() => endDt = picked);
                      }
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
                            style: const TextStyle(fontSize: 13)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Duration
                  Text(
                    'Duration: ${_durationText(startDt, endDt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: endDt.isAfter(startDt)
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ],
              ),
            ),

            actions: [
              TextButton(
                onPressed:
                submitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              submitting
                  ? const Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: SizedBox(
                    width: 24,
                    height: 24,
                    child:
                    CircularProgressIndicator(strokeWidth: 2)),
              )
                  : ElevatedButton.icon(
                onPressed: () {

                  final name = nameCtrl.text.trim();
                  final passcode = passcodeCtrl.text.trim();

                  if (name.isEmpty) {
                    _showSnack('Please enter name');
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
                  if (!endDt.isAfter(startDt)) {
                    _showSnack(
                        'End time must be after start time');
                    return;
                  }
                  setDlgState(() => submitting = true);
                  Navigator.pop(ctx);
                  _submit(
                    name: name,
                    passcode: passcode,
                    startDate: startDt.millisecondsSinceEpoch,
                    endDate: endDt.millisecondsSinceEpoch,
                  );
                },
                icon: const Icon(Icons.check),
                label: const Text('Submit'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange),
              ),
            ],
          ),
        );
      },
    );
  }

  void _submit({
    required String name,
    required String passcode,
    required int startDate,
    required int endDate,
  }) {
    _setStatus('Sending timed passcode to lock...', loading: true);

    PasscodeService.createPasscode(
      passcode: passcode,
      lockData: widget.lockData,
      startDate: startDate,
      endDate: endDate,
      onSuccess: () async {
        await PasscodeService.savePasscodeToFirestore(
          lockId: widget.lockId,
          name: name,
          passcode: passcode,
          startDate: startDate,
          endDate: endDate,
          isTimed: true,
        );
        _setStatus('Timed passcode saved!', success: true);
      },
      onError: (errorCode, errorMsg) {
        _setStatus('Failed: $errorMsg ($errorCode)');
      },
    );
  }

  void _deletePasscode({
    required String docId,
    required String name,
    required String passcode,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Passcode'),
        content: Text('Remove passcode "$passcode"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),

          // ElevatedButton(
          //   style:
          //   ElevatedButton.styleFrom(backgroundColor: Colors.red),
          //   onPressed: () async {
          //     Navigator.pop(ctx);
          //     _setStatus('Deleting...', loading: true);
          //     PasscodeService.deletePasscode(
          //       passcode: passcode,
          //       lockData: widget.lockData,
          //       onSuccess: () async {
          //         await PasscodeService.deletePasscodeFromFirestore(
          //             lockId: widget.lockId, docId: docId);
          //         _setStatus('Deleted', success: true);
          //       },
          //       onError: (errorCode, errorMsg) {
          //         _setStatus('Failed: $errorMsg');
          //       },
          //     );
          //   },
          //   child: const Text('Delete',
          //       style: TextStyle(color: Colors.white)),
          // ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 2)));
  }

  Future<DateTime?> _pickDateTime(
      BuildContext ctx, DateTime initial) async {
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
    return DateTime(
        date.year, date.month, date.day, time.hour, time.minute);
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month]} ${dt.year}  $h:$m';
  }

  String _durationText(DateTime start, DateTime end) {
    if (!end.isAfter(start)) return 'Invalid range';
    final diff = end.difference(start);
    if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours % 24}h';
    if (diff.inHours > 0)
      return '${diff.inHours}h ${diff.inMinutes % 60}m';
    return '${diff.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
      AppBar(title: Text('Timed Passcodes — ${widget.lockName}')),
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
                        child:
                        CircularProgressIndicator(strokeWidth: 2))
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

          // Timed passcode list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
              PasscodeService.getPasscodesStream(widget.lockId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                final allDocs = snap.data?.docs ?? [];
                final docs = allDocs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return data['isTimed'] == true;
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.timer_off,
                            size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text('No timed passcodes yet.',
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
                      padding:
                      const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        '${docs.length} timed passcode(s)',
                        style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16),
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
                          final endDate =
                              data['endDate'] as int? ?? 0;
                          final startDate =
                              data['startDate'] as int? ?? 0;

                          final isExpired = endDate > 0 &&
                              DateTime.now().millisecondsSinceEpoch >
                                  endDate;

                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isExpired
                                    ? Colors.grey
                                    : Colors.orange,
                                child: Icon(
                                  isExpired
                                      ? Icons.timer_off
                                      : Icons.timer,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                      name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isExpired
                                          ? Colors.grey
                                          : Colors.orange,
                                      borderRadius:
                                      BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isExpired ? 'Expired' : 'Active',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),

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
                                  if (startDate > 0)
                                    Text(
                                      'From: ${_formatDateTime(DateTime.fromMillisecondsSinceEpoch(startDate))}',
                                      style: const TextStyle(
                                          fontSize: 11),
                                    ),
                                  if (endDate > 0)
                                    Text(
                                      'To: ${_formatDateTime(DateTime.fromMillisecondsSinceEpoch(endDate))}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isExpired
                                            ? Colors.red
                                            : Colors.orange,
                                      ),
                                    ),
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
        onPressed: _loading ? null : _showAddTimedDialog,
        backgroundColor: _loading ? Colors.grey : Colors.orange,
        icon: _loading
            ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white
            )
        )
            : const Icon(Icons.timer),
        label: Text(_loading ? 'Sending...' : 'Add Timed Passcode'),
      ),
    );
  }
}