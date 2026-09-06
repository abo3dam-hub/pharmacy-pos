import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_text_styles.dart';

/// Shows a themed confirmation dialog and resolves with the user's choice.
///
/// Use for destructive / sensitive actions; the destructive variant renders
/// the confirm action in the semantic error color. Labels default to the
/// localized `commonConfirm` / `commonCancel`.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    ),
  );
  return result ?? false;
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    this.confirmLabel,
    this.cancelLabel,
    this.destructive = false,
  });

  final String title;
  final String message;
  final String? confirmLabel;
  final String? cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final typography = context.appTypography;

    return AlertDialog(
      title: Text(title, style: typography.sectionTitle),
      content: Text(message, style: typography.body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel ?? l10n.commonCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: destructive ? colors.error : null,
            foregroundColor: destructive ? colors.onError : null,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel ?? l10n.commonConfirm),
        ),
      ],
    );
  }
}