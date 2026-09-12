// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'نظام إدارة الصيدلية';

  @override
  String get appSlogan => 'نظام احترافي لإدارة الصيدلية و نقطة البيع';

  @override
  String get navDashboard => 'الرئيسية';

  @override
  String get navSale => 'مبيعات';

  @override
  String get navInventory => 'المخزون';

  @override
  String get navPurchases => 'المشتريات';

  @override
  String get navCustomers => 'العملاء';

  @override
  String get navSuppliers => 'الموردون';

  @override
  String get navAccounts => 'الحسابات';

  @override
  String get navReports => 'التقارير';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get navUsers => 'المستخدمون';

  @override
  String get navAlternatives => 'البدائل';

  @override
  String get navLostSales => 'النواقص';

  @override
  String get navReturn => 'المرتجعات';

  @override
  String get commonSave => 'حفظ';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonSearch => 'بحث';

  @override
  String get commonAdd => 'إضافة';

  @override
  String get commonDelete => 'حذف';

  @override
  String get commonEdit => 'تعديل';

  @override
  String get commonPrint => 'طباعة';

  @override
  String get commonConfirm => 'تأكيد';

  @override
  String get commonClose => 'إغلاق';

  @override
  String get commonBack => 'رجوع';

  @override
  String get commonNext => 'التالي';

  @override
  String get commonPrevious => 'السابق';

  @override
  String get commonLoading => 'جارٍ التحميل...';

  @override
  String get commonError => 'حدث خطأ';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonNone => 'لا يوجد';

  @override
  String get commonYes => 'نعم';

  @override
  String get commonNo => 'لا';

  @override
  String get commonTotal => 'الإجمالي';

  @override
  String get commonSubtotal => 'المجموع الفرعي';

  @override
  String get commonDiscount => 'الخصم';

  @override
  String get commonTax => 'الضريبة';

  @override
  String get commonChange => 'الباقي';

  @override
  String get commonPaid => 'المدفوع';

  @override
  String get commonProfit => 'الربح';

  @override
  String get loginTitle => 'تسجيل الدخول';

  @override
  String get loginWelcome => 'تسجيل الدخول إلى النظام';

  @override
  String get loginUsername => 'اسم المستخدم';

  @override
  String get loginPassword => 'كلمة المرور';

  @override
  String get loginButton => 'دخول';

  @override
  String get loginFailed => 'اسم المستخدم أو كلمة المرور غير صحيحة';

  @override
  String get loginUserInactive => 'هذا المستخدم غير مفعّل';

  @override
  String get userLogout => 'تسجيل الخروج';

  @override
  String get userRole => 'الدور';

  @override
  String get roleAdmin => 'مدير النظام';

  @override
  String get rolePharmacist => 'صيدلي';

  @override
  String get roleCashier => 'أمين الصندوق';

  @override
  String get roleViewer => 'مشاهد';

  @override
  String get authPermissionDenied => 'ليس لديك صلاحية لتنفيذ هذا الإجراء';

  @override
  String get authSaveError => 'حدث خطأ أثناء حفظ البيانات';

  @override
  String get usersTitle => 'المستخدمون';

  @override
  String get usersList => 'قائمة المستخدمين';

  @override
  String get usersAdd => 'إضافة مستخدم';

  @override
  String get usersCreateTitle => 'إضافة مستخدم جديد';

  @override
  String get usersEditTitle => 'تعديل مستخدم';

  @override
  String get usersSearchHint => 'ابحث عن مستخدم بالاسم أو اسم المستخدم';

  @override
  String get usersEmpty => 'لا يوجد مستخدمون مطابقون';

  @override
  String get userFullName => 'الاسم الكامل';

  @override
  String get userUsername => 'اسم المستخدم';

  @override
  String get userPhone => 'رقم الهاتف';

  @override
  String get userNotes => 'ملاحظات';

  @override
  String get userStatusActive => 'مفعّل';

  @override
  String get userStatusInactive => 'غير مفعّل';

  @override
  String get userLastLogin => 'آخر تسجيل دخول';

  @override
  String get userNeverLoggedIn => 'لم يسجل الدخول بعد';

  @override
  String get userLastLoginLabel => 'دخول أخير';

  @override
  String get userActivate => 'تفعيل';

  @override
  String get userDeactivate => 'تعطيل';

  @override
  String get userDeactivateConfirmTitle => 'تعطيل المستخدم';

  @override
  String userDeactivateConfirmMessage(String name) {
    return 'هل تريد تعطيل المستخدم «$name»؟';
  }

  @override
  String userActivateConfirmMessage(String name) {
    return 'هل تريد تفعيل المستخدم «$name»؟';
  }

  @override
  String get userChangePassword => 'تغيير كلمة المرور';

  @override
  String get userChangePasswordTitle => 'تغيير كلمة المرور';

  @override
  String get userNewPassword => 'كلمة المرور الجديدة';

  @override
  String get userConfirmPassword => 'تأكيد كلمة المرور';

  @override
  String get userPasswordMismatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get userPasswordMinLength =>
      'كلمة المرور يجب أن تكون 6 أحرف على الأقل';

  @override
  String get userRequiredField => 'هذا الحقل مطلوب';

  @override
  String get userUsernameExists => 'اسم المستخدم مستخدم مسبقًا';

  @override
  String get userCreatedMessage => 'تم إنشاء المستخدم';

  @override
  String get userUpdatedMessage => 'تم تحديث المستخدم';

  @override
  String get userActivatedMessage => 'تم تفعيل المستخدم';

  @override
  String get userDeactivatedMessage => 'تم تعطيل المستخدم';

  @override
  String get userPasswordChangedMessage => 'تم تغيير كلمة المرور';

  @override
  String get accessDeniedTitle => 'الوصول مرفوض';

  @override
  String get accessDeniedMessage => 'ليس لديك صلاحية للوصول إلى هذه الصفحة';

  @override
  String get checkout => 'إنهاء البيع';

  @override
  String get holdBill => 'تعليق الفاتورة';

  @override
  String get cartEmpty => 'السلة فارغة';

  @override
  String get notEnoughStock => 'المخزون غير كافٍ';

  @override
  String get price => 'السعر';

  @override
  String get quantity => 'الكمية';

  @override
  String get batchNo => 'رقم الدفعة';

  @override
  String get expiryDate => 'تاريخ الانتهاء';

  @override
  String get unitBoxes => 'علب';

  @override
  String get unitStrips => 'ظروف';

  @override
  String get dashboardTodayOrders => 'طلبات اليوم';

  @override
  String get dashboardDailySales => 'مبيعات اليوم';

  @override
  String get dashboardLowStock => 'أصناف منخفضة المخزون';

  @override
  String get dashboardProfitToday => 'ربح اليوم';

  @override
  String get dashboardKpis => 'نظرة عامة';

  @override
  String get dashboardUnitsSold => 'الوحدات المباعة اليوم';

  @override
  String get dashboardActiveItems => 'المنتجات النشطة';

  @override
  String get dashboardStockValue => 'قيمة المخزون';

  @override
  String get dashboardLowStockEmpty =>
      'لا توجد منتجات منخفضة المخزون — المخزون جيد.';

  @override
  String get dashboardNearExpiry => 'قرب انتهاء الصلاحية';

  @override
  String get dashboardNearExpiryEmpty => 'لا توجد دفعات تنتهي قريبًا.';

  @override
  String get dashboardRecentSales => 'أحدث الفواتير بيعًا';

  @override
  String get dashboardRecentPurchases => 'أحدث المشتريات';

  @override
  String get dashboardRecentEmpty => 'لا يوجد بعد.';

  @override
  String get dashboardError => 'تعذر تحميل لوحة المعلومات.';

  @override
  String get dashboardRetry => 'إعادة المحاولة';

  @override
  String get inventoryLowStock => 'منخفض المخزون';

  @override
  String get inventoryOutOfStock => 'نفد المخزون';

  @override
  String get saleNewSale => 'بيع جديد';

  @override
  String get saleRecentInvoices => 'الفواتير الأخيرة';

  @override
  String get purchaseNewPurchase => 'شراء جديد';

  @override
  String get purchaseRecent => 'فواتير الشراء الأخيرة';

  @override
  String get customersList => 'قائمة العملاء';

  @override
  String get suppliersList => 'قائمة الموردين';

  @override
  String get accountsCashbox => 'الصندوق';

  @override
  String get accountsJournal => 'دفتر اليومية';

  @override
  String get accountsLedger => 'دفتر الأستاذ';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsDatabase => 'قاعدة البيانات';

  @override
  String get settingsBackup => 'النسخ الاحتياطي';

  @override
  String get settingsAppInfo => 'معلومات التطبيق';

  @override
  String get settingsSchemaVersion => 'إصدار المخطط';

  @override
  String get settingsVersion => 'الإصدار';

  @override
  String get itemTradeName => 'الاسم التجاري';

  @override
  String get itemBarcode => 'الباركود';

  @override
  String get itemCategory => 'التصنيف';

  @override
  String get itemUnit => 'الوحدة';

  @override
  String get itemCost => 'التكلفة';

  @override
  String get itemPrice => 'سعر البيع';

  @override
  String get itemStock => 'الرصيد';

  @override
  String get inventoryTabItems => 'المنتجات';

  @override
  String get inventoryTabCategories => 'التصنيفات';

  @override
  String get inventoryTabManufacturers => 'المصنعون';

  @override
  String get inventoryTabUnits => 'الوحدات';

  @override
  String get inventorySearchHint => 'ابحث بالاسم أو الباركود';

  @override
  String get inventoryAddItem => 'إضافة منتج';

  @override
  String get inventoryItemAddTitle => 'إضافة منتج جديد';

  @override
  String get inventoryItemEditTitle => 'تعديل منتج';

  @override
  String get inventoryItemsEmpty => 'لا توجد منتجات مطابقة';

  @override
  String get inventoryActiveFilter => 'المفعّلة فقط';

  @override
  String get inventoryInStock => 'المواد الموجودة في المخزون';

  @override
  String get inventoryProductTree => 'شجرة المواد';

  @override
  String inventoryStockTooltip(String stock, String price) {
    return 'الرصيد الحالي: $stock · سعر البيع: $price';
  }

  @override
  String get inventoryCreatedMessage => 'تم إنشاء المنتج';

  @override
  String get inventoryUpdatedMessage => 'تم تحديث المنتج';

  @override
  String get inventoryActivatedMessage => 'تم تفعيل المنتج';

  @override
  String get inventoryDeactivatedMessage => 'تم إيقاف المنتج';

  @override
  String get inventoryImport => 'استيراد من إكسل';

  @override
  String get inventoryExport => 'تصدير إلى إكسل';

  @override
  String inventoryImportDone(int created, int updated) {
    return 'اكتمل الاستيراد: $created جديدًا، $updated محدّثًا';
  }

  @override
  String inventoryImportIssues(int skipped) {
    return 'سقط $skipped صفًا';
  }

  @override
  String inventoryImportMaster(int count) {
    return 'أُنشئت $count بيانات أساسية جديدة';
  }

  @override
  String get inventoryExportDone => 'تم تصدير الملف';

  @override
  String get inventoryImportFailed => 'تعذر قراءة الملف';

  @override
  String get inventoryImportParsing => 'جارٍ تحليل ملف إكسل...';

  @override
  String get inventoryImportApplying => 'جارٍ استيراد المنتجات...';

  @override
  String inventoryImportProgress(int processed, int total) {
    return '$processed من $total';
  }

  @override
  String get inventoryImportCancel => 'إلغاء الاستيراد';

  @override
  String get inventoryImportCancelled => 'تم إلغاء الاستيراد';

  @override
  String get itemBarcodePrimary => 'الباركود الأساسي';

  @override
  String get itemScientificName => 'الاسم العلمي';

  @override
  String get itemActiveIngredient => 'المادة الفعالة';

  @override
  String get itemTradeNameEn => 'الاسم التجاري (إنجليزي)';

  @override
  String get itemManufacturer => 'المصنع';

  @override
  String get itemPharmaForm => 'الشكل الصيدلاني';

  @override
  String get itemDose => 'الجرعة';

  @override
  String get itemSizeVolume => 'الحجم/السعة';

  @override
  String get itemShelfLocation => 'موقع الرف';

  @override
  String get itemSecondaryBarcode => 'باركود ثانوي';

  @override
  String get itemEquivalentDrug => 'دواء مكافئ';

  @override
  String get itemHasExpiry => 'للتاريخ صلاحية';

  @override
  String get itemIsControlled => 'عقار خاضع لضبط خاص';

  @override
  String get itemLockPriceAutoUpdate => 'قفل التحديث التلقائي للأسعار';

  @override
  String get itemRequiresPrescription => 'يتطلب وصفة طبية';

  @override
  String get itemPurchaseDiscount => 'خصم الشراء';

  @override
  String get itemSellingPrice => 'سعر البيع';

  @override
  String get itemWholesalePrice => 'سعر الجملة';

  @override
  String get itemHalfWholesalePrice => 'سعر نصف الجملة';

  @override
  String get itemCustomPrice1 => 'سعر خاص 1';

  @override
  String get itemCustomPrice2 => 'سعر خاص 2';

  @override
  String get itemVatRate => 'نسبة الضريبة';

  @override
  String get itemMinimumStock => 'الحد الأدنى للمخزون';

  @override
  String get itemMaximumStock => 'الحد الأعلى للمخزون';

  @override
  String get itemUsageInstructions => 'تعليمات الاستخدام';

  @override
  String get itemGeneralNotes => 'ملاحظات عامة';

  @override
  String get itemLicenseNumber => 'رقم الترخيص';

  @override
  String get itemUnitsRelation => 'علاقة الوحدات';

  @override
  String get itemBaseUnit => 'الأجزاء';

  @override
  String get itemLargeUnit => 'الوحدة الكبيرة';

  @override
  String get itemPackagingUnit => 'التعبئة التجارية';

  @override
  String get itemUnitsPerLarge => 'عدد الأجزاء';

  @override
  String get itemSuppliers => 'الموردون';

  @override
  String get itemAddNew => 'إضافة جديد';

  @override
  String get inventoryUnitsRequired => 'يجب تحديد الأجزاء وشكل التعبئة';

  @override
  String get inventorySelectBaseUnit => 'اختر الأجزاء';

  @override
  String get inventorySelectLargeUnit => 'اختر التعبئة التجارية';

  @override
  String get inventoryUnitsPerLargeInvalid =>
      'عدد الأجزاء يجب أن يكون أكبر من صفر';

  @override
  String get itemClassificationSection => 'التصنيف والمعلومات الدوائية';

  @override
  String get itemPricePartsSection => 'التكلفة / السعر / الأجزاء';

  @override
  String get itemCurrentStock => 'الرصيد الحالي';

  @override
  String get itemProfitMargin => 'هامش الربح';

  @override
  String get statusNormal => 'مخزون طبيعي';

  @override
  String get statusHealthy => 'سليمة';

  @override
  String get statusNearExpiry => 'قريب الانتهاء';

  @override
  String get statusExpired => 'منتهٍ';

  @override
  String get batchesTitle => 'تشغيلات المنتج';

  @override
  String get batchesAdd => 'إدخال تشغيلة';

  @override
  String get batchesAddTitle => 'إدخال تشغيلة جديدة';

  @override
  String get batchesVoidTitle => 'إلغاء التشغيلة';

  @override
  String get batchesVoidConfirm => 'هل تريد إلغاء هذه التشغيلة؟';

  @override
  String get batchesAddedMessage => 'تم إدخال التشغيلة';

  @override
  String get batchesVoidedMessage => 'تم إلغاء التشغيلة';

  @override
  String get batchesEmpty => 'لا توجد تشغيلات';

  @override
  String get batchUnitCost => 'تكلفة الوحدة';

  @override
  String get batchReceivedDate => 'تاريخ الاستلام';

  @override
  String get batchBonusQty => 'كمية الهدية';

  @override
  String get batchNotes => 'ملاحظات التشغيلة';

  @override
  String get batchRemaining => 'الرصيد المتبقي';

  @override
  String get batchVoided => 'ملغاة';

  @override
  String get movementType => 'نوع الحركة';

  @override
  String get moveOpening => 'افتتاحي';

  @override
  String get movePurchase => 'شراء';

  @override
  String get moveSale => 'بيع';

  @override
  String get moveSaleReturn => 'مرتجع مبيعات';

  @override
  String get movePurchaseReturn => 'مرتجع شراء';

  @override
  String get moveAdjustment => 'ضبط مخزون';

  @override
  String get moveDamaged => 'تالف';

  @override
  String get moveExpired => 'منتهي الصلاحية';

  @override
  String get moveTransfer => 'تحويل';

  @override
  String get moveCorrection => 'تصحيح يدوي';

  @override
  String get movementsList => 'سجل الحركات';

  @override
  String get movementsDate => 'التاريخ';

  @override
  String get movementsDelta => 'الكمية';

  @override
  String get movementsBalance => 'الرصيد بعد الحركة';

  @override
  String get adjustStockTitle => 'تسوية مخزون';

  @override
  String get adjustStockDone => 'تمت التسوية';

  @override
  String get adjustNote => 'ملاحظة التسوية';

  @override
  String get adjustmentIncrease => 'إضافة رصيد';

  @override
  String get adjustmentDecrease => 'خصم رصيد';

  @override
  String get bulkAction => 'إجراء جماعي';

  @override
  String get bulkTitle => 'إجراءات جماعية';

  @override
  String get bulkChangeCategory => 'تغيير التصنيف';

  @override
  String get bulkChangeShelf => 'تغيير موقع الرف';

  @override
  String get bulkAdjustPricePercent => 'تعديل الأسعار بنسبة';

  @override
  String get bulkPercent => 'النسبة المئوية';

  @override
  String bulkSelectedCount(int count) {
    return 'تم تحديد $count منتج';
  }

  @override
  String bulkDone(int count) {
    return 'اكتملت العملية على $count منتج';
  }

  @override
  String get bulkSelectHint => 'حدد منتجًا واحدًا على الأقل';

  @override
  String get bulkPriceScopeTitle => 'نطاق التعديل';

  @override
  String get bulkPriceScopeAll => 'جميع المنتجات';

  @override
  String get bulkPriceScopeManufacturer => 'منتجات مصنّع محدد';

  @override
  String get bulkPriceScopeSupplier => 'منتجات من مورد محدد';

  @override
  String bulkPriceScopeManual(int count) {
    return 'المنتجات المحددة ($count)';
  }

  @override
  String get categoriesTitle => 'التصنيفات';

  @override
  String get categoriesAdd => 'إضافة تصنيف';

  @override
  String get categoriesAddTitle => 'إضافة تصنيف جديد';

  @override
  String get categoriesEditTitle => 'تعديل تصنيف';

  @override
  String get categoriesEmpty => 'لا توجد تصنيفات';

  @override
  String get categoryName => 'اسم التصنيف';

  @override
  String get categoryNameEn => 'اسم التصنيف (إنجليزي)';

  @override
  String get manufacturerName => 'اسم المصنع';

  @override
  String get manufacturerCountry => 'الدولة';

  @override
  String get manufacturerWebsite => 'الموقع الإلكتروني';

  @override
  String get manufacturersAdd => 'إضافة مصنع';

  @override
  String get manufacturersEditTitle => 'تعديل مصنع';

  @override
  String get manufacturersEmpty => 'لا توجد مصانع';

  @override
  String get groupName => 'اسم المجموعة';

  @override
  String get groupsAdd => 'إضافة مجموعة';

  @override
  String get groupsEditTitle => 'تعديل مجموعة';

  @override
  String get groupsEmpty => 'لا توجد مجموعات';

  @override
  String get unitName => 'اسم الوحدة';

  @override
  String get unitAbbreviation => 'الاختصار';

  @override
  String get activeIngredientName => 'اسم المادة الفعالة';

  @override
  String get indicationName => 'اسم الاستطباب';

  @override
  String get activeIngredientsAdd => 'إضافة مادة فعالة';

  @override
  String get activeIngredientsEditTitle => 'تعديل مادة فعالة';

  @override
  String get activeIngredientsEmpty => 'لا توجد مواد فعالة';

  @override
  String get indicationsAdd => 'إضافة استطباب';

  @override
  String get indicationsEditTitle => 'تعديل استطباب';

  @override
  String get indicationsEmpty => 'لا توجد استطبابات';

  @override
  String get itemActiveIngredients => 'المواد الفعالة';

  @override
  String get activeIngredientStrength => 'العيار';

  @override
  String get itemActiveIngredientsSearch => 'ابحث عن مادة فعالة…';

  @override
  String get itemActiveIngredientsHint =>
      'ابحث وأضف المواد الفعالة مع قوة كل منها (العيار)';

  @override
  String get itemActiveIngredientsRemove => 'إزالة المادة الفعالة';

  @override
  String get itemIndications => 'الاستطبابات';

  @override
  String get inventoryTabActiveIngredients => 'المواد الفعالة';

  @override
  String get inventoryTabIndications => 'الاستطبابات';

  @override
  String get masterDataNameEn => 'الاسم (إنجليزي)';

  @override
  String get unitsAdd => 'إضافة وحدة';

  @override
  String get unitsEditTitle => 'تعديل وحدة';

  @override
  String get unitsEmpty => 'لا توجد وحدات';

  @override
  String get masterDataSavedMessage => 'تم الحفظ بنجاح';

  @override
  String get inventoryRequiredName => 'الاسم مطلوب';

  @override
  String get inventorySelectCategory => 'اختر التصنيف';

  @override
  String get inventoryBatches => 'التشغيلات';

  @override
  String get inventoryAdjustStock => 'تسوية المخزون';

  @override
  String get inventoryBatchView => 'عرض التشغيلات';

  @override
  String get suppliersTab => 'الموردون';

  @override
  String get suppliersBalancesTab => 'الأرصدة';

  @override
  String get suppliersEmpty => 'لا يوجد موردون';

  @override
  String get suppliersSearchHint => 'بحث بالاسم أو الهاتف أو الكود';

  @override
  String get supplierAdd => 'إضافة مورد';

  @override
  String get supplierAddTitle => 'مورد جديد';

  @override
  String get supplierEditTitle => 'تعديل مورد';

  @override
  String get supplierName => 'الاسم';

  @override
  String get supplierCode => 'الكود';

  @override
  String get supplierPhone => 'الهاتف';

  @override
  String get supplierSecondaryPhone => 'هاتف ثانٍ';

  @override
  String get supplierEmail => 'البريد الإلكتروني';

  @override
  String get supplierAddress => 'العنوان';

  @override
  String get supplierContactPerson => 'جهة الاتصال';

  @override
  String get supplierTaxVatNumber => 'الرقم الضريبي';

  @override
  String get supplierLicenseRegistration => 'الترخيص / السجل';

  @override
  String get supplierOpeningBalance => 'الرصيد الافتتاحي';

  @override
  String get supplierCreditLimit => 'الحد الائتماني';

  @override
  String get supplierNotes => 'ملاحظات';

  @override
  String get supplierCreatedMessage => 'تمت إضافة المورد';

  @override
  String get supplierUpdatedMessage => 'تم تعديل المورد';

  @override
  String get supplierActivatedMessage => 'تمت إعادة تفعيل المورد';

  @override
  String get supplierDeactivatedMessage => 'تم تعطيل المورد';

  @override
  String supplierDeactivateConfirmMessage(Object name) {
    return 'تعطيل المورد «$name»؟';
  }

  @override
  String supplierActivateConfirmMessage(Object name) {
    return 'إعادة تفعيل المورد «$name»؟';
  }

  @override
  String get supplierBalance => 'الرصيد';

  @override
  String get supplierStatement => 'كشف الحساب';

  @override
  String get supplierStatementTitle => 'كشف حساب المورد';

  @override
  String get supplierStatementDateFrom => 'من';

  @override
  String get supplierStatementDateTo => 'إلى';

  @override
  String get statementDate => 'التاريخ';

  @override
  String get statementDescription => 'البيان';

  @override
  String get statementDebit => 'مدين';

  @override
  String get statementCredit => 'دائن';

  @override
  String get statementOpening => 'الرصيد الافتتاحي';

  @override
  String get statementClosing => 'الرصيد الختامي';

  @override
  String get statementBalance => 'الرصيد';

  @override
  String statementRowInvoice(Object number) {
    return 'فاتورة شراء $number';
  }

  @override
  String statementRowReturn(Object number) {
    return 'مرتجع مشتريات $number';
  }

  @override
  String get statementNoData => 'لا توجد حركات في هذا النطاق';

  @override
  String get purchaseStatusPending => 'معلّقة';

  @override
  String get purchaseStatusReceived => 'مُستلمة';

  @override
  String get purchaseStatusCancelled => 'ملغاة';

  @override
  String get purchaseAddInvoice => 'فاتورة شراء جديدة';

  @override
  String get purchasesEmpty => 'لا توجد فواتير شراء';

  @override
  String get purchasesSearchHint => 'بحث برقم الفاتورة';

  @override
  String get purchasesFilterSupplier => 'كل الموردين';

  @override
  String get purchasesFilterStatus => 'كل الحالات';

  @override
  String get purchaseInvoiceNumber => 'رقم الفاتورة';

  @override
  String get purchaseInvoiceDate => 'التاريخ';

  @override
  String get purchaseSupplierLabel => 'المورد';

  @override
  String get purchaseTotal => 'الإجمالي';

  @override
  String get purchasePaid => 'المدفوع';

  @override
  String get purchaseRemaining => 'المتبقي';

  @override
  String get purchaseCreateTitle => 'فاتورة شراء جديدة';

  @override
  String get purchaseEditTitle => 'تعديل فاتورة الشراء';

  @override
  String get purchaseOrderNumber => 'رقم الفاتورة';

  @override
  String get purchaseOrderDate => 'تاريخ الفاتورة';

  @override
  String get purchaseExpectedDate => 'التاريخ المتوقع (اختياري)';

  @override
  String get purchasePaidAmount => 'المبلغ المدفوع';

  @override
  String get purchaseNotes => 'ملاحظات';

  @override
  String get purchaseSubtotal => 'المجموع الفرعي';

  @override
  String get purchaseDiscount => 'الخصومات';

  @override
  String get purchaseGrandTotal => 'الإجمالي النهائي';

  @override
  String get purchaseItemPlaceholder => 'اختر منتجاً';

  @override
  String get purchaseItemSearchHint => 'بحث عن منتج…';

  @override
  String get purchaseQty => 'الكمية';

  @override
  String get purchaseUnitCost => 'سعر الوحدة';

  @override
  String get purchaseUnitType => 'الوحدة';

  @override
  String get purchaseDiscountPct => 'الخصم %';

  @override
  String get purchaseBonus => 'الهدايا/البونص';

  @override
  String get purchaseAddLine => 'إضافة سطر';

  @override
  String get purchaseRemoveLine => 'حذف السطر';

  @override
  String get purchaseNoLines => 'أضف سطراً واحداً على الأقل';

  @override
  String get purchaseReceive => 'استلام';

  @override
  String get purchaseCancel => 'إلغاء الفاتورة';

  @override
  String get purchaseReturn => 'مرتجع';

  @override
  String get purchaseReceiveTitle => 'استلام فاتورة الشراء';

  @override
  String get purchaseReceiveIntro => 'أدخل أرقام التشغيلات لاستلام المخزون';

  @override
  String get purchaseBatchNumber => 'رقم التشغيلة';

  @override
  String get purchaseExpiryDate => 'تاريخ الصلاحية (اختياري)';

  @override
  String get purchaseReceivedMessage => 'تم استلام الفاتورة وإنشاء التشغيلات';

  @override
  String get purchaseCreatedMessage => 'تم حفظ فاتورة الشراء';

  @override
  String get purchaseUpdatedMessage => 'تم تعديل فاتورة الشراء';

  @override
  String get purchaseCancelledMessage => 'تم إلغاء فاتورة الشراء';

  @override
  String get purchaseCancelConfirm => 'إلغاء هذه الفاتورة؟';

  @override
  String get purchaseDetailTitle => 'فاتورة شراء';

  @override
  String get purchaseReturnTitle => 'مرتجع مشتريات';

  @override
  String get purchaseReturnOrderNo => 'رقم المرتجع';

  @override
  String get purchaseReturnQty => 'الكمية المرتجعة';

  @override
  String get purchaseReturnAvailable => 'المتاح';

  @override
  String get purchaseReturnReason => 'السبب (اختياري)';

  @override
  String get purchaseReturnSavedMessage => 'تم تسجيل المرتجع';

  @override
  String get purchaseReturnValidation => 'تحقق من كميات المرتجع';

  @override
  String get purchaseBonus1 => 'بونص 1';

  @override
  String get purchaseBonus2 => 'بونص 2';

  @override
  String get purchaseBonusGift => 'هدية';

  @override
  String get purchaseBonusButton => 'بونص';

  @override
  String get purchaseBonusItem => 'منتج البونص';

  @override
  String get purchaseStatusLabel => 'الحالة';

  @override
  String get purchaseRequiredSupplier => 'اختر المورد';

  @override
  String get purchaseRequiredLines => 'أضف سطراً واحداً على الأقل';

  @override
  String get purchaseRequiredNumber => 'رقم الفاتورة مطلوب';

  @override
  String get purchaseItemNotNull => 'اختر منتجاً لكل سطر';

  @override
  String get purchaseQtyPositive => 'الكمية يجب أن تكون موجبة';

  @override
  String get purchaseCostPositive => 'سعر الوحدة يجب أن يكون موجباً';

  @override
  String get supplierNameRequired => 'الاسم مطلوب';

  @override
  String get customersTab => 'العملاء';

  @override
  String get customersEmpty => 'لا يوجد عملاء';

  @override
  String get customersSearchHint => 'بحث بالاسم أو الهاتف أو البريد';

  @override
  String get customerAdd => 'إضافة عميل';

  @override
  String get customerAddTitle => 'عميل جديد';

  @override
  String get customerEditTitle => 'تعديل عميل';

  @override
  String get customerName => 'اسم العميل';

  @override
  String get customerPhone => 'رقم الهاتف';

  @override
  String get customerSecondaryPhone => 'هاتف آخر';

  @override
  String get customerEmail => 'البريد الإلكتروني';

  @override
  String get customerAddress => 'العنوان';

  @override
  String get customerNotes => 'ملاحظات';

  @override
  String get customerHasAccount => 'حساب آجل (ائتماني)';

  @override
  String get customerAccount => 'الحساب';

  @override
  String get customerAccountEnabled => 'مفعّل';

  @override
  String get customerAccountDisabled => 'غير مفعّل';

  @override
  String get customerOpeningBalance => 'الرصيد الافتتاحي';

  @override
  String get customerCreditLimit => 'الحد الائتماني';

  @override
  String get customerDateOfBirth => 'تاريخ الميلاد';

  @override
  String get customerGender => 'الجنس';

  @override
  String get customerGenderMale => 'ذكر';

  @override
  String get customerGenderFemale => 'أنثى';

  @override
  String get customerMedicalHistory => 'التاريخ المرضي';

  @override
  String get customerTaxVatNumber => 'الرقم الضريبي';

  @override
  String get customerBalance => 'رصيد الحساب';

  @override
  String get customerNameRequired => 'اسم العميل مطلوب';

  @override
  String get customerCreatedMessage => 'تم إضافة العميل';

  @override
  String get customerUpdatedMessage => 'تم تحديث بيانات العميل';

  @override
  String get customerActivatedMessage => 'تم تفعيل العميل';

  @override
  String get customerDeactivatedMessage => 'تم تعطيل العميل';

  @override
  String get customerAccountEnabledMessage => 'تم تفعيل الحساب الائتماني';

  @override
  String get customerAccountDisabledMessage => 'تم تعطيل الحساب الائتماني';

  @override
  String customerDeactivateConfirmMessage(String name) {
    return 'تعطيل العميل «$name»؟';
  }

  @override
  String customerActivateConfirmMessage(String name) {
    return 'إعادة تفعيل العميل «$name»؟';
  }

  @override
  String customerAccountDisableConfirmMessage(String name) {
    return 'تعطيل الحساب الائتماني للعميل «$name»؟';
  }

  @override
  String customerAccountEnableConfirmMessage(String name) {
    return 'تفعيل الحساب الائتماني للعميل «$name»؟';
  }

  @override
  String get customerStatement => 'كشف الحساب';

  @override
  String get customerViewPrescriptions => 'وصفات العميل';

  @override
  String get customerStatementDateFrom => 'من';

  @override
  String get customerStatementDateTo => 'إلى';

  @override
  String statementRowSaleInvoice(String number) {
    return 'فاتورة بيع $number';
  }

  @override
  String statementRowSaleReturn(String number) {
    return 'مرتجع بيع $number';
  }

  @override
  String get prescriptionsTab => 'الوصفات الطبية';

  @override
  String get prescriptionsEmpty => 'لا توجد وصفات';

  @override
  String get prescriptionsSearchHint => 'بحث برقم الوصفة أو المريض أو الطبيب';

  @override
  String get prescriptionAdd => 'وصفة جديدة';

  @override
  String get prescriptionAddTitle => 'وصفة طبية جديدة';

  @override
  String get prescriptionNumber => 'رقم الوصفة';

  @override
  String get prescriptionPatient => 'المريض';

  @override
  String get prescriptionPatientName => 'اسم المريض';

  @override
  String get prescriptionPatientAge => 'العمر';

  @override
  String get prescriptionPatientGender => 'جنس المريض';

  @override
  String get prescriptionDoctorName => 'اسم الطبيب';

  @override
  String get prescriptionDoctorSpecialty => 'التخصص';

  @override
  String get prescriptionClinicHospital => 'العيادة / المستشفى';

  @override
  String get prescriptionIssuedAt => 'تاريخ الوصفة';

  @override
  String get prescriptionExpiryAt => 'تاريخ الانتهاء';

  @override
  String get prescriptionNotes => 'ملاحظات الوصفة';

  @override
  String get prescriptionImagePath => 'مسار صورة الوصفة';

  @override
  String get prescriptionItems => 'أصناف الوصفة';

  @override
  String get prescriptionAddItem => 'إضافة صنف';

  @override
  String get prescriptionItem => 'الصنف';

  @override
  String get prescriptionQuantity => 'الكمية';

  @override
  String get prescriptionDosage => 'الجرعة';

  @override
  String get prescriptionFrequency => 'التكرار';

  @override
  String get prescriptionDurationDays => 'مدة العلاج (أيام)';

  @override
  String get prescriptionLineNotes => 'ملاحظات السطر';

  @override
  String get prescriptionStatus => 'الحالة';

  @override
  String get prescriptionStatusActive => 'نشطة';

  @override
  String get prescriptionStatusPartiallyDispensed => 'صرف جزئي';

  @override
  String get prescriptionStatusDispensed => 'تم صرفها';

  @override
  String get prescriptionStatusExpired => 'منتهية';

  @override
  String get prescriptionStatusCancelled => 'ملغاة';

  @override
  String get prescriptionCustomer => 'العميل';

  @override
  String get prescriptionRequiredCustomer =>
      'يجب اختيار عميل للوصفة — لا تُنشأ وصفات بدون مريض';

  @override
  String get prescriptionRequiredPatient => 'اسم المريض مطلوب';

  @override
  String get prescriptionRequiredItems => 'أضف صنفاً واحداً على الأقل';

  @override
  String get prescriptionRequiredQuantity => 'الكمية يجب أن تكون أكبر من صفر';

  @override
  String get prescriptionCreatedMessage => 'تم إنشاء الوصفة';

  @override
  String get prescriptionDetail => 'تفاصيل الوصفة';

  @override
  String get prescriptionPrepareForSale => 'تجهيز للبيع';

  @override
  String get prescriptionPreparedMessage => 'الوصفة جاهزة للربط في نقطة البيع';

  @override
  String get prescriptionCannotPrepare => 'لا يمكن ربط هذه الوصفة بالبيع';

  @override
  String get partialSaleSection => 'إعدادات البيع الجزئي';

  @override
  String get partialSaleEnabled => 'السماح بالبيع الجزئي';

  @override
  String get partialSalePartsPerFull => 'عدد الأجزاء في العبوة';

  @override
  String get partialSaleMarkupPercent => 'نسبة الزيادة %';

  @override
  String get partialSalePartPrice => 'سعر بيع الجزء';

  @override
  String get partialSaleRestoreAuto => 'استعادة الحساب التلقائي';

  @override
  String get partialSalePartPriceInvalid => 'أدخل سعر جزء صالحًا';

  @override
  String get partialSalePartsRequired => 'أدخل عدد الأجزاء في العبوة الكاملة';

  @override
  String get partialSalePartsInvalid =>
      'عدد الأجزاء في العبوة يجب أن يكون أكبر من 1';

  @override
  String get partialSaleMarkupInvalid => 'نسبة الزيادة يجب أن تكون بين 0 و100';

  @override
  String get posSearchHint => 'ابحث عن دواء بالاسم أو الباركود...';

  @override
  String get posScanOrSearch => 'امسح الباركود أو ابحث عن منتج';

  @override
  String posCustomerTab(int tab) {
    return 'عميل $tab';
  }

  @override
  String get posReturnTab => 'مرتجعات';

  @override
  String get posCartItemEmpty => 'السلة فارغة — أضف أصنافاً للبيع';

  @override
  String get posDeleteHeldBill => 'حذف الفاتورة المعلقة';

  @override
  String get posUnitBox => 'علبة';

  @override
  String get posUnitStrip => 'ظروف';

  @override
  String get posUnitUnit => 'وحدة';

  @override
  String get posTotalLabel => 'الإجمالي';

  @override
  String get posPayButton => 'دفع (F12)';

  @override
  String get posHoldBill => 'حفظ فاتورة (F5)';

  @override
  String get posHoldBillSaved => 'تم حفظ الفاتورة مؤقتاً';

  @override
  String get posHoldBillRestored => 'تم استرجاع الفاتورة';

  @override
  String get posHoldBillEmpty => 'لا توجد فواتير محفوظة';

  @override
  String get posCheckoutComplete => 'تم إتمام البيع بنجاح';

  @override
  String get posPrintReceipt => 'طباعة الإيصال';

  @override
  String get posPrintFailed => 'تعذر طباعة المستند';

  @override
  String get posQtyDecrease => 'إنقاص الكمية';

  @override
  String get posQtyIncrease => 'زيادة الكمية';

  @override
  String get posRemoveLine => 'إزالة الصنف';

  @override
  String get zReportTitle => 'تقرير نهاية الوردية (Z)';

  @override
  String get zReportPrint => 'طباعة التقرير';

  @override
  String get zReportPeriodPrefix => 'الفترة';

  @override
  String get zReportFrom => 'من';

  @override
  String get zReportTo => 'إلى';

  @override
  String get zReportDays => 'أيام';

  @override
  String get zReportSalesSummary => 'ملخص المبيعات';

  @override
  String get zReportReturnsSection => 'المرتجعات والإلغاءات';

  @override
  String get zReportDrawerSection => 'تسوية الخزينة';

  @override
  String get zReportInvoicesCount => 'عدد الفواتير';

  @override
  String get zReportUnitsSold => 'الوحدات المباعة';

  @override
  String get zReportTotalSales => 'إجمالي المبيعات';

  @override
  String get zReportCash => 'نقداً';

  @override
  String get zReportCard => 'بطاقة';

  @override
  String get zReportCredit => 'آجل (ذمم)';

  @override
  String get zReportReturnsBrief => 'المرتجعات (عدد / قيمة)';

  @override
  String get zReportVoidsBrief => 'الفواتير الملغاة (عدد / قيمة)';

  @override
  String get zReportCustomerCollected => 'تحصيل ذمم العملاء';

  @override
  String get zReportCustomerRefunded => 'استرداد ذمم العملاء';

  @override
  String get zReportDrawerOpening => 'رصيد الافتتاح';

  @override
  String get zReportDrawerNet => 'صافي الحركات';

  @override
  String get zReportDrawerExpected => 'الرصيد المتوقع (نهاية الفترة)';

  @override
  String get zReportDrawerLedger => 'الرصيد الجاري (سجل الخزينة)';

  @override
  String get zReportDrawerDeclared => 'الإغلاق المعلن';

  @override
  String get zReportDrawerDiff => 'فرق الخزينة';

  @override
  String get zReportEmptyPeriod => 'لا توجد مبيعات ضمن الفترة المحددة';

  @override
  String get posReceiptSummaryTitle => 'ملخص الإيصال';

  @override
  String get posCashReceived => 'المبلغ المقبوض';

  @override
  String get posCardAmount => 'قيمة البطاقة';

  @override
  String get posChangeLabel => 'الباقي';

  @override
  String get posMixedPayment => 'دفع مختلط (نقد + بطاقة)';

  @override
  String get posInvalidPayment => 'المبلغ غير كافٍ أو غير صحيح';

  @override
  String get posItemNotFound => 'المنتج غير موجود في الدليل';

  @override
  String get posOutOfStock => 'نفدت الكمية';

  @override
  String get posRequiresPrescription => 'يتطلب وصفة طبية نشطة';

  @override
  String get posReturnSearchHint => 'ابحث برقم الفاتورة أو اسم العميل...';

  @override
  String get posNoInvoices => 'لا توجد فواتير مطابقة';

  @override
  String get posReturnableQuantity => 'الكمية المرتجعة';

  @override
  String get posReturnButton => 'إرجاع';

  @override
  String get posReturnReason => 'سبب المرتجع';

  @override
  String get posReturnSuccess => 'تم استلام المرتجع بنجاح';

  @override
  String get posOverReturnBlocked => 'لا يمكن إرجاع أكثر من الكمية الأصلية';

  @override
  String get posLostSaleTitle => 'تسجيل منتج ناقص';

  @override
  String get posLostSalePrompt => 'أدخل اسم المنتج وكميته';

  @override
  String get posLostSaleName => 'اسم/مواصفة المنتج';

  @override
  String get posLostSaleSciName => 'الاسم العلمي';

  @override
  String get posLostSaleNotes => 'ملاحظات';

  @override
  String get posLostSaleQty => 'الكمية المطلوبة';

  @override
  String get posLostSaleSaved => 'تم تسجيل المنتج الناقص';

  @override
  String get posNoResults => 'لا توجد نتائج مطابقة';

  @override
  String get posCustomerLabel => 'العميل';

  @override
  String get posPrescriptionLabel => 'الوصفة';

  @override
  String get posActivePrescriptions => 'الوصفات النشطة';

  @override
  String get posNoPrescriptions => 'لا توجد وصفات نشطة لهذا العميل';

  @override
  String get posPriceChange => 'تعديل السعر';

  @override
  String get posItemAdded => 'تمت إضافة المنتج للسلة';

  @override
  String get posCartCleared => 'تم تفريغ السلة';

  @override
  String get posQuantityUpdated => 'تم تحديث الكمية';

  @override
  String get posInvoiceTitle => 'فاتورة البيع';

  @override
  String get posSaleNumber => 'رقم الفاتورة';

  @override
  String get posSaleDate => 'التاريخ';

  @override
  String get posLineItem => 'المنتج';

  @override
  String get posLineQty => 'الكمية';

  @override
  String get posLineUnitPrice => 'سعر الوحدة';

  @override
  String get posLineTotal => 'الإجمالي';

  @override
  String get posLineDiscount => 'الخصم';

  @override
  String get posLineReturnable => 'الكمية القابلة للإرجاع';

  @override
  String get posAlternativesTitle => 'البدائل المقترحة لـ';

  @override
  String get posAlternativesTier1 => 'مطابق: نفس المكون والجرعة والشكل';

  @override
  String get posAlternativesTier2 => 'نفس المكون بجرعة أو شكل مختلف';

  @override
  String get posAlternativesTier3 => 'يشارك مكوناً فعالاً';

  @override
  String get posAlternativesEmpty => 'لا توجد بدائل متاحة حالياً';

  @override
  String get posAlternativesFailed => 'تعذر تحميل البدائل';

  @override
  String get posAvailableStock => 'متاح';

  @override
  String get posCreditLabel => 'آجل';

  @override
  String get posCreditDownCash => 'دفعة نقدية';

  @override
  String get posCreditDownCard => 'دفعة بطاقة';

  @override
  String get posCreditRemaining => 'مستحق على العميل';

  @override
  String get posCreditOutstanding => 'الرصيد الحالي';

  @override
  String get posCreditAvailable => 'المتاح قبل السقف';

  @override
  String get posCreditLimit => 'السقف الائتماني';

  @override
  String get posCreditUnlimited => 'بدون سقف';

  @override
  String get posCreditCustomerRequired =>
      'البيع الآجل يتطلب تحديد عميل له حساب آجل';

  @override
  String get posCashLabel => 'نقدي';

  @override
  String get posCardLabel => 'بطاقة';

  @override
  String get posMixedLabel => 'مختلط';

  @override
  String get posClearCart => 'تفريغ السلة';

  @override
  String get posRx => 'وصفة';

  @override
  String get posReceiptFooter => 'فرع الصيدلية · شكراً لتعاملكم معنا';

  @override
  String posItemCount(int count) {
    return '$count صنف';
  }

  @override
  String get posRestore => 'استرجاع';

  @override
  String get posCustomerSearchHint => 'ابحث عن عميل بالاسم أو الهاتف';

  @override
  String get posChooseActiveRx => 'اختر الوصفة النشطة';

  @override
  String get posReturnSelectInvoiceHint =>
      'اختر فاتورة من القائمة وحدد الكميات المرتجعة';

  @override
  String get posVoidInvoice => 'إلغاء الفاتورة';

  @override
  String get posInvoiceVoided => 'تم إلغاء الفاتورة';

  @override
  String get posVoidInvoiceFailed => 'تعذر إلغاء الفاتورة';

  @override
  String get cashboxTitle => 'الصندوق';

  @override
  String get cashboxReadOnly =>
      'وضع العرض فقط — تحتاج صلاحية «التعامل مع الصندوق» لإجراء العمليات';

  @override
  String get cashboxActionOpen => 'فتح الصندوق';

  @override
  String get cashboxActionClose => 'إغلاق الصندوق';

  @override
  String get cashboxActionDeposit => 'إيداع نقدي';

  @override
  String get cashboxActionWithdraw => 'سحب نقدي';

  @override
  String get cashboxActionAdjust => 'تسوية الصندوق';

  @override
  String get cashboxSessionOpen => 'الجلسة مفتوحة';

  @override
  String get cashboxSessionClosed => 'الجلسة مقفلة';

  @override
  String get cashboxOpenedBy => 'فُتح بواسطة';

  @override
  String get cashboxOpenedAt => 'فُتح في';

  @override
  String get cashboxClosedBy => 'أُغلق بواسطة';

  @override
  String get cashboxClosedAt => 'أُغلق في';

  @override
  String get cashboxRunning => 'الرصيد الجاري';

  @override
  String get cashboxExpected => 'الرصيد المتوقع';

  @override
  String get cashboxDeclared => 'الرصيد المعلن';

  @override
  String get cashboxSurplus => 'زيادة';

  @override
  String get cashboxShortage => 'عجز';

  @override
  String get cashboxMovementsTitle => 'تفاصيل الحركة';

  @override
  String get cashboxTypeOpen => 'افتتاح';

  @override
  String get cashboxTypeClose => 'إغلاق';

  @override
  String get cashboxTypeSale => 'مبيعات نقدية';

  @override
  String get cashboxTypeRefund => 'مبالغ مستردة';

  @override
  String get cashboxTypePayment => 'مقبوضات عملاء';

  @override
  String get cashboxTypeDeposit => 'إيداعات';

  @override
  String get cashboxTypeWithdraw => 'سحوبات';

  @override
  String get cashboxTypeExpense => 'مصروفات';

  @override
  String get cashboxTypeAdjustment => 'تسويات';

  @override
  String get cashboxInflows => 'المقبوضات';

  @override
  String get cashboxOutflows => 'المدفوعات';

  @override
  String get cashboxNetMoves => 'صافي الحركة';

  @override
  String get cashboxHistoryTitle => 'سجل حركة الصندوق';

  @override
  String get cashboxHistoryEmpty => 'لا توجد حركات مسجلة';

  @override
  String get cashboxFilterAll => 'كل الأنواع';

  @override
  String get cashboxColTime => 'الوقت';

  @override
  String get cashboxColType => 'النوع';

  @override
  String get cashboxColAmount => 'المبلغ';

  @override
  String get cashboxColRemaining => 'الرصيد';

  @override
  String get cashboxColOperator => 'الموظف';

  @override
  String get cashboxColNote => 'ملاحظة';

  @override
  String get cashboxNotOpened => 'الصندوق غير مفتوح';

  @override
  String get cashboxNotOpenedHint =>
      'افتح الصندوق لبدء نوبة العمل وتسجيل الحركات';

  @override
  String get cashboxNotOpenedReadOnly =>
      'الصندوق غير مفتوح — راجع مدير الصيدلية لفتحه';

  @override
  String get cashboxOpeningLabel => 'الرصيد الافتتاحي';

  @override
  String get cashboxNoteOptional => 'ملاحظة (اختياري)';

  @override
  String get cashboxDeclaredLabel => 'الرصيد النقدي المعدود عند الإغلاق';

  @override
  String get cashboxReason => 'السبب';

  @override
  String get cashboxAmountLabel => 'المبلغ';

  @override
  String get cashboxAdjustHint => 'المبلغ الموجب إيداع، والسالب سحب';

  @override
  String get cashboxOpeningRequired => 'أدخل الرصيد الافتتاحي';

  @override
  String get cashboxOpeningInvalid => 'قيمة افتتاح غير صالحة';

  @override
  String get cashboxClosingRequired => 'أدخل الرصيد المعدود عند الإغلاق';

  @override
  String get cashboxClosingInvalid => 'قيمة إغلاق غير صالحة';

  @override
  String get cashboxMoveRequired => 'أدخل المبلغ';

  @override
  String get cashboxMoveInvalid => 'المبلغ يجب أن يكون أكبر من صفر';

  @override
  String get cashboxReasonRequired => 'السبب مطلوب';

  @override
  String get navExpenses => 'المصروفات';

  @override
  String get expensesTitle => 'المصروفات';

  @override
  String get expensesAdd => 'تسجيل مصروف';

  @override
  String get expensesAddTitle => 'تسجيل مصروف جديد';

  @override
  String get expensesEmpty => 'لا توجد مصروفات مسجلة';

  @override
  String get expensesTotalCount => 'عدد السجلات';

  @override
  String get expensesPageTotal => 'إجمالي هذه الصفحة';

  @override
  String get expensesSearchHint => 'بحث بالوصف أو رقم المصروف';

  @override
  String get expensesFilterAllCategories => 'كل الفئات';

  @override
  String get expensesFilterAllPayments => 'كل طرق الدفع';

  @override
  String get expensesFilterAllStatus => 'كل الحالات';

  @override
  String get expensesFilterActiveOnly => 'النشطة فقط';

  @override
  String get expensesFilterVoidedOnly => 'الملغاة فقط';

  @override
  String get expensesStatusActive => 'نشط';

  @override
  String get expensesStatusVoided => 'ملغى';

  @override
  String get expensesReadOnly => 'عرض فقط — لا تملك صلاحية لإدارة المصروفات';

  @override
  String get expensesColNumber => 'الرقم';

  @override
  String get expensesColDate => 'التاريخ';

  @override
  String get expensesColDescription => 'الوصف';

  @override
  String get expensesColCategory => 'الفئة';

  @override
  String get expensesColPayment => 'الدفع';

  @override
  String get expensesColAmount => 'المبلغ';

  @override
  String get expensesColOperator => 'المستخدم';

  @override
  String get expensesColStatus => 'الحالة';

  @override
  String get expensesCash => 'نقدي';

  @override
  String get expensesCard => 'بطاقة';

  @override
  String get expensesShowReceipt => 'عرض الإيصال';

  @override
  String get expensesAttachReceipt => 'إرفاق إيصال';

  @override
  String get expensesCancelAction => 'إلغاء المصروف';

  @override
  String get expenseAmount => 'المبلغ';

  @override
  String get expenseAmountRequired => 'أدخل المبلغ';

  @override
  String get expenseAmountInvalid => 'المبلغ يجب أن يكون أكبر من صفر';

  @override
  String get expenseDescription => 'الوصف';

  @override
  String get expenseDescriptionRequired => 'أدخل وصف المصروف';

  @override
  String get expenseCategory => 'فئة المصروف';

  @override
  String get expenseCategoryRequired => 'اختر فئة المصروف';

  @override
  String get expenseSupplier => 'المورد (اختياري)';

  @override
  String get expenseNoSupplier => 'بدون مورد';

  @override
  String get expensePaymentNote =>
      'يُسجَّل الدفع هنا ويُعكس نقدًا أو بطاقة عند الإلغاء';

  @override
  String get expenseDate => 'تاريخ المصروف';

  @override
  String get expenseNotesOptional => 'ملاحظات (اختياري)';

  @override
  String get expenseReceiptUnreadable =>
      'تعذر عرض الملف — قد يكون تالفاً أو بصيغة غير مدعومة';

  @override
  String get expenseEditDescription => 'تعديل المصروف';

  @override
  String get expenseAmountImmutableHint =>
      'لا يمكن تعديل المبلغ أو الفئة أو طريقة الدفع بعد القيد';

  @override
  String get expenseCancelTitle => 'إلغاء المصروف';

  @override
  String get expenseCancelReason => 'سبب الإلغاء';

  @override
  String get expenseCancelReasonRequired => 'أدخل سبب الإلغاء';

  @override
  String expenseCancelConfirmMessage(String number) {
    return 'سيتم عكس مصروف $number نقديًا ودفترًا بالكامل. لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String get expenseCategoryEditTitle => 'تعديل الفئة';

  @override
  String get expenseCategoryAddTitle => 'فئة مصروف جديدة';

  @override
  String get expenseCategoryCode => 'كود الفئة';

  @override
  String get expenseCategoryCodeHint => 'مثال: utilities, transport…';

  @override
  String get expenseCategoryName => 'اسم الفئة';

  @override
  String get expenseCategoryNameEn => 'الاسم بالإنجليزية (اختياري)';

  @override
  String get expenseCategoryAccount => 'الحساب (بالدليل مثل 5100)';

  @override
  String get expenseCategorySystemBlock =>
      'الفئات النظامية لا يمكن تعديلها أو تعطيلها';

  @override
  String get expenseCategoriesTitle => 'فئات المصروفات';

  @override
  String get expenseNoCategories => 'لا توجد فئات مصروفات';

  @override
  String get expenseCategoryAdd => 'فئة جديدة';

  @override
  String get expenseCreatedMessage => 'تم تسجيل المصروف';

  @override
  String get expenseUpdatedMessage => 'تم تحديث المصروف';

  @override
  String get expenseCancelledMessage => 'تم عكس المصروف';

  @override
  String get expenseReceiptAttached => 'تم إرفاق الإيصال';

  @override
  String get expenseCategoryCreatedMessage => 'تم إنشاء الفئة';

  @override
  String get expenseCategoryUpdatedMessage => 'تم تحديث الفئة';

  @override
  String get expenseCategoryActivated => 'تم تفعيل الفئة';

  @override
  String get expenseCategoryDeactivated => 'تم تعطيل الفئة';

  @override
  String get navCashbox => 'الصندوق';

  @override
  String get navChartAccounts => 'دليل الحسابات';

  @override
  String get navJournal => 'دفتر اليومية';

  @override
  String get navAccountStatement => 'كشف حساب';

  @override
  String get navPeriodClose => 'إقفال الفترة';

  @override
  String get chartAccountsTitle => 'دليل الحسابات';

  @override
  String get journalTitle => 'دفتر اليومية';

  @override
  String get accountStatementTitle => 'كشف حساب';

  @override
  String get periodCloseTitle => 'إقفال الفترة';

  @override
  String get accountsAddTitle => 'إضافة حساب';

  @override
  String get accountsEditTitle => 'تعديل حساب';

  @override
  String get accountsColCode => 'الرمز';

  @override
  String get accountsColName => 'الاسم';

  @override
  String get accountsColType => 'النوع';

  @override
  String get accountsColBalance => 'الرصيد';

  @override
  String get accountsColStatus => 'الحالة';

  @override
  String get accountsNameEn => 'الاسم بالإنجليزية';

  @override
  String get accountsOpeningBalance => 'الرصيد الافتتاحي';

  @override
  String get accountsNotes => 'ملاحظات';

  @override
  String get accountsNoData => 'لا توجد بيانات';

  @override
  String get accountsCodeRequired => 'أدخل رمز الحساب';

  @override
  String get accountsNameRequired => 'أدخل اسم الحساب';

  @override
  String get accountsFilterAll => 'الكل';

  @override
  String get accountTypeAsset => 'أصول';

  @override
  String get accountTypeLiability => 'خصوم';

  @override
  String get accountTypeEquity => 'حقوق ملكية';

  @override
  String get accountTypeRevenue => 'إيرادات';

  @override
  String get accountTypeExpense => 'مصروفات';

  @override
  String get journalColEntryNumber => 'رقم القيد';

  @override
  String get journalColDate => 'التاريخ';

  @override
  String get journalColDescription => 'الوصف';

  @override
  String get journalColRefType => 'المرجع';

  @override
  String get journalColDebit => 'مدين';

  @override
  String get journalColCredit => 'دائن';

  @override
  String get journalFilterRefType => 'نوع المرجع';

  @override
  String get journalReversalBadge => 'قيد عكسي';

  @override
  String get journalDetailTitle => 'تفاصيل القيد';

  @override
  String get journalDetailLines => 'بنود القيد';

  @override
  String get accountStatementFromDate => 'من تاريخ';

  @override
  String get accountStatementToDate => 'إلى تاريخ';

  @override
  String get accountStatementClosingBalance => 'الرصيد الختامي';

  @override
  String get accountStatementSelectAccount => 'اختر حساباً لعرض كشف الحساب';

  @override
  String get periodName => 'اسم الفترة';

  @override
  String get periodStartDate => 'تاريخ البدء';

  @override
  String get periodEndDate => 'تاريخ الانتهاء';

  @override
  String get periodStatus => 'الحالة';

  @override
  String get periodOpen => 'مفتوحة';

  @override
  String get periodClosed => 'مقفلة';

  @override
  String get periodCreate => 'فترة جديدة';

  @override
  String get periodNameRequired => 'أدخل اسم الفترة';

  @override
  String get periodCreatedMessage => 'تم إنشاء الفترة';

  @override
  String get periodClosedMessage => 'تم إقفال الفترة';

  @override
  String get periodCloseConfirmMessage => 'هل أنت متأكد من إقفال الفترة؟';

  @override
  String get periodCloseReason => 'سبب الإقفال';

  @override
  String get refTypeSale => 'بيع';

  @override
  String get refTypePurchase => 'شراء';

  @override
  String get refTypeReturn => 'مرتجع';

  @override
  String get refTypeExpense => 'مصروف';

  @override
  String get refTypeCashbox => 'صندوق';

  @override
  String get refTypeOpeningBalance => 'رصيد افتتاحي';

  @override
  String get refTypeAdjustment => 'تسوية';

  @override
  String get refTypeManual => 'يدوي';

  @override
  String get refTypeCustomerPayment => 'دفعة عميل';

  @override
  String get csRecordPayment => 'تسجيل دفعة';

  @override
  String get csPaymentTitle => 'استلام دفعة من العميل';

  @override
  String get csPaymentAmount => 'المبلغ';

  @override
  String get csPaymentCash => 'نقدي';

  @override
  String get csPaymentCard => 'بطاقة';

  @override
  String get csPaymentNote => 'ملاحظة';

  @override
  String get csPaymentAmountError => 'أدخل مبلغاً موجباً';

  @override
  String get csPaymentSplitError => 'النقدي + البطاقة يجب أن يساوي المبلغ';

  @override
  String get csPaymentSaved => 'تم تسجيل الدفعة';

  @override
  String get csPaymentRefundTitle => 'استرداد للعميل';

  @override
  String get reportExportExcel => 'تصدير إلى إكسل';

  @override
  String get reportExportExcelDone => 'تم تصدير ملف الإكسل';

  @override
  String get reportTitle => 'التقارير';

  @override
  String get reportAddTitle => 'طي التقارير';

  @override
  String get reportTrialBalance => 'ميزان المراجعة';

  @override
  String get reportIncomeStatement => 'قائمة الدخل';

  @override
  String get reportBalanceSheet => 'الميزانية العمومية';

  @override
  String get reportAccountStatement => 'كشف حساب';

  @override
  String get reportSales => 'المبيعات';

  @override
  String get reportPurchases => 'المشتريات';

  @override
  String get reportInventory => 'المخزون';

  @override
  String get reportLostSales => 'النواقص';

  @override
  String get reportCustomerStatement => 'كشف حساب عميل';

  @override
  String get reportSupplierStatement => 'كشف حساب مورد';

  @override
  String get reportFromDate => 'من تاريخ';

  @override
  String get reportToDate => 'إلى تاريخ';

  @override
  String get reportRefresh => 'تحديث';

  @override
  String get reportNoPermission => 'لا تملك صلاحية لعرض هذا التقرير';

  @override
  String get reportTrialBalanceTitle => 'ميزان المراجعة';

  @override
  String get reportTrialBalanceAccount => 'الحساب';

  @override
  String get reportTrialBalanceOpening => 'الرصيد الافتتاحي';

  @override
  String get reportTrialBalanceDebit => 'مدين';

  @override
  String get reportTrialBalanceCredit => 'دائن';

  @override
  String get reportTrialBalanceClosing => 'الرصيد الختامي';

  @override
  String get reportBalanced => 'متوازن';

  @override
  String get reportNotBalanced => 'غير متوازن';

  @override
  String get reportIncomeSalesRevenue => 'إيرادات المبيعات';

  @override
  String get reportIncomeSalesReturns => 'مرتجعات المبيعات';

  @override
  String get reportIncomeNetRevenue => 'صافي الإيرادات';

  @override
  String get reportIncomeCogs => 'تكلفة البضاعة المباعة';

  @override
  String get reportIncomeGrossProfit => 'مجمل الربح';

  @override
  String get reportIncomeOperatingExpenses => 'المصاريف التشغيلية';

  @override
  String get reportIncomeNetIncome => 'صافي الربح';

  @override
  String get reportIncomeExpenseRow => 'مصروف';

  @override
  String get reportBalanceAssets => 'الأصول';

  @override
  String get reportBalanceLiabilities => 'الخصوم';

  @override
  String get reportBalanceEquity => 'حقوق الملكية';

  @override
  String get reportBalanceTotal => 'الإجمالي';

  @override
  String get reportBalanceAsset => 'أصل';

  @override
  String get reportBalanceLiability => 'التزام';

  @override
  String get reportBalanceEquityItem => 'بند';

  @override
  String get reportBalanceRetainedEarnings =>
      'الأرباح المحتجزة (الأرباح المتراكمة)';

  @override
  String get reportDate => 'التاريخ';

  @override
  String get reportSalesCount => 'عدد الفواتير';

  @override
  String get reportSalesUnits => 'الوحدات المباعة';

  @override
  String get reportSalesSubtotal => 'الإجمالي قبل الخصم';

  @override
  String get reportSalesDiscount => 'الخصم';

  @override
  String get reportSalesVat => 'ضريبة القيمة المضافة';

  @override
  String get reportSalesTotal => 'إجمالي المبيعات';

  @override
  String get reportSalesNet => 'صافي المبيعات';

  @override
  String get reportSalesPaid => 'المدفوع';

  @override
  String get reportSalesCash => 'نقدي';

  @override
  String get reportSalesCard => 'بطاقة';

  @override
  String get reportSalesCredit => 'آجل';

  @override
  String get reportSalesVoided => 'الملغاة';

  @override
  String get reportSalesReturns => 'المرتجعات';

  @override
  String get reportSalesProfit => 'الربح';

  @override
  String get reportCustomer => 'العميل';

  @override
  String get reportAllCustomers => 'كل العملاء';

  @override
  String get reportUser => 'المستخدم';

  @override
  String get reportAllUsers => 'كل المستخدمين';

  @override
  String get reportPurchasesCount => 'عدد الفواتير';

  @override
  String get reportPurchasesSubtotal => 'الإجمالي قبل الخصم';

  @override
  String get reportPurchasesDiscount => 'الخصم';

  @override
  String get reportPurchasesTax => 'الضريبة';

  @override
  String get reportPurchasesShipping => 'الشحن';

  @override
  String get reportPurchasesTotal => 'إجمالي المشتريات';

  @override
  String get reportPurchasesPaid => 'المدفوع';

  @override
  String get reportPurchasesRemaining => 'المتبقي';

  @override
  String get reportPurchasesNet => 'صافي المشتريات';

  @override
  String get reportPurchasesReturns => 'مرتجعات المشتريات';

  @override
  String get reportSupplier => 'المورد';

  @override
  String get reportAllSuppliers => 'كل الموردين';

  @override
  String get reportInventoryCount => 'عدد الأصناف';

  @override
  String get reportInventoryTotalStock => 'إجمالي الكميات';

  @override
  String get reportInventoryValue => 'قيمة المخزون';

  @override
  String get reportInventoryLowStock => 'أصناف منخفضة';

  @override
  String get reportInventoryOutOfStock => 'نافد';

  @override
  String get reportInventoryItemCode => 'الباركود';

  @override
  String get reportInventoryItemName => 'الصنف';

  @override
  String get reportInventoryCurrentStock => 'المخزون الحالي';

  @override
  String get reportInventoryMin => 'الحد الأدنى';

  @override
  String get reportInventoryMax => 'الحد الأقصى';

  @override
  String get reportInventoryUnitCost => 'متوسط التكلفة';

  @override
  String get reportInventoryValue2 => 'القيمة';

  @override
  String get reportInventoryMovement => 'حركة المخزون';

  @override
  String get reportMovementType => 'النوع';

  @override
  String get reportMovementCount => 'عدد الحركات';

  @override
  String get reportMovementQty => 'الكمية';

  @override
  String get reportMovementTotal => 'المبلغ';

  @override
  String get reportLostSalesCount => 'عدد الطلبات';

  @override
  String get reportLostSalesQty => 'الكمية المطلوبة';

  @override
  String get reportLostSalesItem => 'الصنف';

  @override
  String get reportLostSalesBarcode => 'الباركود';

  @override
  String get reportLostSalesCustomer => 'العميل';

  @override
  String get reportLostSalesStatus => 'الحالة';

  @override
  String get reportLostSalesNote => 'ملاحظة';

  @override
  String get reportLostStatusOpen => 'مفتوح';

  @override
  String get reportLostStatusOrdered => 'تم الطلب';

  @override
  String get reportLostStatusResolved => 'تم التوفير';

  @override
  String get reportLostStatusCancelled => 'ملغى';

  @override
  String get reportAllStatuses => 'كل الحالات';

  @override
  String get reportGeneratedAt => 'وقت التوليد';

  @override
  String get reportPeriod => 'الفترة';

  @override
  String get reportSelectEntity => 'اختر من القائمة';

  @override
  String get reportStatementOpening => 'الرصيد الافتتاحي';

  @override
  String get reportNoData => 'لا توجد بيانات في هذا النطاق';

  @override
  String get navAudit => 'سجل التدقيق';

  @override
  String get auditDetailTitle => 'تفاصيل العملية';

  @override
  String get auditSearchHint =>
      'ابحث عن عملية (العملية، الكيان، المعرف، ملاحظة)';

  @override
  String get auditFromDate => 'من تاريخ';

  @override
  String get auditToDate => 'إلى تاريخ';

  @override
  String get auditAllActions => 'كل العمليات';

  @override
  String get auditAllUsers => 'كل المستخدمين';

  @override
  String get auditClearFilters => 'مسح الفلاتر';

  @override
  String get auditEmpty => 'لا توجد عمليات مطابقة';

  @override
  String get auditColumnDate => 'الوقت';

  @override
  String get auditColumnUser => 'المستخدم';

  @override
  String get auditColumnAction => 'العملية';

  @override
  String get auditColumnEntity => 'الكيان';

  @override
  String get auditColumnEntityId => 'المعرف';

  @override
  String get auditColumnNote => 'ملاحظة';

  @override
  String get auditSnapshotsTitle => 'لقطات التغيير';

  @override
  String get auditBeforeLabel => 'قبل';

  @override
  String get auditAfterLabel => 'بعد';

  @override
  String get auditActionCreate => 'إنشاء';

  @override
  String get auditActionUpdate => 'تعديل';

  @override
  String get auditActionDelete => 'حذف';

  @override
  String get auditActionLogin => 'تسجيل دخول';

  @override
  String get auditActionLogout => 'تسجيل خروج';

  @override
  String get auditActionLoginFailed => 'محاولة دخول فاشلة';

  @override
  String get auditActionVoid => 'إلغاء';

  @override
  String get auditActionRestore => 'استعادة';

  @override
  String get auditActionPriceChange => 'تغيير سعر';

  @override
  String get auditActionBulkOp => 'عملية جماعية';

  @override
  String get auditActionConfig => 'تغيير الإعدادات';

  @override
  String get auditActionBackup => 'نسخة احتياطية';

  @override
  String get auditActionRestoreBackup => 'استعادة نسخة';

  @override
  String get auditEntityUser => 'مستخدم';

  @override
  String get auditEntityRole => 'دور';

  @override
  String get auditEntityPermission => 'صلاحية';

  @override
  String get auditEntityAppSettings => 'إعدادات النظام';

  @override
  String get auditEntityItem => 'صنف';

  @override
  String get auditEntityBatch => 'دفعة';

  @override
  String get auditEntityCategory => 'فئة';

  @override
  String get auditEntityManufacturer => 'مصنّع';

  @override
  String get auditEntityTherapeuticGroup => 'مجموعة علاجية';

  @override
  String get auditEntityUnit => 'وحدة';

  @override
  String get auditEntityCustomer => 'عميل';

  @override
  String get auditEntitySupplier => 'مورد';

  @override
  String get auditEntitySalesInvoice => 'فاتورة بيع';

  @override
  String get auditEntityPurchaseInvoice => 'فاتورة شراء';

  @override
  String get auditEntityReturn => 'مرتجع';

  @override
  String get auditEntityExpense => 'مصروف';

  @override
  String get auditEntityPrescription => 'وصفة طبية';

  @override
  String get auditEntityCashbox => 'صندوق';

  @override
  String get auditEntityPeriod => 'فترة';

  @override
  String get auditEntityLostSale => 'ناقص';

  @override
  String get auditEntityBackup => 'نسخة احتياطية';

  @override
  String get settingsGeneralTitle => 'الإعدادات العامة';

  @override
  String get settingsBusinessName => 'اسم النشاط التجاري';

  @override
  String get settingsBusinessNameHint => 'يظهر في الفواتير والتقارير';

  @override
  String get settingsBusinessNameRequired => 'اسم النشاط التجاري مطلوب';

  @override
  String get settingsTaxRate => 'نسبة الضريبة';

  @override
  String get settingsTaxRateHint => 'نسبة ضريبة القيمة المضافة';

  @override
  String get settingsTaxInvalid => 'نسبة الضريبة يجب أن تكون بين 0% و 100%';

  @override
  String get settingsCurrency => 'العملة';

  @override
  String get settingsCurrencyHint => 'رمز العملة المعروض في الواجهة';

  @override
  String get settingsSavedMessage => 'تم حفظ الإعدادات بنجاح';

  @override
  String get shortcutsTitle => 'اختصارات لوحة المفاتيح';

  @override
  String get shortcutsSubtitle =>
      'تُطبّق الاختصارات في كل شاشات النظام وتُحفظ تلقائيًا';

  @override
  String get shortcutsSaved => 'تم تحديث الاختصارات';

  @override
  String get shortcutsDuplicate =>
      'هذا المفتاح مُعيّن لإجراء آخر، اختر مفتاحًا مختلفًا';

  @override
  String get shortcutsSearch => 'البحث عن منتج';

  @override
  String get shortcutsToggleUnit => 'تبديل وحدة الصرف';

  @override
  String get shortcutsHoldBill => 'تعليق الفاتورة';

  @override
  String get shortcutsCheckout => 'إتمام البيع';

  @override
  String get shortcutsAlternatives => 'عرض البدائل';

  @override
  String get rolesSubtitle => 'إدارة أدوار المستخدمين وصلاحياتهم';

  @override
  String get rolesAdd => 'إضافة دور';

  @override
  String get rolesEmpty => 'لا توجد أدوار';

  @override
  String get rolesCreateTitle => 'دور جديد';

  @override
  String get rolesEditTitle => 'تعديل الدور';

  @override
  String get rolesNameAr => 'اسم الدور';

  @override
  String get rolesNameRequired => 'اسم الدور مطلوب';

  @override
  String get rolesPermissionsTitle => 'الصلاحيات';

  @override
  String rolesPermissionsCount(int count) {
    return '$count صلاحية';
  }

  @override
  String rolesUsersCount(int count) {
    return '$count مستخدم';
  }

  @override
  String get rolesSystemBadge => 'دور أساسي';

  @override
  String get rolesInactiveBadge => 'معطّل';

  @override
  String get rolesNameExists => 'اسم الدور موجود مسبقاً';

  @override
  String rolesPermissionsFor(String name) {
    return 'صلاحيات $name';
  }

  @override
  String get rolesPermissionsSaved => 'تم حفظ الصلاحيات';

  @override
  String get rolesUpdatedMessage => 'تم تحديث الدور';

  @override
  String get rolesCreatedMessage => 'تم إنشاء الدور';

  @override
  String get rolesDeletedMessage => 'تم حذف الدور';

  @override
  String get rolesDelete => 'حذف الدور';

  @override
  String get rolesDeleteTitle => 'حذف الدور';

  @override
  String rolesDeleteConfirm(String name) {
    return 'هل تريد حذف الدور «$name»؟';
  }

  @override
  String get rolesTabTitle => 'الأدوار';

  @override
  String get permissionsTabTitle => 'الصلاحيات';

  @override
  String get permissionsSubtitle => 'كافة صلاحيات النظام حسب الوحدات';

  @override
  String get permissionsSelectAll => 'تحديد الكل';

  @override
  String get permissionsClearAll => 'إزالة الكل';

  @override
  String get dataManagementTitle => 'النسخ الاحتياطي والاستعادة';

  @override
  String get dataManagementSubtitle =>
      'إدارة النسخ الاحتياطي والاستعادة وتصدير البيانات';

  @override
  String get dataManagementBackupTitle => 'إنشاء نسخة احتياطية';

  @override
  String get dataManagementBackupHint =>
      'نسخة ذاتية الاحتواء تشمل قاعدة البيانات وإيصالات المصروفات المرفقة، مع المعرّف وسجل التدقيق.';

  @override
  String get dataManagementCreateBackup => 'إنشاء نسخة احتياطية';

  @override
  String get dataManagementChooseDestinationFolder => 'اختيار مجلد الحفظ';

  @override
  String get dataManagementBackupCreated => 'تم إنشاء النسخة الاحتياطية بنجاح';

  @override
  String dataManagementBackupSize(String size) {
    return 'الحجم: $size';
  }

  @override
  String get dataManagementRestoreTitle => 'الاستعادة من نسخة';

  @override
  String get dataManagementRestoreHint =>
      'الاستعادة تستبدل البيانات الحالية بالكامل. تُنشأ نسخة أمان تلقائية قبل أي استعادة.';

  @override
  String get dataManagementChooseArchive => 'اختيار ملف النسخة';

  @override
  String get dataManagementRestoreNow => 'بدء الاستعادة';

  @override
  String get dataManagementRestoreConfirmTitle => 'تأكيد الاستعادة';

  @override
  String get dataManagementRestoreConfirmBody =>
      'سيتم استبدال البيانات الحالية بالكامل بمحتويات النسخة. يُنشأ نسخة أمان تلقائية أولاً، ولا يمكن التراجع عن العملية بعد اكتمالها.';

  @override
  String get dataManagementRestoreRestartRequired =>
      'تمت الاستعادة بنجاح. الرجاء تسجيل الخروج وإعادة تشغيل التطبيق لعرض البيانات المستعادة.';

  @override
  String get dataManagementRestoreInvalid => 'النسخة غير صالحة للاستعادة';

  @override
  String get dataManagementRestorePreviewStatus => 'الحالة';

  @override
  String get dataManagementRestorePreviewSchema => 'إصدار قاعدة البيانات';

  @override
  String get dataManagementRestorePreviewDate => 'تاريخ النسخة';

  @override
  String get dataManagementRestorePreviewApp => 'إصدار التطبيق';

  @override
  String get dataManagementRestorePreviewValid => 'صالحة';

  @override
  String get dataManagementRestorePreviewInvalid => 'غير صالحة';

  @override
  String dataManagementRestoreSchemaNote(int version) {
    return 'إصدار المخطط في النسخة: $version';
  }

  @override
  String dataManagementFilesCount(int count) {
    return '$count ملف مرفق';
  }

  @override
  String get dataManagementExportTitle => 'تصدير البيانات';

  @override
  String get dataManagementExportHint =>
      'تصدير كامل لجميع الجداول إلى ملفات CSV داخل مجلد، مع ملف معلومات، دون أي تعديل على قاعدة البيانات.';

  @override
  String get dataManagementExportNow => 'بدء التصدير';

  @override
  String get dataManagementExportDone => 'تم تصدير البيانات بنجاح';

  @override
  String get dataManagementExportDestination => 'مجلد التصدير';

  @override
  String dataManagementExportSummary(int rows, int tables) {
    return '$rows صف في $tables جدول';
  }

  @override
  String get dataManagementNotPermitted => 'ليست لديك صلاحية لهذا الإجراء';

  @override
  String get dataManagementRestartRequiredTitle => 'إعادة التشغيل مطلوبة';

  @override
  String get auditLogDateFrom => 'من';

  @override
  String get auditLogDateTo => 'إلى';

  @override
  String get inventoryDeleteTitle => 'حذف المنتج';

  @override
  String inventoryDeleteConfirm(String name) {
    return 'هل تريد حذف المنتج \"$name\" نهائيًا؟ لا يمكن التراجع بعد الحذف، ويُسمح فقط للمنتجات غير المستخدمة.';
  }

  @override
  String get inventoryDeleteBlocked =>
      'لا يمكن حذف منتج مرتبط بمخزون أو تشغيلات أو فواتير؛ لاستبعاده استخدم الإيقاف.';

  @override
  String get inventoryDeleteMessage => 'تم حذف المنتج';

  @override
  String get masterDataDeleteTitle => 'حذف';

  @override
  String masterDataDeleteConfirm(String name) {
    return 'هل تريد حذف \"$name\" نهائيًا؟ لا يمكن حذف أي عنصر مستخدم في منتجات.';
  }

  @override
  String get masterDataDeleteBlocked =>
      'لا يمكن حذف عنصر مستخدم في منتجات أو فواتير؛ استخدم الإيقاف بدلاً من الحذف.';

  @override
  String get masterDataDeletedMessage => 'تم حذف العنصر';

  @override
  String get masterDataSearchHint => 'ابحث بالاسم';

  @override
  String masterDataCount(int count) {
    return '$count عنصر';
  }
}
