import 'package:excel/excel.dart';

import '../../../../core/money/money.dart';
import '../../../../core/util/smart_search.dart';
import '../../../../shared/database/app_database.dart';
import '../../domain/entities/inventory_item.dart';
import '../repositories/inventory_repository.dart';

/// Excel (.xlsx) export/import of item master data (§27, "Excel import/export").
///
/// Export writes the full §5 profile plus live stock snapshot. Import accepts
/// the same header layout; master-data entities are matched by *name*
/// (categories, manufacturers, active ingredients, indications, units) and
/// items are matched deterministically. The only hard requirement per row is a
/// non-empty trade name.
///
/// **Matching (Phase 18.2A, safe & deterministic — never guesses):**
///   1. a non-empty barcode cell is looked up in an in-memory
///      primary/secondary barcode index (exact); a barcode that matches nobody
///      identifies a brand-new row (no fuzzy barcode edits, source ids are
///      never synthesised into barcodes);
///   2. otherwise the normalized trade name is looked up and narrowed by the
///      **composite identity**: every discriminator the row provides (active
///      ingredient + strength pairs, pharmaceutical form, dose, manufacturer)
///      must match a candidate exactly; portions not provided are ignored
///      (blank = preserve on update);
///   3. exactly one candidate → update it; none → create; **more than one →
///      conflict/ambiguous** (reported, row skipped). `package_shape`/unit
///      relations are NOT part of the identity.
///
/// **Scalability (Phase 18.2A):** the whole catalog is loaded **once** per
/// import (plus bulk relational-ingredient / indication / unit projections),
/// indexes (barcode, normalized trade name, composite) are built in memory and
/// no database query or full-catalog scan runs per sheet row; the row loop
/// yields periodically so a 14 000-row file never blocks the UI isolate. The
/// Excel contract is unchanged: blank optional cells on an existing item
/// preserve the current value (financial fields, stock limits, location,
/// barcodes, expiry flag, ingredients, indications, units and the appended
/// المكافئ/الشكل الصيدلاني/الجرعة/الحجم columns).
class InventoryExcelService {
  const InventoryExcelService(this._repo);

  final InventoryRepository _repo;

  static const String _sheetName = 'products';

  /// Column keys (header text) shared by export and import. Phase 18 template:
  /// التعبئة التجارية / الأجزاء / عدد الأجزاء for units; the relational
  /// فعالة list (name:strength pairs, ';' separated) and الاستطبابات take the
  /// place of the removed sub-category / therapeutic-group columns.
  static const List<String> headers = [
    'الرمز الشريطي الرئيسي',
    'الرمز الشريطي الثانوي',
    'الاسم التجاري',
    'الاسم التجاري (EN)',
    'الاسم العلمي',
    'المادة الفعالة',
    'المواد الفعالة',
    'التصنيف',
    'الشركة المصنعة',
    'الاستطبابات',
    'الموقع',
    'له تاريخ صلاحية',
    'الأجزاء',
    'التعبئة التجارية',
    'عدد الأجزاء',
    'سعر البيع',
    'سعر الجملة',
    'سعر الجملة النصف',
    'ضريبة %',
    'سعر التكلفة',
    'الحد الأدنى',
    'الحد الأقصى',
    'المخزون الحالي',
    'المكافئ',
    'الشكل الصيدلاني',
    'الجرعة / العيار',
    'الحجم',
  ];

  static const Map<String, int> _colIndex = {
    'الرمز الشريطي الرئيسي': 0,
    'الرمز الشريطي الثانوي': 1,
    'الاسم التجاري': 2,
    'الاسم التجاري (EN)': 3,
    'الاسم العلمي': 4,
    'المادة الفعالة': 5,
    'المواد الفعالة': 6,
    'التصنيف': 7,
    'الشركة المصنعة': 8,
    'الاستطبابات': 9,
    'الموقع': 10,
    'له تاريخ صلاحية': 11,
    'الأجزاء': 12,
    'التعبئة التجارية': 13,
    'عدد الأجزاء': 14,
    'سعر البيع': 15,
    'سعر الجملة': 16,
    'سعر الجملة النصف': 17,
    'ضريبة %': 18,
    'سعر التكلفة': 19,
    'الحد الأدنى': 20,
    'الحد الأقصى': 21,
    'المخزون الحالي': 22,
    'المكافئ': 23,
    'الشكل الصيدلاني': 24,
    'الجرعة / العيار': 25,
    'الحجم': 26,
  };

