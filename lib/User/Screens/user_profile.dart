import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shoo_fi/User/Widgets/user_repository.dart';
import 'package:shoo_fi/User/Services/user_onboarding_categories.dart';
import 'package:shoo_fi/shared/app_dialog.dart';

import '../../main.dart'; // for LocaleController
import '../../shared/ui/app_spacing.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _repo = UserRepo();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _photoUrlCtrl = TextEditingController();
  final TextEditingController _coverUrlCtrl = TextEditingController();

  bool _loading = true;
  bool _savingInline = false;

  bool _notificationsEnabled = true;
  String _language = 'en'; // en | ar
  double _myRating = 0; // 0 means not rated yet

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _photoUrlCtrl.dispose();
    _coverUrlCtrl.dispose();
    super.dispose();
  }

  // -------------------------
  // UI strings (simple in-file)
  // -------------------------
  String _t(String en, String ar) {
    final isAr = context.watch<LocaleController>().isArabic;
    return isAr ? ar : en;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final u = await _repo.getUserOnce();
      final authUser = FirebaseAuth.instance.currentUser;

      _nameCtrl.text =
          (u?['displayName'] ?? authUser?.displayName ?? '').toString();

      _photoUrlCtrl.text =
          (u?['photoUrl'] ?? authUser?.photoURL ?? '').toString();

      _coverUrlCtrl.text =
          (u?['coverUrl'] ?? u?['coverImageUrl'] ?? '').toString();

      _notificationsEnabled = (u?['notificationsEnabled'] as bool?) ?? true;

      _language = (u?['language'] ?? 'en').toString();
      if (mounted) {
        context.read<LocaleController>().setLocale(_language);
      }

      final rating = await _repo.getMyRating();
      _myRating = (rating ?? 0).toDouble();
    } catch (_) {
      // ✅ Do NOT block UX with dialog; show a snack and keep screen usable.
      _snack(_t(
        'Could not load your profile right now.',
        'تعذر تحميل الملف الشخصي الآن.',
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // -------------------------
  // Actions
  // -------------------------
  Future<void> _logout() async {
    await _repo.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  Future<void> _setLanguage(String lang) async {
    if (_savingInline) return;
    setState(() {
      _savingInline = true;
      _language = lang;
    });

    try {
      await _repo.setLanguage(lang);
      if (!mounted) return;
      context.read<LocaleController>().setLocale(lang);
    } catch (_) {
      if (!mounted) return;
      await AppDialogs.showError(
        context,
        title: _t('Update failed', 'فشل التحديث'),
        message: _t('Could not update language. Please try again.',
            'تعذر تحديث اللغة. حاول مرة أخرى.'),
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
      await _repo.setNotificationsEnabled(v);
    } catch (_) {
      if (!mounted) return;
      await AppDialogs.showError(
        context,
        title: _t('Update failed', 'فشل التحديث'),
        message: _t('We could not update this setting. Please try again.',
            'تعذر تحديث هذا الإعداد. حاول مرة أخرى.'),
      );
      if (mounted) setState(() => _notificationsEnabled = !v);
    } finally {
      if (mounted) setState(() => _savingInline = false);
    }
  }

  Future<void> _openProfileSettings() async {
    final cs = Theme.of(context).colorScheme;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.sm,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
          ),
          child: StatefulBuilder(
            builder: (context, setLocal) {
              final previewUrl = _photoUrlCtrl.text.trim();

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _t('Profile settings', 'إعدادات الملف الشخصي'),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(_t('Update your profile details',
                        'حدّث معلومات ملفك الشخصي')),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: cs.primary.withAlpha(24),
                        backgroundImage:
                        previewUrl.isNotEmpty ? NetworkImage(previewUrl) : null,
                        child: previewUrl.isEmpty
                            ? Icon(Icons.person, size: 26, color: cs.primary)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _t(
                            'This is how your profile image will appear.',
                            'هكذا ستظهر صورة ملفك الشخصي.',
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: _t('Display name', 'اسم العرض'),
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _photoUrlCtrl,
                    decoration: InputDecoration(
                      labelText: _t('Profile image URL', 'رابط صورة الملف'),
                      hintText: 'https://example.com/photo.jpg',
                      prefixIcon: const Icon(Icons.link),
                    ),
                    onChanged: (_) => setLocal(() {}),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _coverUrlCtrl,
                    decoration: InputDecoration(
                      labelText: _t('Cover image URL', 'رابط صورة الغلاف'),
                      hintText: 'https://example.com/cover.jpg',
                      prefixIcon: const Icon(Icons.image_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _saveProfileSettings();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _t('Save', 'حفظ'),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _saveProfileSettings() async {
    if (_savingInline) return;
    setState(() => _savingInline = true);

    try {
      final name = _nameCtrl.text.trim();
      final photoUrl = _photoUrlCtrl.text.trim();
      final coverUrl = _coverUrlCtrl.text.trim();
      final authUser = FirebaseAuth.instance.currentUser;

      // keep existing repo behavior
      await _repo.updateProfile(
        displayName: name,
        photoUrl: photoUrl,
      );

      // store cover + keep fields consistent
      if (authUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(authUser.uid)
            .set(
          {
            'displayName': name,
            'photoUrl': photoUrl,
            'coverUrl': coverUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      if (!mounted) return;
      _snack(_t('Profile updated.', 'تم تحديث الملف الشخصي.'));
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      await AppDialogs.showError(
        context,
        title: _t('Save failed', 'فشل الحفظ'),
        message: _t('We could not save your changes. Please try again.',
            'تعذر حفظ التغييرات. حاول مرة أخرى.'),
      );
    } finally {
      if (mounted) setState(() => _savingInline = false);
    }
  }

  Future<void> _openCopyright() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.copyright),
              title: Text(
                _t('Copyright information', 'معلومات حقوق النشر'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(_t('ShooFi? – Graduation Project',
                  'ShooFi? – مشروع تخرج')),
            ),
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _t(
                  '• All trademarks and brand names belong to their respective owners.\n'
                      '• Icons/images used in the demo are for educational purposes.\n'
                      '• If any third-party assets are used, they remain under their original licenses.',
                  '• جميع العلامات التجارية والأسماء تعود لمالكيها.\n'
                      '• الأيقونات/الصور المستخدمة في العرض لأغراض تعليمية.\n'
                      '• أي أصول خارجية تبقى ضمن تراخيصها الأصلية.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_t('Close', 'إغلاق')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAbout() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline),
              title: Text(
                _t('About ShooFi?', 'حول ShooFi?'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(_t('Tonight. Tomorrow. Anytime.',
                  'الليلة. غداً. بأي وقت.')),
            ),
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _t(
                  'ShooFi? helps users in Jordan discover events, view details, book tickets, and report issues.\n\n'
                      'This app was built as a graduation project and includes user, organizer, and admin roles.',
                  'ShooFi? يساعد المستخدمين في الأردن على اكتشاف الفعاليات، عرض التفاصيل، حجز التذاكر، والإبلاغ عن المشاكل.\n\n'
                      'تم بناء التطبيق كمشروع تخرج ويدعم أدوار المستخدم والمنظم والمشرف.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_t('Close', 'إغلاق')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRateUs() async {
    double temp = _myRating;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: StatefulBuilder(
          builder: (context, setLocal) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.star_rate_rounded),
                  title: Text(
                    _t('Rate us', 'قيّمنا'),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(_t(
                    'Help us improve by leaving a rating.',
                    'ساعدنا على التحسين بترك تقييم.',
                  )),
                ),
                const Divider(),
                const SizedBox(height: 8),
                _StarRow(
                  value: temp,
                  onChanged: (v) => setLocal(() => temp = v),
                ),
                const SizedBox(height: 10),
                Text(
                  _t(
                    temp == 0 ? 'Tap a star to rate' : 'Your rating: ${temp.toInt()}/5',
                    temp == 0 ? 'اضغط على نجمة للتقييم' : 'تقييمك: ${temp.toInt()}/5',
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
                    child: Text(_t('Submit', 'إرسال')),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _submitRating(double rating) async {
    if (_savingInline) return;
    setState(() => _savingInline = true);

    try {
      await _repo.submitRating(rating.toInt());
      if (!mounted) return;

      setState(() => _myRating = rating);
      _snack(_t('Thanks for rating!', 'شكراً لتقييمك!'));
    } catch (_) {
      if (!mounted) return;
      await AppDialogs.showError(
        context,
        title: _t('Failed', 'فشل'),
        message: _t('Could not submit rating. Please try again.',
            'تعذر إرسال التقييم. حاول مرة أخرى.'),
      );
    } finally {
      if (mounted) setState(() => _savingInline = false);
    }
  }

  // -------------------------
  // Tiles (container style)
  // -------------------------
  Widget _settingsCard({
    required IconData icon,
    required String titleEn,
    required String titleAr,
    required String subtitleEn,
    required String subtitleAr,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(
          _t(titleEn, titleAr),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(_t(subtitleEn, subtitleAr)),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final cs = theme.colorScheme;

    final previewUrl = _photoUrlCtrl.text.trim();

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Profile', 'الملف الشخصي')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: cs.primary.withAlpha(24),
                    backgroundImage:
                    previewUrl.isNotEmpty ? NetworkImage(previewUrl) : null,
                    child: previewUrl.isEmpty
                        ? Icon(Icons.person, size: 32, color: cs.primary)
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (_nameCtrl.text.trim().isEmpty)
                              ? _t('Your profile', 'ملفك الشخصي')
                              : _nameCtrl.text.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _t('Manage your settings and preferences',
                              'إدارة الإعدادات والتفضيلات'),
                          style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Container 1: Profile settings
          _settingsCard(
            icon: Icons.manage_accounts_outlined,
            titleEn: 'Profile settings',
            titleAr: 'إعدادات الملف الشخصي',
            subtitleEn: 'Update name, profile photo, and cover photo',
            subtitleAr: 'تعديل الاسم وصورة الملف وصورة الغلاف',
            onTap: _openProfileSettings,
          ),

          // Container 2: Language toggle
          Card(
            child: ListTile(
              leading: const Icon(Icons.language_outlined),
              title: Text(
                _t('Language', 'اللغة'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(_t('English / Arabic', 'إنجليزي / عربي')),
              trailing: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'en', label: Text('EN')),
                  ButtonSegment(value: 'ar', label: Text('AR')),
                ],
                selected: {_language},
                onSelectionChanged: (s) => _setLanguage(s.first),
              ),
            ),
          ),

          // Container 3: Notifications toggle
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: Text(_t('Notifications', 'الإشعارات'),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(_t(
                'Get updates about bookings and events (future feature).',
                'استقبال تحديثات عن الحجوزات والفعاليات (ميزة مستقبلية).',
              )),
              value: _notificationsEnabled,
              onChanged: _setNotifications,
            ),
          ),

          // Container 4: Category preferences
          _settingsCard(
            icon: Icons.tune,
            titleEn: 'Category preferences',
            titleAr: 'تفضيلات الفئات',
            subtitleEn: 'Choose which categories appear in your feed',
            subtitleAr: 'اختر الفئات التي تظهر في صفحتك الرئيسية',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserOnboardingCategories()),
            ),
          ),

          // Container 5: Copyright
          _settingsCard(
            icon: Icons.copyright,
            titleEn: 'Copyright information',
            titleAr: 'معلومات حقوق النشر',
            subtitleEn: 'Legal and third-party credits',
            subtitleAr: 'معلومات قانونية واعتمادات خارجية',
            onTap: _openCopyright,
          ),

          // Container 6: Rate us
          _settingsCard(
            icon: Icons.star_rate_rounded,
            titleEn: 'Rate us',
            titleAr: 'قيّمنا',
            subtitleEn: _myRating == 0
                ? 'Leave a 1–5 star rating'
                : 'Your rating: ${_myRating.toInt()}/5',
            subtitleAr: _myRating == 0
                ? 'اترك تقييماً من ١ إلى ٥'
                : 'تقييمك: ${_myRating.toInt()}/5',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_myRating > 0)
                  Text(
                    '${_myRating.toInt()}/5',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: _openRateUs,
          ),

          // Container 7: About
          _settingsCard(
            icon: Icons.info_outline,
            titleEn: 'About',
            titleAr: 'حول',
            subtitleEn: 'Learn more about ShooFi?',
            subtitleAr: 'تعرف أكثر على ShooFi?',
            onTap: _openAbout,
          ),

          const SizedBox(height: AppSpacing.md),

          // Logout at bottom
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: Text(_t('Logout', 'تسجيل الخروج')),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          if (_savingInline)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(_t('Saving…', 'جاري الحفظ…')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final double value; // 0..5
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
          color: filled ? cs.primary : cs.onSurfaceVariant,
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

