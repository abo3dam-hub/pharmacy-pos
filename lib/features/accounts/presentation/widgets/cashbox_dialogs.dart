import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/amount_field.dart';
import '../../../../l10n/app_localizations.dart';

/// Result of the drawer-open dialog: opening float + optional note, or null.
typedef CashboxOpenResult = ({int openingMicros, String? note});

/// Result of the drawer-close dialog: declared counted cash + mandatory reason.
typedef CashboxCloseResult = ({int declaredCloseMicros, String reason});

/// Result of deposit/withdraw dialog: amount + mandatory reason.
typedef CashboxMoveResult = ({int amountMicros, String reason});

/// Result of the adjustment dialog: signed amount + mandatory reason.
typedef CashboxAdjustResult = ({int signedMicros, String reason});

Money? _parseMoney(String text) {
  try {
    return Money.parse(text);
  } on FormatException {
    return null;
  }
}

/// Opens the Cash Box (فتح الصندوق) with the opening float.
Future<CashboxOpenResult?> showCashboxOpenDialog(BuildContext context) async {
  final result = await showDialog<CashboxOpenResult>(
    context: context,
    builder: (_) => const _CashboxOpenDialog(),
  );
  return result;
}

/// Closes the Cash Box (إغلاق الصندوق): counts the drawer and records the
/// declared closing cash. The live expected balance is shown as guidance.
Future<CashboxCloseResult?> showCashboxCloseDialog(
  BuildContext context, {
  required int expectedClosingMicros,
}) async {
  final result = await showDialog<CashboxCloseResult>(
    context: context,
    builder: (_) => _CashboxCloseDialog(expectedClosingMicros: expectedClosingMicros),
  );
  return result;
}

/// Deposit (إيداع نقدي) / Withdrawal (سحب نقدي) into/out of the drawer.
Future<CashboxMoveResult?> showCashboxMoveDialog(
  BuildContext context, {
  required bool isDeposit,
}) async {
  final result = await showDialog<CashboxMoveResult>(
    context: context,
    builder: (_) => _CashboxMoveDialog(isDeposit: isDeposit),
  );
  return result;
}

/// Authorized drawer adjustment (تسوية الصندوق): signed amount + reason.
Future<CashboxAdjustResult?> showCashboxAdjustDialog(
  BuildContext context, {
  required int expectedClosingMicros,
}) async {
  final result = await showDialog<CashboxAdjustResult>(
    context: context,
    builder: (_) => _CashboxAdjustDialog(expectedClosingMicros: expectedClosingMicros),
  );
  return result;
}

class _CashboxOpenDialog extends StatefulWidget {
  const _CashboxOpenDialog();

  @override
  State<_CashboxOpenDialog> createState() => _CashboxOpenDialogState();
}

class _CashboxOpenDialogState extends State<_CashboxOpenDialog> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();
  String? _error;

  void _submit() {
    final text = _amount.text.trim();
    if (text.isEmpty) {
      setState(() => _error = _l10n.cashboxOpeningRequired);
      return;
    }
    final parsed = _parseMoney(text);
    if (parsed == null || parsed.micros < 0) {
      setState(() => _error = _l10n.cashboxOpeningInvalid);
      return;
    }
    Navigator.of(context).pop(
      (openingMicros: parsed.micros, note: _note.text.trim().isEmpty ? null : _note.text.trim()),
    );
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    return AlertDialog(
      title: Text(l10n.cashboxActionOpen),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AmountField(
              controller: _amount,
              hintText: l10n.cashboxOpeningLabel,
              autofocus: true,
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _note,
              decoration: InputDecoration(
                labelText: l10n.cashboxNoteOptional,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.m),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.commonConfirm)),
      ],
    );
  }
}

class _CashboxCloseDialog extends StatefulWidget {
  const _CashboxCloseDialog({required this.expectedClosingMicros});

  final int expectedClosingMicros;

