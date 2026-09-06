import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../data/daos/purchase_dao.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/repositories/purchases_repository.dart';

/// Shows the receive dialog: one batch number (+ optional expiry) per pending
/// line, entered before goods are added to stock (§12).
Future<List<ReceiveLineInput>?> showReceiveDialog(
  BuildContext context, {
  required List<PurchaseLineView> lines,
}) {
  return showDialog<List<ReceiveLineInput>>(
    context: context,
    builder: (_) => _ReceiveDialog(lines: lines),
  );
}

class _ReceiveDialog extends StatefulWidget {
  const _ReceiveDialog({required this.lines});

  final List<PurchaseLineView> lines;

  @override
  State<_ReceiveDialog> createState() => _ReceiveDialogState();
}

class _ReceiveDialogState extends State<_ReceiveDialog> {
  final Map<String, TextEditingController> _batch = {};
  final Map<String, DateTime?> _expiry = {};

  @override
  void initState() {
    super.initState();
    for (final l in widget.lines) {
      _batch[l.line.id] = TextEditingController();
      _expiry[l.line.id] = null;
    }
  }

  @override
  void dispose() {
    for (final c in _batch.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickExpiry(String lineId) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry[lineId] ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _expiry[lineId] = picked);
    }
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final inputs = <ReceiveLineInput>[];
    for (final l in widget.lines) {
      final number = _batch[l.line.id]!.text.trim();
      if (number.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.purchaseBatchNumber)));
        return;
      }
      final exp = _expiry[l.line.id];
      inputs.add(ReceiveLineInput(
        lineId: l.line.id,
        batchNumber: number,
        expiryDate: exp == null
            ? null
            : DateTime(exp.year, exp.month, exp.day).millisecondsSinceEpoch,
      ));
    }
    Navigator.of(context).pop(inputs);
  }

  static String _fmtDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.purchaseReceiveTitle,
          style: context.appTypography.sectionTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.purchaseReceiveIntro,
                  style: context.appTypography.bodySecondary),
              const SizedBox(height: AppSpacing.s),
              for (final l in widget.lines) ...[
                const SizedBox(height: AppSpacing.m),
                Text(l.itemName, style: context.appTypography.label),
                const SizedBox(height: AppSpacing.s),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _batch[l.line.id],
                        decoration: InputDecoration(
                          labelText: l10n.purchaseBatchNumber,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    OutlinedButton.icon(
                      onPressed: () => _pickExpiry(l.line.id),
                      icon: const Icon(Icons.event_outlined),
                      label: Text(_expiry[l.line.id] == null
                          ? l10n.purchaseExpiryDate
                          : _fmtDate(_expiry[l.line.id]!)),
                    ),
                  ],
                ),
              ],
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
          icon: const Icon(Icons.inventory_2_outlined),
          label: Text(l10n.purchaseReceive),
        ),
      ],
    );
  }
}