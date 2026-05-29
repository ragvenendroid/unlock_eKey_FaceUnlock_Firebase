import 'package:flutter/material.dart';
import 'package:ttlock_flutter/ttlock.dart';
import '../services/firebase_service.dart';
import '../models/lock_model.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({Key? key}) : super(key: key);

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final List<Map> _devices = [];        // store raw Map
  bool _scanning = false;
  String _status = 'Tap Scan to find nearby locks';

  @override
  void dispose() {
    TTLock.stopScanLock();
    super.dispose();
  }

  void _startScan() {
    setState(() {
      _devices.clear();
      _scanning = true;
      _status = 'Scanning for locks...';
    });

    TTLock.startScanLock((deviceInfo) {
      if (!mounted) return;
      // deviceInfo is TTLockScanModel — get mac from it
      final model = deviceInfo as TTLockScanModel;
      final mac = model.lockMac;
      final exists = _devices.any((d) => d['lockMac'] == mac);
      if (!exists && mac.isNotEmpty) {
        // Store as Map using the same keys TTLockScanModel uses
        setState(() => _devices.add({
          'lockMac': model.lockMac,
          'lockName': model.lockName,
          'electricQuantity': model.electricQuantity,
          'isInited': model.isInited,
          'isAllowUnlock': model.isAllowUnlock,
          'lockVersion': model.lockVersion,
          'rssi': model.rssi,
        }));
      }
    });

    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        TTLock.stopScanLock();
        setState(() {
          _scanning = false;
          _status = _devices.isEmpty
              ? 'No locks found. Try again.'
              : '${_devices.length} lock(s) found. Tap to initialize.';
        });
      }
    });
  }

  void _initializeLock(Map device) async {
    final mac = device['lockMac'] as String? ?? '';
    setState(() => _status = 'Initializing $mac...');

    TTLock.initLock(
      device,
          (lockData) async {
        try {
          final lockMac = device['lockMac'] as String? ?? '';
          final lockName = device['lockName'] as String? ?? '';

          final lock = LockModel(
            lockId: lockMac.replaceAll(':', ''),
            lockMac: lockMac,
            lockData: lockData,
            lockName: lockName.isNotEmpty ? lockName : 'My Lock',
            ownerUid: FirebaseService.currentUser!.uid,
            ownerEmail: FirebaseService.currentUser!.email!,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          );
          await FirebaseService.saveLock(lock);

          if (mounted) {
            setState(() => _status = 'Lock initialized and saved!');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Lock added successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            await Future.delayed(const Duration(seconds: 1));
            if (mounted) Navigator.pop(context);
          }
        } catch (e) {
          if (mounted) setState(() => _status = 'Failed: $e');
        }
      },
          (errorCode, errorMsg) {
        if (mounted) {
          setState(() => _status = 'Init failed: $errorMsg ($errorCode)');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Lock')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.indigo.shade100),
              ),
              child: Row(
                children: [
                  if (_scanning)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  if (_scanning) const SizedBox(width: 8),
                  Expanded(
                    child: Text(_status,
                        style: const TextStyle(color: Colors.indigo)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _scanning ? null : _startScan,
              icon: const Icon(Icons.bluetooth_searching),
              label: Text(_scanning ? 'Scanning...' : 'Scan for Locks'),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _devices.isEmpty
                  ? const Center(
                child: Text(
                  'Make sure your lock is in\ninitialization mode (reset).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              )
                  : ListView.separated(
                itemCount: _devices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final device = _devices[i];
                  final mac = device['lockMac'] ?? 'Unknown';
                  final name = device['lockName'] ?? '';
                  final rssi = device['rssi'] ?? 0;
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.indigo,
                        child: Icon(Icons.bluetooth, color: Colors.white),
                      ),
                      title: Text(name.toString().isNotEmpty
                          ? name.toString()
                          : mac.toString()),
                      subtitle: Text('MAC: $mac  RSSI: $rssi'),
                      trailing: ElevatedButton(
                        onPressed: () => _initializeLock(device),
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size(80, 36)),
                        child: const Text('Add'),
                      ),
                    ),
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