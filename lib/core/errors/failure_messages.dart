import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'failures.dart';

/// Converts a failure into a clear, reason-carrying user message. Every
/// surfaced failure goes through here so no page silently collapses to the
/// generic "حفظ فشل" without explaining the actual cause.
String failureMessage(AppLocalizations l10n, Failure failure) {
  return switch (failure) {
    UnauthorizedFailure() => l10n.authPermissionDenied,
    ValidationFailure() => failure.message,
    DuplicateFailure() => failure.message,
    NotFoundFailure() => failure.message,
    InsufficientStockFailure() => failure.message,
    ExpiredBatchFailure() => failure.message,
    InvalidOperationFailure() => failure.message,
    DatabaseFailure(message: final m) when (m).trim().isNotEmpty => m,
    _ => l10n.authSaveError,
  };
}

/// Shows [failure] in a snackbar using [failureMessage]; no-op for null.
void showFailureSnack(BuildContext context, Failure? failure) {
  if (failure == null || !context.mounted) return;
  final message = failureMessage(AppLocalizations.of(context), failure);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}