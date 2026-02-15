import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shoo_fi/Admin/Screens/admin_login.dart';

import '../../shared/app_dialog.dart';
import '../../shared/friendly_errors.dart';
import 'admin_event_detail.dart';

/// Helpers available to Reports/Analytics
Future<Map<String, dynamic>?> _getUserDoc(String uid) async {
  if (uid.isEmpty) return null;
  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  return doc.data();
}

Future<Map<String, dynamic>?> _getOrganizerDoc(String uid) async {
  if (uid.isEmpty) return null;
  final doc = await FirebaseFirestore.instance.collection('organizers').doc(uid).get();
  return doc.data();
}

String _bestNameFromDoc(Map<String, dynamic>? data, {required String fallback}) {
  if (data == null) return fallback;
  final v = (data['name'] ?? data['displayName'] ?? data['fullName'] ?? data['email'] ?? fallback).toString().trim();
  return v.isEmpty ? fallback : v;
}

String _bestEventTitleFromMap(Map<String, dynamic>? data, {required String fallback}) {
  if (data == null) return fallback;
  final v = (data['title'] ?? data['eventTitle'] ?? data['name'] ?? fallback).toString().trim();
  return v.isEmpty ? fallback : v;
}

class AdminHomeScreen extends StatelessWidget {
  static const routeName = '/admin/home';
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdminHomePage();
}

