import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/database/app_database.dart';
import '../../domain/usecases/bulk_use_cases.dart';

/// Bulk-action form result.
class BulkFormResult {
  const BulkFormResult(this.input);

  final BulkUpdateInput input;
}

/// Bulk grid dialog (§22): change category / shelf location / price-by-%.
/// [canChangePrices] hides the price option without the `change_prices` grant.
Future<BulkFormResult?> showBulkDialog(
  BuildContext context, {
  required List<String> itemIds,
  required List<CategoryRow> categories,
  required List<ManufacturerRow> manufacturers,
  required List<SupplierRow> suppliers,
  required bool canChangePrices,
}) async {
  final result = await showDialog<BulkFormResult>(
    context: context,
    builder: (_) => _BulkDialog(
      itemIds: itemIds,
      categories: categories,
      manufacturers: manufacturers,
      suppliers: suppliers,
      canChangePrices: canChangePrices,
    ),
  );
  return result;
}

class _BulkDialog extends StatefulWidget {
  const _BulkDialog({
    required this.itemIds,
    required this.categories,
    required this.manufacturers,
    required this.suppliers,
    required this.canChangePrices,
  });

  final List<String> itemIds;
  final List<CategoryRow> categories;
  final List<ManufacturerRow> manufacturers;
  final List<SupplierRow> suppliers;
  final bool canChangePrices;

  @override
  State<_BulkDialog> createState() => _BulkDialogState();
}

class _BulkDialogState extends State<_BulkDialog> {
  final _shelf = TextEditingController();
  final _percent = TextEditingController();

  BulkOperation? _operation;
  String? _categoryId;
  BulkPriceScope _scope = BulkPriceScope.manual;
  String? _manufacturerId;
  String? _supplierId;

  @override
  void dispose() {
    _shelf.dispose();
    _percent.dispose();
    super.dispose();
  }

  int? _parsePercentBasisPoints() {
    final v = _percent.text.trim();
    if (v.isEmpty) return null;
    final d = double.tryParse(v.replaceAll(',', ''));
    if (d == null) return null;
    return (d * 100).round();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final op = _operation;
    if (op == null) {
      _fail(l10n.bulkSelectHint);
      return;
    }
    switch (op) {
      case BulkOperation.changeCategory:
        if (_categoryId == null) {
          _fail(l10n.inventorySelectCategory);
          return;
        }
      case BulkOperation.changeShelfLocation:
        if (_shelf.text.trim().isEmpty) {
          _fail(l10n.itemShelfLocation);
          return;
        }
      case BulkOperation.adjustPricePercent:
        final bp = _parsePercentBasisPoints();
        if (bp == null || bp == 0) {
          _fail(l10n.bulkPercent);
          return;
        }
        if (_scope == BulkPriceScope.manufacturer &&
            _manufacturerId == null) {
          _fail(l10n.bulkPriceScopeManufacturer);
          return;
        }
        if (_scope == BulkPriceScope.supplier && _supplierId == null) {
          _fail(l10n.bulkPriceScopeSupplier);
          return;
        }
    }
    Navigator.of(context).pop(BulkFormResult(
      BulkUpdateInput(
        operation: op,
        itemIds: widget.itemIds,
        categoryId: _categoryId,
        shelfLocation: _shelf.text.trim().isEmpty ? null : _shelf.text.trim(),
        basisPoints: _parsePercentBasisPoints() ?? 0,
        priceScope: op == BulkOperation.adjustPricePercent ? _scope
            : BulkPriceScope.manual,
        priceManufacturerId: _manufacturerId,
        priceSupplierId: _supplierId,
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
      title: Text(l10n.bulkTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.bulkSelectedCount(widget.itemIds.length)),
            const SizedBox(height: AppSpacing.m),
            RadioGroup<BulkOperation>(
              groupValue: _operation,
              onChanged: (v) => setState(() => _operation = v),
              child: Column(
                children: [
                  for (final op in [
                    BulkOperation.changeCategory,
                    BulkOperation.changeShelfLocation,
                    if (widget.canChangePrices) BulkOperation.adjustPricePercent,
                  ])
                    RadioListTile<BulkOperation>(
                      title: Text(_label(l10n, op) ?? op.name),
                      value: op,
                      dense: true,
                    ),
                ],
              ),
            ),
            if (_operation == BulkOperation.changeCategory) ...[
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: InputDecoration(labelText: l10n.itemCategory),
                items: [
                  for (final c in widget.categories)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
            ],
            if (_operation == BulkOperation.changeShelfLocation)
              TextFormField(
                controller: _shelf,
                decoration: InputDecoration(labelText: l10n.itemShelfLocation),
              ),
            if (_operation == BulkOperation.adjustPricePercent) ...[
              TextFormField(
                controller: _percent,
                decoration: InputDecoration(
                  labelText: l10n.bulkPercent,
                  helperText: '+5 or -10',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: AppSpacing.s),
              Text(l10n.bulkPriceScopeTitle),
              RadioGroup<BulkPriceScope>(
                groupValue: _scope,
                onChanged: (v) =>
                    setState(() => _scope = v ?? BulkPriceScope.manual),
                child: Column(
                  children: [
                    for (final scope in BulkPriceScope.values)
                      RadioListTile<BulkPriceScope>(
                        title: Text(_scopeLabel(l10n, scope)),
                        value: scope,
                        dense: true,
                      ),
                  ],
                ),
              ),
              if (_scope == BulkPriceScope.manufacturer)
                DropdownButtonFormField<String>(
                  initialValue: _manufacturerId,
                  decoration: InputDecoration(labelText: l10n.itemManufacturer),
                  items: [
                    for (final m in widget.manufacturers)
                      DropdownMenuItem(value: m.id, child: Text(m.name)),
                  ],
                  onChanged: (v) => setState(() => _manufacturerId = v),
                ),
              if (_scope == BulkPriceScope.supplier)
                DropdownButtonFormField<String>(
                  initialValue: _supplierId,
                  decoration: InputDecoration(labelText: l10n.supplierName),
                  items: [
                    for (final s in widget.suppliers)
                      DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (v) => setState(() => _supplierId = v),
                ),
            ],
          ],
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

  String? _label(AppLocalizations l10n, BulkOperation op) => switch (op) {
        BulkOperation.changeCategory => l10n.bulkChangeCategory,
        BulkOperation.changeShelfLocation => l10n.bulkChangeShelf,
        BulkOperation.adjustPricePercent => l10n.bulkAdjustPricePercent,
      };

  String _scopeLabel(AppLocalizations l10n, BulkPriceScope scope) =>
      switch (scope) {
        BulkPriceScope.all => l10n.bulkPriceScopeAll,
        BulkPriceScope.manufacturer => l10n.bulkPriceScopeManufacturer,
        BulkPriceScope.supplier => l10n.bulkPriceScopeSupplier,
        BulkPriceScope.manual => l10n.bulkPriceScopeManual(
            widget.itemIds.length),
      };
}