  // ----- Export -----

  /// Serialises [views] to xlsx bytes (export only; read-only permission).
  List<int> exportItems(List<InventoryItemView> views) {
    final excel = Excel.createExcel();
    final sheet = excel[_sheetName];
    sheet.appendRow([for (final h in headers) TextCellValue(h)]);
    for (final v in views) {
      final item = v.item;
      final units = v.units;
      sheet.appendRow([
        TextCellValue(item.primaryBarcode ?? ''),
        TextCellValue(item.secondaryBarcode ?? ''),
        TextCellValue(item.tradeName),
        TextCellValue(item.tradeNameEn ?? ''),
        TextCellValue(item.scientificName ?? ''),
        TextCellValue(item.activeIngredient ?? ''),
        TextCellValue(
          [for (final i in v.activeIngredients) _ingredientCell(i)].join('; '),
        ),
        TextCellValue(v.categoryName ?? ''),
        TextCellValue(v.manufacturerName ?? ''),
        TextCellValue(v.indicationNames.join('; ')),
        TextCellValue(item.shelfLocation ?? ''),
        BoolCellValue(item.hasExpiry),
        TextCellValue(v.baseUnitName ?? ''),
        TextCellValue(v.largeUnitName ?? ''),
        units == null ? TextCellValue('') : IntCellValue(units.unitsPerLarge),
        TextCellValue(Money.fromUnits(item.sellingPriceMicros).format()),
        TextCellValue(Money.fromUnits(item.wholesalePriceMicros).format()),
        TextCellValue(Money.fromUnits(item.halfWholesalePriceMicros).format()),
        IntCellValue(item.vatRateBasisPoints ~/ 100),
        TextCellValue(Money.fromUnits(item.costMicros).format()),
        IntCellValue(item.minimumStockBase),
        IntCellValue(item.maximumStockBase),
        IntCellValue(item.currentStockBase),
        TextCellValue(item.equivalentDrug ?? ''),
        TextCellValue(item.pharmaForm ?? ''),
        TextCellValue(item.dose ?? ''),
        TextCellValue(item.sizeVolume ?? ''),
      ]);
    }
    return excel.save(fileName: 'inventory.xlsx')!;
  }

  static String _ingredientCell(ItemIngredientRef ref) =>
      (ref.strength?.isNotEmpty ?? false)
      ? '${ref.name}:${ref.strength}'
      : ref.name;

