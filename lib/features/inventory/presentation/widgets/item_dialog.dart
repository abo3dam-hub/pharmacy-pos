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
/// Layout (2026-09-26 redesign): one large 3-column RTL work window —
/// basic info + technical details | packaging & sales + inventory & advanced
/// pricing | classifications + active ingredients + alternatives — with a
/// fixed header, a fixed footer (cancel / save&add-to-inventory / save) and
/// no scrolling of the main window (long inner lists scroll independently).
/// On narrow screens the three column groups switch via a segmented control.
///
/// Phase 17 product-master design lock:
///   • التعبئة التجارية / الأجزاء / عدد الأجزاء replace the old unit-relation
///     labels; the sellable part is expressed through the parts unit only (the
///     legacy "sellable part unit" picker is gone).
///   • سعر بيع الجزء is either auto-derived from the approved formula or an
///     explicit pharmacist override ([ItemDraft.partialSalePriceMicros]);
///     manual mode persists until "استعادة الحساب التلقائي" is tapped.
///   • Active ingredients carry an optional العيار (strength) each.
///   • Usage instructions / general notes / license number are intentionally
///     not shown in this window; their stored values are preserved untouched
///     on save (removal from UI ≠ deletion from the database).
Future<ItemFormResult?> showItemFormDialog(
  BuildContext context, {
  required String title,
  ItemDraft? initial,

  /// Database id of the item being edited, or null when creating. Only used
  /// to offer the "view alternatives" action; never changes save behavior.
  String? itemId,
  required List<CategoryRow> categories,
  required List<ManufacturerRow> manufacturers,
  required List<UnitRow> units,
  List<SupplierRow> suppliers = const [],
  List<ActiveIngredientRow> activeIngredients = const [],
  List<IndicationRow> indications = const [],
  Future<Object?> Function(MasterDataKind kind, MasterDataDraft draft)?
  onCreateMasterData,
  Future<SupplierRow?> Function(SupplierDraft draft)? onCreateSupplier,

  /// Opens the existing alternatives view for the item being edited. The
  /// dialog only shows the alternatives section when both [itemId] and this
  /// callback are provided; the alternatives search/matching itself is
  /// untouched.
  Future<void> Function()? onViewAlternatives,
  int defaultPartialSaleMarkupBasisPoints = 2000,
  bool showContinueAction = false,
}) async {
  final result = await showDialog<ItemFormResult>(
    context: context,
    builder: (_) => _ItemFormDialog(
      title: title,
      initial: initial,
      itemId: itemId,
      categories: categories,
      manufacturers: manufacturers,
      units: units,
      suppliers: suppliers,
      activeIngredients: activeIngredients,
      indications: indications,
      onCreateMasterData: onCreateMasterData,
      onCreateSupplier: onCreateSupplier,
      onViewAlternatives: onViewAlternatives,
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
    this.itemId,
    required this.categories,
    required this.manufacturers,
    required this.units,
    this.suppliers = const [],
    this.activeIngredients = const [],
    this.indications = const [],
    this.onCreateMasterData,
    this.onCreateSupplier,
    this.onViewAlternatives,
    this.defaultPartialSaleMarkupBasisPoints = 2000,
    this.showContinueAction = false,
  });

  final String title;
  final ItemDraft? initial;
  final String? itemId;
  final List<CategoryRow> categories;
  final List<ManufacturerRow> manufacturers;
  final List<UnitRow> units;
  final List<SupplierRow> suppliers;
  final List<ActiveIngredientRow> activeIngredients;
  final List<IndicationRow> indications;
  final Future<Object?> Function(MasterDataKind kind, MasterDataDraft draft)?
  onCreateMasterData;
  final Future<SupplierRow?> Function(SupplierDraft draft)? onCreateSupplier;
  final Future<void> Function()? onViewAlternatives;
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

  // ----- 2026-09-26 redesign: single 3-column work window -----
  //
  // One large RTL window: right = basic info + technical details,
  // middle = packaging & sales + inventory & advanced pricing,
  // left = classifications + active ingredients + alternatives.
  // Fixed header, fixed footer, no scrolling of the main window — each
  // column scrolls internally only if the viewport is too short.
  // Narrow screens switch the three column groups via a segmented control.

  /// Narrow-screen section index (0 = basic, 1 = packaging, 2 =
  /// classifications). Unused on wide screens.
  int _narrowSection = 0;

  /// Three columns need roughly 320px each; below this the groups switch
  /// via a segmented control instead of squeezing unreadably.
  static const double _threeColumnMinWidth = 960;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= _threeColumnMinWidth;
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: EdgeInsets.all(wide ? AppSpacing.xl : AppSpacing.s),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: wide ? 1380 : 560,
          maxHeight: math.max(480, size.height - (wide ? 48 : 24)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _header(l10n, colorScheme),
              Expanded(
                child: wide ? _threeColumns(l10n) : _narrowBody(l10n),
              ),
              _footer(l10n, colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  /// Fixed header: window title + close button. Never scrolls away.
  Widget _header(AppLocalizations l10n, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.title,
              style: context.appTypography.pageTitle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.commonClose,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// Fixed footer: cancel | save-and-add-to-inventory | save. Never scrolls
  /// away; every action keeps its current behavior. On narrow screens the
  /// actions stack in two compact rows so the long labels never overflow.
  Widget _footer(AppLocalizations l10n, ColorScheme colorScheme) {
    final wide = MediaQuery.sizeOf(context).width >= _threeColumnMinWidth;
    final cancel = TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: Text(l10n.commonCancel),
    );
    final save = FilledButton(
      onPressed: () => _submit(),
      child: Text(l10n.commonSave),
    );
    final Widget saveContinue = FilledButton.tonalIcon(
      onPressed: () => _submit(ItemFormAction.saveContinue),
      icon: const Icon(Icons.add_card_outlined),
      label: Text(l10n.itemSaveAndContinueBatch),
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: wide
          ? Row(
              children: [
                cancel,
                const Spacer(),
                if (widget.showContinueAction) ...[
                  saveContinue,
                  const SizedBox(width: AppSpacing.s),
                ],
                save,
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (widget.showContinueAction) ...[
                      Expanded(child: saveContinue),
                      const SizedBox(width: AppSpacing.s),
                    ],
                    save,
                  ],
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: cancel,
                ),
              ],
            ),
    );
  }

  /// Desktop layout: three equal columns. In RTL the first Row child renders
  /// on the right, so the order below is right → middle → left.
  Widget _threeColumns(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _columnCard(_rightColumn(l10n))),
          const SizedBox(width: AppSpacing.m),
          Expanded(child: _columnCard(_middleColumn(l10n))),
          const SizedBox(width: AppSpacing.m),
          Expanded(child: _columnCard(_leftColumn(l10n))),
        ],
      ),
    );
  }

  /// Narrow screens: one column group at a time, switched explicitly — every
  /// field stays reachable while header and footer never move.
  Widget _narrowBody(AppLocalizations l10n) {
    final sections = <Widget>[
      _columnCard(_rightColumn(l10n)),
      _columnCard(_middleColumn(l10n)),
      _columnCard(_leftColumn(l10n)),
    ];
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 0,
                  label: Text(l10n.itemSectionBasicInfo),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text(l10n.itemSectionPackaging),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text(l10n.itemSectionClassifications),
                ),
              ],
              selected: {_narrowSection},
              onSelectionChanged: (s) =>
                  setState(() => _narrowSection = s.first),
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Expanded(child: sections[_narrowSection]),
        ],
      ),
    );
  }

  /// A column's card: subtle surface holding its sections. Scrolls internally
  /// only when the viewport is too short for the content — at desktop sizes
  /// everything fits and no scrolling occurs.
  Widget _columnCard(List<Widget> sections) {
    return Card(
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: sections,
        ),
      ),
    );
  }

  /// Right column — basic info + technical details (single-column field
  /// stack, like the reference design's right panel).
  List<Widget> _rightColumn(AppLocalizations l10n) => [
    CompactSection(l10n.itemSectionBasicInfo),
    _text(_c('tradeName'), l10n.itemTradeName, required: true),
    const SizedBox(height: AppSpacing.s),
    _text(_c('tradeNameEn'), l10n.itemTradeNameEn),
    const SizedBox(height: AppSpacing.s),
    _text(
      _c('primaryBarcode'),
      l10n.itemBarcodePrimary,
      suffixIcon: _scanButton('primaryBarcode'),
    ),
    const SizedBox(height: AppSpacing.s),
    _text(
      _c('secondaryBarcode'),
      l10n.itemSecondaryBarcode,
      suffixIcon: _scanButton('secondaryBarcode'),
    ),
    CompactSection(l10n.itemSectionTechnical),
    _text(_c('scientificName'), l10n.itemScientificName),
    const SizedBox(height: AppSpacing.s),
    _text(_c('equivalentDrug'), l10n.itemEquivalentDrug),
    const SizedBox(height: AppSpacing.s),
    _text(_c('pharmaForm'), l10n.itemPharmaForm),
    const SizedBox(height: AppSpacing.s),
    _text(_c('dose'), l10n.itemDose),
    const SizedBox(height: AppSpacing.s),
    _masterDropdown(
      value: _manufacturerId,
      label: l10n.itemManufacturer,
      items: _manufacturers,
      nameOf: (m) => m.name,
      onChanged: (v) => setState(() => _manufacturerId = v),
      kind: MasterDataKind.manufacturer,
    ),
    const SizedBox(height: AppSpacing.s),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _text(_c('sizeVolume'), l10n.itemSizeVolume)),
        const SizedBox(width: AppSpacing.s),
        Expanded(child: _text(_c('shelfLocation'), l10n.itemShelfLocation)),
      ],
    ),
  ];

  /// Middle column — packaging & sales, pricing, inventory & advanced
  /// pricing. Denser multi-field rows, like the reference design.
  List<Widget> _middleColumn(AppLocalizations l10n) => [
    CompactSection(l10n.itemSectionPackaging),
    _unitDropdown(
      value: _largeUnitId,
      label: l10n.itemPackagingUnit,
      onChanged: (v) => setState(() => _largeUnitId = v),
    ),
    const SizedBox(height: AppSpacing.s),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _unitDropdown(
            value: _partUnitId,
            label: l10n.itemBaseUnit,
            onChanged: (v) => setState(() {
              _partUnitId = v;
              if (v != null) _largeUnitId ??= v;
            }),
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        Expanded(
          child: TextFormField(
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
        ),
      ],
    ),
    const SizedBox(height: AppSpacing.xs),
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
      const SizedBox(height: AppSpacing.xs),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _text(
              _c('partialSaleMarkupBasisPoints'),
              l10n.partialSaleMarkupPercent,
              onChanged: (_) => _recomputePartPrice(),
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: _text(
              _c('partialSalePartPrice'),
              l10n.partialSalePartPrice,
              onChanged: (v) {
                if (v.trim().isNotEmpty) {
                  _partPriceManual = true;
                }
              },
            ),
          ),
        ],
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: _restoreAutoPartPrice,
          icon: const Icon(Icons.auto_fix_high, size: 18),
          label: Text(l10n.partialSaleRestoreAuto),
        ),
      ),
    ],
    CompactSection(l10n.itemSectionPricing),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _text(
            _c('cost'),
            _costLabel(l10n),
            onChanged: (_) => _recomputePartPrice(),
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        Expanded(
          child: _text(
            _c('selling'),
            l10n.itemPrice,
            onChanged: (_) => _recomputePartPrice(),
          ),
        ),
      ],
    ),
    CompactSection(l10n.itemSectionAdvanced),
    FormGrid(
      minColumnWidth: 120,
      children: [
        _text(_c('discount'), l10n.itemPurchaseDiscount),
        _text(_c('custom1'), l10n.itemCustomPrice1),
        _text(_c('custom2'), l10n.itemCustomPrice2),
      ],
    ),
    const SizedBox(height: AppSpacing.s),
    FormGrid(
      minColumnWidth: 120,
      children: [
        _text(_c('vat'), l10n.itemVatRate),
        _text(_c('wholesale'), l10n.itemWholesalePrice),
        _text(_c('halfWholesale'), l10n.itemHalfWholesalePrice),
      ],
    ),
    const SizedBox(height: AppSpacing.s),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _text(_c('minStock'), l10n.itemMinimumStock)),
        const SizedBox(width: AppSpacing.s),
        Expanded(child: _text(_c('maxStock'), l10n.itemMaximumStock)),
      ],
    ),
    const SizedBox(height: AppSpacing.xs),
    FormGrid(
      minColumnWidth: 150,
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

  /// Left column — classifications & indications, active ingredients with
  /// strengths, alternatives.
  List<Widget> _leftColumn(AppLocalizations l10n) => [
    CompactSection(l10n.itemSectionClassifications),
    _masterDropdown(
      value: _categoryId,
      label: l10n.itemCategory,
      items: _categories,
      nameOf: (c) => c.name,
      onChanged: (v) => setState(() => _categoryId = v),
      kind: MasterDataKind.category,
    ),
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
              final created = await _addMasterDataWithName(
                MasterDataKind.indication,
                name,
              );
              return created as IndicationRow?;
            },
      addNewLabel: l10n.itemAddNew,
      searchHint: l10n.itemIndications,
    ),
    CompactSection(
      '${l10n.itemActiveIngredients} (${_selectedActiveIngredientIds.length})',
    ),
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
    CompactSection(l10n.itemSectionAlternatives),
    ..._alternativesSection(l10n),
  ];

  /// Alternatives section: in edit mode offers the existing alternatives
  /// view (search/matching untouched); when creating, alternatives only
  /// exist after the item is saved.
  List<Widget> _alternativesSection(AppLocalizations l10n) {
    if (widget.itemId != null && widget.onViewAlternatives != null) {
      return [
        OutlinedButton.icon(
          onPressed: () => widget.onViewAlternatives!(),
          icon: const Icon(Icons.swap_horiz_outlined),
          label: Text(l10n.itemViewAlternatives),
        ),
      ];
    }
    return [
      Text(
        l10n.itemAlternativesAfterSave,
        style: context.appTypography.labelSmall,
      ),
    ];
  }

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
