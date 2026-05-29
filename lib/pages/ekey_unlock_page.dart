import 'package:flutter/material.dart';
import 'package:ttlock_flutter/ttlock.dart';
import '../models/ekey_model.dart';

class EkeyUnlockPage extends StatefulWidget {
  final EkeyModel ekey;
  const EkeyUnlockPage({Key? key, required this.ekey}) : super(key: key);

  @override
  State<EkeyUnlockPage> createState() => _EkeyUnlockPageState();
}

class _EkeyUnlockPageState extends State<EkeyUnlockPage> {
  bool _unlocking = false;
  String _status = '';
  bool _success = false;

  void _unlock() {
    // Check expiry
    if (widget.ekey.isExpired) {
      setState(() => _status = 'This ekey has expired.');
      return;
    }

    setState(() {
      _unlocking = true;
      _status = 'Scanning for lock via BLE...';
      _success = false;
    });



    // Use lockData from Firestore (owner's lockData shared via ekey)
    TTLock.controlLock(
      widget.ekey.lockData,
      TTControlAction.unlock,
      (lockTime, electricQuantity, uniqueId, lockData) {
        if (mounted) {
          setState(() {
            _unlocking = false;
            _success = true;
            _status = 'Unlocked successfully!\nBattery: $electricQuantity%';
          });
        }
      },
      (errorCode, errorMsg) {
        if (mounted) {
          setState(() {
            _unlocking = false;
            _success = false;
            _status = 'Failed: $errorMsg\n($errorCode)';
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ekey = widget.ekey;

    return Scaffold(
      appBar: AppBar(title: Text(ekey.lockName)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ekey info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.vpn_key, color: Colors.indigo),
                      const SizedBox(width: 8),
                      const Text('Ekey Details',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ]),
                    const Divider(height: 20),
                    _infoRow('Lock', ekey.lockName),
                    _infoRow('Sent by', ekey.ownerEmail),
                    _infoRow('Key type', ekey.keyType),
                    _infoRow('Status',
                        ekey.isExpired ? 'Expired' : ekey.status),
                    if (ekey.endDate != 0)
                      _infoRow(
                        'Expires',
                        DateTime.fromMillisecondsSinceEpoch(ekey.endDate)
                            .toString()
                            .substring(0, 16),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Big unlock button
            SizedBox(
              height: 64,
              child: ElevatedButton.icon(
                onPressed: (_unlocking || ekey.isExpired) ? null : _unlock,
                icon: _unlocking
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.lock_open, size: 28),
                label: Text(
                  _unlocking ? 'Connecting...' : 'Unlock Lock',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      ekey.isExpired ? Colors.grey : Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Status message
            if (_status.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _success
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _success ? Colors.green : Colors.red,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _success ? Icons.check_circle : Icons.error_outline,
                      color: _success ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _status,
                        style: TextStyle(
                          color: _success
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (ekey.isExpired)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'This ekey has expired. Contact the lock owner for a new one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:',
                style: const TextStyle(
                    color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
