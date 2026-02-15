import 'package:flutter/material.dart';

class AppDialogs {
  AppDialogs._();

  /// Overlay popup with an OK button.
  static Future<void> showMessage(
      BuildContext context, {
        required String title,
        required String message,
        String okText = 'OK',
        bool barrierDismissible = false,
      }) async {
    if (!context.mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(okText),
            ),
          ],
        );
      },
    );
  }

  static Future<void> showError(
      BuildContext context, {
        String title = 'Something went wrong',
        required String message,
      }) {
    return showMessage(
      context,
      title: title,
      message: message,
      okText: 'OK',
      barrierDismissible: false,
    );
  }

  static Future<void> showInfo(
      BuildContext context, {
        String title = 'Done',
        required String message,
      }) {
    return showMessage(
      context,
      title: title,
      message: message,
      okText: 'OK',
      barrierDismissible: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Backward-compatible API (so old code compiles):
  // AppDialogs.toast(...) and AppDialogs.dialog(...)
  // Both are still "overlay popups with OK", no SnackBars.
  // ---------------------------------------------------------------------------

  /// Replaces old "toast" usage. Shows a small info dialog with OK.
  static Future<void> toast(
      BuildContext context, {
        required String message,
        String title = 'Notice',
      }) {
    return showInfo(
      context,
      title: title,
      message: message,
    );
  }

  /// Replaces old "dialog" usage. Shows an error/info dialog with OK.
  static Future<void> dialog(
      BuildContext context, {
        required String title,
        required String message,
        bool barrierDismissible = false,
      }) {
    return showMessage(
      context,
      title: title,
      message: message,
      okText: 'OK',
      barrierDismissible: barrierDismissible,
    );
  }

  // ---------------------------------------------------------------------------
  // Confirm dialog (YES/NO)
  // ---------------------------------------------------------------------------

  /// Preferred API name (matches your current UI usage): AppDialogs.confirm(...)
  static Future<bool> confirm(
      BuildContext context, {
        String title = 'Confirm',
        required String message,
        String confirmText = 'Confirm',
        String cancelText = 'Cancel',
        bool isDanger = false,
      }) {
    return showConfirm(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      isDanger: isDanger,
    );
  }

  /// Keep this too in case some files call AppDialogs.showConfirm(...)
  static Future<bool> showConfirm(
      BuildContext context, {
        String title = 'Confirm',
        required String message,
        String confirmText = 'Confirm',
        String cancelText = 'Cancel',
        bool isDanger = false,
      }) async {
    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(cancelText),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: isDanger
                  ? FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              )
                  : null,
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}
