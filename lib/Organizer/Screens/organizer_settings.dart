import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shoo_fi/shared/app_dialog.dart';
import '../../Auth/role_login.dart';
import '../../Auth/app_role.dart';
import '../../shared/theme/theme_controller.dart';
import '../../shared/ui/app_spacing.dart';
import '../organizer_controller.dart';

class OrganizerSettingsScreen extends StatefulWidget {
  final bool embed;
  const OrganizerSettingsScreen({super.key, this.embed = false});

  @override
  State<OrganizerSettingsScreen> createState() => _OrganizerSettingsScreenState();
}

class _OrganizerSettingsScreenState extends State<OrganizerSettingsScreen> {
  bool _loading = true;
  bool _savingInline = false;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _coverUrlCtrl = TextEditingController();
  final TextEditingController _profileUrlCtrl = TextEditingController();

  bool _notificationsEnabled = true;
  double _myRating = 0;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_rebuildIfMounted);
    _coverUrlCtrl.addListener(_rebuildIfMounted);
    _profileUrlCtrl.addListener(_rebuildIfMounted);
    _load();
  }

  void _rebuildIfMounted() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_rebuildIfMounted);
    _coverUrlCtrl.removeListener(_rebuildIfMounted);
    _profileUrlCtrl.removeListener(_rebuildIfMounted);

    _nameCtrl.dispose();
    _coverUrlCtrl.dispose();
    _profileUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final c = context.read<OrganizerController>();

      _nameCtrl.text = (c.organizerName).trim();
      _coverUrlCtrl.text = (c.coverImageUrl ?? '').trim();
      _profileUrlCtrl.text = (c.profileImageUrl ?? '').trim();

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final snap = await FirebaseFirestore.instance.collection('organizers').doc(uid).get();
        final data = snap.data() ?? {};
        _notificationsEnabled = (data['notificationsEnabled'] as bool?) ?? true;
        _myRating = ((data['myRating'] ?? 0) as num).toDouble();
      }
    } catch (_) {
      // keep screen usable
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    context.read<ThemeController>().setRole(AppRole.user);

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleLoginScreen()),
          (_) => false,
    );
  }

  bool _looksLikeUrl(String s) {
    if (s.isEmpty) return true; // allow empty
    final uri = Uri.tryParse(s);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
  }

  Future<void> _saveProfileSettings() async {
    if (_savingInline) return;

    final name = _nameCtrl.text.trim();
    final coverUrl = _coverUrlCtrl.text.trim();
    final profileUrl = _profileUrlCtrl.text.trim();

    if (name.isEmpty) {
      await AppDialogs.showError(
        context,
        title: 'Missing name',
        message: 'Organizer name is required.',
      );
      return;
    }

    if (!_looksLikeUrl(coverUrl) || !_looksLikeUrl(profileUrl)) {
      await AppDialogs.showError(
        context,
        title: 'Invalid URL',
        message: 'Please enter a valid URL that starts with http:// or https://',
      );
      return;
    }

    setState(() => _savingInline = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // 1) Update organizers collection (your current structure)
      await FirebaseFirestore.instance.collection('organizers').doc(uid).set(
        {
          'id': uid,
          'name': name,
          'coverImageUrl': coverUrl,
          'profileImageUrl': profileUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // 2) ALSO update users collection (many screens read from here)
      // We write multiple keys to match whatever your UI expects.
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'displayName': name,
          'photoUrl': profileUrl,        // common key
          'coverUrl': coverUrl,          // common key
          'profileImageUrl': profileUrl, // mirror
          'coverImageUrl': coverUrl,     // mirror
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // 3) Refresh controller cache (if organizer screens use controller)
      await context.read<OrganizerController>().refreshOrganizerProfile();

      if (!mounted) return;
      await AppDialogs.showInfo(context, message: 'Your changes have been saved.');
    } catch (_) {
      if (!mounted) return;
      await AppDialogs.showError(
        context,
        message: 'Unable to save changes. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _savingInline = false);
    }
  }

  Future<void> _setNotifications(bool v) async {
    if (_savingInline) return;

    setState(() {
      _savingInline = true;
      _notificationsEnabled = v;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('organizers').doc(uid).set(
        {
          'notificationsEnabled': v,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      if (!mounted) return;
      await AppDialogs.showError(
        context,
        title: 'Update failed',
        message: 'We could not update this setting. Please try again.',
      );
      if (mounted) setState(() => _notificationsEnabled = !v);
    } finally {
      if (mounted) setState(() => _savingInline = false);
    }
  }

  Future<void> _openProfileSettings() async {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: cs.surface,
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          minChildSize: 0.55,
          maxChildSize: 0.95,
          builder: (context, scrollCtrl) {
            final coverUrl = _coverUrlCtrl.text.trim();
            final profileUrl = _profileUrlCtrl.text.trim();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  top: AppSpacing.sm,
                  bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
                ),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Profile settings',
                        style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        'Update organizer name and images',
                        style: t.bodySmall?.copyWith(color: cs.onSurface.withAlpha(170)),
                      ),
                    ),
                    const SizedBox(height: 6),

                    Expanded(
                      child: ListView(
                        controller: scrollCtrl,
                        children: [
                          // Cover preview
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AspectRatio(
                              aspectRatio: 16 / 6,
                              child: Container(
                                color: cs.primary.withAlpha(12),
                                child: coverUrl.isEmpty
                                    ? Center(
                                  child: Icon(Icons.image_outlined, color: cs.primary.withAlpha(180), size: 34),
                                )
                                    : Image.network(
                                  coverUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Icon(Icons.broken_image_outlined, color: cs.error.withAlpha(200), size: 34),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: cs.primary.withAlpha(24),
                                backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                                child: profileUrl.isEmpty
                                    ? Icon(Icons.person, size: 26, color: cs.primary)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'This is how your profile image will appear.',
                                  style: t.bodyMedium?.copyWith(color: cs.onSurface.withAlpha(210)),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Organizer name',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.md),

                          TextFormField(
                            controller: _coverUrlCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Cover image URL',
                              prefixIcon: Icon(Icons.image_outlined),
                              hintText: 'https://...',
                            ),
                            keyboardType: TextInputType.url,
                          ),

                          const SizedBox(height: AppSpacing.md),

                          TextFormField(
                            controller: _profileUrlCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Profile image URL',
                              prefixIcon: Icon(Icons.person_outline),
                              hintText: 'https://...',
                            ),
                            keyboardType: TextInputType.url,
                          ),

                          const SizedBox(height: 12),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _saveProfileSettings();
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        ),
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

  Future<void> _openCopyright() async {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: cs.surface,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.9,
        builder: (context, scrollCtrl) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.copyright),
                  title: Text('Copyright information', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  subtitle: Text('ShooFi? – Graduation Project', style: t.bodySmall?.copyWith(color: cs.onSurface.withAlpha(170))),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    children: [
                      Text(
                        '• All trademarks and brand names belong to their respective owners.\n'
                            '• Icons/images used in the demo are for educational purposes.\n'
                            '• If any third-party assets are used, they remain under their original licenses.',
                        style: t.bodyMedium?.copyWith(color: cs.onSurface.withAlpha(210), height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAbout() async {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: cs.surface,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.9,
        builder: (context, scrollCtrl) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline),
                  title: Text('About ShooFi?', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  subtitle: Text('Tonight. Tomorrow. Anytime.', style: t.bodySmall?.copyWith(color: cs.onSurface.withAlpha(170))),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    children: [
                      Text(
                        'ShooFi? helps users in Jordan discover events, view details, book tickets, and report issues.\n\n'
                            'This app was built as a graduation project and includes user, organizer, and admin roles.',
                        style: t.bodyMedium?.copyWith(color: cs.onSurface.withAlpha(210), height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openRateUs() async {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    double temp = _myRating;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: cs.surface,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        minChildSize: 0.45,
        maxChildSize: 0.85,
        builder: (context, scrollCtrl) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: StatefulBuilder(
              builder: (context, setLocal) {
                return Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.star_rate_rounded),
                      title: Text('Rate us', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                      subtitle: Text('Help us improve by leaving a rating.', style: t.bodySmall?.copyWith(color: cs.onSurface.withAlpha(170))),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView(
                        controller: scrollCtrl,
                        children: [
                          const SizedBox(height: 6),
                          _StarRow(
                            value: temp,
                            onChanged: (v) => setLocal(() => temp = v),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: Text(
                              temp == 0 ? 'Tap a star to rate' : 'Your rating: ${temp.toInt()}/5',
                              style: t.bodyMedium?.copyWith(color: cs.onSurface.withAlpha(210), fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: temp == 0
                                  ? null
                                  : () async {
                                Navigator.pop(context);
                                await _submitRating(temp);
                              },
                              child: const Text('Submit'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitRating(double rating) async {
    if (_savingInline) return;
    setState(() => _savingInline = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('organizers').doc(uid).set(
        {
          'myRating': rating.toInt(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      setState(() => _myRating = rating);
      await AppDialogs.showInfo(context, message: 'Thanks for rating!');
    } catch (_) {
      if (!mounted) return;
      await AppDialogs.showError(context, message: 'Could not submit rating. Please try again.');
    } finally {
      if (mounted) setState(() => _savingInline = false);
    }
  }

  Widget _settingsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Card(
      child: ListTile(
        leading: Icon(icon, color: cs.primary),
        title: Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle, style: t.bodySmall?.copyWith(color: cs.onSurface.withAlpha(170))),
        trailing: trailing ?? Icon(Icons.chevron_right, color: cs.onSurface.withAlpha(170)),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final previewUrl = _profileUrlCtrl.text.trim();

    final content = _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: cs.primary.withAlpha(24),
                  backgroundImage: previewUrl.isNotEmpty ? NetworkImage(previewUrl) : null,
                  child: previewUrl.isEmpty ? Icon(Icons.person, size: 32, color: cs.primary) : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nameCtrl.text.trim().isEmpty ? 'Organizer profile' : _nameCtrl.text.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Manage your settings and profile',
                        style: t.bodySmall?.copyWith(color: cs.onSurface.withAlpha(170)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        _settingsCard(
          icon: Icons.manage_accounts_outlined,
          title: 'Profile settings',
          subtitle: 'Update name, profile photo, and cover photo',
          onTap: _openProfileSettings,
        ),

        Card(
          child: SwitchListTile(
            secondary: Icon(Icons.notifications_active_outlined, color: cs.primary),
            title: Text('Notifications', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
            subtitle: Text(
              'Get updates about your events (future feature).',
              style: t.bodySmall?.copyWith(color: cs.onSurface.withAlpha(170)),
            ),
            value: _notificationsEnabled,
            onChanged: _setNotifications,
          ),
        ),

        _settingsCard(
          icon: Icons.copyright,
          title: 'Copyright information',
          subtitle: 'Legal and third-party credits',
          onTap: _openCopyright,
        ),

        _settingsCard(
          icon: Icons.star_rate_rounded,
          title: 'Rate us',
          subtitle: _myRating == 0 ? 'Leave a 1–5 star rating' : 'Your rating: ${_myRating.toInt()}/5',
          onTap: _openRateUs,
        ),

        _settingsCard(
          icon: Icons.info_outline,
          title: 'About',
          subtitle: 'Learn more about ShooFi?',
          onTap: _openAbout,
        ),

        const SizedBox(height: AppSpacing.md),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        if (_savingInline)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: const [
                SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 10),
                Text('Saving…'),
              ],
            ),
          ),
      ],
    );

    if (widget.embed) return content;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: content,
    );
  }
}

class _StarRow extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _StarRow({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget star(int i) {
      final filled = value >= i;
      return IconButton(
        onPressed: () => onChanged(i.toDouble()),
        icon: Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          color: filled ? cs.primary : cs.onSurface.withAlpha(140),
          size: 34,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [star(1), star(2), star(3), star(4), star(5)],
    );
  }
}
