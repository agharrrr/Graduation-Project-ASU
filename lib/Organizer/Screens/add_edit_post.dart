import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../Models/event_post.dart';
import '../organizer_controller.dart';

class AddEditPostScreen extends StatefulWidget {
  final EventPost? existingEvent;
  final bool readOnly;

  const AddEditPostScreen({
    super.key,
    this.existingEvent,
    this.readOnly = false,
  });

  @override
  State<AddEditPostScreen> createState() => _AddEditPostScreenState();
}

class _AddEditPostScreenState extends State<AddEditPostScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _coverCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _capacityCtrl;

  DateTime? _start;
  DateTime? _end;
  bool _isPaid = false;
  String? _category;
  bool _saving = false;

  final _categories = const [
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

  @override
  void initState() {
    super.initState();
    final e = widget.existingEvent;

    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _locationCtrl = TextEditingController(text: e?.location ?? '');
    _coverCtrl = TextEditingController(text: e?.coverImageUrl ?? '');
    _priceCtrl = TextEditingController(text: (e?.price)?.toString() ?? '');
    _capacityCtrl = TextEditingController(text: e != null ? e.capacity.toString() : '50');

    _start = e?.startDateTime ?? DateTime.now().add(const Duration(days: 1));
    _end = e?.endDateTime ?? _start!.add(const Duration(hours: 2));
    _isPaid = e?.isPaid ?? false;

    if (e != null && e.category.isNotEmpty && _categories.contains(e.category)) {
      _category = e.category;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _coverCtrl.dispose();
    _priceCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.existingEvent != null;

  bool get _isPublished => widget.existingEvent?.status == EventStatus.published;

  bool get _within24h {
    final start = widget.existingEvent?.startDateTime;
    if (!_isPublished || start == null) return false;
    return start.isBefore(DateTime.now().add(const Duration(hours: 24)));
  }

  /// Admin permission for price edits:
  /// Using your existing flag allowEditPublished.
  bool get _canEditPrice {
    if (!_isPublished) return true; // drafts/new events: normal
    return widget.existingEvent?.allowEditPublished == true; // published: requires admin flag
  }

  bool get _canEditDateTime {
    if (!_isPublished) return true; // drafts/new events: normal
    return !_within24h; // published: lock within 24 hours
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<OrganizerController>();

    final readOnly = widget.readOnly;

    final title = _isEditing
        ? (readOnly ? 'Event (read-only)' : 'Edit event')
        : 'Add event';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (readOnly)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Editing is locked'),
                    subtitle: const Text('This event cannot be edited right now.'),
                  ),
                ),

              if (!readOnly && _isPublished)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Published event rules'),
                    subtitle: Text(
                      _within24h
                          ? 'Date/time is locked because the event starts within 24 hours.'
                          : 'Date/time can be edited (more than 24 hours remaining).',
                    ),
                  ),
                ),

              if (!readOnly && _isPublished && !_canEditPrice)
                Card(
                  child: const ListTile(
                    leading: Icon(Icons.payments_outlined),
                    title: Text('Price is locked'),
                    subtitle: Text('Only admin permission allows editing the price for published events.'),
                  ),
                ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _titleCtrl,
                enabled: !readOnly,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descCtrl,
                enabled: !readOnly,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 4,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _locationCtrl,
                enabled: !readOnly,
                decoration: const InputDecoration(labelText: 'Location'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _coverCtrl,
                enabled: !readOnly,
                decoration: const InputDecoration(labelText: 'Cover image URL'),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Category'),
                value: _category,
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: readOnly ? null : (v) => setState(() => _category = v),
                validator: (v) => (v == null || v.isEmpty) ? 'Choose a category' : null,
              ),
              const SizedBox(height: 12),

              SwitchListTile(
                title: const Text('Paid event'),
                value: _isPaid,
                onChanged: readOnly ? null : (v) => setState(() => _isPaid = v),
              ),

              if (_isPaid)
                TextFormField(
                  controller: _priceCtrl,
                  enabled: !readOnly && _canEditPrice,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Price (JOD)',
                    helperText: (!readOnly && _isPublished && !_canEditPrice)
                        ? 'Locked: admin permission required for published events.'
                        : null,
                  ),
                  validator: (v) {
                    if (!_isPaid) return null;
                    if (_isPublished && !_canEditPrice) return null;

                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'Enter a price';
                    final n = int.tryParse(s);
                    if (n == null || n < 0) return 'Invalid price';
                    return null;
                  },
                ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _capacityCtrl,
                enabled: !readOnly,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Capacity'),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'Required';
                  final n = int.tryParse(s);
                  if (n == null || n <= 0) return 'Invalid capacity';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              _dateRow(readOnly),

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (readOnly || _saving) ? null : () => _save(controller),
                  child: _saving
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text(_isEditing ? 'Save' : 'Publish'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateRow(bool readOnly) {
    final df = DateFormat('EEE, dd MMM yyyy • HH:mm');
    final dateLocked = _isPublished && !_canEditDateTime;

    return Row(
      children: [
        Expanded(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Starts at'),
            subtitle: Text(df.format(_start!)),
            trailing: dateLocked ? const Icon(Icons.lock_outline) : const Icon(Icons.edit_calendar_outlined),
            onTap: (readOnly || dateLocked)
                ? null
                : () async {
              final picked = await _pickDateTime(_start!);
              if (picked != null) {
                setState(() => _start = picked);
                if (_end!.isBefore(_start!)) {
                  _end = _start!.add(const Duration(hours: 2));
                }
              }
            },
          ),
        ),
        Expanded(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ends at'),
            subtitle: Text(df.format(_end!)),
            trailing: dateLocked ? const Icon(Icons.lock_outline) : const Icon(Icons.edit_calendar_outlined),
            onTap: (readOnly || dateLocked)
                ? null
                : () async {
              final picked = await _pickDateTime(_end!);
              if (picked != null) setState(() => _end = picked);
            },
          ),
        ),
      ],
    );
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save(OrganizerController controller) async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _saving = true);

    try {
      final old = widget.existingEvent;

      // Preserve date/time if locked
      final DateTime finalStart = (_isPublished && !_canEditDateTime && old != null) ? old.startDateTime : _start!;
      final DateTime finalEnd = (_isPublished && !_canEditDateTime && old != null) ? old.endDateTime : _end!;

      // Preserve price if locked
      final int? finalPrice;
      if (!_isPaid) {
        finalPrice = null;
      } else if (_isPublished && !_canEditPrice && old != null) {
        finalPrice = old.price;
      } else {
        finalPrice = int.tryParse(_priceCtrl.text.trim()) ?? 0;
      }

      // ✅ CRITICAL FIX: ensure event id is NEVER empty for new events
      final String eventId = (old?.id.trim().isNotEmpty == true)
          ? old!.id.trim()
          : FirebaseFirestore.instance.collection('events').doc().id;

      final event = EventPost(
        id: eventId,
        organizerId: controller.organizerId, // make sure your controller sets this to UID
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: (_category ?? '').trim(),
        location: _locationCtrl.text.trim(),
        coverImageUrl: _coverCtrl.text.trim().isEmpty ? null : _coverCtrl.text.trim(),
        startDateTime: finalStart,
        endDateTime: finalEnd,
        isPaid: _isPaid,
        price: finalPrice,
        capacity: int.tryParse(_capacityCtrl.text.trim()) ?? 1,

        // Keep existing status when editing; new events are published
        status: old?.status ?? EventStatus.published,

        allowEditPublished: old?.allowEditPublished ?? false,
        likesCount: old?.likesCount ?? 0,
        commentsCount: old?.commentsCount ?? 0,
        viewsCount: old?.viewsCount ?? 0,
        bookingsCount: old?.bookingsCount ?? 0,
        createdAt: old?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        archived: old?.archived ?? false,
        city: old?.city,
      );

      await controller.saveEvent(event);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(old == null ? 'Event published' : 'Event updated')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
