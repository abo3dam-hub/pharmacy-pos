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
/// (categories, sub-categories, manufacturers, therapeutic groups, units) and
/// items are matched by primary barcode (create or update).
/// The sheet keeps a fixed Arabic header row for every target.
class InventoryExcelService {
  const InventoryExcelService(this._repo);

  final InventoryRepository _repo;

  static const String _sheetName = 'products';

  /// Column keys (header text) shared by export and import. Phase 17 product
  /// model: التعبئة التجارية / الأجزاء / عدد الأجزاء replace the old unit
  /// naming; sub-category, therapeutic group and sub-unit price columns are
  /// gone from the template.
  static const List<String> headers = [
    'الرمز الشريطي الرئيسي',
    'الرمز الشريطي الثانوي',
    'الاسم التجاري',
    'الاسم التجاري (EN)',
    'الاسم العلمي',
    'المادة الفعالة',
    'التصنيف',
    'الشركة المصنعة',
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
  ];

  static const Map<String, int> _colIndex = {
    'الرمز الشريطي الرئيسي': 0,
    'الرمز الشريطي الثانوي': 1,
    'الاسم التجاري': 2,
    'الاسم التجاري (EN)': 3,
    'الاسم العلمي': 4,
    'المادة الفعالة': 5,
    'التصنيف': 6,
    'الشركة المصنعة': 7,
    'الموقع': 8,
    'له تاريخ صلاحية': 9,
    'الأجزاء': 10,
    'التعبئة التجارية': 11,
    'عدد الأجزاء': 12,
    'سعر البيع': 13,
    'سعر الجملة': 14,
    'سعر الجملة النصف': 15,
    'ضريبة %': 16,
    'سعر التكلفة': 17,
    'الحد الأدنى': 18,
    'الحد الأقصى': 19,
    'المخزون الحالي': 20,
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
        TextCellValue(v.categoryName ?? ''),
        TextCellValue(v.manufacturerName ?? ''),
        TextCellValue(item.shelfLocation ?? ''),
        BoolCellValue(item.hasExpiry),
        TextCellValue(v.baseUnitName ?? ''),
        TextCellValue(v.largeUnitName ?? ''),
        IntCellValue(units?.unitsPerLarge ?? 1),
        TextCellValue(Money.fromUnits(item.sellingPriceMicros).format()),
        TextCellValue(Money.fromUnits(item.wholesalePriceMicros).format()),
        TextCellValue(Money.fromUnits(item.halfWholesalePriceMicros).format()),
        IntCellValue(item.vatRateBasisPoints ~/ 100),
        TextCellValue(Money.fromUnits(item.costMicros).format()),
        IntCellValue(item.minimumStockBase),
        IntCellValue(item.maximumStockBase),
        IntCellValue(item.currentStockBase),
      ]);
    }
    return excel.save(fileName: 'inventory.xlsx')!;
  }

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

    final issues = <String>[];
    final rows = <ImportRow>[];
    for (var r = 1; r < sheet.maxRows; r++) {
      final values = sheet.row(r);
      String at(int idx) =>
          _cellToText(values.length > idx ? values[idx]?.value : null).trim();

      final barcode = at(_colIndex['الرمز الشريطي الرئيسي']!);
      final tradeName = at(_colIndex['الاسم التجاري']!);
      if (tradeName.isEmpty) continue;
      final existing = barcode.isNotEmpty ? await _matchingItem(barcode) : null;

      // Duplicate barcode within the file.
      if (existing == null &&
          rows.any((row) => row.barcode == barcode && barcode.isNotEmpty)) {
        issues.add('الصف ${r + 1}: الرمز "$barcode" مكرر داخل الملف');
        continue;
      }

      final categoryName = at(_colIndex['التصنيف']!);
      CategoryRow? category;
      if (categoryName.isNotEmpty) {
        category = byCategoryName[categoryName];
        if (category == null) {
          issues.add('الصف ${r + 1}: التصنيف "$categoryName" غير معروف');
          continue;
        }
      }

      final manufacturerName = at(_colIndex['الشركة المصنعة']!);
      final manufacturer = manufacturerName.isNotEmpty
          ? byManufacturerName[manufacturerName]
          : null;
      if (manufacturerName.isNotEmpty && manufacturer == null) {
        issues.add('الصف ${r + 1}: الشركة "$manufacturerName" غير معروفة');
        continue;
      }

      final baseName = at(_colIndex['الأجزاء']!);
      final largeName = at(_colIndex['التعبئة التجارية']!);
      final baseUnit = baseName.isEmpty ? null : byUnitName[baseName];
      final largeUnit = largeName.isEmpty ? null : byUnitName[largeName];
      if (baseName.isNotEmpty && (baseUnit == null || largeUnit == null)) {
        issues.add(
            'الصف ${r + 1}: الوحدات "$baseName" / "$largeName" غير معروفة');
        continue;
      }

      // Unit relation: from the sheet when given, otherwise preserved for
      // existing items (and mandatory for new ones).
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
      if (existing == null && relation == null) {
        issues.add('الصف ${r + 1}: الوحدات مطلوبة للمنتج الجديد');
        continue;
      }

      final selling = _parseMoney(at(_colIndex['سعر البيع']!));
      final wholesale = _parseMoney(at(_colIndex['سعر الجملة']!));
      final half = _parseMoney(at(_colIndex['سعر الجملة النصف']!));
      final cost = _parseMoney(at(_colIndex['سعر التكلفة']!));
      if (selling == null || cost == null) {
        issues.add('الصف ${r + 1}: قيم مالية غير صالحة');
        continue;
      }

      // Category is mandatory for new items; keep the persisted one on update.
      final categoryId = category?.id ??
          (existing?.categoryId ??
              (categoryName.isNotEmpty ? null : existing?.categoryId));
      if (categoryId == null || categoryId.isEmpty) {
        issues.add('الصف ${r + 1}: التصنيف مطلوب للمنتج الجديد');
        continue;
      }

      final draft = ItemDraft(
        primaryBarcode: barcode.isEmpty ? null : barcode,
        secondaryBarcode:
            _orNull(at(_colIndex['الرمز الشريطي الثانوي']!)),
        tradeName: tradeName,
        tradeNameEn: _orNull(at(_colIndex['الاسم التجاري (EN)']!)),
        scientificName: _orNull(at(_colIndex['الاسم العلمي']!)),
        activeIngredient: _orNull(at(_colIndex['المادة الفعالة']!)),
        categoryId: categoryId,
        subCategoryId: existing?.subCategoryId,
        therapeuticGroupId: existing?.therapeuticGroupId,
        manufacturerId: manufacturer?.id ?? existing?.manufacturerId,
        shelfLocation: _orNull(at(_colIndex['الموقع']!)),
        hasExpiry: _cellBool(values, _colIndex['له تاريخ صلاحية']!),
        sellingPriceMicros: selling,
        subUnitPriceMicros: existing?.subUnitPriceMicros ?? selling,
        wholesalePriceMicros:
            wholesale ?? existing?.wholesalePriceMicros ?? selling,
        halfWholesalePriceMicros:
            half ?? existing?.halfWholesalePriceMicros ?? selling,
        vatRateBasisPoints: (_parseInt(at(_colIndex['ضريبة %']!)) ?? 0) * 100,
        costMicros: cost,
        minimumStockBase: _parseInt(at(_colIndex['الحد الأدنى']!)) ?? 0,
        maximumStockBase: _parseInt(at(_colIndex['الحد الأقصى']!)) ?? 0,
        units: relation,
      );
      rows.add(ImportRow(
        draft: draft,
        rowNumber: r + 1,
        barcode: barcode.isEmpty ? null : barcode,
      ));
    }
    return (rows: rows, issues: issues);
  }

  Future<ItemRow?> _matchingItem(String barcode) async {
    final all = await _repo.searchItems(const PageRequest(pageSize: 10000));
    for (final row in all.items) {
      if (row.primaryBarcode == barcode || row.secondaryBarcode == barcode) {
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
/// row for error reporting; [barcode] is the matching key.
class ImportRow {
  const ImportRow({
    required this.draft,
    required this.rowNumber,
    this.barcode,
  });

  final ItemDraft draft;
  final int rowNumber;
  final String? barcode;
}