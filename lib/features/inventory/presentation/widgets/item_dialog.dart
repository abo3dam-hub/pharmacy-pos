import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../../../core/money/money.dart';
import '../../../../core/scanning/scan_barcode_button.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/compact_form.dart';
import '../../../../core/units/package_cost.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../../core/widgets/searchable_multi_select_field.dart';
import '../../../../domain/services/partial_price_calculator.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/database/app_database.dart';
import '../../../suppliers/domain/repositories/supplier_repository.dart';
import '../../../suppliers/presentation/widgets/supplier_dialog.dart';
import '../../domain/repositories/inventory_repository.dart';
import 'master_data_dialog.dart';

/// What the user chose in the item form: plain save, or save and jump to the
/// new item's batch (تشغيلة) ledger.
enum ItemFormAction { save, saveContinue }

/// Result of the item form: the validated [ItemDraft] plus the chosen
/// [ItemFormAction].
class ItemFormResult {
  const ItemFormResult(this.draft, {this.action = ItemFormAction.save});

  final ItemDraft draft;
  final ItemFormAction action;
}

/// Shows the §5 item create/edit form dialog. Returns a validated draft or
/// null if cancelled. Money is entered as decimal and stored in integer
/// micro-units; percentages are integer basis points. Master-data + supplier
/// creates are performed via [onCreateMasterData] / [onCreateSupplier] so the
/// dialog stays widget-testable while the caller owns persisting and audit.
///
/// Phase 17 product-master design lock:
///   • التعبئة التجارية / الأجزاء / عدد الأجزاء replace the old unit-relation
///     labels; the sellable part is expressed through the parts unit only (the
///     legacy "sellable part unit" picker is gone).
///   • سعر بيع الجزء is either auto-derived from the approved formula or an
///     explicit pharmacist override ([ItemDraft.partialSalePriceMicros]);
///     manual mode persists until "استعادة الحساب التلقائي" is tapped.
///   • Active ingredients carry an optional العيار (strength) each.
Future<ItemFormResult?> showItemFormDialog(
  BuildContext context, {
  required String title,
  ItemDraft? initial,
  required List<CategoryRow> categories,
  required List<ManufacturerRow> manufacturers,
  required List<UnitRow> units,
  List<SupplierRow> suppliers = const [],
  List<ActiveIngredientRow> activeIngredients = const [],
  List<IndicationRow> indications = const [],
  Future<Object?> Function(MasterDataKind kind, MasterDataDraft draft)?
  onCreateMasterData,
  Future<SupplierRow?> Function(SupplierDraft draft)? onCreateSupplier,
  int defaultPartialSaleMarkupBasisPoints = 2000,
  bool showContinueAction = false,
}) async {
  final result = await showDialog<ItemFormResult>(
    context: context,
    builder: (_) => _ItemFormDialog(
      title: title,
      initial: initial,
      categories: categories,
      manufacturers: manufacturers,
      units: units,
      suppliers: suppliers,
      activeIngredients: activeIngredients,
      indications: indications,
      onCreateMasterData: onCreateMasterData,
      onCreateSupplier: onCreateSupplier,
      defaultPartialSaleMarkupBasisPoints: defaultPartialSaleMarkupBasisPoints,
      showContinueAction: showContinueAction,
    ),
  );
  return result;
}

class _ItemFormDialog extends StatefulWidget {
  const _ItemFormDialog({
    required this.title,
    this.initial,
    required this.categories,
    required this.manufacturers,
    required this.units,
    this.suppliers = const [],
    this.activeIngredients = const [],
    this.indications = const [],
    this.onCreateMasterData,
    this.onCreateSupplier,
    this.defaultPartialSaleMarkupBasisPoints = 2000,
    this.showContinueAction = false,
  });

  final String title;
  final ItemDraft? initial;
  final List<CategoryRow> categories;
  final List<ManufacturerRow> manufacturers;
  final List<UnitRow> units;
  final List<SupplierRow> suppliers;
  final List<ActiveIngredientRow> activeIngredients;
  final List<IndicationRow> indications;
  final Future<Object?> Function(MasterDataKind kind, MasterDataDraft draft)?
  onCreateMasterData;
  final Future<SupplierRow?> Function(SupplierDraft draft)? onCreateSupplier;
  final int defaultPartialSaleMarkupBasisPoints;

  /// Whether to show the "حفظ و اضافة الى المخزون" (save-and-continue to the
  /// batch entry) action. Only meaningful for create (edit keeps one action).
  final bool showContinueAction;

  @override
  State<_ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends State<_ItemFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final ItemDraft _initial;

  final _controllers = <String, TextEditingController>{};
  final _strengthControllers = <String, TextEditingController>{};

