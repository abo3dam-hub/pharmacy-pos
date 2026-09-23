import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/units/package_cost.dart';
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
/// [unitsPerLarge]/[baseUnitName]/[largeUnitName] describe the item's
/// commercial package so the dialog can offer package-vs-base-unit entry;
/// the returned [AddBatchInput] always carries canonical base-unit values.
Future<BatchFormResult?> showBatchFormDialog(
  BuildContext context, {
  required String itemId,
  required bool hasExpiry,
  int unitsPerLarge = 1,
  String baseUnitName = '',
  String largeUnitName = '',
}) async {
  final result = await showDialog<BatchFormResult>(
    context: context,
    builder: (_) => _BatchFormDialog(
      itemId: itemId,
      hasExpiry: hasExpiry,
      unitsPerLarge: unitsPerLarge,
      baseUnitName: baseUnitName,
      largeUnitName: largeUnitName,
    ),
  );
  return result;
}

class _BatchFormDialog extends StatefulWidget {
  const _BatchFormDialog({
    required this.itemId,
    required this.hasExpiry,
    this.unitsPerLarge = 1,
    this.baseUnitName = '',
    this.largeUnitName = '',
  });

  final String itemId;
  final bool hasExpiry;
  final int unitsPerLarge;
  final String baseUnitName;
  final String largeUnitName;

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

  /// Entry mode: package quantities + package cost (default when the item has
  /// a multi-unit package) vs base-unit quantities + base-unit cost.
  late bool _inPackages;

  @override
  void initState() {
    super.initState();
    _inPackages = widget.unitsPerLarge > 1;
  }

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
    // The form is entered per commercial package by default; the batch (and
    // COGS) is stored per base unit — convert here (half-up).
    final upl = widget.unitsPerLarge;
    final inPackages = _inPackages && upl > 1;
    final quantityBase = inPackages ? qty * upl : qty;
    int cost;
    try {
      final entered = _cost.text.trim().isEmpty
          ? 0
          : Money.parse(_cost.text.trim()).units;
      cost =
          inPackages ? packageCostToBaseUnitCost(entered, upl) : entered;
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
        quantityBase: quantityBase,
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
    final hasPackage = widget.unitsPerLarge > 1;
    // Unit name shown in the quantity/cost labels — always explicit about the
    // basis so a package cost is never mistaken for a base-unit cost. Only
    // shown when the real unit name is known; otherwise the plain label is
    // kept (no redundant "الكمية (الكمية)").
    final String? entryUnitName = (_inPackages && hasPackage)
        ? (widget.largeUnitName.isNotEmpty ? widget.largeUnitName : null)
        : (widget.baseUnitName.isNotEmpty ? widget.baseUnitName : null);
    final quantityLabel = entryUnitName == null
        ? l10n.quantity
        : '${l10n.quantity} ($entryUnitName)';
    final costLabel = entryUnitName == null
        ? l10n.batchUnitCost
        : '${l10n.batchUnitCost} ($entryUnitName)';
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
                if (hasPackage && widget.largeUnitName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.m),
                    child: SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: true,
                          label: Text(widget.largeUnitName),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text(widget.baseUnitName.isNotEmpty
                              ? widget.baseUnitName
                              : l10n.quantity),
                        ),
                      ],
                      selected: {_inPackages},
                      onSelectionChanged: (s) =>
                          setState(() => _inPackages = s.first),
                    ),
                  ),
                TextFormField(
                  controller: _quantity,
                  decoration: InputDecoration(
                    labelText: quantityLabel,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.m),
                TextFormField(
                  controller: _cost,
                  decoration: InputDecoration(
                    labelText: costLabel,
                  ),
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