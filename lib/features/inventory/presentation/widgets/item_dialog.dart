import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/database/app_database.dart';
import '../../../suppliers/domain/repositories/supplier_repository.dart';
import '../../../suppliers/presentation/widgets/supplier_dialog.dart';
import '../../domain/repositories/inventory_repository.dart';
import 'master_data_dialog.dart';

/// Result of the item form: the validated [ItemDraft].
class ItemFormResult {
  const ItemFormResult(this.draft);

  final ItemDraft draft;
}

/// Shows the §5 item create/edit form dialog. Returns a validated draft or
/// null if cancelled. Money is entered as decimal and stored in integer
/// micro-units; percentages are integer basis points. Master-data + supplier
/// creates are performed via [onCreateMasterData] / [onCreateSupplier] so the
/// dialog stays widget-testable while the caller owns persisting and audit.
Future<ItemFormResult?> showItemFormDialog(
  BuildContext context, {
  required String title,
  ItemDraft? initial,
  required List<CategoryRow> categories,
  required List<SubCategoryRow> subCategories,
  required List<ManufacturerRow> manufacturers,
  required List<TherapeuticGroupRow> groups,
  required List<UnitRow> units,
  List<SupplierRow> suppliers = const [],
  List<ActiveIngredientRow> activeIngredients = const [],
  List<IndicationRow> indications = const [],
  Future<Object?> Function(MasterDataKind kind, MasterDataDraft draft)?
      onCreateMasterData,
  Future<SupplierRow?> Function(SupplierDraft draft)? onCreateSupplier,
  int defaultPartialSaleMarkupBasisPoints = 1000,
}) async {
  final result = await showDialog<ItemFormResult>(
    context: context,
    builder: (_) => _ItemFormDialog(
      title: title,
      initial: initial,
      categories: categories,
      subCategories: subCategories,
      manufacturers: manufacturers,
      groups: groups,
      units: units,
      suppliers: suppliers,
      activeIngredients: activeIngredients,
      indications: indications,
      onCreateMasterData: onCreateMasterData,
      onCreateSupplier: onCreateSupplier,
      defaultPartialSaleMarkupBasisPoints: defaultPartialSaleMarkupBasisPoints,
    ),
  );
  return result;
}

class _ItemFormDialog extends StatefulWidget {
  const _ItemFormDialog({
    required this.title,
    this.initial,
    required this.categories,
    required this.subCategories,
    required this.manufacturers,
    required this.groups,
    required this.units,
    this.suppliers = const [],
    this.activeIngredients = const [],
    this.indications = const [],
    this.onCreateMasterData,
    this.onCreateSupplier,
    this.defaultPartialSaleMarkupBasisPoints = 1000,
  });

  final String title;
  final ItemDraft? initial;
  final List<CategoryRow> categories;
  final List<SubCategoryRow> subCategories;
  final List<ManufacturerRow> manufacturers;
  final List<TherapeuticGroupRow> groups;
  final List<UnitRow> units;
  final List<SupplierRow> suppliers;
  final List<ActiveIngredientRow> activeIngredients;
  final List<IndicationRow> indications;
  final Future<Object?> Function(MasterDataKind kind, MasterDataDraft draft)?
      onCreateMasterData;
  final Future<SupplierRow?> Function(SupplierDraft draft)? onCreateSupplier;
  final int defaultPartialSaleMarkupBasisPoints;

  @override
  State<_ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends State<_ItemFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final ItemDraft _initial;

  final _controllers = <String, TextEditingController>{};

  late List<CategoryRow> _categories;
  late List<SubCategoryRow> _subCategories;
  late List<ManufacturerRow> _manufacturers;
  late List<TherapeuticGroupRow> _groups;
  late List<UnitRow> _units;
  late List<SupplierRow> _suppliers;
  late List<ActiveIngredientRow> _activeIngredients;
  late List<IndicationRow> _indications;

  bool _hasExpiry = false;
  bool _isControlled = false;
  bool _lockAutoPrice = false;
  bool _requiresPrescription = false;

  String? _categoryId;
  String? _subCategoryId;
  String? _manufacturerId;
  String? _groupId;
  String? _baseUnitId;
  String? _largeUnitId;
  String _unitsPerLarge = '1';
  late final Set<String> _selectedSupplierIds;
  late final Set<String> _selectedActiveIngredientIds;
  late final Set<String> _selectedIndicationIds;
  bool _partialSaleEnabled = false;
  String? _sellablePartUnitId;

