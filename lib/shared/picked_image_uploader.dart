import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shoo_fi/shared/app_dialog.dart';
import 'friendly_errors.dart';
import 'file_image.dart';


class PickedImageUploader extends StatefulWidget {
  final String storageFolder;
  final String? initialImageUrl;
  final ValueChanged<String> onUploaded;
  final String title;
  final int maxSizeMb;

  const PickedImageUploader({
    super.key,
    required this.storageFolder,
    required this.onUploaded,
    this.initialImageUrl,
    this.title = 'Image',
    this.maxSizeMb = 6,
  });

  @override
  State<PickedImageUploader> createState() => _PickedImageUploaderState();
}

class _PickedImageUploaderState extends State<PickedImageUploader> {
  Uint8List? _bytes;
  String? _path; // mobile only
  String? _uploadedUrl;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _uploadedUrl = widget.initialImageUrl;
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;

    final sizeBytes = file.size;
    final maxBytes = widget.maxSizeMb * 1024 * 1024;
    if (sizeBytes > maxBytes) {
      if (!mounted) return;
      await AppDialogs.showError(
        context,
        message: 'This image is too large. Please choose a smaller one (max ${widget.maxSizeMb}MB).',
      );
      return;
    }

    setState(() {
      _bytes = file.bytes;
      _path = file.path;
    });
  }

  Future<void> _upload() async {
    if (_bytes == null) {
      if (!mounted) return;
      await AppDialogs.showError(
        context,
        message: 'Please choose an image first.',
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      await AppDialogs.showError(
        context,
        message: 'You are not logged in. Please sign in again.',
      );
      return;
    }

    setState(() => _uploading = true);

    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance.ref(
        '${widget.storageFolder}/${user.uid}/$ts.jpg',
      );

      await ref.putData(
        _bytes!,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final url = await ref.getDownloadURL();

      setState(() {
        _uploadedUrl = url;
      });

      widget.onUploaded(url);

      if (!mounted) return;
      await AppDialogs.showInfo(
        context,
        title: 'Uploaded',
        message: 'Your image has been uploaded.',
      );
    } catch (e) {
      if (!mounted) return;
      await AppDialogs.showError(
        context,
        message: FriendlyErrors.fromUnknown(e),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget preview;
    if (_bytes != null) {
      preview = Image.memory(_bytes!, fit: BoxFit.cover);
    } else if (!kIsWeb && _path != null && _path!.isNotEmpty) {
      preview = fileImageWidget(_path!, fit: BoxFit.cover);
    } else if (_uploadedUrl != null && _uploadedUrl!.trim().isNotEmpty) {
      preview = Image.network(_uploadedUrl!, fit: BoxFit.cover);
    } else {
      preview = const Center(child: Icon(Icons.image, size: 42));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: ColoredBox(
                  color: Colors.black12,
                  child: preview,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploading ? null : _pick,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Choose'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _uploading ? null : _upload,
                    icon: _uploading
                        ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(_uploading ? 'Uploading...' : 'Upload'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Tip: Choose → Upload, then save your event/profile.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ],
        ),
      ),
    );
  }
}
