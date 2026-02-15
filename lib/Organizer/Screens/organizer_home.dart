import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Models/event_post.dart';
import '../Widgets/event_post_card.dart';
import '../organizer_controller.dart';
import 'add_edit_post.dart';

import '../../shared/ui/app_spacing.dart';
import '../../shared/ui/empty_state.dart';
import 'package:shoo_fi/shared/app_dialog.dart';

class OrganizerHomeScreen extends StatelessWidget {
  final bool embed;
  const OrganizerHomeScreen({super.key, this.embed = false});

  Future<void> _requestEditAccess(BuildContext context, EventPost event) async {
    final organizerId = context.read<OrganizerController>().organizerId.trim();
    if (organizerId.isEmpty) return;

    final ok = await AppDialogs.confirm(
      context,
      title: 'Request edit access',
      message: 'Send a request to admin to allow editing this published event?',
      confirmText: 'Send request',
    );

    if (ok != true) return;

    try {
      final reqId = '${event.id}_$organizerId';
      await FirebaseFirestore.instance.collection('edit_requests').doc(reqId).set(
        {
          'eventId': event.id,
          'organizerId': organizerId,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!context.mounted) return;
      await AppDialogs.showInfo(context, message: 'Request sent to admin.');
    } catch (_) {
      if (!context.mounted) return;
      await AppDialogs.showError(context, message: 'Could not send the request. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<OrganizerController>();

    final uid = FirebaseAuth.instance.currentUser?.uid;

    // ✅ IMPORTANT: typed stream to avoid Stream<dynamic> issues
    final Stream<DocumentSnapshot<Map<String, dynamic>>> organizerDocStream =
    (uid == null)
        ? const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty()
        : FirebaseFirestore.instance.collection('organizers').doc(uid).snapshots();

    final publishedCount =
        controller.events.where((e) => e.status == EventStatus.published).length;

    final content = RefreshIndicator(
      onRefresh: () async {
        await controller.refreshEvents();
      },
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: organizerDocStream,
        builder: (context, snap) {
          final data = snap.data?.data() ?? {};

          // ✅ Read live values from Firestore
          final fsName = (data['name'] ?? '').toString().trim();
          final fsCover = (data['coverImageUrl'] ?? '').toString().trim();
          final fsProfile = (data['profileImageUrl'] ?? '').toString().trim();
          final fsFollowers = (data['followersCount'] ?? 0);

          // Fallbacks (only for name) if doc isn't ready yet
          final rawName = fsName.isNotEmpty ? fsName : controller.organizerName.trim();
          final displayName = rawName.isEmpty ? 'Organizer' : rawName;
          final avatarInitial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'O';

          final coverUrl = fsCover;     // ✅ ONLY firestore
          final profileUrl = fsProfile; // ✅ ONLY firestore

          final followersCount = (fsFollowers is num) ? fsFollowers.toInt() : 0;

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                automaticallyImplyLeading: false,
                centerTitle: false,
                flexibleSpace: LayoutBuilder(
                  builder: (context, constraints) {
                    final top = constraints.biggest.height;
                    final collapsed = top <= (kToolbarHeight + 40);

                    return FlexibleSpaceBar(
                      titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 12),
                      title: AnimatedOpacity(
                        duration: const Duration(milliseconds: 160),
                        opacity: collapsed ? 1 : 0,
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/icons/app_icon.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'ShooFi?',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (coverUrl.isNotEmpty)
                            Image.network(
                              coverUrl,
                              key: ValueKey(coverUrl), // ✅ forces rebuild when URL changes
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: Colors.black.withOpacity(0.25)),
                            )
                          else
                            Container(color: Colors.black.withOpacity(0.25)),

                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.15),
                                    Colors.black.withOpacity(0.55),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 18,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 160),
                              opacity: collapsed ? 0 : 1,
                              child: _OrganizerHeader(
                                displayName: displayName,
                                avatarInitial: avatarInitial,
                                profileUrl: profileUrl,
                                followersCount: followersCount,
                                publishedCount: publishedCount,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Your events',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      if (!controller.isLoading)
                        Text(
                          '${controller.events.length}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 96),
                sliver: controller.isLoading
                    ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
                    : controller.events.isEmpty
                    ? const SliverFillRemaining(
                  child: EmptyState(
                    icon: Icons.event_busy_outlined,
                    title: 'No events yet',
                    message: 'Create your first event to start reaching your audience.',
                  ),
                )
                    : SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final event = controller.events[index];

                      final canEdit = event.status == EventStatus.draft ||
                          (event.status == EventStatus.published &&
                              (event.allowEditPublished == true));

                      final needsRequest = event.status == EventStatus.published &&
                          (event.allowEditPublished != true);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: EventPostCard(
                          event: event,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddEditPostScreen(
                                  existingEvent: event,
                                  readOnly: !canEdit,
                                ),
                              ),
                            );
                          },
                          onRequestEdit: needsRequest
                              ? () => _requestEditAccess(context, event)
                              : null,
                        ),
                      );
                    },
                    childCount: controller.events.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    final fab = FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEditPostScreen()),
        );
      },
      icon: const Icon(Icons.add),
      label: const Text('Add event'),
    );

    if (embed) {
      return Stack(
        children: [
          content,
          Positioned(right: 16, bottom: 16, child: fab),
        ],
      );
    }

    return Scaffold(
      floatingActionButton: fab,
      body: content,
    );
  }
}

class _OrganizerHeader extends StatelessWidget {
  final String displayName;
  final String avatarInitial;
  final String profileUrl;
  final int followersCount;
  final int publishedCount;

  const _OrganizerHeader({
    required this.displayName,
    required this.avatarInitial,
    required this.profileUrl,
    required this.followersCount,
    required this.publishedCount,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.75),
          ),
          child: CircleAvatar(
            key: ValueKey(profileUrl),
            radius: 28,
            backgroundColor: cs.primary.withAlpha(28),
            backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
            child: profileUrl.isEmpty
                ? Text(
              avatarInitial,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _MiniPill(icon: Icons.people_alt_outlined, text: '$followersCount followers'),
                  _MiniPill(icon: Icons.event_note_outlined, text: '$publishedCount posts'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white.withOpacity(0.90)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
