import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../Organizer/Models/event_post.dart';
import '../../shared/app_dialog.dart';
import '../../shared/friendly_errors.dart';

Future<Map<String, dynamic>?> _getOrganizerDoc(String uid) async {
  if (uid.isEmpty) return null;
  final doc = await FirebaseFirestore.instance.collection('organizers').doc(uid).get();
  return doc.data();
}

String _bestOrgName(Map<String, dynamic>? data, {required String fallback}) {
  if (data == null) return fallback;
  final v = (data['name'] ?? data['displayName'] ?? data['fullName'] ?? data['email'] ?? fallback).toString();
  return v.trim().isEmpty ? fallback : v;
}

class AdminEventDetailScreen extends StatelessWidget {
  final String eventId;

  const AdminEventDetailScreen({
    super.key,
    required this.eventId,
  });

  Future<void> _toggleAllowEditPublished(bool currentValue) async {
    await FirebaseFirestore.instance.collection('events').doc(eventId).set(
      {'allowEditPublished': !currentValue, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<void> _toggleArchived(bool currentValue) async {
    await FirebaseFirestore.instance.collection('events').doc(eventId).set(
      {'archived': !currentValue, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<void> _deleteEvent(BuildContext context) async {
    try {
      await FirebaseFirestore.instance.collection('events').doc(eventId).delete();
      if (!context.mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      await AppDialogs.showError(
        context,
        title: 'Delete failed',
        message: FriendlyErrors.fromUnknown(e),
      );
    }
  }

  // -------------------------
  // Edit requests helpers
  // -------------------------
  CollectionReference<Map<String, dynamic>> get _editReqRef =>
      FirebaseFirestore.instance.collection('edit_requests');

  Stream<QuerySnapshot<Map<String, dynamic>>> _watchEditRequestsForEvent() {
    return _editReqRef.where('eventId', isEqualTo: eventId).snapshots();
  }

  Future<void> _approveRequest({
    required String requestId,
  }) async {
    final db = FirebaseFirestore.instance;
    final eventRef = db.collection('events').doc(eventId);
    final reqRef = _editReqRef.doc(requestId);

    await db.runTransaction((tx) async {
      final reqSnap = await tx.get(reqRef);
      if (!reqSnap.exists) throw Exception('Request not found');

      // 1) allow edit on event
      tx.set(
        eventRef,
        {
          'allowEditPublished': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // 2) mark request approved
      tx.set(
        reqRef,
        {
          'status': 'approved',
          'updatedAt': FieldValue.serverTimestamp(),
          'handledAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> _rejectRequest({
    required String requestId,
  }) async {
    await _editReqRef.doc(requestId).set(
      {
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
        'handledAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventRef = FirebaseFirestore.instance.collection('events').doc(eventId);

    final bookingsQ = FirebaseFirestore.instance.collectionGroup('bookings').where('eventId', isEqualTo: eventId);

    final reportsQ = FirebaseFirestore.instance.collection('reports').where('eventId', isEqualTo: eventId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: eventRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Event details')),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Event details')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Event details')),
            body: const Center(child: Text('Event not found.')),
          );
        }

        final data = snapshot.data!.data() ?? <String, dynamic>{};
        final event = EventPost.fromMap(data, snapshot.data!.id);

        final allowEdit = event.allowEditPublished == true;
        final archived = event.archived == true;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Event details'),
            actions: [
              IconButton(
                tooltip: 'Delete event',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete event?'),
                      content: const Text('This will permanently delete the event.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                      ],
                    ),
                  );

                  if (ok == true) {
                    await _deleteEvent(context);
                  }
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                event.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),

              if (event.coverImageUrl != null && event.coverImageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    event.coverImageUrl!,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: const Center(child: Icon(Icons.image_outlined, size: 50)),
                ),

              const SizedBox(height: 14),

              _MetaLine(label: 'Category', value: event.category),
              _MetaLine(label: 'Location', value: event.location),

              // Organizer NAME (not id)
              FutureBuilder<Map<String, dynamic>?>(
                future: _getOrganizerDoc(event.organizerId),
                builder: (context, snap) {
                  final orgName = _bestOrgName(
                    snap.data,
                    fallback: event.organizerId.isEmpty ? '—' : event.organizerId,
                  );
                  return _MetaLine(label: 'Organizer', value: orgName);
                },
              ),

              _MetaLine(label: 'Status', value: event.status.name),

              const SizedBox(height: 14),

              // Live counts
              Row(
                children: [
                  Expanded(
                    child: _CountCard(
                      icon: Icons.confirmation_number_outlined,
                      title: 'Bookings',
                      stream: bookingsQ.snapshots().map((s) => s.docs.length),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CountCard(
                      icon: Icons.flag_outlined,
                      title: 'Reports',
                      stream: reportsQ.snapshots().map((s) => s.docs.length),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Text(
                'Description',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(event.description.isEmpty ? '—' : event.description),

              const SizedBox(height: 18),

              Card(
                child: SwitchListTile(
                  title: const Text('Allow organizer to edit published event'),
                  subtitle: const Text(
                    'If enabled, organizer can edit this published event. Otherwise it is read-only.',
                  ),
                  value: allowEdit,
                  onChanged: (_) async {
                    await _toggleAllowEditPublished(allowEdit);
                  },
                ),
              ),

              Card(
                child: SwitchListTile(
                  title: const Text('Archive event'),
                  subtitle: const Text('Archived events should not appear to users.'),
                  value: archived,
                  onChanged: (_) async {
                    await _toggleArchived(archived);
                  },
                ),
              ),

              const SizedBox(height: 18),

              Text(
                'Edit requests',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),

              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _watchEditRequestsForEvent(),
                builder: (context, reqSnap) {
                  if (reqSnap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (reqSnap.hasError) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text('Could not load edit requests: ${reqSnap.error}'),
                      ),
                    );
                  }

                  final docs = reqSnap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          'No edit requests for this event.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: docs.map((d) {
                      final m = d.data();
                      final status = (m['status'] ?? 'pending').toString().toLowerCase();
                      final organizerId = (m['organizerId'] ?? '').toString().trim();

                      final bool isPending = status == 'pending';

                      return Card(
                        child: ListTile(
                          leading: Icon(
                            isPending
                                ? Icons.hourglass_top_rounded
                                : (status == 'approved' ? Icons.check_circle : Icons.cancel),
                          ),
                          title: FutureBuilder<Map<String, dynamic>?>(
                            future: _getOrganizerDoc(organizerId),
                            builder: (context, snap) {
                              final name = _bestOrgName(
                                snap.data,
                                fallback: organizerId.isEmpty ? '—' : organizerId,
                              );
                              return Text('Organizer: $name');
                            },
                          ),
                          subtitle: Text('Status: ${status.isEmpty ? 'pending' : status}'),
                          trailing: isPending
                              ? Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () async {
                                  try {
                                    await _rejectRequest(requestId: d.id);
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    await AppDialogs.showError(
                                      context,
                                      message: FriendlyErrors.fromUnknown(e),
                                    );
                                  }
                                },
                                child: const Text('Reject'),
                              ),
                              FilledButton(
                                onPressed: () async {
                                  try {
                                    await _approveRequest(requestId: d.id);
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    await AppDialogs.showError(
                                      context,
                                      message: FriendlyErrors.fromUnknown(e),
                                    );
                                  }
                                },
                                child: const Text('Approve'),
                              ),
                            ],
                          )
                              : null,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetaLine extends StatelessWidget {
  final String label;
  final String value;

  const _MetaLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: t.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Stream<int> stream;

  const _CountCard({
    required this.icon,
    required this.title,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.bodySmall),
                  const SizedBox(height: 4),
                  StreamBuilder<int>(
                    stream: stream,
                    builder: (context, snap) {
                      final v = snap.data;
                      return Text(
                        v?.toString() ?? '—',
                        style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
