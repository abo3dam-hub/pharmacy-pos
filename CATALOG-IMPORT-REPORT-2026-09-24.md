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