  @override
  void initState() {
    super.initState();
    _initial = widget.initial ?? const ItemDraft(tradeName: '', categoryId: '');
    _categories = [...widget.categories];
    _subCategories = [...widget.subCategories];
    _manufacturers = [...widget.manufacturers];
    _groups = [...widget.groups];
    _units = [...widget.units];
    _suppliers = [...widget.suppliers];
    _activeIngredients = [...widget.activeIngredients];
    _indications = [...widget.indications];
    _selectedSupplierIds = {..._initial.supplierIds};
    _selectedActiveIngredientIds = {..._initial.activeIngredientIds};
    _selectedIndicationIds = {..._initial.indicationIds};
    _hasExpiry = _initial.hasExpiry;
    _isControlled = _initial.isControlledDrug;
    _lockAutoPrice = _initial.lockAutoPriceUpdate;
    _requiresPrescription = _initial.requiresPrescription;
    _categoryId = _initial.categoryId.isEmpty ? null : _initial.categoryId;
    _subCategoryId = _initial.subCategoryId;
    _manufacturerId = _initial.manufacturerId;
    _groupId = _initial.therapeuticGroupId;
    _baseUnitId = _initial.units?.baseUnitId;
    _largeUnitId = _initial.units?.largeUnitId;
    _unitsPerLarge = '${_initial.units?.unitsPerLarge ?? 1}';
    _partialSaleEnabled = _initial.partialSaleEnabled;
    _sellablePartUnitId = _initial.sellablePartUnitId;

    String seed(String key, String value) {
      final c = TextEditingController(text: value);
      _controllers[key] = c;
      return key;
    }

    seed('primaryBarcode', _initial.primaryBarcode ?? '');
    seed('secondaryBarcode', _initial.secondaryBarcode ?? '');
    seed('tradeName', _initial.tradeName);
    seed('tradeNameEn', _initial.tradeNameEn ?? '');
    seed('scientificName', _initial.scientificName ?? '');
    seed('activeIngredient', _initial.activeIngredient ?? '');
    seed('equivalentDrug', _initial.equivalentDrug ?? '');
    seed('pharmaForm', _initial.pharmaForm ?? '');
    seed('dose', _initial.dose ?? '');
    seed('sizeVolume', _initial.sizeVolume ?? '');
    seed('shelfLocation', _initial.shelfLocation ?? '');
    seed('usageInstructions', _initial.usageInstructions ?? '');
    seed('generalNotes', _initial.generalNotes ?? '');
    seed('licenseNumber', _initial.licenseNumber ?? '');
    seed('cost', Money.fromUnits(_initial.costMicros).format());
    seed('discount', _pct(_initial.purchaseDiscountBasisPoints));
    seed('selling', Money.fromUnits(_initial.sellingPriceMicros).format());
    seed('subUnit', Money.fromUnits(_initial.subUnitPriceMicros).format());
    seed('wholesale', Money.fromUnits(_initial.wholesalePriceMicros).format());
    seed('halfWholesale',
        Money.fromUnits(_initial.halfWholesalePriceMicros).format());
    seed('custom1', Money.fromUnits(_initial.customPrice1Micros).format());
    seed('custom2', Money.fromUnits(_initial.customPrice2Micros).format());
    seed('vat', _pct(_initial.vatRateBasisPoints));
    seed('minStock', '${_initial.minimumStockBase}');
    seed('maxStock', '${_initial.maximumStockBase}');
    seed('partsPerFullProduct',
        _initial.partsPerFullProduct != null ? '${_initial.partsPerFullProduct}' : '');
    seed('sellablePartBaseQuantity',
        _initial.sellablePartBaseQuantity != null
            ? '${_initial.sellablePartBaseQuantity}'
            : '');
    seed('partialSaleMarkupBasisPoints',
        _initial.partialSaleMarkupBasisPoints != null
            ? _pct(_initial.partialSaleMarkupBasisPoints!)
            : '');
  }

  static String _pct(int basisPoints) =>
      (basisPoints / 100).toStringAsFixed(basisPoints % 100 == 0 ? 0 : 2);

