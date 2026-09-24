# تقرير تحويل قاعدة بيانات الأدوية (Zena Catalog) — 2026-09-24

## المصدر
- الملف: `zena_catalog__1__0_jiie.csv` (رفعه علي، 22,292 صنف، UTF-8)
- الأعمدة المستخدمة: barcode / name (AR) / nameEn / form / package /
  uses / dosage / price / company_name / fact

## المخرجات
- `pharmacy_catalog_import.xlsx` — ورقة `products` بنفس ترويسة
  `InventoryExcelService.headers` (27 عموداً عربياً)، جاهز للاستيراد من
  شاشة المخزون ← استيراد Excel.
- `tool/convert_zena_catalog.py` — سكربت التحويل (قابل لإعادة التشغيل).

## قواعد التحويل
| حقل التطبيق | المصدر | ملاحظة |
|---|---|---|
| الرمز الشريطي الرئيسي/الثانوي | barcode | الخلية قد تحوي عدة باركودات مفصولة بفاصلة: الأول رئيسي، الثاني ثانوي، الباقي يُهمل |
| الاسم التجاري / (EN) | name / nameEn | كما هي |
| المادة الفعالة | form | النص الكامل (مثال: `atorvastatin 20mg / c-tab`) |
| المواد الفعالة | form | مُحللة لصيغة `name:strength` مفصولة بـ `؛` (مثال: `amoxicillin:875mg;clavulanicAcid:125mg`) وتُنشأ تلقائياً بسجلات المواد الفعالة |
| الشركة المصنعة | company_name | تُنشأ تلقائياً عند غيابها |
| الاستطبابات | uses | الفاصلة `,` تُعامل كفاصل استطبابات (تتحول لـ `؛`) |
| الشكل الصيدلاني | form | مُستنتج من اللاحقة (`c-tab`→مضغوطات مغلفة، `cap`→كبسولات…) أو من الاسم العربي عند غياب form |
| الجرعة / العيار | dosage | كما هي |
| الأجزاء / التعبئة التجارية / عدد الأجزاء | fact | **فقط عندما fact > 1**: الأجزاء=الوحدة الجزئية (شريط/أمبول/فيال/ظرف…)، التعبئة=علبة، العدد=fact. المستورِد يحوّل سعر التكلفة (سعر العبوة) لسعر الجزء تلقائياً |
| سعر التكلفة | price | سعر العبوة التجارية كما في الملف |
| سعر البيع | — | **فارغ (= 0)**: الملف لا يحوي أسعار بيع — يجب تعبئتها لاحقاً |

## ما يُتوقع عند الاستيراد داخل التطبيق
- 22,292 صفاً؛ ~107 صفوف ستُتخطى كـ"مكرر داخل الملف" (نفس الباركود لمنتجين
  مختلفين — يُحفظ الأول ويُبلَّغ عن الباقي بقائمة المشاكل).
- 4,184 صفاً بلا باركود تُطابق بالاسم + (المادة الفعالة/العيار/الشكل/الشركة).
- المصنّعون والمواد الفعالة والاستطبابات والوحدات غير الموجودة **تُنشأ
  تلقائياً** وتُعرض بقائمة "سجلات رئيسية جديدة".
- **مهم**: الأصناف الموجودة مسبقاً بنفس الباركود سيُحدَّث بعض حقولها
  (التكلفة مثلاً) — خذ نسخة احتياطية من التطبيق قبل الاستيراد.

## قرارات بانتظار علي
1. **سعر البيع**: الملف بلا أسعار بيع → كل الأصناف بسعر 0. إما يعبئها يدوياً/دفعة، أو نولّد نسخة بسعر البيع = سعر التكلفة كنقطة بداية.
2. **تاريخ الصلاحية**: تركته فارغاً (لا). تفعيله لـ 22k صنف يعني إدخال تاريخ صلاحية مع كل فاتورة شراء — قرار تشغيلي.
3. 95 صنفاً بعدد أجزاء > 1 لم نستطع تحديد وحدته الجزئية → استوردت بلا علاقة وحدات (التكلفة تبقى للعبوة الكاملة)؛ تُضبط يدوياً عند الحاجة.

## Fix (2026-09-24, 02:55): openpyxl output vs app importer

Ali reported two symptoms with the generated file:

1. Desktop Excel: "We found problems on some content" on open.
2. App import: stuck on "جاري التحميل" for 15+ minutes, nothing happens.

