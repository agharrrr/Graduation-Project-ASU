import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shoo_fi/shared/app_dialog.dart';
import '../../shared/friendly_errors.dart';


class ReportScreen extends StatefulWidget {
  final String eventId;
  final String? eventTitle;

  const ReportScreen({super.key, required this.eventId, this.eventTitle});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await AppDialogs.showError(
        context,
        message: 'Please sign in first to submit a report.',
      );
      return;
    }

    if (_selectedReason == null) {
      await AppDialogs.showError(
        context,
        message: 'Please select a reason before submitting.',
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'eventId': widget.eventId,
        'eventTitle': widget.eventTitle ?? '',
        'reportedBy': user.uid,
        'reason': _selectedReason,
        'details': _detailsController.text.trim(),
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      await AppDialogs.showInfo(
        context,
        title: 'Thank you',
        message: 'Your report has been submitted.',
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      await AppDialogs.showError(
        context,
        message: FriendlyErrors.fromUnknown(e),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Report content')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((widget.eventTitle ?? '').trim().isNotEmpty) ...[
              Text(
                widget.eventTitle!,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'Select a reason',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedReason,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                labelText: 'Reason',
              ),
              items: const [
                'Spam',
                'Fake Event',
                'Inappropriate Content',
                'Harassment',
                'Scam / Fraud',
                'Other',
              ].map((reason) {
                return DropdownMenuItem(
                  value: reason,
                  child: Text(reason),
                );
              }).toList(),
              onChanged: _submitting ? null : (value) => setState(() => _selectedReason = value),
            ),
            const SizedBox(height: 18),
            Text(
              'Details (optional)',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _detailsController,
              maxLines: 4,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                hintText: 'Describe what is wrong…',
              ),
              enabled: !_submitting,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Submit report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