  // ----- Import -----

/// Parses bytes into import rows, resolving master-data by name and items by
/// deterministic matching (barcode → composite identity; ambiguous rows are
/// skipped with an issue). The item catalog is loaded exactly once and every
/// per-row lookup is an in-memory index access (Phase 18.2A).
///
/// **Master-data auto-creation (Phase 18.3):** instead of rejecting a row
/// whose referenced master entity (category, manufacturer, active ingredient,
/// indication or unit) is unknown, the missing entity is created on the spot
/// and the row imported — so a supplier's full catalog sheet inserts complete.
/// Every auto-created row is reported through [createdMaster] so the caller can
/// audit it like an explicit master-data create.
  Future<
      ({
        List<ImportRow> rows,
        List<String> issues,
        List<CreatedMasterRecord> createdMaster,
      })> parseImport(
    List<int> bytes,
  ) async {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[_sheetName];
    if (sheet == null || sheet.maxRows == 0) {
      return (
        rows: const <ImportRow>[],
        issues: const ['ملف بدون أوراق بيانات'],
        createdMaster: const <CreatedMasterRecord>[],
      );
    }

    // Pre-load master-data lookups outside the loop.
    final categories = await _repo.categories();
    final byCategoryName = {for (final c in categories) c.name.trim(): c};
    final manufacturers = await _repo.manufacturers();
    final byManufacturerName = {
      for (final m in manufacturers) m.name.trim(): m,
    };
    final unitList = await _repo.units();
    final byUnitName = {
      for (final u in unitList) u.name: u,
      for (final u in unitList)
        if (u.nameEn != null && u.nameEn!.isNotEmpty) u.nameEn!: u,
    };
    final ingredientList = await _repo.activeIngredients();
    final byIngredientName = {
      for (final i in ingredientList) i.name.trim(): i,
      for (final i in ingredientList)
        if (i.nameEn != null && i.nameEn!.isNotEmpty) i.nameEn!.trim(): i,
    };
    final indicationList = await _repo.indications();
    final byIndicationName = {
      for (final d in indicationList) d.name.trim(): d,
      for (final d in indicationList)
        if (d.nameEn != null && d.nameEn!.isNotEmpty) d.nameEn!.trim(): d,
    };

    // The one-shot item catalog: all rows + bulk relational/unit projections.
    final catalog = await _ItemCatalog.load(_repo);

    final issues = <String>[];
    final rows = <ImportRow>[];
    final createdMaster = <CreatedMasterRecord>[];
    final seenTargets = <String, int>{};
    for (var r = 1; r < sheet.maxRows; r++) {
      // Yield to the event loop every 256 rows so a very large file never
      // blocks the UI isolate (chunked processing, no timing assumptions).
      if (r % 256 == 0) {
        await Future<void>.delayed(Duration.zero);
      }

      final values = sheet.row(r);
      String at(int idx) =>
          _cellToText(values.length > idx ? values[idx]?.value : null).trim();

      final barcode = at(_colIndex['الرمز الشريطي الرئيسي']!);
      final tradeName = at(_colIndex['الاسم التجاري']!);
      if (tradeName.isEmpty) continue;

      final categoryName = at(_colIndex['التصنيف']!);
      var category = categoryName.isEmpty
          ? null
          : byCategoryName[categoryName];
      if (categoryName.isNotEmpty && category == null) {
        category = await _repo.createCategory(MasterDataDraft(
              name: categoryName,
            ));
        byCategoryName[categoryName] = category;
        createdMaster.add(CreatedMasterRecord(
          entityType: 'category',
          entityId: category.id,
          name: category.name,
        ));
      }

      final manufacturerName = at(_colIndex['الشركة المصنعة']!);
      var manufacturer = manufacturerName.isNotEmpty
          ? byManufacturerName[manufacturerName]
          : null;
      if (manufacturerName.isNotEmpty && manufacturer == null) {
        manufacturer = await _repo.createManufacturer(MasterDataDraft(
              name: manufacturerName,
            ));
        byManufacturerName[manufacturerName] = manufacturer;
        createdMaster.add(CreatedMasterRecord(
          entityType: 'manufacturer',
          entityId: manufacturer.id,
          name: manufacturer.name,
        ));
      }

      // Relational active ingredients encoded as `name:strength` pairs
      // separated by ';' (strength optional, §4.2b). Only pairs the sheet
      // actually provides take part in the composite match; a blank cell for
      // an existing item preserves its current relational set.
      final rawIngredients = at(_colIndex['المواد الفعالة']!).trim();
      var ingredientIds = <String>[];
      var ingredientStrengths = <String, String>{};
      if (rawIngredients.isNotEmpty) {
        for (final entry in _splitEntries(rawIngredients)) {
          final (name, strength) = _splitPair(entry);
          var ingredient = byIngredientName[name];
          if (ingredient == null) {
            ingredient =
                await _repo.createActiveIngredient(MasterDataDraft(name: name));
            byIngredientName[name] = ingredient;
            createdMaster.add(CreatedMasterRecord(
              entityType: 'active_ingredient',
              entityId: ingredient.id,
              name: ingredient.name,
            ));
          }
          ingredientIds.add(ingredient.id);
          if (strength.isNotEmpty) {
            ingredientStrengths[ingredient.id] = strength;
          }
        }
      }

      final rawIndications = at(_colIndex['الاستطبابات']!).trim();
      var indicationIds = <String>[];
      if (rawIndications.isNotEmpty) {
        for (final name in _splitEntries(rawIndications)) {
          var indication = byIndicationName[name];
          if (indication == null) {
            indication =
                await _repo.createIndication(MasterDataDraft(name: name));
            byIndicationName[name] = indication;
            createdMaster.add(CreatedMasterRecord(
              entityType: 'indication',
              entityId: indication.id,
              name: indication.name,
            ));
          }
          indicationIds.add(indication.id);
        }
      }

      final pharmaForm = at(_colIndex['الشكل الصيدلاني']!);
      final dose = at(_colIndex['الجرعة / العيار']!);

      // Deterministic item resolution: barcode first, else composite.
      final (existing, ambiguous) = _resolveItem(
        catalog,
        barcode: barcode,
        tradeName: tradeName,
        providedForm: _normOrNull(pharmaForm),
        providedDose: _normOrNull(dose),
        providedManufacturerId: manufacturer?.id,
        providedIngredientIds: ingredientIds,
        providedIngredientStrengths: ingredientStrengths,
      );
      if (ambiguous) {
        issues.add(
          'الصف ${r + 1}: الاسم "$tradeName" يطابق أكثر من منتج '
          '(أضف الباركود أو العيار أو الشكل الصيدلاني أو الشركة للتمييز)',
        );
        continue;
      }

      // Duplicate targeting within the file: the same item (by barcode,
      // matched id, or creation identity) may only appear once.
      final targetKey = barcode.isNotEmpty
          ? 'b:$barcode'
          : existing != null
          ? 'i:${existing.id}'
          : 'c:${_creationIdentity(tradeName, pharmaForm, dose, manufacturer?.id, ingredientIds, ingredientStrengths)}';
      final alreadySeenAt = seenTargets[targetKey];
      if (alreadySeenAt != null) {
        issues.add(
          'الصف ${r + 1}: هذا المنتج مكرر داخل الملف (رُصد أولاً في '
          'الصف $alreadySeenAt)',
        );
        continue;
      }
      seenTargets[targetKey] = r + 1;

      // Blank relational fields for an existing item preserve its current set
      // (resolved from the in-memory catalog, never per-row).
      final preservedIngredientIds = rawIngredients.isEmpty && existing != null
          ? [
              for (final rel
                  in catalog.activeIngredientsByItem[existing.id] ??
                      const <ItemActiveIngredientRow>[])
                rel.activeIngredientId,
            ]
          : ingredientIds;
      final preservedIngredientStrengths =
          rawIngredients.isEmpty && existing != null
          ? {
              for (final rel
                  in catalog.activeIngredientsByItem[existing.id] ??
                      const <ItemActiveIngredientRow>[])
                if ((rel.strength ?? '').isNotEmpty)
                  rel.activeIngredientId: rel.strength!,
            }
          : ingredientStrengths;
      final preservedIndicationIds = rawIndications.isEmpty && existing != null
          ? catalog.indicationIdsByItem[existing.id] ?? const <String>[]
          : indicationIds;

      final baseName = at(_colIndex['الأجزاء']!);
      final largeName = at(_colIndex['التعبئة التجارية']!);
      var baseUnit = baseName.isEmpty ? null : byUnitName[baseName];
      var largeUnit = largeName.isEmpty ? null : byUnitName[largeName];
      if (baseName.isNotEmpty && baseUnit == null) {
        baseUnit = await _repo.createUnit(MasterDataDraft(name: baseName));
        byUnitName[baseName] = baseUnit;
        createdMaster.add(CreatedMasterRecord(
          entityType: 'unit',
          entityId: baseUnit.id,
          name: baseUnit.name,
        ));
      }
      if (largeName.isNotEmpty && largeUnit == null) {
        largeUnit = await _repo.createUnit(MasterDataDraft(name: largeName));
        byUnitName[largeName] = largeUnit;
        createdMaster.add(CreatedMasterRecord(
          entityType: 'unit',
          entityId: largeUnit.id,
          name: largeUnit.name,
        ));
      }
      if (baseName.isNotEmpty && (baseUnit == null || largeUnit == null)) {
        issues.add(
          'الصف ${r + 1}: الوحدات "$baseName" / "$largeName" غير مكتملة',
        );
        continue;
      }

      // Unit relation: from the sheet when complete, otherwise preserved for
      // existing items (optional for new ones, Phase 18). Unit relations are
      // NOT part of the item identity (never used to disambiguate).
      final existingUnits = existing == null
          ? null
          : catalog.unitsByItem[existing.id];
      final ItemUnitRelation? relation = baseUnit != null && largeUnit != null
          ? ItemUnitRelation(
              baseUnitId: baseUnit.id,
              largeUnitId: largeUnit.id,
              unitsPerLarge: _parseInt(at(_colIndex['عدد الأجزاء']!)) ?? 1,
            )
          : existingUnits == null
          ? null
          : ItemUnitRelation(
              baseUnitId: existingUnits.baseUnitId,
              largeUnitId: existingUnits.largeUnitId,
              unitsPerLarge: existingUnits.unitsPerLarge,
            );

      // Financial/stock fields are optional: a blank cell for an existing item
      // preserves the current value, for a new item it defaults to zero. Only
      // a *non-blank* unparseable value is rejected.
      final sellingRaw = at(_colIndex['سعر البيع']!);
      final wholesaleRaw = at(_colIndex['سعر الجملة']!);
      final halfRaw = at(_colIndex['سعر الجملة النصف']!);
      final costRaw = at(_colIndex['سعر التكلفة']!);
      final selling = sellingRaw.isEmpty ? null : _parseMoney(sellingRaw);
      final wholesale = wholesaleRaw.isEmpty ? null : _parseMoney(wholesaleRaw);
      final half = halfRaw.isEmpty ? null : _parseMoney(halfRaw);
      final cost = costRaw.isEmpty ? null : _parseMoney(costRaw);
      if ((sellingRaw.isNotEmpty && selling == null) ||
          (costRaw.isNotEmpty && cost == null)) {
        issues.add('الصف ${r + 1}: قيم مالية غير صالحة');
        continue;
      }
      final vatRaw = at(_colIndex['ضريبة %']!);
      final minRaw = at(_colIndex['الحد الأدنى']!);
      final maxRaw = at(_colIndex['الحد الأقصى']!);
      final expiryText = at(_colIndex['له تاريخ صلاحية']!);

      final draft = ItemDraft(
        primaryBarcode: barcode.isEmpty ? existing?.primaryBarcode : barcode,
        secondaryBarcode:
            _orNull(at(_colIndex['الرمز الشريطي الثانوي']!)) ??
            existing?.secondaryBarcode,
        tradeName: tradeName,
        tradeNameEn:
            _orNull(at(_colIndex['الاسم التجاري (EN)']!)) ??
            existing?.tradeNameEn,
        scientificName:
            _orNull(at(_colIndex['الاسم العلمي']!)) ?? existing?.scientificName,
        activeIngredient:
            _orNull(at(_colIndex['المادة الفعالة']!)) ??
            existing?.activeIngredient,
        equivalentDrug:
            _orNull(at(_colIndex['المكافئ']!)) ?? existing?.equivalentDrug,
        pharmaForm:
            _orNull(at(_colIndex['الشكل الصيدلاني']!)) ?? existing?.pharmaForm,
        dose: _orNull(at(_colIndex['الجرعة / العيار']!)) ?? existing?.dose,
        sizeVolume: _orNull(at(_colIndex['الحجم']!)) ?? existing?.sizeVolume,
        categoryId: category?.id ?? existing?.categoryId,
        manufacturerId: manufacturer?.id ?? existing?.manufacturerId,
        shelfLocation:
            _orNull(at(_colIndex['الموقع']!)) ?? existing?.shelfLocation,
        hasExpiry: expiryText.trim().isEmpty
            ? (existing?.hasExpiry ?? false)
            : _cellBool(values, _colIndex['له تاريخ صلاحية']!),
        sellingPriceMicros: selling ?? existing?.sellingPriceMicros ?? 0,
        subUnitPriceMicros: existing?.subUnitPriceMicros ?? selling ?? 0,
        wholesalePriceMicros:
            wholesale ?? existing?.wholesalePriceMicros ?? selling ?? 0,
        halfWholesalePriceMicros:
            half ?? existing?.halfWholesalePriceMicros ?? selling ?? 0,
        vatRateBasisPoints: vatRaw.trim().isEmpty
            ? (existing?.vatRateBasisPoints ?? 0)
            : (_parseInt(vatRaw) ?? 0) * 100,
        costMicros: cost ?? existing?.costMicros ?? 0,
        minimumStockBase: minRaw.trim().isEmpty
            ? (existing?.minimumStockBase ?? 0)
            : (_parseInt(minRaw) ?? 0),
        maximumStockBase: maxRaw.trim().isEmpty
            ? (existing?.maximumStockBase ?? 0)
            : (_parseInt(maxRaw) ?? 0),
        units: relation,
        activeIngredientIds: preservedIngredientIds,
        activeIngredientStrengths: preservedIngredientStrengths,
        indicationIds: preservedIndicationIds,
        // Fields the sheet does not model are preserved untouched on update so
        // an import is an in-place edit of the product master (lossless
        // round-trip, Phase 18.1).
        isControlledDrug: existing?.isControlledDrug ?? false,
        lockAutoPriceUpdate: existing?.lockAutoPriceUpdate ?? false,
        requiresPrescription: existing?.requiresPrescription ?? false,
        customPrice1Micros: existing?.customPrice1Micros ?? 0,
        customPrice2Micros: existing?.customPrice2Micros ?? 0,
        purchaseDiscountBasisPoints: existing?.purchaseDiscountBasisPoints ?? 0,
        usageInstructions: existing?.usageInstructions,
        generalNotes: existing?.generalNotes,
        licenseNumber: existing?.licenseNumber,
        partialSaleEnabled: existing?.partialSaleEnabled ?? false,
        sellablePartUnitId: existing?.sellablePartUnitId,
        partsPerFullProduct: existing?.partsPerFullProduct,
        sellablePartBaseQuantity: existing?.sellablePartBaseQuantity,
        partialSaleMarkupBasisPoints: existing?.partialSaleMarkupBasisPoints,
        partialSalePriceMicros: existing?.partialSalePriceMicros,
      );
      rows.add(
        ImportRow(
          draft: draft,
          rowNumber: r + 1,
          barcode: barcode.isEmpty ? null : barcode,
          existingItemId: existing?.id,
        ),
      );
    }
    return (rows: rows, issues: issues, createdMaster: createdMaster);
  }