  @override
  State<_CashboxCloseDialog> createState() => _CashboxCloseDialogState();
}

class _CashboxCloseDialogState extends State<_CashboxCloseDialog> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  String? _error;

  void _submit() {
    final text = _amount.text.trim();
    if (text.isEmpty) {
      setState(() => _error = _l10n.cashboxClosingRequired);
      return;
    }
    final parsed = _parseMoney(text);
    if (parsed == null || parsed.micros < 0) {
      setState(() => _error = _l10n.cashboxClosingInvalid);
      return;
    }
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = _l10n.cashboxReasonRequired);
      return;
    }
    Navigator.of(context).pop(
      (declaredCloseMicros: parsed.micros, reason: _reason.text.trim()),
    );
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    return AlertDialog(
      title: Text(l10n.cashboxActionClose),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${l10n.cashboxExpected}: '
              '${Money.fromUnits(widget.expectedClosingMicros).formatArabicDigits()}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.m),
            AmountField(
              controller: _amount,
              hintText: l10n.cashboxDeclaredLabel,
              autofocus: true,
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _reason,
              decoration: InputDecoration(
                labelText: l10n.cashboxReason,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.m),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.commonConfirm)),
      ],
    );
  }
}

class _CashboxMoveDialog extends StatefulWidget {
  const _CashboxMoveDialog({required this.isDeposit});

  final bool isDeposit;

  @override
  State<_CashboxMoveDialog> createState() => _CashboxMoveDialogState();
}

class _CashboxMoveDialogState extends State<_CashboxMoveDialog> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  String? _error;

  void _submit() {
    final text = _amount.text.trim();
    if (text.isEmpty) {
      setState(() => _error = _l10n.cashboxMoveRequired);
      return;
    }
    final parsed = _parseMoney(text);
    if (parsed == null || parsed.micros <= 0) {
      setState(() => _error = _l10n.cashboxMoveInvalid);
      return;
    }
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = _l10n.cashboxReasonRequired);
      return;
    }
    Navigator.of(context).pop(
      (amountMicros: parsed.micros, reason: _reason.text.trim()),
    );
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    return AlertDialog(
      title: Text(widget.isDeposit ? l10n.cashboxActionDeposit : l10n.cashboxActionWithdraw),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AmountField(
              controller: _amount,
              hintText: l10n.cashboxAmountLabel,
              autofocus: true,
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _reason,
              decoration: InputDecoration(
                labelText: l10n.cashboxReason,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.m),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.commonConfirm)),
      ],
    );
  }
}

class _CashboxAdjustDialog extends StatefulWidget {
  const _CashboxAdjustDialog({required this.expectedClosingMicros});

  final int expectedClosingMicros;

  @override
  State<_CashboxAdjustDialog> createState() => _CashboxAdjustDialogState();
}

class _CashboxAdjustDialogState extends State<_CashboxAdjustDialog> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  String? _error;

  void _submit() {
    final text = _amount.text.trim();
    if (text.isEmpty) {
      setState(() => _error = _l10n.cashboxMoveRequired);
      return;
    }
    final parsed = _parseMoney(text);
    if (parsed == null || parsed.micros == 0) {
      setState(() => _error = _l10n.cashboxMoveInvalid);
      return;
    }
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = _l10n.cashboxReasonRequired);
      return;
    }
    Navigator.of(context).pop(
      (signedMicros: parsed.micros, reason: _reason.text.trim()),
    );
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    return AlertDialog(
      title: Text(l10n.cashboxActionAdjust),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${l10n.cashboxExpected}: '
              '${Money.fromUnits(widget.expectedClosingMicros).formatArabicDigits()}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.m),
            AmountField(
              controller: _amount,
              hintText: l10n.cashboxAdjustHint,
              autofocus: true,
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _reason,
              decoration: InputDecoration(
                labelText: l10n.cashboxReason,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.m),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.commonConfirm)),
      ],
    );
  }
}