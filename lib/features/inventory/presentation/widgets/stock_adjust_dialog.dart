import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/database/app_database.dart';
import '../../domain/repositories/inventory_repository.dart';

/// Stock-adjustment form result.
class StockAdjustFormResult {
  const StockAdjustFormResult(this.input);

  final StockAdjustInput input;
}

/// Adjustment dialog (§1.?) — increase/decrease of an item's ledger balance.
Future<StockAdjustFormResult?> showStockAdjustDialog(
  BuildContext context, {
  required String itemId,
  required List<BatchRow> batches,
}) async {
  final result = await showDialog<StockAdjustFormResult>(
    context: context,
    builder: (_) => _StockAdjustDialog(itemId: itemId, batches: batches),
  );
  return result;
}

class _StockAdjustDialog extends StatefulWidget {
  const _StockAdjustDialog({required this.itemId, required this.batches});

  final String itemId;
  final List<BatchRow> batches;

  @override
  State<_StockAdjustDialog> createState() => _StockAdjustDialogState();
}

class _StockAdjustDialogState extends State<_StockAdjustDialog> {
  final _formKey = GlobalKey<FormState>();
  final _delta = TextEditingController();
  final _cost = TextEditingController();
  final _note = TextEditingController();

  bool _increase = true;
  String? _batchId;

  @override
  void initState() {
    super.initState();
    for (final b in widget.batches) {
      if (!b.isVoided) {
        _batchId = b.id;
        return;
      }
    }
    _batchId = widget.batches.isEmpty ? null : widget.batches.first.id;
  }

  @override
  void dispose() {
    _delta.dispose();
    _cost.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    final v = int.tryParse(_delta.text.trim());
    if (v == null || v <= 0) {
      _fail(l10n.quantity);
      return;
    }
    int cost;
    try {
      cost = _cost.text.trim().isEmpty
          ? 0
          : Money.parse(_cost.text.trim()).units;
    } on FormatException {
      _fail(l10n.authSaveError);
      return;
    }
    if (cost < 0) {
      _fail(l10n.authSaveError);
      return;
    }
    final delta = _increase ? v : -v;
    Navigator.of(context).pop(StockAdjustFormResult(
      StockAdjustInput(
        itemId: widget.itemId,
        batchId: _batchId,
        movementType: 'stock_adjustment',
        deltaBase: delta,
        unitCostMicros: cost,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    ));
  }

  void _fail(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.adjustStockTitle),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: true,
                      label: Text(l10n.adjustmentIncrease),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text(l10n.adjustmentDecrease),
                    ),
                  ],
                  selected: {_increase},
                  onSelectionChanged: (s) =>
                      setState(() => _increase = s.first),
                ),
                const SizedBox(height: AppSpacing.m),
                TextFormField(
                  controller: _delta,
                  decoration: InputDecoration(labelText: l10n.quantity),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.m),
                TextFormField(
                  controller: _cost,
                  decoration: InputDecoration(labelText: l10n.batchUnitCost),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                if (widget.batches.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.m),
                  DropdownButtonFormField<String>(
                    initialValue: _batchId,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.batchNo),
                    items: [
                      for (final b in widget.batches)
                        DropdownMenuItem(
                          value: b.id,
                          child: Text(b.batchNumber),
                        ),
                    ],
                    onChanged: (v) => setState(() => _batchId = v),
                  ),
                ],
                const SizedBox(height: AppSpacing.m),
                TextFormField(
                  controller: _note,
                  decoration: InputDecoration(labelText: l10n.adjustNote),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}