  /// Deterministic item resolution (Phase 18.2A). Returns `(item, false)` for
  /// a single match or an unambiguous new-creation, or `(null, true)` when the
  /// barcode maps to several rows (impossible, barcodes are unique) or the
  /// normalized trade name resolves to more than one candidate composite.
  static (ItemRow?, bool) _resolveItem(
    _ItemCatalog catalog, {
    required String barcode,
    required String tradeName,
    String? providedForm,
    String? providedDose,
    String? providedManufacturerId,
    List<String> providedIngredientIds = const [],
    Map<String, String> providedIngredientStrengths = const {},
  }) {
    if (barcode.isNotEmpty) {
      return (catalog.byBarcode(barcode), false);
    }

    final candidates =
        catalog.byNormalizedName[SmartSearch.normalize(tradeName)] ??
        const <ItemRow>[];
    if (candidates.isEmpty) return (null, false);

    final matched = <ItemRow>[];
    for (final candidate in candidates) {
      if (!_coversCandidate(
        catalog,
        candidate,
        providedForm: providedForm,
        providedDose: providedDose,
        providedManufacturerId: providedManufacturerId,
        providedIngredientIds: providedIngredientIds,
        providedIngredientStrengths: providedIngredientStrengths,
      )) {
        continue;
      }
      matched.add(candidate);
      if (matched.length > 1) return (null, true);
    }
    return matched.isEmpty ? (null, false) : (matched.first, false);
  }

