import 'package:excel/excel.dart';

import '../../../../core/data_grid/page_request.dart';
import '../../../../core/money/money.dart';
import '../../../../shared/database/app_database.dart';
import '../../domain/entities/inventory_item.dart';
import '../repositories/inventory_repository.dart';

/// Excel (.xlsx) export/import of item master data (§27, "Excel import/export").
///
/// Export writes the full §5 profile plus live stock snapshot. Import accepts
/// the same header layout; master-data entities are matched by *name*
/// (categories, manufacturers, active ingredients, indications, units) and
/// items are matched by primary barcode, falling back to trade name (create or
/// update). The only hard requirement per row is a non-empty trade name.
/// The sheet keeps a fixed Arabic header row. Phase 18.1: the المكافئ /
/// الشكل الصيدلاني / الجرعة / الحجم columns were appended at the end (indices
/// 23–26) so previously exported files stay positionally valid, and a blank
/// cell for an existing item preserves the current value (financial fields,
/// stock limits, location, barcodes, expiry flag, ingredients, indications,
/// units and the four appended fields are never overwritten by a blank).
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
    sheet.appendRow([
      for (final h in headers) TextCellValue(h),
    ]);
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
            [for (final i in v.activeIngredients) _ingredientCell(i)].join('; ')),
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
      (ref.strength?.isNotEmpty ?? false) ? '${ref.name}:${ref.strength}' : ref.name;

  // ----- Import -----

  /// Parses bytes into import rows, resolving master-data by name. Rows that
  /// cannot be matched cleanly are reported in [ExcelImportIssues].
  Future<({List<ImportRow> rows, List<String> issues})> parseImport(
      List<int> bytes) async {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[_sheetName];
    if (sheet == null || sheet.maxRows == 0) {
      return (rows: const <ImportRow>[], issues: const ['ملف بدون أوراق بيانات']);
    }

    // Pre-load master-data lookups outside the loop.
    final categories = await _repo.categories();
    final byCategoryName = {for (final c in categories) c.name.trim(): c};
    final manufacturers = await _repo.manufacturers();
    final byManufacturerName = {for (final m in manufacturers) m.name.trim(): m};
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

    final issues = <String>[];
    final rows = <ImportRow>[];
    final seenKeys = <String>{};
    for (var r = 1; r < sheet.maxRows; r++) {
      final values = sheet.row(r);
      String at(int idx) =>
          _cellToText(values.length > idx ? values[idx]?.value : null).trim();

      final barcode = at(_colIndex['الرمز الشريطي الرئيسي']!);
      final tradeName = at(_colIndex['الاسم التجاري']!);
      if (tradeName.isEmpty) continue;
      final existing = await _matchingItem(barcode, tradeName);

      // Duplicate matching key within the file.
      final key = barcode.isNotEmpty ? 'b:$barcode' : 't:${tradeName.toLowerCase()}';
      if (existing == null && seenKeys.contains(key)) {
        issues.add('الصف ${r + 1}: ${barcode.isNotEmpty ? 'الرمز' : 'الاسم'} "$key" مكرر داخل الملف');
        continue;
      }
      seenKeys.add(key);

      final categoryName = at(_colIndex['التصنيف']!);
      final category = categoryName.isEmpty
          ? null
          : byCategoryName[categoryName];
      if (categoryName.isNotEmpty && category == null) {
        issues.add('الصف ${r + 1}: التصنيف "$categoryName" غير معروف');
        continue;
      }

      final manufacturerName = at(_colIndex['الشركة المصنعة']!);
      final manufacturer = manufacturerName.isNotEmpty
          ? byManufacturerName[manufacturerName]
          : null;
      if (manufacturerName.isNotEmpty && manufacturer == null) {
        issues.add('الصف ${r + 1}: الشركة "$manufacturerName" غير معروفة');
        continue;
      }

      // Relational active ingredients encoded as `name:strength` pairs
      // separated by ';' (strength optional, §4.2b). A blank cell for an
      // existing item preserves its current relational set.
      final rawIngredients = at(_colIndex['المواد الفعالة']!).trim();
      var ingredientIds = <String>[];
      var ingredientStrengths = <String, String>{};
      var ingredientsOk = true;
      if (rawIngredients.isEmpty && existing != null) {
        final rels = await _repo.activeIngredientRelationsForItem(existing.id);
        ingredientIds = [for (final r in rels) r.activeIngredientId];
        ingredientStrengths = {
          for (final r in rels)
            if ((r.strength ?? '').isNotEmpty) r.activeIngredientId: r.strength!,
        };
      } else {
        for (final entry in _splitEntries(rawIngredients)) {
          final (name, strength) = _splitPair(entry);
          final ingredient = byIngredientName[name];
          if (ingredient == null) {
            issues.add('الصف ${r + 1}: المادة الفعالة "$name" غير معروفة');
            ingredientsOk = false;
            break;
          }
          ingredientIds.add(ingredient.id);
          if (strength.isNotEmpty) ingredientStrengths[ingredient.id] = strength;
        }
      }
      if (!ingredientsOk) continue;

      final rawIndications = at(_colIndex['الاستطبابات']!).trim();
      var indicationIds = <String>[];
      var indicationsOk = true;
      if (rawIndications.isEmpty && existing != null) {
        indicationIds = await _repo.indicationIdsForItem(existing.id);
      } else {
        for (final name in _splitEntries(rawIndications)) {
          final indication = byIndicationName[name];
          if (indication == null) {
            issues.add('الصف ${r + 1}: الاستطباب "$name" غير معروف');
            indicationsOk = false;
            break;
          }
          indicationIds.add(indication.id);
        }
      }
      if (!indicationsOk) continue;

      final baseName = at(_colIndex['الأجزاء']!);
      final largeName = at(_colIndex['التعبئة التجارية']!);
      final baseUnit = baseName.isEmpty ? null : byUnitName[baseName];
      final largeUnit = largeName.isEmpty ? null : byUnitName[largeName];
      if (baseName.isNotEmpty && (baseUnit == null || largeUnit == null)) {
        issues.add(
            'الصف ${r + 1}: الوحدات "$baseName" / "$largeName" غير معروفة');
        continue;
      }

      // Unit relation: from the sheet when complete, otherwise preserved for
      // existing items (optional for new ones, Phase 18).
      final existingUnits =
          existing == null ? null : await _repo.itemUnitsFor(existing.id);
      final ItemUnitRelation? relation =
          baseUnit != null && largeUnit != null
              ? ItemUnitRelation(
                  baseUnitId: baseUnit.id,
                  largeUnitId: largeUnit.id,
                  unitsPerLarge:
                      _parseInt(at(_colIndex['عدد الأجزاء']!)) ?? 1,
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
        secondaryBarcode: _orNull(at(_colIndex['الرمز الشريطي الثانوي']!)) ??
            existing?.secondaryBarcode,
        tradeName: tradeName,
        tradeNameEn:
            _orNull(at(_colIndex['الاسم التجاري (EN)']!)) ?? existing?.tradeNameEn,
        scientificName:
            _orNull(at(_colIndex['الاسم العلمي']!)) ?? existing?.scientificName,
        activeIngredient:
            _orNull(at(_colIndex['المادة الفعالة']!)) ?? existing?.activeIngredient,
        equivalentDrug:
            _orNull(at(_colIndex['المكافئ']!)) ?? existing?.equivalentDrug,
        pharmaForm:
            _orNull(at(_colIndex['الشكل الصيدلاني']!)) ?? existing?.pharmaForm,
        dose: _orNull(at(_colIndex['الجرعة / العيار']!)) ?? existing?.dose,
        sizeVolume: _orNull(at(_colIndex['الحجم']!)) ?? existing?.sizeVolume,
        categoryId: category?.id ?? existing?.categoryId,
        manufacturerId: manufacturer?.id ?? existing?.manufacturerId,
        shelfLocation: _orNull(at(_colIndex['الموقع']!)) ?? existing?.shelfLocation,
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
        activeIngredientIds: ingredientIds,
        activeIngredientStrengths: ingredientStrengths,
        indicationIds: indicationIds,
        // Fields the sheet does not model are preserved untouched on update so
        // an import is an in-place edit of the product master (lossless
        // round-trip, Phase 18.1).
        isControlledDrug: existing?.isControlledDrug ?? false,
        lockAutoPriceUpdate: existing?.lockAutoPriceUpdate ?? false,
        requiresPrescription: existing?.requiresPrescription ?? false,
        customPrice1Micros: existing?.customPrice1Micros ?? 0,
        customPrice2Micros: existing?.customPrice2Micros ?? 0,
        purchaseDiscountBasisPoints:
            existing?.purchaseDiscountBasisPoints ?? 0,
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
      rows.add(ImportRow(
        draft: draft,
        rowNumber: r + 1,
        barcode: barcode.isEmpty ? null : barcode,
        existingItemId: existing?.id,
      ));
    }
    return (rows: rows, issues: issues);
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

  Future<ItemRow?> _matchingItem(String barcode, String tradeName) async {
    final all = await _repo.searchItems(const PageRequest(pageSize: 10000));
    if (barcode.isNotEmpty) {
      for (final row in all.items) {
        if (row.primaryBarcode == barcode || row.secondaryBarcode == barcode) {
          return row;
        }
      }
    }
    for (final row in all.items) {
      if (row.tradeName.trim().toLowerCase() == tradeName.toLowerCase()) {
        return row;
      }
    }
    return null;
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
    final cleaned = _toAsciiDigits(raw)
        .replaceAll(',', '')
        .replaceAll('٬', '')
        .trim();
    if (cleaned.isEmpty) return null;
    return int.tryParse(cleaned);
  }

  /// Parses a monetary cell via [Money] (integer micro-units, never REAL).
  static int? _parseMoney(String raw) {
    final cleaned = _toAsciiDigits(raw)
        .replaceAll(',', '')
        .replaceAll('٬', '')
        .replaceAll('٫', '.')
        .trim();
    if (cleaned.isEmpty) return 0;
    try {
      return Money.parse(cleaned).units;
    } on FormatException {
      return null;
    }
  }

  static String _toAsciiDigits(String input) =>
      input.split('').map((c) {
        final code = c.codeUnitAt(0);
        if (code >= 0x0660 && code <= 0x0669) {
          return String.fromCharCode(code - 0x0660 + 0x30);
        }
        return c;
      }).join();

  static String? _orNull(String value) => value.isEmpty ? null : value;
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