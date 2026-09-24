#!/usr/bin/env python3
"""Convert the Zena drug catalog CSV into the pharmacy-pos Excel import format.

Source (UTF-8 CSV, 12 columns):
    barcode | name (AR) | nameEn | form | package | uses | dosage |
    price | company_name | fact | ...

Target: .xlsx with the sheet/headers from
`lib/features/inventory/domain/services/inventory_excel_service.dart`
(`products` sheet, Arabic headers).

Mapping decisions (see CATALOG-IMPORT-REPORT-2026-09-24.md):
- barcode cell may hold several comma-separated barcodes:
  first -> primary, second -> secondary, rest dropped.
- `form` ("paracetamol 500mg / c-tab") feeds:
  * المادة الفعالة (free text, whole string),
  * المواد الفعالة (relational `name:strength` pairs joined by ';'),
  * الشكل الصيدلاني (Arabic, parsed from the suffix),
  * الأجزاء (sub-unit, e.g. شريط/أمبول) when fact > 1.
- Unit relation is only written when fact > 1:
  الأجزاء=<sub-unit>, التعبئة التجارية=علبة, عدد الأجزاء=fact.
  The importer converts the package cost to a per-part cost itself.
- سعر البيع left blank (0) on purpose: no sale prices in the catalog.
- `uses`: ',' treated as an indication separator (-> '؛'); '/' kept as-is.
- له تاريخ صلاحية / stock / category / location left blank.

Usage:
    python3 tool/convert_zena_catalog.py <input.csv> <output.xlsx>
"""

from __future__ import annotations

import csv
import re
import sys
from collections import Counter

from openpyxl import Workbook

HEADERS = [
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
]

# form suffix -> (sub-unit, pharmaceutical form in Arabic)
FORM_MAP = {
    'c-tab': ('شريط', 'مضغوطات مغلفة'),
    'tab': ('شريط', 'مضغوطات'),
    'chew-tab': ('شريط', 'مضغوطات للمضغ'),
    'chewtab': ('شريط', 'مضغوطات للمضغ'),
    'efferv-tab': ('شريط', 'مضغوطات فوارة'),
    'eff-tab': ('شريط', 'مضغوطات فوارة'),
    'sr-tab': ('شريط', 'مضغوطات مديدة التحرر'),
    'xr-tab': ('شريط', 'مضغوطات مديدة التحرر'),
    'er-tab': ('شريط', 'مضغوطات مديدة التحرر'),
    'dr-tab': ('شريط', 'مضغوطات مغلفة معويا'),
    'loz': ('شريط', 'أقراص مص'),
    'cap': ('شريط', 'كبسولات'),
    'sr-cap': ('شريط', 'كبسولات مديدة التحرر'),
    'dr-cap': ('شريط', 'كبسولات مغلفة معويا'),
    'soft-cap': ('شريط', 'كبسولات رخوة'),
    'softcap': ('شريط', 'كبسولات رخوة'),
    'amp': ('أمبول', 'أمبولات'),
    'vial': ('فيال', 'فيال'),
    'supp': ('تحميلة', 'تحاميل'),
    'ovule': ('تحميلة', 'تحاميل مهبلية'),
    'sachet': ('ظرف', 'أظرف'),
    'puff': ('بخاخ', 'بخاخات'),
    'spray': ('بخاخ', 'بخاخات'),
    'drops': ('نقطة', 'نقط'),
    'drop': ('نقطة', 'نقط'),
    'ml': ('مل', 'شراب'),
    'gr': ('غرام', 'كريم / مرهم'),
    'gel': ('غرام', 'جل'),
    'dose': ('بخاخ', 'بخاخات'),
}

# Arabic name keywords -> (sub-unit, form) fallback when `form` is empty.
NAME_FALLBACK = [
    ('قرص', ('شريط', 'مضغوطات')),
    ('مضغوط', ('شريط', 'مضغوطات')),
    ('كبسول', ('شريط', 'كبسولات')),
    ('امبول', ('أمبول', 'أمبولات')),
    ('أمبول', ('أمبول', 'أمبولات')),
    ('فيال', ('فيال', 'فيال')),
    ('تحميل', ('تحميلة', 'تحاميل')),
    ('ظرف', ('ظرف', 'أظرف')),
    ('بخاخ', ('بخاخ', 'بخاخات')),
    ('قطرة', ('نقطة', 'نقط')),
    ('نقط', ('نقطة', 'نقط')),
    ('شراب', ('مل', 'شراب')),
    ('معلق', ('مل', 'معلق')),
    ('كريم', ('غرام', 'كريم')),
    ('مرهم', ('غرام', 'مرهم')),
    ('جل', ('غرام', 'جل')),
    ('لصاقة', ('لصاقة', 'لصاقات')),
    ('بودرة', ('ظرف', 'بودرة')),
]

_ING_RE = re.compile(r'^([A-Za-z][A-Za-z .\-]*?)\s*(\d[\w./%]*)\s*$')