  late List<CategoryRow> _categories;
  late List<ManufacturerRow> _manufacturers;
  late List<UnitRow> _units;
  late List<SupplierRow> _suppliers;
  late List<ActiveIngredientRow> _activeIngredients;
  late List<IndicationRow> _indications;

  bool _hasExpiry = false;
  bool _isControlled = false;
  bool _lockAutoPrice = false;
  bool _requiresPrescription = false;

  String? _categoryId;
  String? _manufacturerId;
  String? _partUnitId;
  String? _largeUnitId;
  String _partsCount = '1';
  late final Set<String> _selectedSupplierIds;
  late final Set<String> _selectedActiveIngredientIds;
  late final Set<String> _selectedIndicationIds;
  bool _partialSaleEnabled = false;
  bool _partPriceManual = false;

  /// Legacy per-part base factor preserved across edits; always 1 for new
  /// items so one part == one base unit (Phase 17 normalization).
  int _sellablePartBaseQuantity = 1;

  @override
  void initState() {
    super.initState();
    _initial = widget.initial ?? const ItemDraft(tradeName: '', categoryId: '');
    _categories = [...widget.categories];
    _manufacturers = [...widget.manufacturers];
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
    _categoryId = (_initial.categoryId == null || _initial.categoryId!.isEmpty)
        ? null
        : _initial.categoryId;
    _manufacturerId = _initial.manufacturerId;
    _partUnitId = _initial.units?.baseUnitId;
    _largeUnitId = _initial.units?.largeUnitId;
    final unitsPerLarge = _initial.units?.unitsPerLarge ?? 1;
    _partsCount =
        '${_initial.partialSaleEnabled ? (_initial.partsPerFullProduct ?? unitsPerLarge) : unitsPerLarge}';
    _sellablePartBaseQuantity = _initial.sellablePartBaseQuantity ?? 1;
    _partialSaleEnabled = _initial.partialSaleEnabled;
    _partPriceManual = _initial.partialSalePriceMicros != null;

    String seed(String key, String value) {
      final c = TextEditingController(text: value);
      _controllers[key] = c;
      return key;
    }

    // The visible "units per large" field must reflect the stored value when
    // editing — it was previously created lazily with hint '1', so every edit
    // showed 1 regardless of the real configuration.
    seed('unitsPerLarge', _partsCount);

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
    // The cost field is entered per commercial package (the pharmacist's
    // unit); costMicros is stored per base unit, so seed the package-scale
    // value here (converted back to per-base on save).
    seed(
      'cost',
      Money.fromUnits(
        baseUnitCostToPackageCost(
          _initial.costMicros,
          _initial.units?.unitsPerLarge ?? 1,
        ),
      ).format(),
    );
    seed('discount', _pct(_initial.purchaseDiscountBasisPoints));
    seed('selling', Money.fromUnits(_initial.sellingPriceMicros).format());
    seed('wholesale', Money.fromUnits(_initial.wholesalePriceMicros).format());
    seed(
      'halfWholesale',
      Money.fromUnits(_initial.halfWholesalePriceMicros).format(),
    );
    seed('custom1', Money.fromUnits(_initial.customPrice1Micros).format());
    seed('custom2', Money.fromUnits(_initial.customPrice2Micros).format());
    seed('vat', _pct(_initial.vatRateBasisPoints));
    seed('minStock', '${_initial.minimumStockBase}');
    seed('maxStock', '${_initial.maximumStockBase}');
    seed(
      'partialSaleMarkupBasisPoints',
      _initial.partialSaleMarkupBasisPoints != null
          ? _pct(_initial.partialSaleMarkupBasisPoints!)
          : _defaultMarkupPercent,
    );
    final partPriceText = _initial.partialSalePriceMicros != null
        ? Money.fromUnits(_initial.partialSalePriceMicros!).format()
        : '';
    seed('partialSalePartPrice', partPriceText);
  }

  static String _pct(int basisPoints) =>
      (basisPoints / 100).toStringAsFixed(basisPoints % 100 == 0 ? 0 : 2);

  int get _defaultMarkupBasisPoints =>
      widget.defaultPartialSaleMarkupBasisPoints;
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

