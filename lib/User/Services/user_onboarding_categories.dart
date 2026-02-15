import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/app_dialog.dart';
import '../../shared/ui/app_spacing.dart';
import '../../main.dart'; // LocaleController

class UserOnboardingCategories extends StatefulWidget {
  const UserOnboardingCategories({super.key});

  @override
  State<UserOnboardingCategories> createState() => _UserOnboardingCategoriesState();
}

class _UserOnboardingCategoriesState extends State<UserOnboardingCategories> {
  final _cityCtrl = TextEditingController();

  final Set<String> _selected = {};
  bool _loading = true;
  bool _saving = false;

  // Must match Event categories used in your events
  static const List<String> categories = [
    'Concert',
    'Workshop',
    'Conference',
    'Sports',
    'Party',
    'Course',
    'Entertainment',
    'Musical',
    'Technology',
    'Art',
  ];

  String _t(String en, String ar) {
    final isAr = context.watch<LocaleController>().isArabic;
    return isAr ? ar : en;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = snap.data() ?? <String, dynamic>{};

      final city = (data['city'] ?? '').toString().trim();
      final existing =
          (data['preferredCategories'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];

      _cityCtrl.text = city;

      _selected
        ..clear()
        ..addAll(existing.where((c) => categories.contains(c)));
    } catch (e) {
      if (!mounted) return;
      await AppDialogs.dialog(
        context,
        title: _t('Load failed', 'فشل التحميل'),
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goHomeAfterSave() {
    // Preferred: if your app uses a Shell that opened this screen,
    // popping with result=true will allow the Shell/Home to refresh.
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context, true);
      return;
    }

    // Fallback: go to home and clear stack (change route if needed).
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home', // ✅ change ONLY if your real home route name differs
          (route) => false,
    );
  }

  Future<void> _save() async {
    final city = _cityCtrl.text.trim();

    if (city.isEmpty) {
      await AppDialogs.showError(
        context,
        title: _t('Missing city', 'المدينة مطلوبة'),
        message: _t('Please enter your city.', 'يرجى إدخال المدينة.'),
      );
      return;
    }

    if (_selected.length < 2) {
      await AppDialogs.toast(
        context,
        title: _t('Choose more', 'اختر المزيد'),
        message: _t('Please choose at least 2 categories.', 'يرجى اختيار فئتين على الأقل.'),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'city': city,
          'preferredCategories': _selected.toList(),
          'updatedAt': FieldValue.serverTimestamp(),

          // onboarding control flags
          'onboardingCompleted': true,
          'needsOnboarding': false,
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      // ✅ Show success message first
      await AppDialogs.showInfo(
        context,
        title: _t('Saved', 'تم الحفظ'),
        message: _t('Your preferences have been saved.', 'تم حفظ تفضيلاتك.'),
      );

      if (!mounted) return;

      // ✅ Then navigate to home / back to shell
      _goHomeAfterSave();
    } catch (e) {
      if (!mounted) return;
      await AppDialogs.showError(
        context,
        title: _t('Save failed', 'فشل الحفظ'),
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(_t('Your preferences', 'تفضيلاتك'))),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            _t('Help us personalize your feed', 'ساعدنا بتخصيص صفحتك الرئيسية'),
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _t('Choose your city and favorite categories.', 'اختر مدينتك والفئات المفضلة لديك.'),
            style: t.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),

          TextFormField(
            controller: _cityCtrl,
            decoration: InputDecoration(
              labelText: _t('City', 'المدينة'),
              prefixIcon: const Icon(Icons.location_city_outlined),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          Text(
            _t('Preferred categories', 'الفئات المفضلة'),
            style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.sm),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: categories.map((c) {
              final selected = _selected.contains(c);
              return FilterChip(
                label: Text(c),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _selected.add(c);
                    } else {
                      _selected.remove(c);
                    }
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.lg),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _saving
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Text(
                  _t('Save', 'حفظ'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
