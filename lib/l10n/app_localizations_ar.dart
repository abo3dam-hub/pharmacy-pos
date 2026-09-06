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
}