  /// True when the candidate's stored profile matches every *provided*
  /// discriminator exactly (ingredient ids + their strengths, pharmaceutical
  /// form, dose, manufacturer). Values the sheet does not provide are ignored.
  static bool _coversCandidate(
    _ItemCatalog catalog,
    ItemRow candidate, {
    String? providedForm,
    String? providedDose,
    String? providedManufacturerId,
    List<String> providedIngredientIds = const [],
    Map<String, String> providedIngredientStrengths = const {},
  }) {
    if (providedForm != null) {
      if (SmartSearch.normalize(candidate.pharmaForm ?? '') != providedForm) {
        return false;
      }
    }
    if (providedDose != null) {
      if (SmartSearch.normalize(candidate.dose ?? '') != providedDose) {
        return false;
      }
    }
    if (providedManufacturerId != null &&
        candidate.manufacturerId != providedManufacturerId) {
      return false;
    }
    if (providedIngredientIds.isNotEmpty) {
      final candidateById = <String, String>{
        for (final r
            in catalog.activeIngredientsByItem[candidate.id] ?? const [])
          r.activeIngredientId: r.strength ?? '',
      };
      for (final id in providedIngredientIds) {
        final candidateStrength = candidateById[id];
        if (candidateStrength == null) return false;
        final providedStrength = providedIngredientStrengths[id] ?? '';
        if (providedStrength.isNotEmpty &&
            SmartSearch.normalize(providedStrength) !=
                SmartSearch.normalize(candidateStrength)) {
          return false;
        }
      }
    }
    return true;
  }