  int get _defaultMarkupBasisPoints => widget.defaultPartialSaleMarkupBasisPoints;
  String get _defaultMarkupPercent => _pct(_defaultMarkupBasisPoints);

  TextEditingController _c(String key, {String? hint}) {
    final existing = _controllers[key];
    if (existing == null) {
      final c = TextEditingController(text: hint ?? '');
      _controllers[key] = c;
      return c;
    }
    return existing;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  int? _microsFrom(String key) {
    final v = _controllers[key]?.text.trim();
    if (v == null || v.isEmpty) return 0;
    try {
      return Money.parse(v).units;
    } on FormatException {
      return null;
    }
  }

  int? _bpFrom(String key) {
    final v = _controllers[key]?.text.trim();
    if (v == null || v.isEmpty) return 0;
    final d = double.tryParse(v.replaceAll(',', ''));
    if (d == null) return null;
    return (d * 100).round();
  }

  int? _intFrom(String key) {
    final v = _controllers[key]?.text.trim();
    if (v == null || v.isEmpty) return 0;
    return int.tryParse(v);
  }

  bool _validate() {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return false;
    if (_controllers['tradeName']!.text.trim().isEmpty) {
      _snack(l10n.inventoryRequiredName);
      return false;
    }
    if (_categoryId == null) {
      _snack(l10n.inventorySelectCategory);
      return false;
    }
    if (_baseUnitId == null) {
      _snack(l10n.inventorySelectBaseUnit);
      return false;
    }
    if (_largeUnitId == null) {
      _snack(l10n.inventorySelectLargeUnit);
      return false;
    }
    final unitsPerLarge = int.tryParse(_unitsPerLarge) ?? 0;
    if (unitsPerLarge <= 0) {
      _snack(l10n.inventoryUnitsPerLargeInvalid);
      return false;
    }
    if (_partialSaleEnabled) {
      if (_sellablePartUnitId == null) {
        _snack(l10n.partialSaleUnitRequired);
        return false;
      }
      final parts = int.tryParse(_c('partsPerFullProduct').text.trim());
      if (parts == null || parts <= 0) {
        _snack(l10n.partialSalePartsRequired);
        return false;
      }
      if (parts <= 1) {
        _snack(l10n.partialSalePartsInvalid);
        return false;
      }
      final baseQty = int.tryParse(_c('sellablePartBaseQuantity').text.trim());
      if (baseQty == null || baseQty < 1) {
        _snack(l10n.partialSaleBaseInvalid);
        return false;
      }
      final markupText = _c('partialSaleMarkupBasisPoints').text.trim();
      if (markupText.isNotEmpty) {
        final d = double.tryParse(markupText.replaceAll(',', ''));
        if (d == null || d < 0 || d > 100) {
          _snack(l10n.partialSaleMarkupInvalid);
          return false;
        }
      }
    }
    return true;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _submit() {
    if (!_validate()) return;
    final l10n = AppLocalizations.of(context);
    final cost = _microsFrom('cost');
    final discount = _bpFrom('discount');
    final selling = _microsFrom('selling');
    final subUnit = _microsFrom('subUnit');
    final wholesale = _microsFrom('wholesale');
    final halfWholesale = _microsFrom('halfWholesale');
    final custom1 = _microsFrom('custom1');
    final custom2 = _microsFrom('custom2');
    final vat = _bpFrom('vat');
    final minStock = _intFrom('minStock');
    final maxStock = _intFrom('maxStock');
    final unitsPerLarge = int.tryParse(_unitsPerLarge);

    final parts = int.tryParse(_c('partsPerFullProduct').text.trim());
    final baseQty = int.tryParse(_c('sellablePartBaseQuantity').text.trim());
    final markupText = _c('partialSaleMarkupBasisPoints').text.trim();
    final markup = markupText.isEmpty ? _defaultMarkupBasisPoints
        : (double.tryParse(markupText.replaceAll(',', ''))! * 100).round();

    if (cost == null || selling == null || subUnit == null ||
        wholesale == null || halfWholesale == null || custom1 == null ||
        custom2 == null || vat == null || discount == null ||
        minStock == null || maxStock == null || unitsPerLarge == null ||
        unitsPerLarge <= 0) {
      _snack(l10n.authSaveError);
      return;
    }

    final draft = ItemDraft(
      primaryBarcode:
          _emptyToNull(_c('primaryBarcode').text),
      secondaryBarcode:
          _emptyToNull(_c('secondaryBarcode').text),
      tradeName: _c('tradeName').text.trim(),
      tradeNameEn: _emptyToNull(_c('tradeNameEn').text),
      scientificName: _emptyToNull(_c('scientificName').text),
      activeIngredient: _emptyToNull(_c('activeIngredient').text),
      equivalentDrug: _emptyToNull(_c('equivalentDrug').text),
      manufacturerId: _manufacturerId,
      categoryId: _categoryId!,
      subCategoryId: _subCategoryId,
      therapeuticGroupId: _groupId,
      pharmaForm: _emptyToNull(_c('pharmaForm').text),
      dose: _emptyToNull(_c('dose').text),
      sizeVolume: _emptyToNull(_c('sizeVolume').text),
      shelfLocation: _emptyToNull(_c('shelfLocation').text),
      hasExpiry: _hasExpiry,
      isControlledDrug: _isControlled,
      lockAutoPriceUpdate: _lockAutoPrice,
      requiresPrescription: _requiresPrescription,
      costMicros: cost,
      purchaseDiscountBasisPoints: discount,
      sellingPriceMicros: selling,
      subUnitPriceMicros: subUnit,
      wholesalePriceMicros: wholesale,
      halfWholesalePriceMicros: halfWholesale,
      customPrice1Micros: custom1,
      customPrice2Micros: custom2,
      vatRateBasisPoints: vat,
      minimumStockBase: minStock,
      maximumStockBase: maxStock,
      usageInstructions: _emptyToNull(_c('usageInstructions').text),
      generalNotes: _emptyToNull(_c('generalNotes').text),
      licenseNumber: _emptyToNull(_c('licenseNumber').text),
      units: ItemUnitRelation(
        baseUnitId: _baseUnitId!,
        largeUnitId: _largeUnitId!,
        unitsPerLarge: unitsPerLarge,
      ),
      supplierIds: _selectedSupplierIds.toList(),
      activeIngredientIds: _selectedActiveIngredientIds.toList(),
      indicationIds: _selectedIndicationIds.toList(),
      partialSaleEnabled: _partialSaleEnabled,
      sellablePartUnitId: _partialSaleEnabled ? _sellablePartUnitId : null,
      partsPerFullProduct: _partialSaleEnabled ? parts : null,
      sellablePartBaseQuantity: _partialSaleEnabled ? baseQty : null,
      partialSaleMarkupBasisPoints: _partialSaleEnabled ? markup : null,
    );
    Navigator.of(context).pop(ItemFormResult(draft));
  }

  static String? _emptyToNull(String value) {
    final t = value.trim();
    return t.isEmpty ? null : t;
  }

  // ----- inline master-data + supplier creation -----

  Future<void> _addMasterData(MasterDataKind kind) async {
    final l10n = AppLocalizations.of(context);
    final title = switch (kind) {
      MasterDataKind.category => l10n.categoriesAddTitle,
      MasterDataKind.subCategory => l10n.subCategoriesAddTitle,
      MasterDataKind.manufacturer => l10n.manufacturersAdd,
      MasterDataKind.group => l10n.groupsAdd,
      MasterDataKind.unit => l10n.unitsAdd,
      MasterDataKind.activeIngredient => l10n.activeIngredientsAdd,
      MasterDataKind.indication => l10n.indicationsAdd,
    };
    final result = await showMasterDataFormDialog(
      context,
      kind: kind,
      title: title,
      categories: _categories,
    );
    if (result == null || !mounted) return;
    final created = await widget.onCreateMasterData?.call(kind, result.draft);
    if (created == null || !mounted) return;
    setState(() {
      switch (kind) {
        case MasterDataKind.category:
          _categories = [..._categories, created as CategoryRow];
          _categoryId = created.id;
          _subCategoryId = null;
        case MasterDataKind.subCategory:
          _subCategories = [..._subCategories, created as SubCategoryRow];
          _subCategoryId = created.id;
        case MasterDataKind.manufacturer:
          _manufacturers = [..._manufacturers, created as ManufacturerRow];
          _manufacturerId = created.id;
        case MasterDataKind.group:
          _groups = [..._groups, created as TherapeuticGroupRow];
          _groupId = created.id;
        case MasterDataKind.unit:
          _units = [..._units, created as UnitRow];
        case MasterDataKind.activeIngredient:
          _activeIngredients = [..._activeIngredients, created as ActiveIngredientRow];
          _selectedActiveIngredientIds.add(created.id);
        case MasterDataKind.indication:
          _indications = [..._indications, created as IndicationRow];
          _selectedIndicationIds.add(created.id);
      }
    });
  }

  Future<void> _addSupplier() async {
    final l10n = AppLocalizations.of(context);
    final draft = await showSupplierFormDialog(
      context,
      title: l10n.supplierAddTitle,
    );
    if (draft == null || !mounted) return;
    final created = await widget.onCreateSupplier?.call(draft);
    if (created == null || !mounted) return;
    setState(() {
      _suppliers = [..._suppliers, created];
      _selectedSupplierIds.add(created.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 680,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _section('${l10n.itemBarcodePrimary} / ${l10n.itemTradeName}'),
                Wrap(
                  spacing: AppSpacing.m,
                  runSpacing: AppSpacing.m,
                  children: [
                    _text(_c('primaryBarcode'), l10n.itemBarcodePrimary, 220),
                    _text(_c('secondaryBarcode'), l10n.itemSecondaryBarcode, 220),
                    _text(_c('tradeName'), l10n.itemTradeName, 220,
                        required: true),
                    _text(_c('tradeNameEn'), l10n.itemTradeNameEn, 220),
                  ],
                ),
                _section(l10n.itemCategory),
                Wrap(
                  spacing: AppSpacing.m,
                  runSpacing: AppSpacing.m,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  children: [
                    _masterDropdown(
                      value: _categoryId,
                      label: l10n.itemCategory,
                      items: _categories,
                      nameOf: (c) => c.name,
                      onChanged: (v) => setState(() {
                        _categoryId = v;
                        _subCategoryId = null;
                      }),
                      kind: MasterDataKind.category,
                      width: 200,
                    ),
                    _masterDropdown<SubCategoryRow>(
                      value: _subCategoryId,
                      label: l10n.itemSubCategory,
                      items:
                          _subCategories.where((s) => s.categoryId == _categoryId).toList(),
                      nameOf: (s) => s.name,
                      onChanged: (v) => setState(() => _subCategoryId = v),
                      width: 210,
                    ),
                    _masterDropdown(
                      value: _manufacturerId,
                      label: l10n.itemManufacturer,
                      items: _manufacturers,
                      nameOf: (m) => m.name,
                      onChanged: (v) => setState(() => _manufacturerId = v),
                      kind: MasterDataKind.manufacturer,
                      width: 200,
                    ),
                    _masterDropdown(
                      value: _groupId,
                      label: l10n.itemGroup,
                      items: _groups,
                      nameOf: (g) => g.name,
                      onChanged: (v) => setState(() => _groupId = v),
                      kind: MasterDataKind.group,
                      width: 200,
                    ),
                    _text(_c('pharmaForm'), l10n.itemPharmaForm, 140),
                    _text(_c('dose'), l10n.itemDose, 140),
                    _text(_c('sizeVolume'), l10n.itemSizeVolume, 140),
                    _text(_c('shelfLocation'), l10n.itemShelfLocation, 140),
                  ],
                ),
                _section(l10n.itemActiveIngredients),
                Wrap(
                  spacing: AppSpacing.s,
                  runSpacing: AppSpacing.s,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final ingredient in _activeIngredients)
                      FilterChip(
                        label: Text(ingredient.name,
                            overflow: TextOverflow.ellipsis),
                        visualDensity: VisualDensity.compact,
                        selected: _selectedActiveIngredientIds
                            .contains(ingredient.id),
                        onSelected: (on) => setState(() {
                          if (on) {
                            _selectedActiveIngredientIds.add(ingredient.id);
                          } else {
                            _selectedActiveIngredientIds
                                .remove(ingredient.id);
                          }
                        }),
                      ),
                    if (widget.onCreateMasterData != null)
                      _addButton(
                          AppLocalizations.of(context).itemAddNew,
                          () => _addMasterData(
                              MasterDataKind.activeIngredient)),
                  ],
                ),
                _section(l10n.itemIndications),
                Wrap(
                  spacing: AppSpacing.s,
                  runSpacing: AppSpacing.s,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final indication in _indications)
                      FilterChip(
                        label: Text(indication.name,
                            overflow: TextOverflow.ellipsis),
                        visualDensity: VisualDensity.compact,
                        selected:
                            _selectedIndicationIds.contains(indication.id),
                        onSelected: (on) => setState(() {
                          if (on) {
                            _selectedIndicationIds.add(indication.id);
                          } else {
                            _selectedIndicationIds.remove(indication.id);
                          }
                        }),
                      ),
                    if (widget.onCreateMasterData != null)
                      _addButton(
                          AppLocalizations.of(context).itemAddNew,
                          () =>
                              _addMasterData(MasterDataKind.indication)),
                  ],
                ),
                _section(l10n.itemSuppliers),
                Wrap(
                  spacing: AppSpacing.s,
                  runSpacing: AppSpacing.s,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final supplier in _suppliers)
                      FilterChip(
                        label: Text(supplier.name,
                            overflow: TextOverflow.ellipsis),
                        visualDensity: VisualDensity.compact,
                        selected: _selectedSupplierIds.contains(supplier.id),
                        onSelected: (on) => setState(() {
                          if (on) {
                            _selectedSupplierIds.add(supplier.id);
                          } else {
                            _selectedSupplierIds.remove(supplier.id);
                          }
                        }),
                      ),
                    if (widget.onCreateSupplier != null)
                      _addButton(l10n.itemAddNew, _addSupplier),
                  ],
                ),
                _section(l10n.itemUnitsRelation),
                Wrap(
                  spacing: AppSpacing.m,
                  runSpacing: AppSpacing.m,
                  children: [
                    _unitDropdown(
                      value: _baseUnitId,
                      label: l10n.itemBaseUnit,
                      onChanged: (v) => setState(() {
                        _baseUnitId = v;
                        if (v != null) _largeUnitId ??= v;
                      }),
                      width: 200,
                    ),
                    _unitDropdown(
                      value: _largeUnitId,
                      label: l10n.itemPackagingUnit,
                      onChanged: (v) => setState(() => _largeUnitId = v),
                      width: 220,
                    ),
                    SizedBox(
                      width: 160,
                      child: TextFormField(
                        controller: _c('unitsPerLarge', hint: '1'),
                        decoration: InputDecoration(
                          labelText: l10n.itemUnitsPerLarge,
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _unitsPerLarge = v.trim(),
                      ),
                    ),
                  ],
                ),
                _section('${l10n.itemCost} / ${l10n.itemPrice}'),
                Wrap(
                  spacing: AppSpacing.m,
                  runSpacing: AppSpacing.m,
                  children: [
                    _text(_c('cost'), l10n.itemCost, 160),
                    _text(_c('discount'), l10n.itemPurchaseDiscount, 160),
                    _text(_c('selling'), l10n.itemPrice, 150),
                    _text(_c('subUnit'), l10n.itemSubUnitPrice, 150),
                    _text(_c('wholesale'), l10n.itemWholesalePrice, 150),
                    _text(_c('halfWholesale'), l10n.itemHalfWholesalePrice, 150),
                    _text(_c('custom1'), l10n.itemCustomPrice1, 140),
                    _text(_c('custom2'), l10n.itemCustomPrice2, 140),
                    _text(_c('vat'), l10n.itemVatRate, 140),
                  ],
                ),
                _section(l10n.partialSaleSection),
                Wrap(
                  spacing: AppSpacing.m,
                  runSpacing: AppSpacing.m,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _switch('partialSaleEnabled', l10n.partialSaleEnabled,
                        _partialSaleEnabled, (v) => setState(() {
                      _partialSaleEnabled = v;
                      if (v && _c('partialSaleMarkupBasisPoints').text.isEmpty) {
                        _c('partialSaleMarkupBasisPoints').text =
                            _defaultMarkupPercent;
                      }
                    })),
                    if (_partialSaleEnabled) ...[
                      _unitDropdown(
                        value: _sellablePartUnitId,
                        label: l10n.partialSaleSellablePart,
                        onChanged: (v) =>
                            setState(() => _sellablePartUnitId = v),
                        width: 200,
                      ),
                      _text(
                          _c('partsPerFullProduct'), l10n.partialSalePartsPerFull,
                          180),
                      _text(
                          _c('sellablePartBaseQuantity'),
                          l10n.partialSaleBaseQuantity,
                          180),
                      _text(
                          _c('partialSaleMarkupBasisPoints'),
                          l10n.partialSaleMarkupPercent,
                          180),
                    ],
                  ],
                ),
                _section(l10n.itemStock),
                Wrap(
                  spacing: AppSpacing.m,
                  runSpacing: AppSpacing.m,
                  children: [
                    _text(_c('minStock'), l10n.itemMinimumStock, 180),
                    _text(_c('maxStock'), l10n.itemMaximumStock, 180),
                  ],
                ),
                _section(''),
                Wrap(
                  spacing: AppSpacing.l,
                  runSpacing: AppSpacing.s,
                  children: [
                    _switch('hasExpiry', l10n.itemHasExpiry, _hasExpiry, (v) =>
                        setState(() => _hasExpiry = v)),
                    _switch('isControlled', l10n.itemIsControlled,
                        _isControlled, (v) => setState(() => _isControlled = v)),
                    _switch('lockAutoPrice', l10n.itemLockPriceAutoUpdate,
                        _lockAutoPrice, (v) => setState(() => _lockAutoPrice = v)),
                    _switch('requiresPrescription', l10n.itemRequiresPrescription,
                        _requiresPrescription,
                        (v) => setState(() => _requiresPrescription = v)),
                  ],
                ),
                _section(l10n.itemScientificName),
                Wrap(
                  spacing: AppSpacing.m,
                  runSpacing: AppSpacing.m,
                  children: [
                    _text(_c('scientificName'), l10n.itemScientificName, 250),
                    _text(_c('activeIngredient'), l10n.itemActiveIngredient, 250),
                    _text(_c('equivalentDrug'), l10n.itemEquivalentDrug, 250),
                  ],
                ),
                _section(l10n.itemUsageInstructions),
                Wrap(
                  spacing: AppSpacing.m,
                  runSpacing: AppSpacing.m,
                  children: [
                    _text(_c('usageInstructions'), l10n.itemUsageInstructions, 300),
                    _text(_c('generalNotes'), l10n.itemGeneralNotes, 300),
                    _text(_c('licenseNumber'), l10n.itemLicenseNumber, 220),
                  ],
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

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.l, bottom: AppSpacing.s),
        child: Text(
          title,
          style: context.appTypography.sectionTitle,
        ),
      );

  Widget _text(
    TextEditingController controller,
    String label,
    double width, {
    bool required = false,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          isDense: true,
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty)
                ? AppLocalizations.of(context).inventoryRequiredName
                : null
            : null,
      ),
    );
  }

  /// Searchable master-data dropdown with an inline "+" create button.
  Widget _masterDropdown<T>({
    required String? value,
    required String label,
    required List<T> items,
    required String Function(T) nameOf,
    ValueChanged<String?>? onChanged,
    MasterDataKind? kind,
    double width = 220,
  }) {
    String idOf(T item) => (item as dynamic).id as String;
    final field = SearchableDropdownField<T>(
      value: value,
      items: items,
      idOf: idOf,
      nameOf: nameOf,
      onChanged: onChanged,
      label: label,
      width: width,
    );
    if (kind == null || widget.onCreateMasterData == null) return field;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field,
        _addButton(
          AppLocalizations.of(context).itemAddNew,
          () => _addMasterData(kind),
          compact: true,
        ),
      ],
    );
  }

  /// Unit dropdown reused by base unit, packaging (large) and sellable-part
  /// fields; all three share the same inline "+" create flow.
  Widget _unitDropdown({
    required String? value,
    required String label,
    ValueChanged<String?>? onChanged,
    double width = 200,
  }) {
    return _masterDropdown<UnitRow>(
      value: value,
      label: label,
      items: _units,
      nameOf: (u) => u.name,
      onChanged: onChanged,
      kind: MasterDataKind.unit,
      width: width,
    );
  }

  Widget _addButton(String tooltip, VoidCallback onPressed,
      {bool compact = false}) {
    return IconButton(
      icon: const Icon(Icons.add_circle_outline),
      tooltip: tooltip,
      iconSize: 20,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      onPressed: onPressed,
    );
  }

  Widget _switch(
    String key,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(value: value, onChanged: onChanged),
        Text(label, style: context.appTypography.label),
      ],
    );
  }
}