def split_barcodes(cell: str) -> list[str]:
    parts = [p.strip().rstrip(',').strip() for p in cell.split(',')]
    return [p for p in parts if p]


def parse_ingredients(form_main: str) -> list[tuple[str, str]]:
    """'amoxicillin 875mg+clavulanicAcid 125mg' -> [('amoxicillin','875mg'), ...]."""
    out: list[tuple[str, str]] = []
    for chunk in form_main.split('+'):
        chunk = chunk.strip().rstrip('.')
        if not chunk:
            continue
        m = _ING_RE.match(chunk)
        if m:
            out.append((m.group(1).strip(), m.group(2).strip()))
        else:
            out.append((chunk, ''))
    return out


def form_parts(form: str) -> tuple[str, str, str, str]:
    """Return (ingredients_relational, form_free_text, subunit, pharma_form_ar)."""
    form = form.strip()
    if not form:
        return '', '', '', ''
    chunks = [c.strip() for c in form.split('/')]
    main = chunks[0]
    suffix = chunks[-1].lower().strip().rstrip('.') if len(chunks) > 1 else ''
    ingredients = parse_ingredients(main)
    relational = ';'.join(
        f'{n}:{s}' if s else n for n, s in ingredients
    )
    subunit, form_ar = FORM_MAP.get(suffix, ('', ''))
    return relational, form, subunit, form_ar


def fallback_unit(ar_name: str) -> tuple[str, str]:
    for kw, val in NAME_FALLBACK:
        if kw in ar_name:
            return val
    return '', ''


def convert(src: str, dst: str) -> dict:
    stats = Counter()
    with open(src, encoding='utf-8') as f:
        reader = csv.reader(f)
        next(reader)  # header
        rows = list(reader)

    wb = Workbook()
    ws = wb.active
    ws.title = 'products'
    ws.append(HEADERS)

    for r in rows:
        stats['rows'] += 1
        barcode_cell, name, name_en, form, package, uses, dosage, price, company, fact = (
            r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10],
        )
        if not name.strip():
            stats['skipped_no_name'] += 1
            continue

        bcs = split_barcodes(barcode_cell)
        primary = bcs[0] if len(bcs) > 0 else ''
        secondary = bcs[1] if len(bcs) > 1 else ''
        if len(bcs) > 2:
            stats['extra_barcodes_dropped'] += len(bcs) - 2

        relational, form_text, subunit, form_ar = form_parts(form)
        if not subunit:
            subunit, fb_form = fallback_unit(name)
            if not form_ar:
                form_ar = fb_form
            if subunit:
                stats['unit_from_arabic_name'] += 1
        if form and not relational:
            stats['ingredient_parse_empty'] += 1

        try:
            parts = int(fact.strip()) if fact.strip() else 1
        except ValueError:
            parts = 1
            stats['bad_fact'] += 1
        if parts < 1:
            parts = 1

        if parts > 1 and subunit:
            base_unit, large_unit, n_parts = subunit, 'علبة', parts
            stats['with_unit_relation'] += 1
        elif parts > 1:
            base_unit, large_unit, n_parts = '', '', parts
            stats['parts_gt1_no_subunit'] += 1
        else:
            base_unit, large_unit, n_parts = '', '', ''

        indications = uses.strip().replace(',', '؛')

        ws.append([
            primary,                 # الرمز الشريطي الرئيسي
            secondary,               # الرمز الشريطي الثانوي
            name.strip(),            # الاسم التجاري
            name_en.strip(),         # الاسم التجاري (EN)
            '',                      # الاسم العلمي
            form_text,               # المادة الفعالة (free text)
            relational,              # المواد الفعالة (relational)
            '',                      # التصنيف
            company.strip(),         # الشركة المصنعة
            indications,             # الاستطبابات
            '',                      # الموقع
            '',                      # له تاريخ صلاحية
            base_unit,               # الأجزاء
            large_unit,              # التعبئة التجارية
            n_parts,                 # عدد الأجزاء
            '',                      # سعر البيع (0 on purpose)
            '',                      # سعر الجملة
            '',                      # سعر الجملة النصف
            '',                      # ضريبة %
            price.strip(),           # سعر التكلفة (per package; importer converts)
            '',                      # الحد الأدنى
            '',                      # الحد الأقصى
            '',                      # المخزون الحالي
            '',                      # المكافئ
            form_ar,                 # الشكل الصيدلاني
            dosage.strip(),          # الجرعة / العيار
            '',                      # الحجم
        ])

    wb.save(dst)
    stats['written'] = ws.max_row - 1
    return dict(stats)


def main() -> None:
    if len(sys.argv) != 3:
        print('usage: convert_zena_catalog.py <input.csv> <output.xlsx>')
        sys.exit(2)
    stats = convert(sys.argv[1], sys.argv[2])
    for k, v in stats.items():
        print(f'{k}: {v}')


if __name__ == '__main__':
    main()
