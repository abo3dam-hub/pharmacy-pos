import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/repositories/inventory_repository.dart';

/// What the user chose in the batch form: plain save, or save and continue to
/// the "add invoice" (فاتورة شراء) screen.
enum BatchFormAction { save, saveAndAddPurchase }

/// Add-batch form result.
class BatchFormResult {
  const BatchFormResult(this.input, {this.action = BatchFormAction.save});

  final AddBatchInput input;
  final BatchFormAction action;
}

/// Manual batch-entry dialog (§4.8). [hasExpiry] toggles expiry requirement.
Future<BatchFormResult?> showBatchFormDialog(
  BuildContext context, {
  required String itemId,
  required bool hasExpiry,
}) async {
  final result = await showDialog<BatchFormResult>(
    context: context,
    builder: (_) => _BatchFormDialog(itemId: itemId, hasExpiry: hasExpiry),
  );
  return result;
}

class _BatchFormDialog extends StatefulWidget {
  const _BatchFormDialog({required this.itemId, required this.hasExpiry});

  final String itemId;
  final bool hasExpiry;

  @override
  State<_BatchFormDialog> createState() => _BatchFormDialogState();
}

class _BatchFormDialogState extends State<_BatchFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _batchNumber = TextEditingController();
  final _quantity = TextEditingController();
  final _cost = TextEditingController();
  final _bonus = TextEditingController();
  final _notes = TextEditingController();

  DateTime? _expiry;
  DateTime? _received;
  String? _expiryError;

  @override
  void dispose() {
    _batchNumber.dispose();
    _quantity.dispose();
    _cost.dispose();
    _bonus.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate(ValueChanged<DateTime?> set) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 730)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) {
      set(picked);
      if (mounted && _expiryError != null) {
        setState(() => _expiryError = null);
      }
    }
  }

  /// Validates expiry inline (never closes the dialog with an unexplained
  /// error) and pops with [action] when the form is valid.
  void _submit([BatchFormAction action = BatchFormAction.save]) {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (widget.hasExpiry && _expiry == null) {
      setState(() => _expiryError = l10n.batchExpiryRequired);
      return;
    }
    final qty = int.tryParse(_quantity.text.trim());
    if (qty == null || qty <= 0) {
      _fail(l10n.quantity);
      return;
    }
    int? cost;
    try {
      cost = _cost.text.trim().isEmpty
          ? 0
          : Money.parse(_cost.text.trim()).units;
    } on FormatException {
      _fail(l10n.batchCostInvalid);
      return;
    }
    final bonus = int.tryParse(_bonus.text.trim()) ?? 0;
    if ((bonus < 0)) {
      _fail(l10n.quantity);
      return;
    }
    Navigator.of(context).pop(BatchFormResult(
      AddBatchInput(
        itemId: widget.itemId,
        batchNumber: _batchNumber.text.trim(),
        expiryDate: _expiry?.millisecondsSinceEpoch,
        quantityBase: qty,
        unitCostMicros: cost,
        receivedDate: _received?.millisecondsSinceEpoch,
        bonusQtyBase: bonus,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ),
      action: action,
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
      title: Text(l10n.batchesAddTitle),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _batchNumber,
                  decoration: InputDecoration(labelText: l10n.batchNo),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.batchesAddTitle
                      : null,
                ),
                const SizedBox(height: AppSpacing.m),
                TextFormField(
                  controller: _quantity,
                  decoration: InputDecoration(labelText: l10n.quantity),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.m),
                TextFormField(
                  controller: _cost,
                  decoration: InputDecoration(labelText: l10n.batchUnitCost),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: AppSpacing.m),
                TextFormField(
                  controller: _bonus,
                  decoration: InputDecoration(labelText: l10n.batchBonusQty),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _dateField(
                            l10n.expiryDate,
                            _expiry,
                            enabled: widget.hasExpiry,
                            onTap: () => _pickDate(
                                (d) => setState(() => _expiry = d)),
                          ),
                          if (_expiryError != null)
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: AppSpacing.xs),
                              child: Text(
                                _expiryError!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: _dateField(
                        l10n.batchReceivedDate,
                        _received,
                        onTap: () =>
                            _pickDate((d) => setState(() => _received = d)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                TextFormField(
                  controller: _notes,
                  decoration: InputDecoration(labelText: l10n.batchNotes),
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
        FilledButton.tonalIcon(
          onPressed: () => _submit(BatchFormAction.saveAndAddPurchase),
          icon: const Icon(Icons.add_shopping_cart_outlined),
          label: Text(l10n.batchSaveAndContinuePurchase),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }

  Widget _dateField(
    String label,
    DateTime? value, {
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, isDense: true),
        child: Text(
          value == null
              ? AppLocalizations.of(context).commonNone
              : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}',
        ),
      ),
    );
  }
}