  TextEditingController _strengthController(
    String ingredientId,
    String initial,
  ) {
    final existing = _strengthControllers[ingredientId];
    if (existing != null) return existing;
    final c = TextEditingController(text: initial);
    _strengthControllers[ingredientId] = c;
    return c;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final c in _strengthControllers.values) {
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
    final parts = int.tryParse(_partsCount) ?? 0;
    if (_partUnitId != null && parts <= 0) {
      _snack(l10n.inventoryUnitsPerLargeInvalid);
      return false;
    }
    if (_partialSaleEnabled) {
      if (_partUnitId == null) {
        _snack(l10n.inventorySelectBaseUnit);
        return false;
      }
      if (parts <= 1) {
        _snack(l10n.partialSalePartsInvalid);
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
      if (_partPriceManual && _c('partialSalePartPrice').text.isNotEmpty) {
        if (_microsFrom('partialSalePartPrice') == null) {
          _snack(l10n.partialSalePartPriceInvalid);
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

  void _submit([ItemFormAction action = ItemFormAction.save]) {
    if (!_validate()) return;
    final l10n = AppLocalizations.of(context);
    final cost = _microsFrom('cost');
    final discount = _bpFrom('discount');
    final selling = _microsFrom('selling');
    final wholesale = _microsFrom('wholesale');
    final halfWholesale = _microsFrom('halfWholesale');
    final custom1 = _microsFrom('custom1');
    final custom2 = _microsFrom('custom2');
    final vat = _bpFrom('vat');
    final minStock = _intFrom('minStock');
    final maxStock = _intFrom('maxStock');

    final parts = int.tryParse(_partsCount) ?? 0;
    final markupText = _c('partialSaleMarkupBasisPoints').text.trim();
    final markup = markupText.isEmpty
        ? _defaultMarkupBasisPoints
        : (double.tryParse(markupText.replaceAll(',', ''))! * 100).round();

    if (cost == null ||
        selling == null ||
        wholesale == null ||
        halfWholesale == null ||
        custom1 == null ||
        custom2 == null ||
        vat == null ||
        discount == null ||
        minStock == null ||
        maxStock == null) {
      _snack(l10n.authSaveError);
      return;
    }

    final partPrice = _microsFrom('partialSalePartPrice');
    final manualPrice =
        _partialSaleEnabled &&
        _partPriceManual &&
        _c('partialSalePartPrice').text.trim().isNotEmpty;
    if (_partialSaleEnabled && manualPrice && partPrice == null) {
      _snack(l10n.partialSalePartPriceInvalid);
      return;
    }

    // Unit relation keeps the legacy invariant unitsPerLarge == parts ×
    // per-part base factor; the factor is preserved for pre-Phase-17 data.
    final normalisedParts = parts;
    final unitsPerLarge = normalisedParts * _sellablePartBaseQuantity;

    final draft = ItemDraft(
      primaryBarcode: _emptyToNull(_c('primaryBarcode').text),
      secondaryBarcode: _emptyToNull(_c('secondaryBarcode').text),
      tradeName: _c('tradeName').text.trim(),
      tradeNameEn: _emptyToNull(_c('tradeNameEn').text),
      scientificName: _emptyToNull(_c('scientificName').text),
      activeIngredient:
          _selectedActiveIngredientIds.isEmpty &&
              _initial.activeIngredientIds.isNotEmpty
          ? null
          : _emptyToNull(_c('activeIngredient').text),
      equivalentDrug: _emptyToNull(_c('equivalentDrug').text),
      manufacturerId: _manufacturerId,
      categoryId: _categoryId,
      pharmaForm: _emptyToNull(_c('pharmaForm').text),
      dose: _emptyToNull(_c('dose').text),
      sizeVolume: _emptyToNull(_c('sizeVolume').text),
      shelfLocation: _emptyToNull(_c('shelfLocation').text),
      hasExpiry: _hasExpiry,
      isControlledDrug: _isControlled,
      lockAutoPriceUpdate: _lockAutoPrice,
      requiresPrescription: _requiresPrescription,
      // The cost field is entered per commercial package (the pharmacist's
      // unit); storage and COGS are per base unit, so convert here (half-up).
      // E.g. a package cost of 11,000 with 3 parts stores ≈3,666.667 per part.
      costMicros: packageCostToBaseUnitCost(cost, unitsPerLarge),
      purchaseDiscountBasisPoints: discount,
      sellingPriceMicros: selling,
      subUnitPriceMicros: _initial.subUnitPriceMicros,
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
      units: (_partUnitId != null && _largeUnitId != null)
          ? ItemUnitRelation(
              baseUnitId: _partUnitId!,
              largeUnitId: _largeUnitId!,
              unitsPerLarge: unitsPerLarge,
            )
          : null,
      supplierIds: _selectedSupplierIds.toList(),
      activeIngredientIds: _selectedActiveIngredientIds.toList(),
      activeIngredientStrengths: {
        for (final id in _selectedActiveIngredientIds)
          if (_strengthControllers[id]?.text.trim().isNotEmpty ?? false)
            id: _strengthControllers[id]!.text.trim(),
      },
      indicationIds: _selectedIndicationIds.toList(),
      partialSaleEnabled: _partialSaleEnabled,
      sellablePartUnitId: _partialSaleEnabled ? _partUnitId : null,
      partsPerFullProduct: _partialSaleEnabled ? parts : null,
      sellablePartBaseQuantity: _partialSaleEnabled
          ? _sellablePartBaseQuantity
          : null,
      partialSaleMarkupBasisPoints: _partialSaleEnabled ? markup : null,
      partialSalePriceMicros: _partialSaleEnabled && manualPrice
          ? partPrice
          : null,
    );
    Navigator.of(context).pop(ItemFormResult(draft, action: action));
  }

  static String? _emptyToNull(String value) {
    final t = value.trim();
    return t.isEmpty ? null : t;
  }

  String _ingredientName(String id) {
    for (final i in _activeIngredients) {
      if (i.id == id) return i.name;
    }
    return id;
  }

  // ----- inline master-data + supplier creation -----

  Future<void> _addMasterData(MasterDataKind kind) async {
    final l10n = AppLocalizations.of(context);
    final title = switch (kind) {
      MasterDataKind.category => l10n.categoriesAddTitle,
      MasterDataKind.manufacturer => l10n.manufacturersAdd,
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
        case MasterDataKind.manufacturer:
          _manufacturers = [..._manufacturers, created as ManufacturerRow];
          _manufacturerId = created.id;
        case MasterDataKind.unit:
          _units = [..._units, created as UnitRow];
        case MasterDataKind.activeIngredient:
          _activeIngredients = [
            ..._activeIngredients,
            created as ActiveIngredientRow,
          ];
          _selectedActiveIngredientIds.add(created.id);
        case MasterDataKind.indication:
          _indications = [..._indications, created as IndicationRow];
          _selectedIndicationIds.add(created.id);
      }
    });
  }

  /// Creates a master-data row with [name] prefilled (used by the
  /// searchable multi-select "add new" row). Returns the created row, or null
  /// if the user cancelled.
  Future<Object?> _addMasterDataWithName(
    MasterDataKind kind,
    String name,
  ) async {
    final l10n = AppLocalizations.of(context);
    final title = switch (kind) {
      MasterDataKind.category => l10n.categoriesAddTitle,
      MasterDataKind.manufacturer => l10n.manufacturersAdd,
      MasterDataKind.unit => l10n.unitsAdd,
      MasterDataKind.activeIngredient => l10n.activeIngredientsAdd,
      MasterDataKind.indication => l10n.indicationsAdd,
    };
    final result = await showMasterDataFormDialog(
      context,
      kind: kind,
      title: title,
      categories: _categories,
      initial: MasterDataDraft(name: name),
    );
    if (result == null || !mounted) return null;
    final created = await widget.onCreateMasterData?.call(kind, result.draft);
    if (created == null || !mounted) return null;
    setState(() {
      switch (kind) {
        case MasterDataKind.category:
          _categories = [..._categories, created as CategoryRow];
        case MasterDataKind.manufacturer:
          _manufacturers = [..._manufacturers, created as ManufacturerRow];
        case MasterDataKind.unit:
          _units = [..._units, created as UnitRow];
        case MasterDataKind.activeIngredient:
          _activeIngredients = [
            ..._activeIngredients,
            created as ActiveIngredientRow,
          ];
        case MasterDataKind.indication:
          _indications = [..._indications, created as IndicationRow];
      }
    });
    return created;
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

  // ----- partial part-price auto/manual handling -----

  void _recomputePartPrice() {
    if (!_partialSaleEnabled || _partPriceManual) return;
    final selling = _microsFrom('selling');
    final parts = int.tryParse(_partsCount) ?? 0;
    if (selling == null || parts <= 1) return;
    final markupText = _c('partialSaleMarkupBasisPoints').text.trim();
    final markup = markupText.isEmpty
        ? _defaultMarkupBasisPoints
        : ((double.tryParse(markupText.replaceAll(',', '')) ?? 0) * 100)
              .round();
    if (markup < 0) return;
    final auto = PartialPriceCalculator().calculatePartialPrice(
      sellingPriceMicros: selling,
      partsPerFullProduct: parts,
      markupBasisPoints: markup,
    );
    _c('partialSalePartPrice').text = Money.fromUnits(auto).format();
  }

  void _restoreAutoPartPrice() {
    setState(() {
      _partPriceManual = false;
      _recomputePartPrice();
    });
  }

  bool _quickMode = true;

  /// Quick / detailed entry toggle. Quick is the default: the pharmacist
  /// sees only what a new item needs 90% of the time; one tap reveals the
  /// full master-data form. No feature is removed.
  Widget _modeToggle(AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.s),
    child: Row(
      children: [
        const Icon(Icons.bolt_outlined, size: 18),
        const SizedBox(width: AppSpacing.s),
        // Expanded so the toggle never overflows narrow screens; the
        // segment icons are dropped when space is tight.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 340;
              return SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: true,
                    label: Text(l10n.itemQuickEntry),
                    icon: compact
                        ? null
                        : const Icon(Icons.flash_on_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text(l10n.itemDetailedEntry),
                    icon: compact
                        ? null
                        : const Icon(Icons.tune_outlined, size: 16),
                  ),
                ],
                selected: {_quickMode},
                onSelectionChanged: (s) =>
                    setState(() => _quickMode = s.first),
                style:
                    const ButtonStyle(visualDensity: VisualDensity.compact),
              );
            },
          ),
        ),
      ],
    ),
  );

  /// Essentials for the 90% case: identity, classification, units,
  /// partial-sale and the two prices that matter. Everything else lives in
  /// the detailed tabs ([_basicTab], [_ingredientsTab], [_pricingTab],
  /// [_notesTab]). Nothing is removed — only hidden until needed.
  List<Widget> _quickSections(AppLocalizations l10n) => [
    CompactSection('${l10n.itemBarcodePrimary} / ${l10n.itemTradeName}'),
    FormGrid(
      children: [
        _text(
          _c('primaryBarcode'),
          l10n.itemBarcodePrimary,
          suffixIcon: _scanButton('primaryBarcode'),
        ),
        _text(
          _c('secondaryBarcode'),
          l10n.itemSecondaryBarcode,
          suffixIcon: _scanButton('secondaryBarcode'),
        ),
        _text(_c('tradeName'), l10n.itemTradeName, required: true),
        _text(_c('tradeNameEn'), l10n.itemTradeNameEn),
      ],
    ),
    CompactSection(l10n.itemClassificationSection),
    FormGrid(
      children: [
        _masterDropdown(
          value: _categoryId,
          label: l10n.itemCategory,
          items: _categories,
          nameOf: (c) => c.name,
          onChanged: (v) => setState(() => _categoryId = v),
          kind: MasterDataKind.category,
        ),
        _masterDropdown(
          value: _manufacturerId,
          label: l10n.itemManufacturer,
          items: _manufacturers,
          nameOf: (m) => m.name,
          onChanged: (v) => setState(() => _manufacturerId = v),
          kind: MasterDataKind.manufacturer,
        ),
        _text(_c('pharmaForm'), l10n.itemPharmaForm),
      ],
    ),
    CompactSection(l10n.itemPricePartsSection),
    FormGrid(
      children: [
        _unitDropdown(
          value: _largeUnitId,
          label: l10n.itemPackagingUnit,
          onChanged: (v) => setState(() => _largeUnitId = v),
        ),
        _unitDropdown(
          value: _partUnitId,
          label: l10n.itemBaseUnit,
          onChanged: (v) => setState(() {
            _partUnitId = v;
            if (v != null) _largeUnitId ??= v;
          }),
        ),
        TextFormField(
          controller: _c('unitsPerLarge', hint: '1'),
          decoration: InputDecoration(
            labelText: l10n.itemUnitsPerLarge,
            isDense: true,
          ),
          keyboardType: TextInputType.number,
          onChanged: (v) {
            setState(() {
              _partsCount = v.trim();
              _recomputePartPrice();
            });
          },
        ),
      ],
    ),
    FormGrid(
      children: [
        _switch(
          'partialSaleEnabled',
          l10n.partialSaleEnabled,
          _partialSaleEnabled,
          (v) => setState(() {
            _partialSaleEnabled = v;
            if (v) {
              if (_c('partialSaleMarkupBasisPoints').text.isEmpty) {
                _c('partialSaleMarkupBasisPoints').text = _defaultMarkupPercent;
              }
              if (_c('partialSalePartPrice').text.isEmpty) {
                _recomputePartPrice();
              }
            }
          }),
        ),
        if (_partialSaleEnabled) ...[
          _text(
            _c('partialSaleMarkupBasisPoints'),
            l10n.partialSaleMarkupPercent,
            onChanged: (_) => _recomputePartPrice(),
          ),
          _text(
            _c('partialSalePartPrice'),
            l10n.partialSalePartPrice,
            onChanged: (v) {
              if (v.trim().isNotEmpty) {
                _partPriceManual = true;
              }
            },
          ),
          TextButton.icon(
            onPressed: _restoreAutoPartPrice,
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: Text(l10n.partialSaleRestoreAuto),
          ),
        ],
      ],
    ),
    FormGrid(
      children: [
        _text(
          _c('cost'),
          _costLabel(l10n),
          onChanged: (_) => _recomputePartPrice(),
        ),
        _text(
          _c('selling'),
          l10n.itemPrice,
          onChanged: (_) => _recomputePartPrice(),
        ),
      ],
    ),

    CompactSection(l10n.itemHasExpiry),
    FormGrid(
      children: [
        _switch(
          'hasExpiry',
          l10n.itemHasExpiry,
          _hasExpiry,
          (v) => setState(() => _hasExpiry = v),
        ),
      ],
    ),
  ];

  /// Every field, in the documented Phase 17 order. Shown in "detailed"
  /// mode; the quick mode above is just a subset of this.
  /// Tab 1/4 — fits without scrolling (see [_buildFullForm]).
  List<Widget> _basicTab(AppLocalizations l10n) => [
    CompactSection('${l10n.itemBarcodePrimary} / ${l10n.itemTradeName}'),
    FormGrid(
      children: [
        _text(
          _c('primaryBarcode'),
          l10n.itemBarcodePrimary,
          suffixIcon: _scanButton('primaryBarcode'),
        ),
        _text(
          _c('secondaryBarcode'),
          l10n.itemSecondaryBarcode,
          suffixIcon: _scanButton('secondaryBarcode'),
        ),
        _text(_c('tradeName'), l10n.itemTradeName, required: true),
        _text(_c('tradeNameEn'), l10n.itemTradeNameEn),
      ],
    ),
    CompactSection(l10n.itemClassificationSection),
    FormGrid(
      children: [
        _masterDropdown(
          value: _categoryId,
          label: l10n.itemCategory,
          items: _categories,
          nameOf: (c) => c.name,
          onChanged: (v) => setState(() => _categoryId = v),
          kind: MasterDataKind.category,
        ),
        _masterDropdown(
          value: _manufacturerId,
          label: l10n.itemManufacturer,
          items: _manufacturers,
          nameOf: (m) => m.name,
          onChanged: (v) => setState(() => _manufacturerId = v),
          kind: MasterDataKind.manufacturer,
        ),
      ],
    ),
    CompactSection(l10n.itemScientificName),
    FormGrid(
      children: [
        _text(_c('scientificName'), l10n.itemScientificName),
        _text(_c('equivalentDrug'), l10n.itemEquivalentDrug),
      ],
    ),
    CompactSection(l10n.itemPharmaForm),
    FormGrid(
      children: [
        _text(_c('dose'), l10n.itemDose),
        _text(_c('sizeVolume'), l10n.itemSizeVolume),
        _text(_c('shelfLocation'), l10n.itemShelfLocation),
      ],
    ),
  ];

  /// Tab 2/4.
  List<Widget> _ingredientsTab(AppLocalizations l10n) => [
    // Searchable multi-select dropdown: long master lists no longer render
    // every option as chips inside the dialog.
    CompactSection('${l10n.itemIndications} (${_selectedIndicationIds.length})'),
    SearchableMultiSelectField<IndicationRow>(
      selectedIds: _selectedIndicationIds,
      items: _indications,
      idOf: (i) => i.id,
      nameOf: (i) => i.name,
      onChanged: (next) => setState(() {
        _selectedIndicationIds
          ..clear()
          ..addAll(next);
      }),
      onAddNew: widget.onCreateMasterData == null
          ? null
          : (name) async {
              final created =
                  await _addMasterDataWithName(MasterDataKind.indication, name);
              return created as IndicationRow?;
            },
      addNewLabel: l10n.itemAddNew,
      searchHint: l10n.itemIndications,
    ),
    CompactSection(
        '${l10n.itemActiveIngredients} (${_selectedActiveIngredientIds.length})'),
    SearchableMultiSelectField<ActiveIngredientRow>(
      selectedIds: _selectedActiveIngredientIds,
      items: _activeIngredients,
      idOf: (i) => i.id,
      nameOf: (i) => i.name,
      onChanged: (next) => setState(() {
        // Drop strength controllers for deselected ingredients.
        for (final removed
            in _selectedActiveIngredientIds.difference(next)) {
          _strengthControllers.remove(removed)?.dispose();
        }
        _selectedActiveIngredientIds
          ..clear()
          ..addAll(next);
      }),
      onAddNew: widget.onCreateMasterData == null
          ? null
          : (name) async {
              final created = await _addMasterDataWithName(
                MasterDataKind.activeIngredient,
                name,
              );
              return created as ActiveIngredientRow?;
            },
      addNewLabel: l10n.itemAddNew,
      searchHint: l10n.itemActiveIngredientsSearch,
    ),
    const SizedBox(height: AppSpacing.xs),
    if (_selectedActiveIngredientIds.isEmpty)
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(
          l10n.itemActiveIngredientsHint,
          style: context.appTypography.labelSmall,
        ),
      ),
    for (final id in _selectedActiveIngredientIds.toList())
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 18),
              visualDensity: VisualDensity.compact,
              tooltip: l10n.itemActiveIngredientsRemove,
              onPressed: () => setState(() {
                _selectedActiveIngredientIds.remove(id);
                _strengthControllers.remove(id)?.dispose();
              }),
            ),
            Expanded(
              flex: 3,
              child: Text(
                _ingredientName(id),
                overflow: TextOverflow.ellipsis,
                style: context.appTypography.label,
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _strengthController(
                  id,
                  _initial.activeIngredientStrengths[id] ?? '',
                ),
                decoration: InputDecoration(
                  labelText: l10n.activeIngredientStrength,
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
    CompactSection('${l10n.itemSuppliers} (${_selectedSupplierIds.length})'),
    SearchableMultiSelectField<SupplierRow>(
      selectedIds: _selectedSupplierIds,
      items: _suppliers,
      idOf: (sup) => sup.id,
      nameOf: (sup) => sup.name,
      onChanged: (next) => setState(() {
        _selectedSupplierIds
          ..clear()
          ..addAll(next);
      }),
      // _addSupplier auto-selects the created row itself, so the
      // multi-select only needs the dialog opened.
      onAddNew: widget.onCreateSupplier == null
          ? null
          : (_) async {
              await _addSupplier();
              return null;
            },
      addNewLabel: l10n.itemAddNew,
      searchHint: l10n.itemSuppliers,
    ),
  ];

  /// Tab 3/4.
  List<Widget> _pricingTab(AppLocalizations l10n) => [
    CompactSection(l10n.itemPricePartsSection),
    FormGrid(
      children: [
        _unitDropdown(
          value: _largeUnitId,
          label: l10n.itemPackagingUnit,
          onChanged: (v) => setState(() => _largeUnitId = v),
        ),
        _unitDropdown(
          value: _partUnitId,
          label: l10n.itemBaseUnit,
          onChanged: (v) => setState(() {
            _partUnitId = v;
            if (v != null) _largeUnitId ??= v;
          }),
        ),
        TextFormField(
          controller: _c('unitsPerLarge', hint: '1'),
          decoration: InputDecoration(
            labelText: l10n.itemUnitsPerLarge,
            isDense: true,
          ),
          keyboardType: TextInputType.number,
          onChanged: (v) {
            setState(() {
              _partsCount = v.trim();
              _recomputePartPrice();
            });
          },
        ),
      ],
    ),
    FormGrid(
      children: [
        _switch(
          'partialSaleEnabled',
          l10n.partialSaleEnabled,
          _partialSaleEnabled,
          (v) => setState(() {
            _partialSaleEnabled = v;
            if (v) {
              if (_c('partialSaleMarkupBasisPoints').text.isEmpty) {
                _c('partialSaleMarkupBasisPoints').text = _defaultMarkupPercent;
              }
              if (_c('partialSalePartPrice').text.isEmpty) {
                _recomputePartPrice();
              }
            }
          }),
        ),
        if (_partialSaleEnabled) ...[
          _text(
            _c('partialSaleMarkupBasisPoints'),
            l10n.partialSaleMarkupPercent,
            onChanged: (_) => _recomputePartPrice(),
          ),
          _text(
            _c('partialSalePartPrice'),
            l10n.partialSalePartPrice,
            onChanged: (v) {
              if (v.trim().isNotEmpty) {
                _partPriceManual = true;
              }
            },
          ),
          TextButton.icon(
            onPressed: _restoreAutoPartPrice,
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: Text(l10n.partialSaleRestoreAuto),
          ),
        ],
      ],
    ),
    FormGrid(
      children: [
        _text(
          _c('cost'),
          _costLabel(l10n),
          onChanged: (_) => _recomputePartPrice(),
        ),
        _text(_c('discount'), l10n.itemPurchaseDiscount),
        _text(
          _c('selling'),
          l10n.itemPrice,
          onChanged: (_) => _recomputePartPrice(),
        ),
        _text(_c('wholesale'), l10n.itemWholesalePrice),
        _text(_c('halfWholesale'), l10n.itemHalfWholesalePrice),
        _text(_c('custom1'), l10n.itemCustomPrice1),
        _text(_c('custom2'), l10n.itemCustomPrice2),
        _text(_c('vat'), l10n.itemVatRate),
      ],
    ),
    CompactSection(l10n.itemStock),
    FormGrid(
      children: [
        _text(_c('minStock'), l10n.itemMinimumStock),
        _text(_c('maxStock'), l10n.itemMaximumStock),
      ],
    ),
    FormGrid(
      children: [
        _switch(
          'hasExpiry',
          l10n.itemHasExpiry,
          _hasExpiry,
          (v) => setState(() => _hasExpiry = v),
        ),
        _switch(
          'isControlled',
          l10n.itemIsControlled,
          _isControlled,
          (v) => setState(() => _isControlled = v),
        ),
        _switch(
          'lockAutoPrice',
          l10n.itemLockPriceAutoUpdate,
          _lockAutoPrice,
          (v) => setState(() => _lockAutoPrice = v),
        ),
        _switch(
          'requiresPrescription',
          l10n.itemRequiresPrescription,
          _requiresPrescription,
          (v) => setState(() => _requiresPrescription = v),
        ),
      ],
    ),
  ];

  /// Tab 4/4.
  List<Widget> _notesTab(AppLocalizations l10n) => [
    CompactSection(l10n.itemUsageInstructions),
    FormGrid(
      children: [
        _text(_c('usageInstructions'), l10n.itemUsageInstructions),
        _text(_c('generalNotes'), l10n.itemGeneralNotes),
        _text(_c('licenseNumber'), l10n.itemLicenseNumber),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      // Viewport-aware width: full 680px on desktop, shrinks to the
      // phone screen so fields never overflow horizontally.
      content: SizedBox(
        width: math.max(
          280,
          math.min(680, MediaQuery.sizeOf(context).width - 64),
        ),
        child: Form(
          key: _formKey,
          child: _quickMode ? _buildQuickForm(l10n) : _buildTabbedForm(l10n),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        if (widget.showContinueAction)
          FilledButton.tonalIcon(
            onPressed: () => _submit(ItemFormAction.saveContinue),
            icon: const Icon(Icons.add_card_outlined),
            label: Text(l10n.itemSaveAndContinueBatch),
          ),
        FilledButton(onPressed: _submit, child: Text(l10n.commonSave)),
      ],
    );
  }

  /// Quick mode is short enough to fit as-is.
  Widget _buildQuickForm(AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [_modeToggle(l10n), ..._quickSections(l10n)],
      ),
    );
  }

  /// Detailed mode as four tabs so the whole window fits the viewport —
  /// no page-level scrolling; each tab's content is sized to fit.
  /// The mode toggle stays pinned above the tabs.
  Widget _buildTabbedForm(AppLocalizations l10n) {
    final tabs = <Tab>[
      Tab(text: l10n.itemTabBasic),
      Tab(text: l10n.itemTabIngredients),
      Tab(text: l10n.itemTabPricing),
      Tab(text: l10n.itemTabNotes),
    ];
    final bodies = <List<Widget>>[
      _basicTab(l10n),
      _ingredientsTab(l10n),
      _pricingTab(l10n),
      _notesTab(l10n),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _modeToggle(l10n),
              // Fixed (non-scrollable) tabs: all four are always visible
              // and tappable — no hidden tabs.
              TabBar(tabs: tabs),
              // Viewport-aware tab body: fills the available dialog height
              // without pushing the actions off-screen. Over-long tab
              // content scrolls internally.
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: math.max(
                      240,
                      MediaQuery.sizeOf(context).height - 340,
                    ),
                  ),
                  child: TabBarView(
                    children: [
                      for (final body in bodies)
                        SingleChildScrollView(
                          padding: const EdgeInsets.only(top: AppSpacing.s),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: body,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Cost label names the commercial (packaging) unit so the pharmacist knows
  /// the amount is entered per package, not per base unit.
  String _costLabel(AppLocalizations l10n) {
    final largeId = _largeUnitId;
    if (largeId == null) return l10n.itemCost;
    for (final u in _units) {
      if (u.id == largeId && u.name.isNotEmpty) {
        return '${l10n.itemCost} (${u.name})';
      }
    }
    return l10n.itemCost;
  }

  /// Camera scan button for barcode fields — fills the field's controller.
  Widget _scanButton(String fieldKey) =>
      ScanBarcodeButton(onScanned: (code) => _c(fieldKey).text = code);

  Widget _text(
    TextEditingController controller,
    String label, {
    bool required = false,
    ValueChanged<String>? onChanged,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        isDense: true,
        suffixIcon: suffixIcon,
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty)
                ? AppLocalizations.of(context).inventoryRequiredName
                : null
          : null,
      onChanged: onChanged,
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
  }) {
    String idOf(T item) => (item as dynamic).id as String;
    final field = SearchableDropdownField<T>(
      value: value,
      items: items,
      idOf: idOf,
      nameOf: nameOf,
      onChanged: onChanged,
      label: label,
    );
    if (kind == null || widget.onCreateMasterData == null) return field;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: field),
        _addButton(
          AppLocalizations.of(context).itemAddNew,
          () => _addMasterData(kind),
          compact: true,
        ),
      ],
    );
  }

  /// Unit dropdown reused by the packaging and parts fields.
  Widget _unitDropdown({
    required String? value,
    required String label,
    ValueChanged<String?>? onChanged,
  }) {
    return _masterDropdown<UnitRow>(
      value: value,
      label: label,
      items: _units,
      nameOf: (u) => u.name,
      onChanged: onChanged,
      kind: MasterDataKind.unit,
    );
  }

  Widget _addButton(
    String tooltip,
    VoidCallback onPressed, {
    bool compact = false,
  }) {
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
      children: [
        Switch(value: value, onChanged: onChanged),
        Expanded(child: Text(label, style: context.appTypography.label)),
      ],
    );
  }
}
