import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/lock_model.dart';
import '../models/ekey_model.dart';
import 'scan_page.dart';
import 'lock_detail_page.dart';
import 'ekey_unlock_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SmartLock'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () async => await FirebaseService.logout(),
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.lock), text: 'My Locks'),
              Tab(icon: Icon(Icons.vpn_key), text: 'Received Ekeys'),
            ],
          ),
        ),

        // FAB to go to scan page (add lock)
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScanPage()),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Add Lock'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),

        body: TabBarView(
          children: [

            // ── Tab 1: My Locks (Owner) ─────────────────────────>
            StreamBuilder<List<LockModel>>(
              stream: FirebaseService.getMyLocks(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final locks = snap.data ?? [];
                if (locks.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_open, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No locks yet.\nTap + Add Lock to scan and\ninitialize your lock.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: locks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final lock = locks[i];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.indigo,
                          child: Icon(Icons.lock, color: Colors.white),
                        ),
                        title: Text(lock.lockName,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(lock.lockMac,
                            style: const TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LockDetailPage(lock: lock),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            // ── Tab 2: Received Ekeys (Guest) ───────────────────
            StreamBuilder<List<EkeyModel>>(
              stream: FirebaseService.getReceivedEkeys(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final ekeys = snap.data ?? [];
                if (ekeys.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.vpn_key_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No ekeys received yet.\nAsk a lock owner to send you one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: ekeys.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final ekey = ekeys[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              ekey.isExpired ? Colors.grey : Colors.green,
                          child:
                              const Icon(Icons.vpn_key, color: Colors.white),
                        ),
                        title: Text(ekey.lockName,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'From: ${ekey.ownerEmail}\nType: ${ekey.keyType}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        isThreeLine: true,
                        trailing: ekey.isExpired
                            ? const Chip(
                                label: Text('Expired',
                                    style: TextStyle(color: Colors.white)),
                                backgroundColor: Colors.grey,
                              )
                            : ElevatedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        EkeyUnlockPage(ekey: ekey),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(80, 36),
                                ),
                                child: const Text('Unlock'),
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
