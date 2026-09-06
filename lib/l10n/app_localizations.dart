import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'نظام إدارة الصيدلية'**
  String get appTitle;

  /// No description provided for @appSlogan.
  ///
  /// In ar, this message translates to:
  /// **'نظام احترافي لإدارة الصيدلية و نقطة البيع'**
  String get appSlogan;

  /// No description provided for @navDashboard.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get navDashboard;

  /// No description provided for @navSale.
  ///
  /// In ar, this message translates to:
  /// **'مبيعات'**
  String get navSale;

  /// No description provided for @navInventory.
  ///
  /// In ar, this message translates to:
  /// **'المخزون'**
  String get navInventory;

  /// No description provided for @navPurchases.
  ///
  /// In ar, this message translates to:
  /// **'المشتريات'**
  String get navPurchases;

  /// No description provided for @navCustomers.
  ///
  /// In ar, this message translates to:
  /// **'العملاء'**
  String get navCustomers;

  /// No description provided for @navSuppliers.
  ///
  /// In ar, this message translates to:
  /// **'الموردون'**
  String get navSuppliers;

  /// No description provided for @navAccounts.
  ///
  /// In ar, this message translates to:
  /// **'الحسابات'**
  String get navAccounts;

  /// No description provided for @navReports.
  ///
  /// In ar, this message translates to:
  /// **'التقارير'**
  String get navReports;

  /// No description provided for @navSettings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get navSettings;

  /// No description provided for @navUsers.
  ///
  /// In ar, this message translates to:
  /// **'المستخدمون'**
  String get navUsers;

  /// No description provided for @navAlternatives.
  ///
  /// In ar, this message translates to:
  /// **'البدائل'**
  String get navAlternatives;

  /// No description provided for @navLostSales.
  ///
  /// In ar, this message translates to:
  /// **'النواقص'**
  String get navLostSales;

  /// No description provided for @navReturn.
  ///
  /// In ar, this message translates to:
  /// **'المرتجعات'**
  String get navReturn;

  /// No description provided for @commonSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get commonCancel;

  /// No description provided for @commonSearch.
  ///
  /// In ar, this message translates to:
  /// **'بحث'**
  String get commonSearch;

  /// No description provided for @commonAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة'**
  String get commonAdd;

  /// No description provided for @commonDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get commonEdit;

  /// No description provided for @commonPrint.
  ///
  /// In ar, this message translates to:
  /// **'طباعة'**
  String get commonPrint;

  /// No description provided for @commonConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get commonConfirm;

  /// No description provided for @commonClose.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get commonClose;

  /// No description provided for @commonBack.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get commonBack;

  /// No description provided for @commonNext.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get commonNext;

  /// No description provided for @commonPrevious.
  ///
  /// In ar, this message translates to:
  /// **'السابق'**
  String get commonPrevious;

  /// No description provided for @commonLoading.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحميل...'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ'**
  String get commonError;

  /// No description provided for @commonRetry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get commonRetry;

  /// No description provided for @commonNone.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد'**
  String get commonNone;

  /// No description provided for @commonYes.
  ///
  /// In ar, this message translates to:
  /// **'نعم'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In ar, this message translates to:
  /// **'لا'**
  String get commonNo;

  /// No description provided for @commonTotal.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get commonTotal;

  /// No description provided for @commonSubtotal.
  ///
  /// In ar, this message translates to:
  /// **'المجموع الفرعي'**
  String get commonSubtotal;

  /// No description provided for @commonDiscount.
  ///
  /// In ar, this message translates to:
  /// **'الخصم'**
  String get commonDiscount;

  /// No description provided for @commonTax.
  ///
  /// In ar, this message translates to:
  /// **'الضريبة'**
  String get commonTax;

  /// No description provided for @commonChange.
  ///
  /// In ar, this message translates to:
  /// **'الباقي'**
  String get commonChange;

  /// No description provided for @commonPaid.
  ///
  /// In ar, this message translates to:
  /// **'المدفوع'**
  String get commonPaid;

  /// No description provided for @commonProfit.
  ///
  /// In ar, this message translates to:
  /// **'الربح'**
  String get commonProfit;

  /// No description provided for @loginTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get loginTitle;

  /// No description provided for @loginWelcome.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول إلى النظام'**
  String get loginWelcome;

  /// No description provided for @loginUsername.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم'**
  String get loginUsername;

  /// No description provided for @loginPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get loginPassword;

  /// No description provided for @loginButton.
  ///
  /// In ar, this message translates to:
  /// **'دخول'**
  String get loginButton;

  /// No description provided for @loginFailed.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم أو كلمة المرور غير صحيحة'**
  String get loginFailed;

  /// No description provided for @loginUserInactive.
  ///
  /// In ar, this message translates to:
  /// **'هذا المستخدم غير مفعّل'**
  String get loginUserInactive;

  /// No description provided for @userLogout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get userLogout;

  /// No description provided for @userRole.
  ///
  /// In ar, this message translates to:
  /// **'الدور'**
  String get userRole;

  /// No description provided for @roleAdmin.
  ///
  /// In ar, this message translates to:
  /// **'مدير النظام'**
  String get roleAdmin;

  /// No description provided for @rolePharmacist.
  ///
  /// In ar, this message translates to:
  /// **'صيدلي'**
  String get rolePharmacist;

  /// No description provided for @roleCashier.
  ///
  /// In ar, this message translates to:
  /// **'أمين الصندوق'**
  String get roleCashier;

  /// No description provided for @roleViewer.
  ///
  /// In ar, this message translates to:
  /// **'مشاهد'**
  String get roleViewer;

  /// No description provided for @authPermissionDenied.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك صلاحية لتنفيذ هذا الإجراء'**
  String get authPermissionDenied;

  /// No description provided for @authSaveError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء حفظ البيانات'**
  String get authSaveError;

  /// No description provided for @usersTitle.
  ///
  /// In ar, this message translates to:
  /// **'المستخدمون'**
  String get usersTitle;

  /// No description provided for @usersList.
  ///
  /// In ar, this message translates to:
  /// **'قائمة المستخدمين'**
  String get usersList;

  /// No description provided for @usersAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مستخدم'**
  String get usersAdd;

  /// No description provided for @usersCreateTitle.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مستخدم جديد'**
  String get usersCreateTitle;

  /// No description provided for @usersEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل مستخدم'**
  String get usersEditTitle;

  /// No description provided for @usersSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن مستخدم بالاسم أو اسم المستخدم'**
  String get usersSearchHint;

  /// No description provided for @usersEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد مستخدمون مطابقون'**
  String get usersEmpty;

  /// No description provided for @userFullName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم الكامل'**
  String get userFullName;

  /// No description provided for @userUsername.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم'**
  String get userUsername;

  /// No description provided for @userPhone.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get userPhone;

  /// No description provided for @userNotes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get userNotes;

  /// No description provided for @userStatusActive.
  ///
  /// In ar, this message translates to:
  /// **'مفعّل'**
  String get userStatusActive;

  /// No description provided for @userStatusInactive.
  ///
  /// In ar, this message translates to:
  /// **'غير مفعّل'**
  String get userStatusInactive;

  /// No description provided for @userLastLogin.
  ///
  /// In ar, this message translates to:
  /// **'آخر تسجيل دخول'**
  String get userLastLogin;

  /// No description provided for @userNeverLoggedIn.
  ///
  /// In ar, this message translates to:
  /// **'لم يسجل الدخول بعد'**
  String get userNeverLoggedIn;

  /// No description provided for @userLastLoginLabel.
  ///
  /// In ar, this message translates to:
  /// **'دخول أخير'**
  String get userLastLoginLabel;

  /// No description provided for @userActivate.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل'**
  String get userActivate;

  /// No description provided for @userDeactivate.
  ///
  /// In ar, this message translates to:
  /// **'تعطيل'**
  String get userDeactivate;

  /// No description provided for @userDeactivateConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعطيل المستخدم'**
  String get userDeactivateConfirmTitle;

  /// No description provided for @userDeactivateConfirmMessage.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد تعطيل المستخدم «{name}»؟'**
  String userDeactivateConfirmMessage(String name);

  /// No description provided for @userActivateConfirmMessage.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد تفعيل المستخدم «{name}»؟'**
  String userActivateConfirmMessage(String name);

  /// No description provided for @userChangePassword.
  ///
  /// In ar, this message translates to:
  /// **'تغيير كلمة المرور'**
  String get userChangePassword;

  /// No description provided for @userChangePasswordTitle.
  ///
  /// In ar, this message translates to:
  /// **'تغيير كلمة المرور'**
  String get userChangePasswordTitle;

  /// No description provided for @userNewPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور الجديدة'**
  String get userNewPassword;

  /// No description provided for @userConfirmPassword.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد كلمة المرور'**
  String get userConfirmPassword;

  /// No description provided for @userPasswordMismatch.
  ///
  /// In ar, this message translates to:
  /// **'كلمتا المرور غير متطابقتين'**
  String get userPasswordMismatch;

  /// No description provided for @userPasswordMinLength.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور يجب أن تكون 6 أحرف على الأقل'**
  String get userPasswordMinLength;

  /// No description provided for @userRequiredField.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحقل مطلوب'**
  String get userRequiredField;

  /// No description provided for @userUsernameExists.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم مستخدم مسبقًا'**
  String get userUsernameExists;

  /// No description provided for @userCreatedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء المستخدم'**
  String get userCreatedMessage;

  /// No description provided for @userUpdatedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث المستخدم'**
  String get userUpdatedMessage;

  /// No description provided for @userActivatedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم تفعيل المستخدم'**
  String get userActivatedMessage;

  /// No description provided for @userDeactivatedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم تعطيل المستخدم'**
  String get userDeactivatedMessage;

  /// No description provided for @userPasswordChangedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم تغيير كلمة المرور'**
  String get userPasswordChangedMessage;

  /// No description provided for @accessDeniedTitle.
  ///
  /// In ar, this message translates to:
  /// **'الوصول مرفوض'**
  String get accessDeniedTitle;

  /// No description provided for @accessDeniedMessage.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك صلاحية للوصول إلى هذه الصفحة'**
  String get accessDeniedMessage;

  /// No description provided for @checkout.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء البيع'**
  String get checkout;

  /// No description provided for @holdBill.
  ///
  /// In ar, this message translates to:
  /// **'تعليق الفاتورة'**
  String get holdBill;

  /// No description provided for @cartEmpty.
  ///
  /// In ar, this message translates to:
  /// **'السلة فارغة'**
  String get cartEmpty;

  /// No description provided for @notEnoughStock.
  ///
  /// In ar, this message translates to:
  /// **'المخزون غير كافٍ'**
  String get notEnoughStock;

  /// No description provided for @price.
  ///
  /// In ar, this message translates to:
  /// **'السعر'**
  String get price;

  /// No description provided for @quantity.
  ///
  /// In ar, this message translates to:
  /// **'الكمية'**
  String get quantity;

  /// No description provided for @batchNo.
  ///
  /// In ar, this message translates to:
  /// **'رقم الدفعة'**
  String get batchNo;

  /// No description provided for @expiryDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الانتهاء'**
  String get expiryDate;

  /// No description provided for @unitBoxes.
  ///
  /// In ar, this message translates to:
  /// **'علب'**
  String get unitBoxes;

  /// No description provided for @unitStrips.
  ///
  /// In ar, this message translates to:
  /// **'شرائط'**
  String get unitStrips;

  /// No description provided for @dashboardTodayOrders.
  ///
  /// In ar, this message translates to:
  /// **'طلبات اليوم'**
  String get dashboardTodayOrders;

  /// No description provided for @dashboardDailySales.
  ///
  /// In ar, this message translates to:
  /// **'مبيعات اليوم'**
  String get dashboardDailySales;

  /// No description provided for @dashboardLowStock.
  ///
  /// In ar, this message translates to:
  /// **'أصناف منخفضة المخزون'**
  String get dashboardLowStock;

  /// No description provided for @dashboardProfitToday.
  ///
  /// In ar, this message translates to:
  /// **'ربح اليوم'**
  String get dashboardProfitToday;

  /// No description provided for @inventoryLowStock.
  ///
  /// In ar, this message translates to:
  /// **'منخفض المخزون'**
  String get inventoryLowStock;

  /// No description provided for @inventoryOutOfStock.
  ///
  /// In ar, this message translates to:
  /// **'نفد المخزون'**
  String get inventoryOutOfStock;

  /// No description provided for @saleNewSale.
  ///
  /// In ar, this message translates to:
  /// **'بيع جديد'**
  String get saleNewSale;

  /// No description provided for @saleRecentInvoices.
  ///
  /// In ar, this message translates to:
  /// **'الفواتير الأخيرة'**
  String get saleRecentInvoices;

  /// No description provided for @purchaseNewPurchase.
  ///
  /// In ar, this message translates to:
  /// **'شراء جديد'**
  String get purchaseNewPurchase;

  /// No description provided for @purchaseRecent.
  ///
  /// In ar, this message translates to:
  /// **'فواتير الشراء الأخيرة'**
  String get purchaseRecent;

  /// No description provided for @customersList.
  ///
  /// In ar, this message translates to:
  /// **'قائمة العملاء'**
  String get customersList;

  /// No description provided for @suppliersList.
  ///
  /// In ar, this message translates to:
  /// **'قائمة الموردين'**
  String get suppliersList;

  /// No description provided for @accountsCashbox.
  ///
  /// In ar, this message translates to:
  /// **'الصندوق'**
  String get accountsCashbox;

  /// No description provided for @accountsJournal.
  ///
  /// In ar, this message translates to:
  /// **'دفتر اليومية'**
  String get accountsJournal;

  /// No description provided for @accountsLedger.
  ///
  /// In ar, this message translates to:
  /// **'دفتر الأستاذ'**
  String get accountsLedger;

  /// No description provided for @settingsLanguage.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get settingsLanguage;

  /// No description provided for @settingsDatabase.
  ///
  /// In ar, this message translates to:
  /// **'قاعدة البيانات'**
  String get settingsDatabase;

  /// No description provided for @settingsBackup.
  ///
  /// In ar, this message translates to:
  /// **'النسخ الاحتياطي'**
  String get settingsBackup;

  /// No description provided for @settingsAppInfo.
  ///
  /// In ar, this message translates to:
  /// **'معلومات التطبيق'**
  String get settingsAppInfo;

  /// No description provided for @settingsSchemaVersion.
  ///
  /// In ar, this message translates to:
  /// **'إصدار المخطط'**
  String get settingsSchemaVersion;

  /// No description provided for @settingsVersion.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار'**
  String get settingsVersion;

  /// No description provided for @itemTradeName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم التجاري'**
  String get itemTradeName;

  /// No description provided for @itemBarcode.
  ///
  /// In ar, this message translates to:
  /// **'الباركود'**
  String get itemBarcode;

  /// No description provided for @itemCategory.
  ///
  /// In ar, this message translates to:
  /// **'التصنيف'**
  String get itemCategory;

  /// No description provided for @itemUnit.
  ///
  /// In ar, this message translates to:
  /// **'الوحدة'**
  String get itemUnit;

  /// No description provided for @itemCost.
  ///
  /// In ar, this message translates to:
  /// **'التكلفة'**
  String get itemCost;

  /// No description provided for @itemPrice.
  ///
  /// In ar, this message translates to:
  /// **'سعر البيع'**
  String get itemPrice;

  /// No description provided for @itemStock.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد'**
  String get itemStock;

  /// No description provided for @inventoryTabItems.
  ///
  /// In ar, this message translates to:
  /// **'المنتجات'**
  String get inventoryTabItems;

  /// No description provided for @inventoryTabCategories.
  ///
  /// In ar, this message translates to:
  /// **'التصنيفات'**
  String get inventoryTabCategories;

  /// No description provided for @inventoryTabManufacturers.
  ///
  /// In ar, this message translates to:
  /// **'المصنعون'**
  String get inventoryTabManufacturers;

  /// No description provided for @inventoryTabGroups.
  ///
  /// In ar, this message translates to:
  /// **'المجموعات العلاجية'**
  String get inventoryTabGroups;

  /// No description provided for @inventoryTabUnits.
  ///
  /// In ar, this message translates to:
  /// **'الوحدات'**
  String get inventoryTabUnits;

  /// No description provided for @inventorySearchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث بالاسم أو الباركود'**
  String get inventorySearchHint;

  /// No description provided for @inventoryAddItem.
  ///
  /// In ar, this message translates to:
  /// **'إضافة منتج'**
  String get inventoryAddItem;

  /// No description provided for @inventoryItemAddTitle.
  ///
  /// In ar, this message translates to:
  /// **'إضافة منتج جديد'**
  String get inventoryItemAddTitle;

  /// No description provided for @inventoryItemEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل منتج'**
  String get inventoryItemEditTitle;

  /// No description provided for @inventoryItemsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد منتجات مطابقة'**
  String get inventoryItemsEmpty;

  /// No description provided for @inventoryActiveFilter.
  ///
  /// In ar, this message translates to:
  /// **'المفعّلة فقط'**
  String get inventoryActiveFilter;

  /// No description provided for @inventoryCreatedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء المنتج'**
  String get inventoryCreatedMessage;

  /// No description provided for @inventoryUpdatedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث المنتج'**
  String get inventoryUpdatedMessage;

  /// No description provided for @inventoryActivatedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم تفعيل المنتج'**
  String get inventoryActivatedMessage;

  /// No description provided for @inventoryDeactivatedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم إيقاف المنتج'**
  String get inventoryDeactivatedMessage;

  /// No description provided for @inventoryImport.
  ///
  /// In ar, this message translates to:
  /// **'استيراد من إكسل'**
  String get inventoryImport;

  /// No description provided for @inventoryExport.
  ///
  /// In ar, this message translates to:
  /// **'تصدير إلى إكسل'**
  String get inventoryExport;

  /// No description provided for @inventoryImportDone.
  ///
  /// In ar, this message translates to:
  /// **'اكتمل الاستيراد: {created} جديدًا، {updated} محدّثًا'**
  String inventoryImportDone(int created, int updated);

  /// No description provided for @inventoryImportIssues.
  ///
  /// In ar, this message translates to:
  /// **'سقط {skipped} صفًا'**
  String inventoryImportIssues(int skipped);

  /// No description provided for @inventoryExportDone.
  ///
  /// In ar, this message translates to:
  /// **'تم تصدير الملف'**
  String get inventoryExportDone;

  /// No description provided for @inventoryImportFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر قراءة الملف'**
  String get inventoryImportFailed;

  /// No description provided for @itemBarcodePrimary.
  ///
  /// In ar, this message translates to:
  /// **'الباركود الأساسي'**
  String get itemBarcodePrimary;

  /// No description provided for @itemScientificName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم العلمي'**
  String get itemScientificName;

  /// No description provided for @itemActiveIngredient.
  ///
  /// In ar, this message translates to:
  /// **'المادة الفعالة'**
  String get itemActiveIngredient;

  /// No description provided for @itemTradeNameEn.
  ///
  /// In ar, this message translates to:
  /// **'الاسم التجاري (إنجليزي)'**
  String get itemTradeNameEn;

  /// No description provided for @itemSubCategory.
  ///
  /// In ar, this message translates to:
  /// **'التصنيف الفرعي'**
  String get itemSubCategory;

  /// No description provided for @itemManufacturer.
  ///
  /// In ar, this message translates to:
  /// **'المصنع'**
  String get itemManufacturer;

  /// No description provided for @itemGroup.
  ///
  /// In ar, this message translates to:
  /// **'المجموعة العلاجية'**
  String get itemGroup;

  /// No description provided for @itemPharmaForm.
  ///
  /// In ar, this message translates to:
  /// **'الشكل الصيدلاني'**
  String get itemPharmaForm;

  /// No description provided for @itemDose.
  ///
  /// In ar, this message translates to:
  /// **'الجرعة'**
  String get itemDose;

  /// No description provided for @itemSizeVolume.
  ///
  /// In ar, this message translates to:
  /// **'الحجم/السعة'**
  String get itemSizeVolume;

  /// No description provided for @itemShelfLocation.
  ///
  /// In ar, this message translates to:
  /// **'موقع الرف'**
  String get itemShelfLocation;

  /// No description provided for @itemSecondaryBarcode.
  ///
  /// In ar, this message translates to:
  /// **'باركود ثانوي'**
  String get itemSecondaryBarcode;

  /// No description provided for @itemEquivalentDrug.
  ///
  /// In ar, this message translates to:
  /// **'دواء مكافئ'**
  String get itemEquivalentDrug;

  /// No description provided for @itemHasExpiry.
  ///
  /// In ar, this message translates to:
  /// **'للتاريخ صلاحية'**
  String get itemHasExpiry;

  /// No description provided for @itemPrintLabel.
  ///
  /// In ar, this message translates to:
  /// **'طباعة باركود تسمية'**
  String get itemPrintLabel;

  /// No description provided for @itemIsOtc.
  ///
  /// In ar, this message translates to:
  /// **'بلا وصفة طبية'**
  String get itemIsOtc;

  /// No description provided for @itemIsControlled.
  ///
  /// In ar, this message translates to:
  /// **'عقار خاضع لضبط خاص'**
  String get itemIsControlled;

  /// No description provided for @itemScaleAlert.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه ميزان الباركود'**
  String get itemScaleAlert;

  /// No description provided for @itemLockPriceAutoUpdate.
  ///
  /// In ar, this message translates to:
  /// **'قفل التحديث التلقائي للأسعار'**
  String get itemLockPriceAutoUpdate;

  /// No description provided for @itemRequiresPrescription.
  ///
  /// In ar, this message translates to:
  /// **'يتطلب وصفة طبية'**
  String get itemRequiresPrescription;

  /// No description provided for @itemPurchaseDiscount.
  ///
  /// In ar, this message translates to:
  /// **'خصم الشراء'**
  String get itemPurchaseDiscount;

  /// No description provided for @itemSellingPrice.
  ///
  /// In ar, this message translates to:
  /// **'سعر البيع'**
  String get itemSellingPrice;

  /// No description provided for @itemSubUnitPrice.
  ///
  /// In ar, this message translates to:
  /// **'سعر الوحدة الفرعية'**
  String get itemSubUnitPrice;

  /// No description provided for @itemWholesalePrice.
  ///
  /// In ar, this message translates to:
  /// **'سعر الجملة'**
  String get itemWholesalePrice;

  /// No description provided for @itemHalfWholesalePrice.
  ///
  /// In ar, this message translates to:
  /// **'سعر نصف الجملة'**
  String get itemHalfWholesalePrice;

  /// No description provided for @itemCustomPrice1.
  ///
  /// In ar, this message translates to:
  /// **'سعر خاص 1'**
  String get itemCustomPrice1;

  /// No description provided for @itemCustomPrice2.
  ///
  /// In ar, this message translates to:
  /// **'سعر خاص 2'**
  String get itemCustomPrice2;

  /// No description provided for @itemVatRate.
  ///
  /// In ar, this message translates to:
  /// **'نسبة الضريبة'**
  String get itemVatRate;

  /// No description provided for @itemMinimumStock.
  ///
  /// In ar, this message translates to:
  /// **'الحد الأدنى للمخزون'**
  String get itemMinimumStock;

  /// No description provided for @itemMaximumStock.
  ///
  /// In ar, this message translates to:
  /// **'الحد الأعلى للمخزون'**
  String get itemMaximumStock;

  /// No description provided for @itemUsageInstructions.
  ///
  /// In ar, this message translates to:
  /// **'تعليمات الاستخدام'**
  String get itemUsageInstructions;

  /// No description provided for @itemGeneralNotes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات عامة'**
  String get itemGeneralNotes;

  /// No description provided for @itemLicenseNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الترخيص'**
  String get itemLicenseNumber;

  /// No description provided for @itemUnitsRelation.
  ///
  /// In ar, this message translates to:
  /// **'علاقة الوحدات'**
  String get itemUnitsRelation;

  /// No description provided for @itemBaseUnit.
  ///
  /// In ar, this message translates to:
  /// **'الوحدة الأساسية'**
  String get itemBaseUnit;

  /// No description provided for @itemLargeUnit.
  ///
  /// In ar, this message translates to:
  /// **'الوحدة الكبيرة'**
  String get itemLargeUnit;

  /// No description provided for @itemUnitsPerLarge.
  ///
  /// In ar, this message translates to:
  /// **'عدد الوحدات الصغرى في الكبرى'**
  String get itemUnitsPerLarge;

  /// No description provided for @itemCurrentStock.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد الحالي'**
  String get itemCurrentStock;

  /// No description provided for @itemProfitMargin.
  ///
  /// In ar, this message translates to:
  /// **'هامش الربح'**
  String get itemProfitMargin;

  /// No description provided for @statusNormal.
  ///
  /// In ar, this message translates to:
  /// **'مخزون طبيعي'**
  String get statusNormal;

  /// No description provided for @statusHealthy.
  ///
  /// In ar, this message translates to:
  /// **'سليمة'**
  String get statusHealthy;

  /// No description provided for @statusNearExpiry.
  ///
  /// In ar, this message translates to:
  /// **'قريب الانتهاء'**
  String get statusNearExpiry;

  /// No description provided for @statusExpired.
  ///
  /// In ar, this message translates to:
  /// **'منتهٍ'**
  String get statusExpired;

  /// No description provided for @batchesTitle.
  ///
  /// In ar, this message translates to:
  /// **'تشغيلات المنتج'**
  String get batchesTitle;

  /// No description provided for @batchesAdd.
  ///
  /// In ar, this message translates to:
  /// **'إدخال تشغيلة'**
  String get batchesAdd;

  /// No description provided for @batchesAddTitle.
  ///
  /// In ar, this message translates to:
  /// **'إدخال تشغيلة جديدة'**
  String get batchesAddTitle;

  /// No description provided for @batchesVoidTitle.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء التشغيلة'**
  String get batchesVoidTitle;

  /// No description provided for @batchesVoidConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد إلغاء هذه التشغيلة؟'**
  String get batchesVoidConfirm;

  /// No description provided for @batchesAddedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم إدخال التشغيلة'**
  String get batchesAddedMessage;

  /// No description provided for @batchesVoidedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء التشغيلة'**
  String get batchesVoidedMessage;

  /// No description provided for @batchesEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد تشغيلات'**
  String get batchesEmpty;

  /// No description provided for @batchUnitCost.
  ///
  /// In ar, this message translates to:
  /// **'تكلفة الوحدة'**
  String get batchUnitCost;

  /// No description provided for @batchReceivedDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الاستلام'**
  String get batchReceivedDate;

  /// No description provided for @batchBonusQty.
  ///
  /// In ar, this message translates to:
  /// **'كمية الهدية'**
  String get batchBonusQty;

  /// No description provided for @batchNotes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات التشغيلة'**
  String get batchNotes;

  /// No description provided for @batchRemaining.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد المتبقي'**
  String get batchRemaining;

  /// No description provided for @batchVoided.
  ///
  /// In ar, this message translates to:
  /// **'ملغاة'**
  String get batchVoided;

  /// No description provided for @movementType.
  ///
  /// In ar, this message translates to:
  /// **'نوع الحركة'**
  String get movementType;

  /// No description provided for @moveOpening.
  ///
  /// In ar, this message translates to:
  /// **'افتتاحي'**
  String get moveOpening;

  /// No description provided for @movePurchase.
  ///
  /// In ar, this message translates to:
  /// **'شراء'**
  String get movePurchase;

  /// No description provided for @moveSale.
  ///
  /// In ar, this message translates to:
  /// **'بيع'**
  String get moveSale;

  /// No description provided for @moveSaleReturn.
  ///
  /// In ar, this message translates to:
  /// **'مرتجع مبيعات'**
  String get moveSaleReturn;

  /// No description provided for @movePurchaseReturn.
  ///
  /// In ar, this message translates to:
  /// **'مرتجع شراء'**
  String get movePurchaseReturn;

  /// No description provided for @moveAdjustment.
  ///
  /// In ar, this message translates to:
  /// **'ضبط مخزون'**
  String get moveAdjustment;

  /// No description provided for @moveDamaged.
  ///
  /// In ar, this message translates to:
  /// **'تالف'**
  String get moveDamaged;

  /// No description provided for @moveExpired.
  ///
  /// In ar, this message translates to:
  /// **'منتهي الصلاحية'**
  String get moveExpired;

  /// No description provided for @moveTransfer.
  ///
  /// In ar, this message translates to:
  /// **'تحويل'**
  String get moveTransfer;

  /// No description provided for @moveCorrection.
  ///
  /// In ar, this message translates to:
  /// **'تصحيح يدوي'**
  String get moveCorrection;

  /// No description provided for @movementsList.
  ///
  /// In ar, this message translates to:
  /// **'سجل الحركات'**
  String get movementsList;

  /// No description provided for @movementsDate.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get movementsDate;

  /// No description provided for @movementsDelta.
  ///
  /// In ar, this message translates to:
  /// **'الكمية'**
  String get movementsDelta;

  /// No description provided for @movementsBalance.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد بعد الحركة'**
  String get movementsBalance;

  /// No description provided for @adjustStockTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسوية مخزون'**
  String get adjustStockTitle;

  /// No description provided for @adjustStockDone.
  ///
  /// In ar, this message translates to:
  /// **'تمت التسوية'**
  String get adjustStockDone;

  /// No description provided for @adjustNote.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة التسوية'**
  String get adjustNote;

  /// No description provided for @adjustmentIncrease.
  ///
  /// In ar, this message translates to:
  /// **'إضافة رصيد'**
  String get adjustmentIncrease;

  /// No description provided for @adjustmentDecrease.
  ///
  /// In ar, this message translates to:
  /// **'خصم رصيد'**
  String get adjustmentDecrease;

  /// No description provided for @bulkAction.
  ///
  /// In ar, this message translates to:
  /// **'إجراء جماعي'**
  String get bulkAction;

  /// No description provided for @bulkTitle.
  ///
  /// In ar, this message translates to:
  /// **'إجراءات جماعية'**
  String get bulkTitle;

  /// No description provided for @bulkChangeCategory.
  ///
  /// In ar, this message translates to:
  /// **'تغيير التصنيف'**
  String get bulkChangeCategory;

  /// No description provided for @bulkChangeShelf.
  ///
  /// In ar, this message translates to:
  /// **'تغيير موقع الرف'**
  String get bulkChangeShelf;

  /// No description provided for @bulkAdjustPricePercent.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الأسعار بنسبة'**
  String get bulkAdjustPricePercent;

  /// No description provided for @bulkPercent.
  ///
  /// In ar, this message translates to:
  /// **'النسبة المئوية'**
  String get bulkPercent;

  /// No description provided for @bulkSelectedCount.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديد {count} منتج'**
  String bulkSelectedCount(int count);

  /// No description provided for @bulkDone.
  ///
  /// In ar, this message translates to:
  /// **'اكتملت العملية على {count} منتج'**
  String bulkDone(int count);

  /// No description provided for @bulkSelectHint.
  ///
  /// In ar, this message translates to:
  /// **'حدد منتجًا واحدًا على الأقل'**
  String get bulkSelectHint;

  /// No description provided for @categoriesTitle.
  ///
  /// In ar, this message translates to:
  /// **'التصنيفات'**
  String get categoriesTitle;

  /// No description provided for @categoriesAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة تصنيف'**
  String get categoriesAdd;

  /// No description provided for @categoriesAddTitle.
  ///
  /// In ar, this message translates to:
  /// **'إضافة تصنيف جديد'**
  String get categoriesAddTitle;

  /// No description provided for @categoriesEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل تصنيف'**
  String get categoriesEditTitle;

  /// No description provided for @subCategoriesAddTitle.
  ///
  /// In ar, this message translates to:
  /// **'إضافة تصنيف فرعي'**
  String get subCategoriesAddTitle;

  /// No description provided for @subCategoriesEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل تصنيف فرعي'**
  String get subCategoriesEditTitle;

  /// No description provided for @addSubCategory.
  ///
  /// In ar, this message translates to:
  /// **'إضافة تصنيف فرعي'**
  String get addSubCategory;

  /// No description provided for @categoriesEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد تصنيفات'**
  String get categoriesEmpty;

  /// No description provided for @categoryName.
  ///
  /// In ar, this message translates to:
  /// **'اسم التصنيف'**
  String get categoryName;

  /// No description provided for @categoryNameEn.
  ///
  /// In ar, this message translates to:
  /// **'اسم التصنيف (إنجليزي)'**
  String get categoryNameEn;

  /// No description provided for @subCategoryName.
  ///
  /// In ar, this message translates to:
  /// **'اسم التصنيف الفرعي'**
  String get subCategoryName;

  /// No description provided for @manufacturerName.
  ///
  /// In ar, this message translates to:
  /// **'اسم المصنع'**
  String get manufacturerName;

  /// No description provided for @manufacturerCountry.
  ///
  /// In ar, this message translates to:
  /// **'الدولة'**
  String get manufacturerCountry;

  /// No description provided for @manufacturerWebsite.
  ///
  /// In ar, this message translates to:
  /// **'الموقع الإلكتروني'**
  String get manufacturerWebsite;

  /// No description provided for @manufacturersAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مصنع'**
  String get manufacturersAdd;

  /// No description provided for @manufacturersEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل مصنع'**
  String get manufacturersEditTitle;

  /// No description provided for @manufacturersEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مصانع'**
  String get manufacturersEmpty;

  /// No description provided for @groupName.
  ///
  /// In ar, this message translates to:
  /// **'اسم المجموعة'**
  String get groupName;

  /// No description provided for @groupsAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مجموعة'**
  String get groupsAdd;

  /// No description provided for @groupsEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل مجموعة'**
  String get groupsEditTitle;

  /// No description provided for @groupsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مجموعات'**
  String get groupsEmpty;

  /// No description provided for @unitName.
  ///
  /// In ar, this message translates to:
  /// **'اسم الوحدة'**
  String get unitName;

  /// No description provided for @unitAbbreviation.
  ///
  /// In ar, this message translates to:
  /// **'الاختصار'**
  String get unitAbbreviation;

  /// No description provided for @masterDataNameEn.
  ///
  /// In ar, this message translates to:
  /// **'الاسم (إنجليزي)'**
  String get masterDataNameEn;

  /// No description provided for @unitsAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة وحدة'**
  String get unitsAdd;

  /// No description provided for @unitsEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل وحدة'**
  String get unitsEditTitle;

  /// No description provided for @unitsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد وحدات'**
  String get unitsEmpty;

  /// No description provided for @masterDataSavedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ بنجاح'**
  String get masterDataSavedMessage;

  /// No description provided for @inventoryRequiredName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم مطلوب'**
  String get inventoryRequiredName;

  /// No description provided for @inventorySelectCategory.
  ///
  /// In ar, this message translates to:
  /// **'اختر التصنيف'**
  String get inventorySelectCategory;

  /// No description provided for @inventoryBatches.
  ///
  /// In ar, this message translates to:
  /// **'التشغيلات'**
  String get inventoryBatches;

  /// No description provided for @inventoryAdjustStock.
  ///
  /// In ar, this message translates to:
  /// **'تسوية المخزون'**
  String get inventoryAdjustStock;

  /// No description provided for @inventoryBatchView.
  ///
  /// In ar, this message translates to:
  /// **'عرض التشغيلات'**
  String get inventoryBatchView;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