  /// Normalizes a name-like discriminator for deterministic comparison.
  static String? _normOrNull(String value) =>
      value.isEmpty ? null : SmartSearch.normalize(value);

  /// Stable creation identity for in-file duplicate detection of new rows.
  static String _creationIdentity(
    String tradeName,
    String pharmaForm,
    String dose,
    String? manufacturerId,
    List<String> ingredientIds,
    Map<String, String> ingredientStrengths,
  ) {
    final sortedIngredientIds = [...ingredientIds]..sort();
    final pairs = [
      for (final id in sortedIngredientIds)
        '$id:${ingredientStrengths[id] ?? ''}',
    ]..sort();
    return [
      SmartSearch.normalize(tradeName),
      SmartSearch.normalize(pharmaForm),
      SmartSearch.normalize(dose),
      manufacturerId ?? '',
      pairs.join(','),
    ].join('\u0001');
  }

  /// Separator-tolerant splitting of a multi-value cell (';', '؛').
  static List<String> _splitEntries(String raw) {
    if (raw.trim().isEmpty) return const [];
    return raw
        .split(RegExp(r'[;؛]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Splits one `name:strength` entry at the first separator (':', ':').
  static (String, String) _splitPair(String entry) {
    final idx = entry.indexOf(':');
    if (idx < 0) return (entry.trim(), '');
    return (entry.substring(0, idx).trim(), entry.substring(idx + 1).trim());
  }

  // ----- helpers -----

  String _cellToText(CellValue? value) {
    if (value == null) return '';
    if (value is TextCellValue) return value.toString();
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) {
      final text = value.value.toStringAsFixed(2);
      return text.endsWith('.00') ? text.substring(0, text.length - 3) : text;
    }
    if (value is BoolCellValue) return value.value ? '1' : '0';
    return value.toString();
  }

  bool _cellBool(List<Data?> values, int idx) {
    if (idx >= values.length) return false;
    final v = values[idx]?.value;
    if (v is BoolCellValue) return v.value;
    final text = _cellToText(v);
    return text == '1' || text.toLowerCase() == 'true' || text == 'نعم';
  }

  /// Parses a numeric cell allowing commas and Arabic-Indic digits.
  static int? _parseInt(String raw) {
    final cleaned = _toAsciiDigits(
      raw,
    ).replaceAll(',', '').replaceAll('٬', '').trim();
    if (cleaned.isEmpty) return null;
    return int.tryParse(cleaned);
  }

  /// Parses a monetary cell via [Money] (integer micro-units, never REAL).
  static int? _parseMoney(String raw) {
    final cleaned = _toAsciiDigits(
      raw,
    ).replaceAll(',', '').replaceAll('٬', '').replaceAll('٫', '.').trim();
    if (cleaned.isEmpty) return 0;
    try {
      return Money.parse(cleaned).units;
    } on FormatException {
      return null;
    }
  }

  static String _toAsciiDigits(String input) => input.split('').map((c) {
    final code = c.codeUnitAt(0);
    if (code >= 0x0660 && code <= 0x0669) {
      return String.fromCharCode(code - 0x0660 + 0x30);
    }
    return c;
  }).join();

  static String? _orNull(String value) => value.isEmpty ? null : value;
}

/// One-shot in-memory item catalog built once per import so every per-row
/// lookup is an index access with zero additional database round trips
/// (Phase 18.2A scalability guarantee).
class _ItemCatalog {
  _ItemCatalog._({
    required this.itemsById,
    required this.barcodeByCode,
    required this.byNormalizedName,
    required this.activeIngredientsByItem,
    required this.indicationIdsByItem,
    required this.unitsByItem,
  });

  final Map<String, ItemRow> itemsById;
  final Map<String, ItemRow> barcodeByCode;
  final Map<String, List<ItemRow>> byNormalizedName;
  final Map<String, List<ItemActiveIngredientRow>> activeIngredientsByItem;
  final Map<String, List<String>> indicationIdsByItem;
  final Map<String, ItemUnitRow> unitsByItem;

  ItemRow? byBarcode(String code) => barcodeByCode[code];

  static Future<_ItemCatalog> load(InventoryRepository repo) async {
    final items = await repo.allItems();
    final ids = {for (final i in items) i.id};
    final activeIngredientsByItem = await repo
        .activeIngredientRelationsForItems(ids);
    final indicationIdsByItem = await repo.indicationIdsForItems(ids);
    final unitsByItem = await repo.itemUnitsForItems(ids);

    final byId = <String, ItemRow>{for (final i in items) i.id: i};
    final barcodeByCode = <String, ItemRow>{};
    for (final i in items) {
      if (i.primaryBarcode case final b when b != null && b.isNotEmpty) {
        barcodeByCode[b] = i;
      }
      if (i.secondaryBarcode case final b when b != null && b.isNotEmpty) {
        barcodeByCode[b] = i;
      }
    }
    final byName = <String, List<ItemRow>>{};
    for (final i in items) {
      final normalized = SmartSearch.normalize(i.tradeName);
      byName.putIfAbsent(normalized, () => []).add(i);
    }

    return _ItemCatalog._(
      itemsById: byId,
      barcodeByCode: barcodeByCode,
      byNormalizedName: byName,
      activeIngredientsByItem: activeIngredientsByItem,
      indicationIdsByItem: indicationIdsByItem,
      unitsByItem: unitsByItem,
    );
  }
}

/// A parsed, validation-ready import row. [rowNumber] is the 1-based Excel
/// row for error reporting; [barcode] is the matching key; [existingItemId] is
/// populated when the row matched an existing item (by barcode or trade name).
class ImportRow {
  const ImportRow({
    required this.draft,
    required this.rowNumber,
    this.barcode,
    this.existingItemId,
  });

  final ItemDraft draft;
  final int rowNumber;
  final String? barcode;
  final String? existingItemId;
}

/// An auto-created master-data row reported by the importer (Phase 18.3). When
/// a sheet row references a category/manufacturer/active ingredient/indication/
/// unit that does not exist yet, the importer creates it and reports it here so
/// the caller can audit the creation like a normal master-data create.
class CreatedMasterRecord {
  const CreatedMasterRecord({
    required this.entityType,
    required this.entityId,
    required this.name,
  });

  final String entityType;
  final String entityId;
  final String name;
}
