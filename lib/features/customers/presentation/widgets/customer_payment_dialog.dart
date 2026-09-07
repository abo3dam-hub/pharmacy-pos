import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';

/// Builds a payment-number like `CP-YYYYMMDD-HHmmssSSS` (collision-safe).
String _nextPaymentNumber(DateTime now) {
  String p(int n) => n.toString().padLeft(2, '0');
  String p3(int n) => n.toString().padLeft(3, '0');
  return 'CP-${now.year}${p(now.month)}${p(now.day)}-'
      '${p(now.hour)}${p(now.minute)}${p(now.second)}${p3(now.millisecond)}';
}

/// Shows a dialog to record money received from a customer on account
/// (reduces their balance) or a refund to the customer. Returns true when a
/// payment was recorded and the caller should refresh, false/null on cancel.
Future<bool> showCustomerPaymentDialog(
  BuildContext context, {
  required String customerId,
  bool isRefund = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _CustomerPaymentDialog(
      customerId: customerId,
      isRefund: isRefund,
    ),
  ).then((v) => v ?? false);
}

class _CustomerPaymentDialog extends ConsumerStatefulWidget {
  const _CustomerPaymentDialog({
    required this.customerId,
    required this.isRefund,
  });

  final String customerId;
  final bool isRefund;

  @override
  ConsumerState<_CustomerPaymentDialog> createState() =>
      _CustomerPaymentDialogState();
}

class _CustomerPaymentDialogState
    extends ConsumerState<_CustomerPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _cash = TextEditingController();
  final _card = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _cash.dispose();
    _card.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final actingUserId = ref.read(authControllerProvider).user?.id;
    if (actingUserId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.authPermissionDenied)));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final amountMicros = Money.parse(_amount.text.trim()).units;
    if (amountMicros <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.csPaymentAmountError)));
      return;
    }
    final cashMicros = _parse(_cash.text);
    final cardMicros = _parse(_card.text);
    if (cashMicros + cardMicros != amountMicros) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.csPaymentSplitError)));
      return;
    }

    setState(() => _busy = true);
    try {
      final service = ref.read(customerPaymentServiceProvider);
      final db = ref.read(databaseProvider);
      final now = DateTime.now();
      if (widget.isRefund) {
        await service.recordCustomerRefund(
          db,
          paymentNumber: _nextPaymentNumber(now),
          customerId: widget.customerId,
          amountMicros: amountMicros,
          cashMicros: cashMicros,
          cardMicros: cardMicros,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          userId: actingUserId,
        );
      } else {
        await service.recordCustomerPayment(
          db,
          paymentNumber: _nextPaymentNumber(now),
          customerId: widget.customerId,
          amountMicros: amountMicros,
          cashMicros: cashMicros,
          cardMicros: cardMicros,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          userId: actingUserId,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.csPaymentSaved)));
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.authSaveError)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int _parse(String value) {
    final v = value.trim();
    if (v.isEmpty) return 0;
    try {
      return Money.parse(v).units;
    } on FormatException {
      return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typography = context.appTypography;
    final title =
        widget.isRefund ? l10n.csPaymentRefundTitle : l10n.csPaymentTitle;

    return AlertDialog(
      title: Text(title, style: typography.sectionTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _amount,
                  decoration: InputDecoration(labelText: l10n.csPaymentAmount),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return l10n.csPaymentAmountError;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cash,
                        decoration: InputDecoration(labelText: l10n.csPaymentCash),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: TextFormField(
                        controller: _card,
                        decoration: InputDecoration(labelText: l10n.csPaymentCard),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                TextFormField(
                  controller: _note,
                  decoration: InputDecoration(labelText: l10n.csPaymentNote),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(l10n.csRecordPayment),
        ),
      ],
    );
  }
}