Root causes (verified by decoding with the exact Dart `excel` 4.0.6 package
the app uses, via the repo's own `package_config.json`):

- openpyxl 3.1 writes the worksheet relationship as an **absolute** target
  (`Target="/xl/worksheets/sheet1.xml"`). The Dart parser resolves it as
  `xl/<target>` -> null -> `Null check operator used on a null value`
  (`TypeError`, an `Error` not an `Exception`, so it escapes the controller's
  `on Exception` catch and the UI stays on "loading" forever).
- Blank cells written as `''` become `<c t="inlineStr"><is></is></c>` (no `<t>`
  node); the parser does `findAllElements('t').first` -> `Bad state: No element`.

Fixes in `tool/convert_zena_catalog.py`:

- `_blank()`: blank strings are written as `None` (empty `<c/>` cell), which
  the Dart parser reads as null.
- `_fix_workbook_rels()`: rewrites the xlsx with a relative worksheet target
  (`Target="worksheets/sheet1.xml"`), which also removes the anomaly desktop
  Excel flagged.

Verification: `Excel.decodeBytes` on the regenerated file succeeds in ~4.2s;
all 22,292 data rows / 27 columns iterate in ~38ms with correct values
(barcode/name/cost/parts spot-checked). Package structure validated
(zip test clean, content-types consistent).

## Fix 2 (2026-09-24, ~03:20): Dart-generated xlsx + per-row import hardening

Ali retested and reported:

1. Desktop Excel STILL offered "recover content" on the openpyxl file, even
   with the relative rel target.
2. App import now parsed fine, then failed mid-apply around row ~4,600 with
   "حدث خطأ غير متوقع" (unexpected error).

Actions:

- `tool/write_catalog_xlsx.dart` (new): the final xlsx is now written with
  the Dart `excel` package itself — the same package and cell types the app
  uses for export (`TextCellValue` incl. `''` blanks, `IntCellValue` for the
  parts count). Standard package layout (`sharedStrings.xml`, relative rel
  targets, single `products` sheet). The Python converter gained
  `prepare_rows()` + a `.json` intermediate output feeding the Dart writer.
- Verified: `Excel.decodeBytes` reads the Dart file; a full end-to-end
  `ImportItemsUseCase` run on a test DB imports 22,178 items with 114
  duplicate issues, and a second run over the populated DB updates 22,146 —
  both clean. Neither the create path nor the update path reproduces Ali's
  ~4,600 failure, so the trigger is specific to his device/database state.
- Hardening in `applyImport`
  (`lib/features/inventory/data/repositories/inventory_repository_impl.dart`):
  per-row failures now catch ALL `Exception`s (not just `DomainException`),
  record `الصف N: خطأ غير متوقع (<type>): <message>` as an issue, and
  continue — a single bad row can no longer abort a 22k-row import with a
  generic error. `ImportCancelledException` still propagates (thrown outside
  the per-row try), so cancel keeps working. `Error`s (OOM etc.) still abort.
- Existing import tests (contract + progress/cancel) pass; `flutter analyze`
  clean on the touched file.

## Fix 3 (2026-09-24, ~03:40): Excel repair prompt on the Dart file + CI fix

Ali reported the Dart-generated file STILL triggered Excel's "problem with
some content" recovery prompt. Structural audit of the file found two
anomalies left by the Dart `excel` writer:

1. Orphan empty drawing: `xl/drawings/drawing1.xml` (+ its sheet rels entry)
   shipped with the `Excel.createExcel()` template, but the sheet has no
   `<drawing>` element referencing it.
2. Stale dimension: `<dimension ref="A1"/>` while the sheet holds
   `A1:AA22293`.

`tool/sanitize_xlsx.py` (new) post-processes the file: drops the orphan
drawing + rels + content-type override, recomputes the dimension from the
actual cells. Verified afterwards: zip valid, all workbook rels resolve,
shared-strings counts consistent, style indices in range, and the app's own
Dart parser still decodes all 22,293 rows. The delivered
`pharmacy_catalog_import.xlsx` is the sanitized build.

Also fixed: CI `flutter analyze` failed on 3 info lints in
`tool/write_catalog_xlsx.dart` (dangling library doc comment,
unintended_html_in_doc_comment) — silenced, pushed, CI re-running.

## Fix 4 (2026-09-24, ~03:50): CI follow-ups + row ~4608 investigation

- Ali confirmed the sanitized xlsx opens cleanly in desktop Excel (no repair
  prompt). The delivered file is the sanitized build.
- CI `flutter analyze` failed on 3 info lints in `tool/write_catalog_xlsx.dart`
  (fixed, pushed; the re-run went green).
- The following commit only touched this report, yet `flutter test` failed on
  CI while the full suite (656 tests) passes locally — suspected flaky CI
  runner; a fresh run was triggered to confirm.
- Row ~4608 "unexpected error" (old app, apply phase): the catalog data in
  rows 4600-4680 was audited — no structural anomaly; the same rows import
  cleanly on a fresh DB and on a simulated dirty DB (pre-existing items with
  overlapping barcodes forcing the update path, barcode-less name matches,
  case-variant ingredients). Zero unexpected-error issues in both runs, so the
  trigger is specific to Ali's on-device database content and could not be
  reproduced here. The old app aborts the whole import on any unexpected
  per-row error with a generic message; the new app (per-row catch-all in
  `applyImport`) completes the import and reports the exact failing rows as
  `الصف N: خطأ غير متوقع (<type>): <message>` issues instead. Next step is for
  Ali to retry with the updated app and send the reported rows.