/// Main page (tabs).
class AdminHomePage extends StatefulWidget {
  static const routeName = '/admin/home';
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
            (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      await AppDialogs.showError(
        context,
        message: FriendlyErrors.fromUnknown(e),
      );
    }
  }

  void _openEditRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminEditRequestsScreen()),
    );
  }

  /// Header: app icon + admin name + "Admin Dashboard"
  Widget get _adminHeader {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Text('Admin Dashboard');

    final ref = FirebaseFirestore.instance.collection('users').doc(uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (_, snap) {
        final data = snap.data?.data() ?? {};
        final name = (data['name'] ?? data['displayName'] ?? data['fullName'] ?? data['email'] ?? 'Admin').toString();

        return Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/icons/app_icon.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
                const Text('Admin Dashboard', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Small badge icon for pending edit requests
  Widget _editRequestsIconButton() {
    final q = FirebaseFirestore.instance
        .collection('edit_requests')
        .orderBy('createdAt', descending: true)
        .limit(200);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        final count = docs.where((d) => (d.data()['status'] ?? 'pending') == 'pending').length;

        return IconButton(
          tooltip: 'Edit requests',
          onPressed: _openEditRequests,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.mail_outline),
              if (count > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB91C1C),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: _adminHeader,
        actions: [
          // ✅ NEW: edit requests inbox
          _editRequestsIconButton(),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.report_problem_outlined), text: 'Reports'),
            Tab(icon: Icon(Icons.insights_outlined), text: 'Analytics'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primary.withValues(alpha: 0.06),
              Colors.transparent,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: TabBarView(
          controller: _tab,
          children: [
            _ReportsTab(db: _db),
            _AdminAnalyticsTab(db: _db),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// EDIT REQUESTS (NEW SCREEN)
/// ---------------------------------------------------------------------------
class AdminEditRequestsScreen extends StatefulWidget {
  const AdminEditRequestsScreen({super.key});

  @override
  State<AdminEditRequestsScreen> createState() => _AdminEditRequestsScreenState();
}

class _AdminEditRequestsScreenState extends State<AdminEditRequestsScreen> {
  final _db = FirebaseFirestore.instance;

  String _filter = 'pending'; // pending | approved | denied | all

  Query<Map<String, dynamic>> _query() {
    // ONLY orderBy => no composite index needed
    return _db
        .collection('edit_requests')
        .orderBy('createdAt', descending: true)
        .limit(200);
  }

  Future<String> _organizerName(String organizerId) async {
    final id = organizerId.trim();
    if (id.isEmpty) return '—';
    final doc = await _getOrganizerDoc(id);
    return _bestNameFromDoc(doc, fallback: id);
  }



  Future<void> _setRequestStatus(String requestId, String status) async {
    final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';
    await _db.collection('edit_requests').doc(requestId).set(
      {
        'status': status,
        'handledBy': adminId,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _approveRequest({
    required String requestId,
    required String eventId,
  }) async {
    if (eventId.trim().isEmpty) {
      await AppDialogs.showError(context, message: 'This request has no valid eventId.');
      return;
    }

    final ok = await AppDialogs.showConfirm(
      context,
      title: 'Approve edit access?',
      message: 'This will allow the organizer to edit the published event.',
      confirmText: 'Approve',
    );
    if (ok != true) return;

    try {
      // 1) Mark request approved
      await _setRequestStatus(requestId, 'approved');

      // 2) Grant event permission
      await _db.collection('events').doc(eventId.trim()).set(
        {
          'allowEditPublished': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      await AppDialogs.showInfo(context, message: 'Approved. Edit access granted.');
    } catch (e) {
      if (!mounted) return;
      await AppDialogs.showError(context, message: FriendlyErrors.fromUnknown(e));
    }
  }

  Future<void> _denyRequest({
    required String requestId,
  }) async {
    final ok = await AppDialogs.showConfirm(
      context,
      title: 'Deny request?',
      message: 'The organizer will not be allowed to edit this published event.',
      confirmText: 'Deny',
    );
    if (ok != true) return;

    try {
      await _setRequestStatus(requestId, 'denied');
      if (!mounted) return;
      await AppDialogs.showInfo(context, message: 'Denied.');
    } catch (e) {
      if (!mounted) return;
      await AppDialogs.showError(context, message: FriendlyErrors.fromUnknown(e));
    }
  }

  Future<void> _openRequestActions({
    required String requestId,
    required String eventId,
    required String organizerId,
    required String status,
  }) async {
    final cs = Theme.of(context).colorScheme;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: cs.primary.withValues(alpha: 0.12),
                    foregroundColor: cs.primary,
                    child: const Icon(Icons.edit_note_outlined),
                  ),
                  title: const Text('Edit request'),
                  subtitle: Text('Status: ${status.toUpperCase()}'),
                ),
                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: eventId.trim().isEmpty
                        ? null
                        : () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminEventDetailScreen(eventId: eventId.trim()),
                        ),
                      );
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open event'),
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: status == 'approved'
                            ? null
                            : () async {
                          Navigator.pop(context);
                          await _approveRequest(requestId: requestId, eventId: eventId);
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Approve'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: status == 'denied'
                            ? null
                            : () async {
                          Navigator.pop(context);
                          await _denyRequest(requestId: requestId);
                        },
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Deny'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                if (status != 'pending')
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          await _setRequestStatus(requestId, 'pending');
                          if (!mounted) return;
                          await AppDialogs.showInfo(context, message: 'Moved back to pending.');
                        } catch (e) {
                          if (!mounted) return;
                          await AppDialogs.showError(context, message: FriendlyErrors.fromUnknown(e));
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Move back to pending'),
                    ),
                  ),

                const SizedBox(height: 4),
                if (organizerId.trim().isNotEmpty)
                  FutureBuilder<String>(
                    future: _organizerName(organizerId),
                    builder: (context, snap) {
                      final name = (snap.data ?? organizerId).trim();
                      return Text(
                        'Organizer: $name',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      );
                    },
                  ),

              ],
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF16A34A);
      case 'denied':
        return const Color(0xFFB91C1C);
      case 'pending':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit requests'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(Icons.filter_list),
                    const Text('Filter:'),
                    _filterChip('pending', 'PENDING'),
                    _filterChip('approved', 'APPROVED'),
                    _filterChip('denied', 'DENIED'),
                    _filterChip('all', 'ALL'),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Unable to load edit requests.\n\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allDocs = snapshot.data?.docs ?? [];
                final docs = _filter == 'all'
                    ? allDocs
                    : allDocs.where((d) => ((d.data()['status'] ?? 'pending').toString() == _filter)).toList();

                if (docs.isEmpty) {
                  return const Center(child: Text('No edit requests found.'));
                }


                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final data = d.data();

                    final requestId = d.id;
                    final eventId = (data['eventId'] ?? '').toString();
                    final organizerId = (data['organizerId'] ?? '').toString();
                    final status = (data['status'] ?? 'pending').toString();

                    final tone = _statusColor(status);

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: tone.withValues(alpha: 0.12),
                          foregroundColor: tone,
                          child: const Icon(Icons.edit_outlined),
                        ),
                        title: Text(
                          eventId.trim().isEmpty ? 'Event (missing id)' : 'Event: $eventId',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _Pill(
                                text: status.toUpperCase(),
                                bg: tone.withValues(alpha: 0.10),
                                fg: tone,
                              ),
                              if (organizerId.trim().isNotEmpty)
                                FutureBuilder<String>(
                                  future: _organizerName(organizerId),
                                  builder: (context, snap) {
                                    final name = (snap.data ?? organizerId).trim();
                                    return _Pill(
                                      text: name.toUpperCase(),
                                      bg: cs.surfaceContainerHighest,
                                      fg: cs.onSurface,
                                    );
                                  },
                                ),

                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openRequestActions(
                          requestId: requestId,
                          eventId: eventId,
                          organizerId: organizerId,
                          status: status,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final cs = Theme.of(context).colorScheme;
    final selected = _filter == value;

    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: cs.primaryContainer,
    );
  }
}

// -----------------------------------------------------------------------------
// REPORTS TAB
// -----------------------------------------------------------------------------

class _ReportsTab extends StatefulWidget {
  final FirebaseFirestore db;
  const _ReportsTab({required this.db});

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  String _statusFilter = 'open'; // open | resolved | all
  String _typeFilter = 'all'; // all | spam | abuse | other

  // Stable caches to prevent flicker
  final Map<String, String> _eventTitleCache = {};
  final Map<String, Future<String>> _eventTitleFutureCache = {};

  /// IMPORTANT:
  /// We ONLY order by createdAt and we DO NOT add where() filters here.
  /// That avoids Firestore composite-index requirements entirely.
  Query<Map<String, dynamic>> _baseQuery() {
    return widget.db
        .collection('reports')
        .orderBy('createdAt', descending: true)
    // Fetch extra then filter locally to avoid index issues:
        .limit(200);
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    return docs.where((d) {
      final data = d.data();
      final status = (data['status'] ?? 'open').toString();
      final type = (data['type'] ?? 'other').toString();

      final statusOk = _statusFilter == 'all' || status == _statusFilter;
      final typeOk = _typeFilter == 'all' || type == _typeFilter;
      return statusOk && typeOk;
    }).toList();
  }

  Future<String> _fetchEventTitleFromEvents(String eventId, String fallback) async {
    final id = eventId.trim();
    if (id.isEmpty) return fallback;

    try {
      final snap = await widget.db.collection('events').doc(id).get();
      final data = snap.data();
      final title = (data?['title'] ?? data?['eventTitle'] ?? data?['name'] ?? '').toString().trim();

      final resolved = title.isNotEmpty ? title : fallback;
      _eventTitleCache[id] = resolved;
      return resolved;
    } catch (_) {
      _eventTitleCache[id] = fallback;
      return fallback;
    }
  }

  /// Returns a stable Future for an event title (no re-fetch on rebuild).
  Future<String> _eventTitleFuture({
    required String eventId,
    required String reportEventTitle,
  }) {
    final id = eventId.trim();

    // If report already has eventTitle, use it and cache it immediately.
    final reportTitle = reportEventTitle.trim();
    if (reportTitle.isNotEmpty) {
      if (id.isNotEmpty) _eventTitleCache[id] = reportTitle;
      return Future.value(reportTitle);
    }

    // If we already resolved it before, return immediately.
    final cached = _eventTitleCache[id];
    if (cached != null && cached.trim().isNotEmpty) {
      return Future.value(cached);
    }

    // Use a stable Future cached by eventId so FutureBuilder doesn't restart.
    return _eventTitleFutureCache.putIfAbsent(
      id.isEmpty ? '__no_event__' : id,
          () => _fetchEventTitleFromEvents(id, 'Reported event'),
    );
  }

  Future<void> _setReportStatus(String reportId, String newStatus) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await widget.db.collection('reports').doc(reportId).set(
      {
        'status': newStatus,
        'handledBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _confirmAndResolve(String reportId) async {
    final ok = await AppDialogs.showConfirm(
      context,
      title: 'Resolve report?',
      message: 'This will mark the report as resolved.',
      confirmText: 'Resolve',
    );
    if (ok != true) return;
    await _setReportStatus(reportId, 'resolved');
  }

  Future<void> _confirmAndReopen(String reportId) async {
    final ok = await AppDialogs.showConfirm(
      context,
      title: 'Reopen report?',
      message: 'This will mark the report as open again.',
      confirmText: 'Reopen',
    );
    if (ok != true) return;
    await _setReportStatus(reportId, 'open');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _SectionTitle(
                        icon: Icons.tune,
                        title: 'Filters',
                        subtitle: 'Narrow down moderation queue',
                      ),
                      const Spacer(),
                      Icon(Icons.shield_outlined, color: cs.primary),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    runSpacing: 10,
                    spacing: 12,
                    children: [
                      _ChipGroup(
                        label: 'Status',
                        value: _statusFilter,
                        options: const ['open', 'resolved', 'all'],
                        onChanged: (v) => setState(() => _statusFilter = v),
                      ),
                      _ChipGroup(
                        label: 'Type',
                        value: _typeFilter,
                        options: const ['all', 'spam', 'abuse', 'other'],
                        onChanged: (v) => setState(() => _typeFilter = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _baseQuery().snapshots(),
            builder: (context, snapshot) {
              // ✅ 1) Errors FIRST (prevents infinite spinner)
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Unable to load reports right now.\n\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              // ✅ 2) Loading state
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // ✅ 3) Safe data access
              final allDocs = snapshot.data?.docs ?? [];
              final docs = _applyFilters(allDocs);

              if (docs.isEmpty) {
                return const Center(child: Text('No reports found for this filter.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  final data = doc.data();

                  final reportId = doc.id;
                  final eventId = (data['eventId'] ?? '').toString();
                  final reportEventTitle = (data['eventTitle'] ?? '').toString();
                  final reason = (data['reason'] ?? '').toString();
                  final status = (data['status'] ?? 'open').toString();
                  final type = (data['type'] ?? 'other').toString();
                  final details = (data['details'] ?? '').toString();
                  final reportedBy = (data['reportedBy'] ?? '').toString();

                  final isOpen = status == 'open';
                  final badgeColor = isOpen ? const Color(0xFFB91C1C) : const Color(0xFF16A34A);

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: badgeColor.withValues(alpha: 0.12),
                        foregroundColor: badgeColor,
                        child: const Icon(Icons.flag_outlined),
                      ),

                      // ✅ Stable title (no flicker)
                      title: FutureBuilder<String>(
                        future: _eventTitleFuture(eventId: eventId, reportEventTitle: reportEventTitle),
                        builder: (context, snap) {
                          final id = eventId.trim();
                          final cached = _eventTitleCache[id];
                          final shown = (snap.data ?? cached ?? 'Reported event').trim();
                          return Text(shown, maxLines: 1, overflow: TextOverflow.ellipsis);
                        },
                      ),

                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Text(reason.isEmpty ? 'No reason provided' : reason),
                          const SizedBox(height: 6),

                          FutureBuilder<Map<String, dynamic>?>(
                            future: _getUserDoc(reportedBy),
                            builder: (_, snap) {
                              final name = _bestNameFromDoc(
                                snap.data,
                                fallback: reportedBy.isEmpty ? '—' : reportedBy,
                              );
                              return Text('Reported by: $name');
                            },
                          ),

                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _Pill(
                                text: type.toUpperCase(),
                                bg: Theme.of(context).colorScheme.surfaceContainerHighest,
                                fg: Theme.of(context).colorScheme.onSurface,
                              ),
                              _Pill(
                                text: status.toUpperCase(),
                                bg: badgeColor.withValues(alpha: 0.10),
                                fg: badgeColor,
                              ),
                              if (details.isNotEmpty)
                                _Pill(
                                  text: 'DETAILS',
                                  bg: Theme.of(context).colorScheme.primaryContainer,
                                  fg: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                            ],
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Moderation actions',
                        onSelected: (action) async {
                          try {
                            if (action == 'open') await _confirmAndReopen(reportId);
                            if (action == 'resolve') await _confirmAndResolve(reportId);

                            if (action == 'event') {
                              if (eventId.trim().isEmpty) {
                                await AppDialogs.showError(
                                  context,
                                  message: 'This report has no event linked to it.',
                                );
                                return;
                              }
                              if (!mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminEventDetailScreen(eventId: eventId.trim()),
                                ),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            await AppDialogs.showError(
                              context,
                              message: FriendlyErrors.fromUnknown(e),
                            );
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'event', child: Text('Open event')),
                          if (isOpen)
                            const PopupMenuItem(value: 'resolve', child: Text('Mark resolved'))
                          else
                            const PopupMenuItem(value: 'open', child: Text('Reopen')),
                        ],
                      ),
                      onTap: eventId.trim().isEmpty
                          ? null
                          : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminEventDetailScreen(eventId: eventId.trim()),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// ANALYTICS TAB
// -----------------------------------------------------------------------------
class _AdminAnalyticsTab extends StatefulWidget {
  final FirebaseFirestore db;
  const _AdminAnalyticsTab({required this.db});

  @override
  State<_AdminAnalyticsTab> createState() => _AdminAnalyticsTabState();
}

class _AdminAnalyticsTabState extends State<_AdminAnalyticsTab> {
  String _range = '30d'; // 7d | 30d | 90d | all

  final Map<String, String> _organizerNameCache = {};

  Future<String> _organizerName(String organizerId) async {
    final id = organizerId.trim();
    if (id.isEmpty) return '—';
    if (_organizerNameCache.containsKey(id)) return _organizerNameCache[id]!;
    final doc = await _getOrganizerDoc(id);
    final name = _bestNameFromDoc(doc, fallback: id);
    _organizerNameCache[id] = name;
    return name;
  }

  DateTime? _rangeStart() {
    final now = DateTime.now();
    switch (_range) {
      case '7d':
        return now.subtract(const Duration(days: 7));
      case '30d':
        return now.subtract(const Duration(days: 30));
      case '90d':
        return now.subtract(const Duration(days: 90));
      case 'all':
      default:
        return null;
    }
  }

  /// IMPORTANT CHANGE:
  /// Do NOT filter events by createdAt (many docs miss createdAt -> titles disappear -> you see IDs).
  Query<Map<String, dynamic>> _eventsQuery() {
    return widget.db.collection('events');
  }

  Query<Map<String, dynamic>> _bookingsQuery() {
    Query<Map<String, dynamic>> q = widget.db.collectionGroup('bookings');
    final start = _rangeStart();
    if (start != null) {
      q = q.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
    }
    return q;
  }

  Query<Map<String, dynamic>> _reportsQuery() {
    Query<Map<String, dynamic>> q = widget.db.collection('reports');
    final start = _rangeStart();
    if (start != null) {
      q = q.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
    }
    return q;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.primary.withValues(alpha: 0.12),
                  foregroundColor: cs.primary,
                  child: const Icon(Icons.insights_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analytics Overview',
                        style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'KPIs, trends, top entities, and moderation signals.',
                        style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                _RangeDropdown(
                  value: _range,
                  onChanged: (v) => setState(() => _range = v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _eventsQuery().snapshots(),
          builder: (context, eventsSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _bookingsQuery().snapshots(),
              builder: (context, bookingsSnap) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _reportsQuery().snapshots(),
                  builder: (context, reportsSnap) {
                    if (eventsSnap.hasError || bookingsSnap.hasError || reportsSnap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'Analytics error:\n'
                                '${eventsSnap.error ?? bookingsSnap.error ?? reportsSnap.error}',
                          ),
                        ),
                      );
                    }

                    if (!eventsSnap.hasData || !bookingsSnap.hasData || !reportsSnap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final events = eventsSnap.data!.docs;
                    final bookings = bookingsSnap.data!.docs;
                    final reports = reportsSnap.data!.docs;

                    // KPIs
                    final totalEvents = events.length;
                    int published = 0, draft = 0, archived = 0;

                    final organizerEventCount = <String, int>{};

                    // counts
                    final eventBookingCount = <String, int>{};
                    final reportsByEvent = <String, int>{};

                    // TITLES (the important fix)
                    final eventTitleById = <String, String>{};

                    // Build title map from EVENTS first
                    for (final doc in events) {
                      final e = doc.data();
                      final status = (e['status'] ?? '').toString();
                      final organizerId = (e['organizerId'] ?? '').toString();

                      final title = _bestEventTitleFromMap(e, fallback: '').trim();

                      if (status == 'published') published++;
                      if (status == 'draft') draft++;
                      if (status == 'archived') archived++;

                      if (organizerId.isNotEmpty) {
                        organizerEventCount[organizerId] = (organizerEventCount[organizerId] ?? 0) + 1;
                      }

                      if (title.isNotEmpty) {
                        eventTitleById[doc.id] = title;
                      }
                    }

                    int activeBookings = 0;
                    int totalTickets = 0;

                    // Revenue for ADMIN = total service fees collected
                    double totalRevenue = 0;

                    DateTime? readTs(dynamic v) => v is Timestamp ? v.toDate() : null;

                    // bookings trend
                    final now = DateTime.now();
                    final start = _rangeStart() ?? now.subtract(const Duration(days: 30));
                    final days = math.max(7, now.difference(start).inDays + 1);
                    final byDay = List<int>.filled(days, 0);

                    // Add titles from BOOKINGS too (guaranteed because you store eventTitle in booking doc)
                    for (final doc in bookings) {
                      final b = doc.data();
                      final status = (b['status'] ?? '').toString();
                      if (status.toLowerCase() == 'confirmed') activeBookings++;

                      final tickets = (b['ticketsCount'] is num) ? (b['ticketsCount'] as num).toInt() : 1;
                      totalTickets += tickets;

                      // --- service fee revenue (3%) ---
                      double fee = 0.0;

                      if (b['serviceFee'] is num) {
                        fee = (b['serviceFee'] as num).toDouble();
                      } else {
                        // backward-compatible fallback
                        if (b['subtotalPrice'] is num) {
                          final subtotal = (b['subtotalPrice'] as num).toDouble();
                          fee = ((subtotal * 0.03) * 100).roundToDouble() / 100;
                        } else if (b['ticketPrice'] is num) {
                          final ticketPrice = (b['ticketPrice'] as num).toDouble();
                          final subtotal = ticketPrice * tickets;
                          fee = ((subtotal * 0.03) * 100).roundToDouble() / 100;
                        } else {
                          fee = 0.0;
                        }
                      }

                      totalRevenue += fee;

                      final eventId = (b['eventId'] ?? '').toString().trim();
                      final bookingTitle = (b['eventTitle'] ?? '').toString().trim();

                      if (eventId.isNotEmpty) {
                        eventBookingCount[eventId] = (eventBookingCount[eventId] ?? 0) + tickets;

                        // If event title is missing from events map, fill from booking doc
                        if (bookingTitle.isNotEmpty && (eventTitleById[eventId] ?? '').trim().isEmpty) {
                          eventTitleById[eventId] = bookingTitle;
                        }
                      }

                      final createdAt = readTs(b['createdAt']);
                      if (createdAt != null) {
                        final idx = createdAt.difference(start).inDays;
                        if (idx >= 0 && idx < byDay.length) byDay[idx] += 1;
                      }
                    }

                    int openReports = 0, resolvedReports = 0;

                    // Add titles from REPORTS too (you usually store eventTitle in report doc)
                    for (final doc in reports) {
                      final r = doc.data();
                      final s = (r['status'] ?? 'open').toString();
                      if (s == 'open') openReports++;
                      if (s == 'resolved') resolvedReports++;

                      final eventId = (r['eventId'] ?? '').toString().trim();
                      final reportTitle = (r['eventTitle'] ?? '').toString().trim();

                      if (eventId.isNotEmpty) {
                        reportsByEvent[eventId] = (reportsByEvent[eventId] ?? 0) + 1;

                        if (reportTitle.isNotEmpty && (eventTitleById[eventId] ?? '').trim().isEmpty) {
                          eventTitleById[eventId] = reportTitle;
                        }
                      }
                    }

                    final totalBookings = bookings.length;
                    final totalReports = reports.length;

                    // ranking lists
                    final topOrganizers = organizerEventCount.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value));
                    final topOrganizersTop5 = topOrganizers.take(5).toList();

                    final topEventsByBookings = eventBookingCount.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value));
                    final topEventsTop5 = topEventsByBookings.take(5).toList();

                    final topReported = reportsByEvent.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value));
                    final topReportedTop5 = topReported.take(5).toList();

                    final statusParts = <String, int>{
                      'Published': published,
                      'Draft': draft,
                      'Archived': archived,
                    };

                    String eventTitleOrId(String eventId) {
                      final t = (eventTitleById[eventId] ?? '').trim();
                      return t.isNotEmpty ? t : eventId;
                    }

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: widget.db.collection('ratings').snapshots(),
                      builder: (context, ratingsSnap) {
                        double avgRating = 0.0;
                        int ratingsCount = 0;

                        if (ratingsSnap.hasData) {
                          final docs = ratingsSnap.data!.docs;
                          int sum = 0;

                          for (final d in docs) {
                            final r = d.data()['rating'];
                            if (r is num) {
                              sum += r.toInt();
                              ratingsCount++;
                            }
                          }
                          avgRating = ratingsCount == 0 ? 0.0 : (sum / ratingsCount);
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _KpiGrid(
                              items: [
                                _Kpi(
                                  title: 'Events',
                                  value: '$totalEvents',
                                  icon: Icons.event_available_outlined,
                                  tone: cs.primary,
                                ),
                                _Kpi(
                                  title: 'Bookings',
                                  value: '$totalBookings',
                                  icon: Icons.confirmation_number_outlined,
                                  tone: const Color(0xFF0EA5E9),
                                ),
                                _Kpi(
                                  title: 'Tickets',
                                  value: '$totalTickets',
                                  icon: Icons.people_outline,
                                  tone: const Color(0xFF22C55E),
                                ),
                                _Kpi(
                                  title: 'App revenue (fees)',
                                  value: '${totalRevenue.toStringAsFixed(2)} JD',
                                  icon: Icons.payments_outlined,
                                  tone: const Color(0xFFF59E0B),
                                ),
                                _Kpi(
                                  title: 'Reports',
                                  value: '$totalReports',
                                  icon: Icons.flag_outlined,
                                  tone: const Color(0xFFB91C1C),
                                ),
                                _Kpi(
                                  title: 'Open reports',
                                  value: '$openReports',
                                  icon: Icons.report_problem_outlined,
                                  tone: const Color(0xFFB91C1C),
                                ),
                                _Kpi(
                                  title: 'Resolved',
                                  value: '$resolvedReports',
                                  icon: Icons.verified_outlined,
                                  tone: const Color(0xFF16A34A),
                                ),
                                _Kpi(
                                  title: 'Active bookings',
                                  value: '$activeBookings',
                                  icon: Icons.task_alt_outlined,
                                  tone: const Color(0xFF6366F1),
                                ),
                                _Kpi(
                                  title: 'Avg rating',
                                  value: ratingsCount == 0 ? '-' : '${avgRating.toStringAsFixed(1)}/5',
                                  icon: Icons.star_rate_rounded,
                                  tone: const Color(0xFFF59E0B),
                                ),
                                _Kpi(
                                  title: 'Ratings',
                                  value: '$ratingsCount',
                                  icon: Icons.reviews_outlined,
                                  tone: const Color(0xFFF59E0B),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            LayoutBuilder(
                              builder: (context, c) {
                                final isWide = c.maxWidth > 850;

                                final left = Expanded(
                                  child: _SectionCard(
                                    title: 'Bookings trend',
                                    subtitle: 'Bookings per day (approx)',
                                    icon: Icons.show_chart,
                                    child: _BarChart(
                                      values: byDay,
                                      startLabel: _range == '7d' ? '7d ago' : 'start',
                                      endLabel: 'today',
                                    ),
                                  ),
                                );

                                final right = Expanded(
                                  child: _SectionCard(
                                    title: 'Event status mix',
                                    subtitle: 'Published vs Draft vs Archived',
                                    icon: Icons.pie_chart_outline,
                                    child: _DonutChart(parts: statusParts),
                                  ),
                                );

                                if (isWide) {
                                  return Row(
                                    children: [
                                      left,
                                      const SizedBox(width: 12),
                                      right,
                                    ],
                                  );
                                }
                                return Column(
                                  children: [
                                    left,
                                    const SizedBox(height: 12),
                                    right,
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 14),

                            _SectionCard(
                              title: 'Top organizers',
                              subtitle: 'By number of events',
                              icon: Icons.workspace_premium_outlined,
                              child: _RankList(
                                rows: topOrganizersTop5
                                    .map(
                                      (e) => _RankRow(
                                    title: e.key,
                                    titleFuture: _organizerName(e.key),
                                    value: '${e.value} events',
                                    icon: Icons.person_outline,
                                  ),
                                )
                                    .toList(),
                                emptyText: 'No organizers found in this range.',
                              ),
                            ),

                            const SizedBox(height: 12),

                            _SectionCard(
                              title: 'Top events',
                              subtitle: 'By booked tickets (from bookings)',
                              icon: Icons.local_fire_department_outlined,
                              child: _RankList(
                                rows: topEventsTop5
                                    .map(
                                      (e) => _RankRow(
                                    title: eventTitleOrId(e.key),
                                    value: '${e.value} tickets',
                                    icon: Icons.event,
                                  ),
                                )
                                    .toList(),
                                emptyText: 'No bookings found in this range.',
                              ),
                            ),

                            const SizedBox(height: 12),

                            _SectionCard(
                              title: 'Moderation hotspots',
                              subtitle: 'Most reported events',
                              icon: Icons.gpp_maybe_outlined,
                              child: _RankList(
                                rows: topReportedTop5
                                    .map(
                                      (e) => _RankRow(
                                    title: eventTitleOrId(e.key),
                                    value: '${e.value} reports',
                                    icon: Icons.flag_outlined,
                                    danger: true,
                                  ),
                                )
                                    .toList(),
                                emptyText: 'No reports found in this range.',
                              ),
                            ),

                            const SizedBox(height: 22),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Widgets
// -----------------------------------------------------------------------------
class _RangeDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _RangeDropdown({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: value,
      underline: const SizedBox.shrink(),
      items: const [
        DropdownMenuItem(value: '7d', child: Text('Last 7 days')),
        DropdownMenuItem(value: '30d', child: Text('Last 30 days')),
        DropdownMenuItem(value: '90d', child: Text('Last 90 days')),
        DropdownMenuItem(value: 'all', child: Text('All time')),
      ],
      onChanged: (v) {
        if (v == null) return;
        onChanged(v);
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: cs.primary),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            Text(subtitle, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.primary.withValues(alpha: 0.10),
                  foregroundColor: cs.primary,
                  child: Icon(icon),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _ChipGroup({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label:  '),
        Wrap(
          spacing: 8,
          children: options.map((o) {
            final selected = o == value;
            return ChoiceChip(
              selected: selected,
              label: Text(o.toUpperCase()),
              onSelected: (_) => onChanged(o),
              selectedColor: cs.primaryContainer,
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const _Pill({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: fg),
      ),
    );
  }
}

class _Kpi {
  final String title;
  final String value;
  final IconData icon;
  final Color tone;

  _Kpi({
    required this.title,
    required this.value,
    required this.icon,
    required this.tone,
  });
}

class _KpiGrid extends StatelessWidget {
  final List<_Kpi> items;
  const _KpiGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        final crossAxisCount = width > 900
            ? 4
            : width > 650
            ? 3
            : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.1,
          ),
          itemBuilder: (_, i) {
            final k = items[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: k.tone.withValues(alpha: 0.12),
                      foregroundColor: k.tone,
                      child: Icon(k.icon),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(k.title, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                          const SizedBox(height: 2),
                          Text(
                            k.value,
                            style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _RankRow {
  final String title;
  final Future<String>? titleFuture;
  final String value;
  final IconData icon;
  final bool danger;

  _RankRow({
    required this.title,
    required this.value,
    required this.icon,
    this.titleFuture,
    this.danger = false,
  });
}

class _RankList extends StatelessWidget {
  final List<_RankRow> rows;
  final String emptyText;

  const _RankList({
    required this.rows,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(emptyText),
      );
    }

    return Column(
      children: List.generate(rows.length, (i) {
        final r = rows[i];
        final tone = r.danger ? const Color(0xFFB91C1C) : Theme.of(context).colorScheme.primary;

        Widget titleWidget;
        if (r.titleFuture != null) {
          titleWidget = FutureBuilder<String>(
            future: r.titleFuture,
            builder: (context, snap) {
              final v = (snap.data ?? r.title).trim();
              return Text(v, maxLines: 1, overflow: TextOverflow.ellipsis);
            },
          );
        } else {
          titleWidget = Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis);
        }

        return Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: tone.withValues(alpha: 0.12),
                foregroundColor: tone,
                child: Icon(r.icon),
              ),
              title: titleWidget,
              trailing: Text(
                r.value,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            if (i != rows.length - 1) const Divider(height: 1),
          ],
        );
      }),
    );
  }
}

// -----------------------------------------------------------------------------
// Charts (no packages)
// -----------------------------------------------------------------------------
class _BarChart extends StatelessWidget {
  final List<int> values;
  final String startLabel;
  final String endLabel;

  const _BarChart({
    required this.values,
    required this.startLabel,
    required this.endLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxV = values.isEmpty ? 1 : values.reduce(math.max);
    final safeMax = math.max(1, maxV);

    return Column(
      children: [
        SizedBox(
          height: 160,
          width: double.infinity,
          child: CustomPaint(
            painter: _BarChartPainter(
              values: values,
              maxValue: safeMax,
              barColor: cs.primary,
              gridColor: cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(startLabel, style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            Text(endLabel, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<int> values;
  final int maxValue;
  final Color barColor;
  final Color gridColor;

  _BarChartPainter({
    required this.values,
    required this.maxValue,
    required this.barColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    if (values.isEmpty) return;

    final paintBar = Paint()..color = barColor.withValues(alpha: 0.85);
    final n = values.length;
    final gap = 2.0;
    final barW = math.max(2.0, (size.width - gap * (n - 1)) / n);

    for (int i = 0; i < n; i++) {
      final v = values[i];
      final h = (v / maxValue) * (size.height - 6);
      final x = i * (barW + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - h, barW, h),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, paintBar);
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.maxValue != maxValue;
}

class _DonutChart extends StatelessWidget {
  final Map<String, int> parts;
  const _DonutChart({required this.parts});

  @override
  Widget build(BuildContext context) {
    final total = parts.values.fold<int>(0, (a, b) => a + b);
    final cs = Theme.of(context).colorScheme;

    final palette = <String, Color>{
      'Published': const Color(0xFF16A34A),
      'Draft': const Color(0xFFF59E0B),
      'Archived': const Color(0xFF6B7280),
    };

    return Row(
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: CustomPaint(
            painter: _DonutPainter(
              parts: parts,
              colors: palette,
              ringColor: cs.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: parts.entries.map((e) {
              final color = palette[e.key] ?? cs.primary;
              final pct = total == 0 ? 0 : ((e.value / total) * 100).round();
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 8,
                  backgroundColor: color,
                ),
                title: Text(e.key),
                trailing: Text(
                  '${e.value}  ($pct%)',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final Map<String, int> parts;
  final Map<String, Color> colors;
  final Color ringColor;

  _DonutPainter({
    required this.parts,
    required this.colors,
    required this.ringColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = parts.values.fold<int>(0, (a, b) => a + b);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..color = ringColor;
    canvas.drawCircle(center, radius - 10, bg);

    if (total == 0) return;

    double start = -math.pi / 2;
    for (final e in parts.entries) {
      final sweep = (e.value / total) * 2 * math.pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..color = colors[e.key] ?? const Color(0xFF0B5FFF);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 10),
        start,
        sweep,
        false,
        paint,
      );

      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.parts != parts;
}
