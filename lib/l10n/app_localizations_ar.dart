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
  String get unitStrips => 'شرائط';

  @override
  String get dashboardTodayOrders => 'طلبات اليوم';

  @override
  String get dashboardDailySales => 'مبيعات اليوم';

  @override
  String get dashboardLowStock => 'أصناف منخفضة المخزون';

  @override
  String get dashboardProfitToday => 'ربح اليوم';

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
  String get inventoryTabGroups => 'المجموعات العلاجية';

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
  String get inventoryExportDone => 'تم تصدير الملف';

  @override
  String get inventoryImportFailed => 'تعذر قراءة الملف';

  @override
  String get itemBarcodePrimary => 'الباركود الأساسي';

  @override
  String get itemScientificName => 'الاسم العلمي';

  @override
  String get itemActiveIngredient => 'المادة الفعالة';

  @override
  String get itemTradeNameEn => 'الاسم التجاري (إنجليزي)';

  @override
  String get itemSubCategory => 'التصنيف الفرعي';

  @override
  String get itemManufacturer => 'المصنع';

  @override
  String get itemGroup => 'المجموعة العلاجية';

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
  String get itemPrintLabel => 'طباعة باركود تسمية';

  @override
  String get itemIsOtc => 'بلا وصفة طبية';

  @override
  String get itemIsControlled => 'عقار خاضع لضبط خاص';

  @override
  String get itemScaleAlert => 'تنبيه ميزان الباركود';

  @override
  String get itemLockPriceAutoUpdate => 'قفل التحديث التلقائي للأسعار';

  @override
  String get itemRequiresPrescription => 'يتطلب وصفة طبية';

  @override
  String get itemPurchaseDiscount => 'خصم الشراء';

  @override
  String get itemSellingPrice => 'سعر البيع';

  @override
  String get itemSubUnitPrice => 'سعر الوحدة الفرعية';

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
  String get itemBaseUnit => 'الوحدة الأساسية';

  @override
  String get itemLargeUnit => 'الوحدة الكبيرة';

  @override
  String get itemUnitsPerLarge => 'عدد الوحدات الصغرى في الكبرى';

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
  String get categoriesTitle => 'التصنيفات';

  @override
  String get categoriesAdd => 'إضافة تصنيف';

  @override
  String get categoriesAddTitle => 'إضافة تصنيف جديد';

  @override
  String get categoriesEditTitle => 'تعديل تصنيف';

  @override
  String get subCategoriesAddTitle => 'إضافة تصنيف فرعي';

  @override
  String get subCategoriesEditTitle => 'تعديل تصنيف فرعي';

  @override
  String get addSubCategory => 'إضافة تصنيف فرعي';

  @override
  String get categoriesEmpty => 'لا توجد تصنيفات';

  @override
  String get categoryName => 'اسم التصنيف';

  @override
  String get categoryNameEn => 'اسم التصنيف (إنجليزي)';

  @override
  String get subCategoryName => 'اسم التصنيف الفرعي';

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
}
