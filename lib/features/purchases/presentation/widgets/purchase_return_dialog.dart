import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../data/daos/purchase_dao.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/repositories/purchases_repository.dart';

/// Return input for one line with its still-returnable quantity.
class ReturnLineInput {
  ReturnLineInput(this.lineId, this.available);

  final String lineId;
  final int available;
  int quantity = 0;
  final TextEditingController controller = TextEditingController();
}

/// Shows the purchase return dialog: choose quantities to send back to the
/// supplier per line, bounded by the still-returnable amount (§14).
Future<PurchaseReturnRequest?> showReturnDialog(
  BuildContext context, {
  required List<PurchaseLineView> lines,
  required Map<String, int> availableByLine,
  required String returnNumber,
  required String invoiceId,
  required String userId,
}) {
  return showDialog<PurchaseReturnRequest>(
    context: context,
    builder: (_) => _ReturnDialog(
      lines: lines,
      availableByLine: availableByLine,
      returnNumber: returnNumber,
      invoiceId: invoiceId,
      userId: userId,
    ),
  );
}

class _ReturnDialog extends StatefulWidget {
  const _ReturnDialog({
    required this.lines,
    required this.availableByLine,
    required this.returnNumber,
    required this.invoiceId,
    required this.userId,
  });

  final List<PurchaseLineView> lines;
  final Map<String, int> availableByLine;
  final String returnNumber;
  final String invoiceId;
  final String userId;

  @override
  State<_ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends State<_ReturnDialog> {
  late final List<ReturnLineInput> _inputs = [
    for (final l in widget.lines)
      ReturnLineInput(l.line.id, widget.availableByLine[l.line.id] ?? 0),
  ];
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final input in _inputs) {
      input.controller.addListener(_onQtyChanged);
    }
  }

  void _onQtyChanged() => setState(() {});

  @override
  void dispose() {
    for (final input in _inputs) {
      input.controller
        ..removeListener(_onQtyChanged)
        ..dispose();
    }
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    for (final input in _inputs) {
      final qty = _parseQty(input.controller.text);
      if (qty < 0 || qty > input.available) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.purchaseReturnValidation)));
        return;
      }
      input.quantity = qty;
    }
    final request = PurchaseReturnRequest(
      returnNumber: widget.returnNumber,
      invoiceId: widget.invoiceId,
      userId: widget.userId,
      lines: [
        for (final input in _inputs)
          if (input.quantity > 0)
            PurchaseReturnLineRequest(
              lineId: input.lineId,
              quantityBase: input.quantity,
            ),
      ],
      reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
    );
    if (request.lines.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.purchaseReturnValidation)));
      return;
    }
    Navigator.of(context).pop(request);
  }

  int _parseQty(String text) => int.tryParse(text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typography = context.appTypography;
    final hasReturnable = _inputs.any((i) => i.available > 0);

    return AlertDialog(
      title: Text(l10n.purchaseReturnTitle, style: typography.sectionTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${l10n.purchaseReturnOrderNo}: ${widget.returnNumber}',
                style: typography.bodySecondary,
              ),
              const SizedBox(height: AppSpacing.s),
              if (!hasReturnable)
                Text(l10n.purchaseReturnValidation,
                    style: typography.bodySecondary)
              else
                for (final input in _inputs) ...[
                  const SizedBox(height: AppSpacing.m),
                  Row(
                    children: [
                      Expanded(
                        child: Text(_labelFor(input),
                            style: typography.label),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: input.controller,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l10n.purchaseReturnQty,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Text(
                        '${l10n.purchaseReturnAvailable}: ${input.available}',
                        style: typography.bodySecondary,
                      ),
                    ],
                  ),
                ],
              const SizedBox(height: AppSpacing.m),
              TextField(
                controller: _reason,
                decoration:
                    InputDecoration(labelText: l10n.purchaseReturnReason),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.assignment_return_outlined),
          label: Text(l10n.purchaseReturn),
        ),
      ],
    );
  }

  String _labelFor(ReturnLineInput input) {
    for (final l in widget.lines) {
      if (l.line.id == input.lineId) return l.itemName;
    }
    return '';
  }
}