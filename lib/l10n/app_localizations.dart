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

  /// No description provided for @suppliersTab.
  ///
  /// In ar, this message translates to:
  /// **'الموردون'**
  String get suppliersTab;

  /// No description provided for @suppliersBalancesTab.
  ///
  /// In ar, this message translates to:
  /// **'الأرصدة'**
  String get suppliersBalancesTab;

  /// No description provided for @suppliersEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد موردون'**
  String get suppliersEmpty;

  /// No description provided for @suppliersSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'بحث بالاسم أو الهاتف أو الكود'**
  String get suppliersSearchHint;

  /// No description provided for @supplierAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مورد'**
  String get supplierAdd;

  /// No description provided for @supplierAddTitle.
  ///
  /// In ar, this message translates to:
  /// **'مورد جديد'**
  String get supplierAddTitle;

  /// No description provided for @supplierEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل مورد'**
  String get supplierEditTitle;

  /// No description provided for @supplierName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get supplierName;

  /// No description provided for @supplierCode.
  ///
  /// In ar, this message translates to:
  /// **'الكود'**
  String get supplierCode;

  /// No description provided for @supplierPhone.
  ///
  /// In ar, this message translates to:
  /// **'الهاتف'**
  String get supplierPhone;

  /// No description provided for @supplierSecondaryPhone.
  ///
  /// In ar, this message translates to:
  /// **'هاتف ثانٍ'**
  String get supplierSecondaryPhone;

  /// No description provided for @supplierEmail.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get supplierEmail;

  /// No description provided for @supplierAddress.
  ///
  /// In ar, this message translates to:
  /// **'العنوان'**
  String get supplierAddress;

  /// No description provided for @supplierContactPerson.
  ///
  /// In ar, this message translates to:
  /// **'جهة الاتصال'**
  String get supplierContactPerson;

  /// No description provided for @supplierTaxVatNumber.
  ///
  /// In ar, this message translates to:
  /// **'الرقم الضريبي'**
  String get supplierTaxVatNumber;

  /// No description provided for @supplierLicenseRegistration.
  ///
  /// In ar, this message translates to:
  /// **'الترخيص / السجل'**
  String get supplierLicenseRegistration;

  /// No description provided for @supplierOpeningBalance.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد الافتتاحي'**
  String get supplierOpeningBalance;

  /// No description provided for @supplierCreditLimit.
  ///
  /// In ar, this message translates to:
  /// **'الحد الائتماني'**
  String get supplierCreditLimit;

  /// No description provided for @supplierNotes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get supplierNotes;

  /// No description provided for @supplierCreatedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تمت إضافة المورد'**
  String get supplierCreatedMessage;

  /// No description provided for @supplierUpdatedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم تعديل المورد'**
  String get supplierUpdatedMessage;

  /// No description provided for @supplierActivatedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تمت إعادة تفعيل المورد'**
  String get supplierActivatedMessage;

  /// No description provided for @supplierDeactivatedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم تعطيل المورد'**
  String get supplierDeactivatedMessage;

  /// No description provided for @supplierDeactivateConfirmMessage.
  ///
  /// In ar, this message translates to:
  /// **'تعطيل المورد «{name}»؟'**
  String supplierDeactivateConfirmMessage(Object name);

  /// No description provided for @supplierActivateConfirmMessage.
  ///
  /// In ar, this message translates to:
  /// **'إعادة تفعيل المورد «{name}»؟'**
  String supplierActivateConfirmMessage(Object name);

  /// No description provided for @supplierBalance.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد'**
  String get supplierBalance;

  /// No description provided for @supplierStatement.
  ///
  /// In ar, this message translates to:
  /// **'كشف الحساب'**
  String get supplierStatement;

  /// No description provided for @supplierStatementTitle.
  ///
  /// In ar, this message translates to:
  /// **'كشف حساب المورد'**
  String get supplierStatementTitle;

  /// No description provided for @supplierStatementDateFrom.
  ///
  /// In ar, this message translates to:
  /// **'من'**
  String get supplierStatementDateFrom;

  /// No description provided for @supplierStatementDateTo.
  ///
  /// In ar, this message translates to:
  /// **'إلى'**
  String get supplierStatementDateTo;

  /// No description provided for @statementDate.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get statementDate;

  /// No description provided for @statementDescription.
  ///
  /// In ar, this message translates to:
  /// **'البيان'**
  String get statementDescription;

  /// No description provided for @statementDebit.
  ///
  /// In ar, this message translates to:
  /// **'مدين'**
  String get statementDebit;

  /// No description provided for @statementCredit.
  ///
  /// In ar, this message translates to:
  /// **'دائن'**
  String get statementCredit;

  /// No description provided for @statementOpening.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد الافتتاحي'**
  String get statementOpening;

  /// No description provided for @statementClosing.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد الختامي'**
  String get statementClosing;

  /// No description provided for @statementBalance.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد'**
  String get statementBalance;

  /// No description provided for @statementRowInvoice.
  ///
  /// In ar, this message translates to:
  /// **'فاتورة شراء {number}'**
  String statementRowInvoice(Object number);

  /// No description provided for @statementRowReturn.
  ///
  /// In ar, this message translates to:
  /// **'مرتجع مشتريات {number}'**
  String statementRowReturn(Object number);

  /// No description provided for @statementNoData.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد حركات في هذا النطاق'**
  String get statementNoData;

  /// No description provided for @purchaseStatusPending.
  ///
  /// In ar, this message translates to:
  /// **'معلّقة'**
  String get purchaseStatusPending;

  /// No description provided for @purchaseStatusReceived.
  ///
  /// In ar, this message translates to:
  /// **'مُستلمة'**
  String get purchaseStatusReceived;

  /// No description provided for @purchaseStatusCancelled.
  ///
  /// In ar, this message translates to:
  /// **'ملغاة'**
  String get purchaseStatusCancelled;

  /// No description provided for @purchaseAddInvoice.
  ///
  /// In ar, this message translates to:
  /// **'فاتورة شراء جديدة'**
  String get purchaseAddInvoice;

  /// No description provided for @purchasesEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد فواتير شراء'**
  String get purchasesEmpty;

  /// No description provided for @purchasesSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'بحث برقم الفاتورة'**
  String get purchasesSearchHint;

  /// No description provided for @purchasesFilterSupplier.
  ///
  /// In ar, this message translates to:
  /// **'كل الموردين'**
  String get purchasesFilterSupplier;

  /// No description provided for @purchasesFilterStatus.
  ///
  /// In ar, this message translates to:
  /// **'كل الحالات'**
  String get purchasesFilterStatus;

  /// No description provided for @purchaseInvoiceNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الفاتورة'**
  String get purchaseInvoiceNumber;

  /// No description provided for @purchaseInvoiceDate.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get purchaseInvoiceDate;

  /// No description provided for @purchaseSupplierLabel.
  ///
  /// In ar, this message translates to:
  /// **'المورد'**
  String get purchaseSupplierLabel;

  /// No description provided for @purchaseTotal.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get purchaseTotal;

  /// No description provided for @purchasePaid.
  ///
  /// In ar, this message translates to:
  /// **'المدفوع'**
  String get purchasePaid;

  /// No description provided for @purchaseRemaining.
  ///
  /// In ar, this message translates to:
  /// **'المتبقي'**
  String get purchaseRemaining;

  /// No description provided for @purchaseCreateTitle.
  ///
  /// In ar, this message translates to:
  /// **'فاتورة شراء جديدة'**
  String get purchaseCreateTitle;

  /// No description provided for @purchaseEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل فاتورة الشراء'**
  String get purchaseEditTitle;

  /// No description provided for @purchaseOrderNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الفاتورة'**
  String get purchaseOrderNumber;

  /// No description provided for @purchaseOrderDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الفاتورة'**
  String get purchaseOrderDate;

  /// No description provided for @purchaseExpectedDate.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ المتوقع (اختياري)'**
  String get purchaseExpectedDate;

  /// No description provided for @purchasePaidAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المدفوع'**
  String get purchasePaidAmount;

  /// No description provided for @purchaseNotes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get purchaseNotes;

  /// No description provided for @purchaseSubtotal.
  ///
  /// In ar, this message translates to:
  /// **'المجموع الفرعي'**
  String get purchaseSubtotal;

  /// No description provided for @purchaseDiscount.
  ///
  /// In ar, this message translates to:
  /// **'الخصومات'**
  String get purchaseDiscount;

  /// No description provided for @purchaseGrandTotal.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي النهائي'**
  String get purchaseGrandTotal;

  /// No description provided for @purchaseItemPlaceholder.
  ///
  /// In ar, this message translates to:
  /// **'اختر منتجاً'**
  String get purchaseItemPlaceholder;

  /// No description provided for @purchaseItemSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'بحث عن منتج…'**
  String get purchaseItemSearchHint;

  /// No description provided for @purchaseQty.
  ///
  /// In ar, this message translates to:
  /// **'الكمية'**
  String get purchaseQty;

  /// No description provided for @purchaseUnitCost.
  ///
  /// In ar, this message translates to:
  /// **'سعر الوحدة'**
  String get purchaseUnitCost;

  /// No description provided for @purchaseUnitType.
  ///
  /// In ar, this message translates to:
  /// **'الوحدة'**
  String get purchaseUnitType;

  /// No description provided for @purchaseDiscountPct.
  ///
  /// In ar, this message translates to:
  /// **'الخصم %'**
  String get purchaseDiscountPct;

  /// No description provided for @purchaseBonus.
  ///
  /// In ar, this message translates to:
  /// **'الهدايا/البونص'**
  String get purchaseBonus;

  /// No description provided for @purchaseAddLine.
  ///
  /// In ar, this message translates to:
  /// **'إضافة سطر'**
  String get purchaseAddLine;

  /// No description provided for @purchaseRemoveLine.
  ///
  /// In ar, this message translates to:
  /// **'حذف السطر'**
  String get purchaseRemoveLine;

  /// No description provided for @purchaseNoLines.
  ///
  /// In ar, this message translates to:
  /// **'أضف سطراً واحداً على الأقل'**
  String get purchaseNoLines;

  /// No description provided for @purchaseReceive.
  ///
  /// In ar, this message translates to:
  /// **'استلام'**
  String get purchaseReceive;

  /// No description provided for @purchaseCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الفاتورة'**
  String get purchaseCancel;

  /// No description provided for @purchaseReturn.
  ///
  /// In ar, this message translates to:
  /// **'مرتجع'**
  String get purchaseReturn;

  /// No description provided for @purchaseReceiveTitle.
  ///
  /// In ar, this message translates to:
  /// **'استلام فاتورة الشراء'**
  String get purchaseReceiveTitle;

  /// No description provided for @purchaseReceiveIntro.
  ///
  /// In ar, this message translates to:
  /// **'أدخل أرقام التشغيلات لاستلام المخزون'**
  String get purchaseReceiveIntro;

  /// No description provided for @purchaseBatchNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم التشغيلة'**
  String get purchaseBatchNumber;

  /// No description provided for @purchaseExpiryDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الصلاحية (اختياري)'**
  String get purchaseExpiryDate;

  /// No description provided for @purchaseReceivedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم استلام الفاتورة وإنشاء التشغيلات'**
  String get purchaseReceivedMessage;

  /// No description provided for @purchaseCreatedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ فاتورة الشراء'**
  String get purchaseCreatedMessage;

  /// No description provided for @purchaseUpdatedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم تعديل فاتورة الشراء'**
  String get purchaseUpdatedMessage;

  /// No description provided for @purchaseCancelledMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء فاتورة الشراء'**
  String get purchaseCancelledMessage;

  /// No description provided for @purchaseCancelConfirm.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء هذه الفاتورة؟'**
  String get purchaseCancelConfirm;

  /// No description provided for @purchaseDetailTitle.
  ///
  /// In ar, this message translates to:
  /// **'فاتورة شراء'**
  String get purchaseDetailTitle;

  /// No description provided for @purchaseReturnTitle.
  ///
  /// In ar, this message translates to:
  /// **'مرتجع مشتريات'**
  String get purchaseReturnTitle;

  /// No description provided for @purchaseReturnOrderNo.
  ///
  /// In ar, this message translates to:
  /// **'رقم المرتجع'**
  String get purchaseReturnOrderNo;

  /// No description provided for @purchaseReturnQty.
  ///
  /// In ar, this message translates to:
  /// **'الكمية المرتجعة'**
  String get purchaseReturnQty;

  /// No description provided for @purchaseReturnAvailable.
  ///
  /// In ar, this message translates to:
  /// **'المتاح'**
  String get purchaseReturnAvailable;

  /// No description provided for @purchaseReturnReason.
  ///
  /// In ar, this message translates to:
  /// **'السبب (اختياري)'**
  String get purchaseReturnReason;

  /// No description provided for @purchaseReturnSavedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل المرتجع'**
  String get purchaseReturnSavedMessage;

  /// No description provided for @purchaseReturnValidation.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من كميات المرتجع'**
  String get purchaseReturnValidation;

  /// No description provided for @purchaseBonus1.
  ///
  /// In ar, this message translates to:
  /// **'بونص 1'**
  String get purchaseBonus1;

  /// No description provided for @purchaseBonus2.
  ///
  /// In ar, this message translates to:
  /// **'بونص 2'**
  String get purchaseBonus2;

  /// No description provided for @purchaseBonusGift.
  ///
  /// In ar, this message translates to:
  /// **'هدية'**
  String get purchaseBonusGift;

  /// No description provided for @purchaseBonusButton.
  ///
  /// In ar, this message translates to:
  /// **'بونص'**
  String get purchaseBonusButton;

  /// No description provided for @purchaseBonusItem.
  ///
  /// In ar, this message translates to:
  /// **'منتج البونص'**
  String get purchaseBonusItem;

  /// No description provided for @purchaseStatusLabel.
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get purchaseStatusLabel;

  /// No description provided for @purchaseRequiredSupplier.
  ///
  /// In ar, this message translates to:
  /// **'اختر المورد'**
  String get purchaseRequiredSupplier;

  /// No description provided for @purchaseRequiredLines.
  ///
  /// In ar, this message translates to:
  /// **'أضف سطراً واحداً على الأقل'**
  String get purchaseRequiredLines;

  /// No description provided for @purchaseRequiredNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الفاتورة مطلوب'**
  String get purchaseRequiredNumber;

  /// No description provided for @purchaseItemNotNull.
  ///
  /// In ar, this message translates to:
  /// **'اختر منتجاً لكل سطر'**
  String get purchaseItemNotNull;

  /// No description provided for @purchaseQtyPositive.
  ///
  /// In ar, this message translates to:
  /// **'الكمية يجب أن تكون موجبة'**
  String get purchaseQtyPositive;

  /// No description provided for @purchaseCostPositive.
  ///
  /// In ar, this message translates to:
  /// **'سعر الوحدة يجب أن يكون موجباً'**
  String get purchaseCostPositive;

  /// No description provided for @supplierNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'الاسم مطلوب'**
  String get supplierNameRequired;

  /// No description provided for @customersTab.
  ///
  /// In ar, this message translates to:
  /// **'العملاء'**
  String get customersTab;

  /// No description provided for @customersEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد عملاء'**
  String get customersEmpty;

  /// No description provided for @customersSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'بحث بالاسم أو الهاتف أو البريد'**
  String get customersSearchHint;

  /// No description provided for @customerAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة عميل'**
  String get customerAdd;

  /// No description provided for @customerAddTitle.
  ///
  /// In ar, this message translates to:
  /// **'عميل جديد'**
  String get customerAddTitle;

  /// No description provided for @customerEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل عميل'**
  String get customerEditTitle;

  /// No description provided for @customerName.
  ///
  /// In ar, this message translates to:
  /// **'اسم العميل'**
  String get customerName;

  /// No description provided for @customerPhone.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get customerPhone;

  /// No description provided for @customerSecondaryPhone.
  ///
  /// In ar, this message translates to:
  /// **'هاتف آخر'**
  String get customerSecondaryPhone;

  /// No description provided for @customerEmail.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get customerEmail;

  /// No description provided for @customerAddress.
  ///
  /// In ar, this message translates to:
  /// **'العنوان'**
  String get customerAddress;

  /// No description provided for @customerNotes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get customerNotes;

  /// No description provided for @customerHasAccount.
  ///
  /// In ar, this message translates to:
  /// **'حساب آجل (ائتماني)'**
  String get customerHasAccount;

  /// No description provided for @customerAccount.
  ///
  /// In ar, this message translates to:
  /// **'الحساب'**
  String get customerAccount;

  /// No description provided for @customerAccountEnabled.
  ///
  /// In ar, this message translates to:
  /// **'مفعّل'**
  String get customerAccountEnabled;

  /// No description provided for @customerAccountDisabled.
  ///
  /// In ar, this message translates to:
  /// **'غير مفعّل'**
  String get customerAccountDisabled;

  /// No description provided for @customerOpeningBalance.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد الافتتاحي'**
  String get customerOpeningBalance;

  /// No description provided for @customerCreditLimit.
  ///
  /// In ar, this message translates to:
  /// **'الحد الائتماني'**
  String get customerCreditLimit;

  /// No description provided for @customerDateOfBirth.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الميلاد'**
  String get customerDateOfBirth;

  /// No description provided for @customerGender.
  ///
  /// In ar, this message translates to:
  /// **'الجنس'**
  String get customerGender;

  /// No description provided for @customerGenderMale.
  ///
  /// In ar, this message translates to:
  /// **'ذكر'**
  String get customerGenderMale;

  /// No description provided for @customerGenderFemale.
  ///
  /// In ar, this message translates to:
  /// **'أنثى'**
  String get customerGenderFemale;

  /// No description provided for @customerMedicalHistory.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ المرضي'**
  String get customerMedicalHistory;

  /// No description provided for @customerTaxVatNumber.
  ///
  /// In ar, this message translates to:
  /// **'الرقم الضريبي'**
  String get customerTaxVatNumber;

  /// No description provided for @customerBalance.
  ///
  /// In ar, this message translates to:
  /// **'رصيد الحساب'**
  String get customerBalance;

  /// No description provided for @customerNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'اسم العميل مطلوب'**
  String get customerNameRequired;

  /// No description provided for @customerCreatedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم إضافة العميل'**
  String get customerCreatedMessage;

  /// No description provided for @customerUpdatedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث بيانات العميل'**
  String get customerUpdatedMessage;

  /// No description provided for @customerActivatedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم تفعيل العميل'**
  String get customerActivatedMessage;

  /// No description provided for @customerDeactivatedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم تعطيل العميل'**
  String get customerDeactivatedMessage;

  /// No description provided for @customerAccountEnabledMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم تفعيل الحساب الائتماني'**
  String get customerAccountEnabledMessage;

  /// No description provided for @customerAccountDisabledMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم تعطيل الحساب الائتماني'**
  String get customerAccountDisabledMessage;

  /// No description provided for @customerDeactivateConfirmMessage.
  ///
  /// In ar, this message translates to:
  /// **'تعطيل العميل «{name}»؟'**
  String customerDeactivateConfirmMessage(String name);

  /// No description provided for @customerActivateConfirmMessage.
  ///
  /// In ar, this message translates to:
  /// **'إعادة تفعيل العميل «{name}»؟'**
  String customerActivateConfirmMessage(String name);

  /// No description provided for @customerAccountDisableConfirmMessage.
  ///
  /// In ar, this message translates to:
  /// **'تعطيل الحساب الائتماني للعميل «{name}»؟'**
  String customerAccountDisableConfirmMessage(String name);

  /// No description provided for @customerAccountEnableConfirmMessage.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل الحساب الائتماني للعميل «{name}»؟'**
  String customerAccountEnableConfirmMessage(String name);

  /// No description provided for @customerStatement.
  ///
  /// In ar, this message translates to:
  /// **'كشف الحساب'**
  String get customerStatement;

  /// No description provided for @customerViewPrescriptions.
  ///
  /// In ar, this message translates to:
  /// **'وصفات العميل'**
  String get customerViewPrescriptions;

  /// No description provided for @customerStatementDateFrom.
  ///
  /// In ar, this message translates to:
  /// **'من'**
  String get customerStatementDateFrom;

  /// No description provided for @customerStatementDateTo.
  ///
  /// In ar, this message translates to:
  /// **'إلى'**
  String get customerStatementDateTo;

  /// No description provided for @statementRowSaleInvoice.
  ///
  /// In ar, this message translates to:
  /// **'فاتورة بيع {number}'**
  String statementRowSaleInvoice(String number);

  /// No description provided for @statementRowSaleReturn.
  ///
  /// In ar, this message translates to:
  /// **'مرتجع بيع {number}'**
  String statementRowSaleReturn(String number);

  /// No description provided for @prescriptionsTab.
  ///
  /// In ar, this message translates to:
  /// **'الوصفات الطبية'**
  String get prescriptionsTab;

  /// No description provided for @prescriptionsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد وصفات'**
  String get prescriptionsEmpty;

  /// No description provided for @prescriptionsSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'بحث برقم الوصفة أو المريض أو الطبيب'**
  String get prescriptionsSearchHint;

  /// No description provided for @prescriptionAdd.
  ///
  /// In ar, this message translates to:
  /// **'وصفة جديدة'**
  String get prescriptionAdd;

  /// No description provided for @prescriptionAddTitle.
  ///
  /// In ar, this message translates to:
  /// **'وصفة طبية جديدة'**
  String get prescriptionAddTitle;

  /// No description provided for @prescriptionNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الوصفة'**
  String get prescriptionNumber;

  /// No description provided for @prescriptionPatient.
  ///
  /// In ar, this message translates to:
  /// **'المريض'**
  String get prescriptionPatient;

  /// No description provided for @prescriptionPatientName.
  ///
  /// In ar, this message translates to:
  /// **'اسم المريض'**
  String get prescriptionPatientName;

  /// No description provided for @prescriptionPatientAge.
  ///
  /// In ar, this message translates to:
  /// **'العمر'**
  String get prescriptionPatientAge;

  /// No description provided for @prescriptionPatientGender.
  ///
  /// In ar, this message translates to:
  /// **'جنس المريض'**
  String get prescriptionPatientGender;

  /// No description provided for @prescriptionDoctorName.
  ///
  /// In ar, this message translates to:
  /// **'اسم الطبيب'**
  String get prescriptionDoctorName;

  /// No description provided for @prescriptionDoctorSpecialty.
  ///
  /// In ar, this message translates to:
  /// **'التخصص'**
  String get prescriptionDoctorSpecialty;

  /// No description provided for @prescriptionClinicHospital.
  ///
  /// In ar, this message translates to:
  /// **'العيادة / المستشفى'**
  String get prescriptionClinicHospital;

  /// No description provided for @prescriptionIssuedAt.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الوصفة'**
  String get prescriptionIssuedAt;

  /// No description provided for @prescriptionExpiryAt.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الانتهاء'**
  String get prescriptionExpiryAt;

  /// No description provided for @prescriptionNotes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات الوصفة'**
  String get prescriptionNotes;

  /// No description provided for @prescriptionImagePath.
  ///
  /// In ar, this message translates to:
  /// **'مسار صورة الوصفة'**
  String get prescriptionImagePath;

  /// No description provided for @prescriptionItems.
  ///
  /// In ar, this message translates to:
  /// **'أصناف الوصفة'**
  String get prescriptionItems;

  /// No description provided for @prescriptionAddItem.
  ///
  /// In ar, this message translates to:
  /// **'إضافة صنف'**
  String get prescriptionAddItem;

  /// No description provided for @prescriptionItem.
  ///
  /// In ar, this message translates to:
  /// **'الصنف'**
  String get prescriptionItem;

  /// No description provided for @prescriptionQuantity.
  ///
  /// In ar, this message translates to:
  /// **'الكمية (الوحدات الأساسية)'**
  String get prescriptionQuantity;

  /// No description provided for @prescriptionDosage.
  ///
  /// In ar, this message translates to:
  /// **'الجرعة'**
  String get prescriptionDosage;

  /// No description provided for @prescriptionFrequency.
  ///
  /// In ar, this message translates to:
  /// **'التكرار'**
  String get prescriptionFrequency;

  /// No description provided for @prescriptionDurationDays.
  ///
  /// In ar, this message translates to:
  /// **'مدة العلاج (أيام)'**
  String get prescriptionDurationDays;

  /// No description provided for @prescriptionLineNotes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات السطر'**
  String get prescriptionLineNotes;

  /// No description provided for @prescriptionStatus.
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get prescriptionStatus;

  /// No description provided for @prescriptionStatusActive.
  ///
  /// In ar, this message translates to:
  /// **'نشطة'**
  String get prescriptionStatusActive;

  /// No description provided for @prescriptionStatusPartiallyDispensed.
  ///
  /// In ar, this message translates to:
  /// **'صرف جزئي'**
  String get prescriptionStatusPartiallyDispensed;

  /// No description provided for @prescriptionStatusDispensed.
  ///
  /// In ar, this message translates to:
  /// **'تم صرفها'**
  String get prescriptionStatusDispensed;

  /// No description provided for @prescriptionStatusExpired.
  ///
  /// In ar, this message translates to:
  /// **'منتهية'**
  String get prescriptionStatusExpired;

  /// No description provided for @prescriptionStatusCancelled.
  ///
  /// In ar, this message translates to:
  /// **'ملغاة'**
  String get prescriptionStatusCancelled;

  /// No description provided for @prescriptionCustomer.
  ///
  /// In ar, this message translates to:
  /// **'العميل'**
  String get prescriptionCustomer;

  /// No description provided for @prescriptionRequiredCustomer.
  ///
  /// In ar, this message translates to:
  /// **'يجب اختيار عميل للوصفة — لا تُنشأ وصفات بدون مريض'**
  String get prescriptionRequiredCustomer;

  /// No description provided for @prescriptionRequiredPatient.
  ///
  /// In ar, this message translates to:
  /// **'اسم المريض مطلوب'**
  String get prescriptionRequiredPatient;

  /// No description provided for @prescriptionRequiredItems.
  ///
  /// In ar, this message translates to:
  /// **'أضف صنفاً واحداً على الأقل'**
  String get prescriptionRequiredItems;

  /// No description provided for @prescriptionRequiredQuantity.
  ///
  /// In ar, this message translates to:
  /// **'الكمية يجب أن تكون أكبر من صفر'**
  String get prescriptionRequiredQuantity;

  /// No description provided for @prescriptionCreatedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء الوصفة'**
  String get prescriptionCreatedMessage;

  /// No description provided for @prescriptionDetail.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الوصفة'**
  String get prescriptionDetail;

  /// No description provided for @prescriptionPrepareForSale.
  ///
  /// In ar, this message translates to:
  /// **'تجهيز للبيع'**
  String get prescriptionPrepareForSale;

  /// No description provided for @prescriptionPreparedMessage.
  ///
  /// In ar, this message translates to:
  /// **'الوصفة جاهزة للربط في نقطة البيع'**
  String get prescriptionPreparedMessage;

  /// No description provided for @prescriptionCannotPrepare.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن ربط هذه الوصفة بالبيع'**
  String get prescriptionCannotPrepare;

  /// No description provided for @partialSaleSection.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات البيع الجزئي'**
  String get partialSaleSection;

  /// No description provided for @partialSaleEnabled.
  ///
  /// In ar, this message translates to:
  /// **'السماح بالبيع الجزئي'**
  String get partialSaleEnabled;

  /// No description provided for @partialSaleSellablePart.
  ///
  /// In ar, this message translates to:
  /// **'وحدة البيع الجزئي'**
  String get partialSaleSellablePart;

  /// No description provided for @partialSalePartsPerFull.
  ///
  /// In ar, this message translates to:
  /// **'عدد الأجزاء في العبوة الكاملة'**
  String get partialSalePartsPerFull;

  /// No description provided for @partialSaleBaseQuantity.
  ///
  /// In ar, this message translates to:
  /// **'عدد الوحدات الأساسية في الجزء'**
  String get partialSaleBaseQuantity;

  /// No description provided for @partialSaleMarkupPercent.
  ///
  /// In ar, this message translates to:
  /// **'نسبة الزيادة %'**
  String get partialSaleMarkupPercent;

  /// No description provided for @posSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن دواء بالاسم أو الباركود...'**
  String get posSearchHint;

  /// No description provided for @posScanOrSearch.
  ///
  /// In ar, this message translates to:
  /// **'امسح الباركود أو ابحث عن منتج'**
  String get posScanOrSearch;

  /// No description provided for @posCustomerTab.
  ///
  /// In ar, this message translates to:
  /// **'عميل {tab}'**
  String posCustomerTab(int tab);

  /// No description provided for @posReturnTab.
  ///
  /// In ar, this message translates to:
  /// **'مرتجعات'**
  String get posReturnTab;

  /// No description provided for @posCartItemEmpty.
  ///
  /// In ar, this message translates to:
  /// **'السلة فارغة — أضف أصنافاً للبيع'**
  String get posCartItemEmpty;

  /// No description provided for @posUnitBox.
  ///
  /// In ar, this message translates to:
  /// **'علبة'**
  String get posUnitBox;

  /// No description provided for @posUnitStrip.
  ///
  /// In ar, this message translates to:
  /// **'شرائط'**
  String get posUnitStrip;

  /// No description provided for @posUnitUnit.
  ///
  /// In ar, this message translates to:
  /// **'وحدة'**
  String get posUnitUnit;

  /// No description provided for @posTotalLabel.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get posTotalLabel;

  /// No description provided for @posPayButton.
  ///
  /// In ar, this message translates to:
  /// **'دفع (F12)'**
  String get posPayButton;

  /// No description provided for @posHoldBill.
  ///
  /// In ar, this message translates to:
  /// **'حفظ فاتورة (F5)'**
  String get posHoldBill;

  /// No description provided for @posHoldBillSaved.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ الفاتورة مؤقتاً'**
  String get posHoldBillSaved;

  /// No description provided for @posHoldBillRestored.
  ///
  /// In ar, this message translates to:
  /// **'تم استرجاع الفاتورة'**
  String get posHoldBillRestored;

  /// No description provided for @posHoldBillEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد فواتير محفوظة'**
  String get posHoldBillEmpty;

  /// No description provided for @posCheckoutComplete.
  ///
  /// In ar, this message translates to:
  /// **'تم إتمام البيع بنجاح'**
  String get posCheckoutComplete;

  /// No description provided for @posPrintReceipt.
  ///
  /// In ar, this message translates to:
  /// **'طباعة الإيصال'**
  String get posPrintReceipt;

  /// No description provided for @posPrintFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر طباعة المستند'**
  String get posPrintFailed;

  /// No description provided for @zReportTitle.
  ///
  /// In ar, this message translates to:
  /// **'تقرير نهاية الوردية (Z)'**
  String get zReportTitle;

  /// No description provided for @zReportPrint.
  ///
  /// In ar, this message translates to:
  /// **'طباعة التقرير'**
  String get zReportPrint;

  /// No description provided for @zReportPeriodPrefix.
  ///
  /// In ar, this message translates to:
  /// **'الفترة'**
  String get zReportPeriodPrefix;

  /// No description provided for @zReportFrom.
  ///
  /// In ar, this message translates to:
  /// **'من'**
  String get zReportFrom;

  /// No description provided for @zReportTo.
  ///
  /// In ar, this message translates to:
  /// **'إلى'**
  String get zReportTo;

  /// No description provided for @zReportDays.
  ///
  /// In ar, this message translates to:
  /// **'أيام'**
  String get zReportDays;

  /// No description provided for @zReportSalesSummary.
  ///
  /// In ar, this message translates to:
  /// **'ملخص المبيعات'**
  String get zReportSalesSummary;

  /// No description provided for @zReportReturnsSection.
  ///
  /// In ar, this message translates to:
  /// **'المرتجعات والإلغاءات'**
  String get zReportReturnsSection;

  /// No description provided for @zReportDrawerSection.
  ///
  /// In ar, this message translates to:
  /// **'تسوية الخزينة'**
  String get zReportDrawerSection;

  /// No description provided for @zReportInvoicesCount.
  ///
  /// In ar, this message translates to:
  /// **'عدد الفواتير'**
  String get zReportInvoicesCount;

  /// No description provided for @zReportUnitsSold.
  ///
  /// In ar, this message translates to:
  /// **'الوحدات المباعة'**
  String get zReportUnitsSold;

  /// No description provided for @zReportTotalSales.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي المبيعات'**
  String get zReportTotalSales;

  /// No description provided for @zReportCash.
  ///
  /// In ar, this message translates to:
  /// **'نقداً'**
  String get zReportCash;

  /// No description provided for @zReportCard.
  ///
  /// In ar, this message translates to:
  /// **'بطاقة'**
  String get zReportCard;

  /// No description provided for @zReportCredit.
  ///
  /// In ar, this message translates to:
  /// **'آجل (ذمم)'**
  String get zReportCredit;

  /// No description provided for @zReportReturnsBrief.
  ///
  /// In ar, this message translates to:
  /// **'المرتجعات (عدد / قيمة)'**
  String get zReportReturnsBrief;

  /// No description provided for @zReportVoidsBrief.
  ///
  /// In ar, this message translates to:
  /// **'الفواتير الملغاة (عدد / قيمة)'**
  String get zReportVoidsBrief;

  /// No description provided for @zReportCustomerCollected.
  ///
  /// In ar, this message translates to:
  /// **'تحصيل ذمم العملاء'**
  String get zReportCustomerCollected;

  /// No description provided for @zReportCustomerRefunded.
  ///
  /// In ar, this message translates to:
  /// **'استرداد ذمم العملاء'**
  String get zReportCustomerRefunded;

  /// No description provided for @zReportDrawerOpening.
  ///
  /// In ar, this message translates to:
  /// **'رصيد الافتتاح'**
  String get zReportDrawerOpening;

  /// No description provided for @zReportDrawerNet.
  ///
  /// In ar, this message translates to:
  /// **'صافي الحركات'**
  String get zReportDrawerNet;

  /// No description provided for @zReportDrawerExpected.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد المتوقع (نهاية الفترة)'**
  String get zReportDrawerExpected;

  /// No description provided for @zReportDrawerLedger.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد الجاري (سجل الخزينة)'**
  String get zReportDrawerLedger;

  /// No description provided for @zReportDrawerDeclared.
  ///
  /// In ar, this message translates to:
  /// **'الإغلاق المعلن'**
  String get zReportDrawerDeclared;

  /// No description provided for @zReportDrawerDiff.
  ///
  /// In ar, this message translates to:
  /// **'فرق الخزينة'**
  String get zReportDrawerDiff;

  /// No description provided for @zReportEmptyPeriod.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مبيعات ضمن الفترة المحددة'**
  String get zReportEmptyPeriod;

  /// No description provided for @posReceiptSummaryTitle.
  ///
  /// In ar, this message translates to:
  /// **'ملخص الإيصال'**
  String get posReceiptSummaryTitle;

  /// No description provided for @posCashReceived.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المقبوض'**
  String get posCashReceived;

  /// No description provided for @posCardAmount.
  ///
  /// In ar, this message translates to:
  /// **'قيمة البطاقة'**
  String get posCardAmount;

  /// No description provided for @posChangeLabel.
  ///
  /// In ar, this message translates to:
  /// **'الباقي'**
  String get posChangeLabel;

  /// No description provided for @posMixedPayment.
  ///
  /// In ar, this message translates to:
  /// **'دفع مختلط (نقد + بطاقة)'**
  String get posMixedPayment;

  /// No description provided for @posInvalidPayment.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ غير كافٍ أو غير صحيح'**
  String get posInvalidPayment;

  /// No description provided for @posItemNotFound.
  ///
  /// In ar, this message translates to:
  /// **'المنتج غير موجود في الدليل'**
  String get posItemNotFound;

  /// No description provided for @posOutOfStock.
  ///
  /// In ar, this message translates to:
  /// **'نفدت الكمية'**
  String get posOutOfStock;

  /// No description provided for @posRequiresPrescription.
  ///
  /// In ar, this message translates to:
  /// **'يتطلب وصفة طبية نشطة'**
  String get posRequiresPrescription;

  /// No description provided for @posReturnSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث برقم الفاتورة أو اسم العميل...'**
  String get posReturnSearchHint;

  /// No description provided for @posNoInvoices.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد فواتير مطابقة'**
  String get posNoInvoices;

  /// No description provided for @posReturnableQuantity.
  ///
  /// In ar, this message translates to:
  /// **'الكمية المرتجعة'**
  String get posReturnableQuantity;

  /// No description provided for @posReturnButton.
  ///
  /// In ar, this message translates to:
  /// **'إرجاع'**
  String get posReturnButton;

  /// No description provided for @posReturnReason.
  ///
  /// In ar, this message translates to:
  /// **'سبب المرتجع'**
  String get posReturnReason;

  /// No description provided for @posReturnSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم استلام المرتجع بنجاح'**
  String get posReturnSuccess;

  /// No description provided for @posOverReturnBlocked.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن إرجاع أكثر من الكمية الأصلية'**
  String get posOverReturnBlocked;

  /// No description provided for @posLostSaleTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل منتج ناقص'**
  String get posLostSaleTitle;

  /// No description provided for @posLostSalePrompt.
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسم المنتج وكميته'**
  String get posLostSalePrompt;

  /// No description provided for @posLostSaleName.
  ///
  /// In ar, this message translates to:
  /// **'اسم/مواصفة المنتج'**
  String get posLostSaleName;

  /// No description provided for @posLostSaleSciName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم العلمي'**
  String get posLostSaleSciName;

  /// No description provided for @posLostSaleNotes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get posLostSaleNotes;

  /// No description provided for @posLostSaleQty.
  ///
  /// In ar, this message translates to:
  /// **'الكمية المطلوبة'**
  String get posLostSaleQty;

  /// No description provided for @posLostSaleSaved.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل المنتج الناقص'**
  String get posLostSaleSaved;

  /// No description provided for @posNoResults.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نتائج مطابقة'**
  String get posNoResults;

  /// No description provided for @posCustomerLabel.
  ///
  /// In ar, this message translates to:
  /// **'العميل'**
  String get posCustomerLabel;

  /// No description provided for @posPrescriptionLabel.
  ///
  /// In ar, this message translates to:
  /// **'الوصفة'**
  String get posPrescriptionLabel;

  /// No description provided for @posActivePrescriptions.
  ///
  /// In ar, this message translates to:
  /// **'الوصفات النشطة'**
  String get posActivePrescriptions;

  /// No description provided for @posNoPrescriptions.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد وصفات نشطة لهذا العميل'**
  String get posNoPrescriptions;

  /// No description provided for @posPriceChange.
  ///
  /// In ar, this message translates to:
  /// **'تعديل السعر'**
  String get posPriceChange;

  /// No description provided for @posItemAdded.
  ///
  /// In ar, this message translates to:
  /// **'تمت إضافة المنتج للسلة'**
  String get posItemAdded;

  /// No description provided for @posCartCleared.
  ///
  /// In ar, this message translates to:
  /// **'تم تفريغ السلة'**
  String get posCartCleared;

  /// No description provided for @posQuantityUpdated.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث الكمية'**
  String get posQuantityUpdated;

  /// No description provided for @posInvoiceTitle.
  ///
  /// In ar, this message translates to:
  /// **'فاتورة البيع'**
  String get posInvoiceTitle;

  /// No description provided for @posSaleNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الفاتورة'**
  String get posSaleNumber;

  /// No description provided for @posSaleDate.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get posSaleDate;

  /// No description provided for @posLineItem.
  ///
  /// In ar, this message translates to:
  /// **'المنتج'**
  String get posLineItem;

  /// No description provided for @posLineQty.
  ///
  /// In ar, this message translates to:
  /// **'الكمية'**
  String get posLineQty;

  /// No description provided for @posLineUnitPrice.
  ///
  /// In ar, this message translates to:
  /// **'سعر الوحدة'**
  String get posLineUnitPrice;

  /// No description provided for @posLineTotal.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get posLineTotal;

  /// No description provided for @posLineDiscount.
  ///
  /// In ar, this message translates to:
  /// **'الخصم'**
  String get posLineDiscount;

  /// No description provided for @posLineReturnable.
  ///
  /// In ar, this message translates to:
  /// **'الكمية القابلة للإرجاع'**
  String get posLineReturnable;

  /// No description provided for @posAlternativesTitle.
  ///
  /// In ar, this message translates to:
  /// **'البدائل المقترحة لـ'**
  String get posAlternativesTitle;

  /// No description provided for @posAlternativesTier1.
  ///
  /// In ar, this message translates to:
  /// **'مطابق: نفس المكون والجرعة والشكل'**
  String get posAlternativesTier1;

  /// No description provided for @posAlternativesTier2.
  ///
  /// In ar, this message translates to:
  /// **'نفس المكون بجرعة أو شكل مختلف'**
  String get posAlternativesTier2;

  /// No description provided for @posAlternativesTier3.
  ///
  /// In ar, this message translates to:
  /// **'يشارك مكوناً فعالاً'**
  String get posAlternativesTier3;

  /// No description provided for @posAlternativesEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد بدائل متاحة حالياً'**
  String get posAlternativesEmpty;

  /// No description provided for @posAlternativesFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر تحميل البدائل'**
  String get posAlternativesFailed;

  /// No description provided for @posAvailableStock.
  ///
  /// In ar, this message translates to:
  /// **'متاح'**
  String get posAvailableStock;

  /// No description provided for @posCreditLabel.
  ///
  /// In ar, this message translates to:
  /// **'آجل'**
  String get posCreditLabel;

  /// No description provided for @posCreditDownCash.
  ///
  /// In ar, this message translates to:
  /// **'دفعة نقدية'**
  String get posCreditDownCash;

  /// No description provided for @posCreditDownCard.
  ///
  /// In ar, this message translates to:
  /// **'دفعة بطاقة'**
  String get posCreditDownCard;

  /// No description provided for @posCreditRemaining.
  ///
  /// In ar, this message translates to:
  /// **'مستحق على العميل'**
  String get posCreditRemaining;

  /// No description provided for @posCreditOutstanding.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد الحالي'**
  String get posCreditOutstanding;

  /// No description provided for @posCreditAvailable.
  ///
  /// In ar, this message translates to:
  /// **'المتاح قبل السقف'**
  String get posCreditAvailable;

  /// No description provided for @posCreditLimit.
  ///
  /// In ar, this message translates to:
  /// **'السقف الائتماني'**
  String get posCreditLimit;

  /// No description provided for @posCreditUnlimited.
  ///
  /// In ar, this message translates to:
  /// **'بدون سقف'**
  String get posCreditUnlimited;

  /// No description provided for @posCreditCustomerRequired.
  ///
  /// In ar, this message translates to:
  /// **'البيع الآجل يتطلب تحديد عميل له حساب آجل'**
  String get posCreditCustomerRequired;

  /// No description provided for @cashboxTitle.
  ///
  /// In ar, this message translates to:
  /// **'الصندوق'**
  String get cashboxTitle;

  /// No description provided for @cashboxReadOnly.
  ///
  /// In ar, this message translates to:
  /// **'وضع العرض فقط — تحتاج صلاحية «التعامل مع الصندوق» لإجراء العمليات'**
  String get cashboxReadOnly;

  /// No description provided for @cashboxActionOpen.
  ///
  /// In ar, this message translates to:
  /// **'فتح الصندوق'**
  String get cashboxActionOpen;

  /// No description provided for @cashboxActionClose.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق الصندوق'**
  String get cashboxActionClose;

  /// No description provided for @cashboxActionDeposit.
  ///
  /// In ar, this message translates to:
  /// **'إيداع نقدي'**
  String get cashboxActionDeposit;

  /// No description provided for @cashboxActionWithdraw.
  ///
  /// In ar, this message translates to:
  /// **'سحب نقدي'**
  String get cashboxActionWithdraw;

  /// No description provided for @cashboxActionAdjust.
  ///
  /// In ar, this message translates to:
  /// **'تسوية الصندوق'**
  String get cashboxActionAdjust;

  /// No description provided for @cashboxSessionOpen.
  ///
  /// In ar, this message translates to:
  /// **'الجلسة مفتوحة'**
  String get cashboxSessionOpen;

  /// No description provided for @cashboxSessionClosed.
  ///
  /// In ar, this message translates to:
  /// **'الجلسة مقفلة'**
  String get cashboxSessionClosed;

  /// No description provided for @cashboxOpenedBy.
  ///
  /// In ar, this message translates to:
  /// **'فُتح بواسطة'**
  String get cashboxOpenedBy;

  /// No description provided for @cashboxOpenedAt.
  ///
  /// In ar, this message translates to:
  /// **'فُتح في'**
  String get cashboxOpenedAt;

  /// No description provided for @cashboxClosedBy.
  ///
  /// In ar, this message translates to:
  /// **'أُغلق بواسطة'**
  String get cashboxClosedBy;

  /// No description provided for @cashboxClosedAt.
  ///
  /// In ar, this message translates to:
  /// **'أُغلق في'**
  String get cashboxClosedAt;

  /// No description provided for @cashboxRunning.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد الجاري'**
  String get cashboxRunning;

  /// No description provided for @cashboxExpected.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد المتوقع'**
  String get cashboxExpected;

  /// No description provided for @cashboxDeclared.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد المعلن'**
  String get cashboxDeclared;

  /// No description provided for @cashboxSurplus.
  ///
  /// In ar, this message translates to:
  /// **'زيادة'**
  String get cashboxSurplus;

  /// No description provided for @cashboxShortage.
  ///
  /// In ar, this message translates to:
  /// **'عجز'**
  String get cashboxShortage;

  /// No description provided for @cashboxMovementsTitle.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الحركة'**
  String get cashboxMovementsTitle;

  /// No description provided for @cashboxTypeOpen.
  ///
  /// In ar, this message translates to:
  /// **'افتتاح'**
  String get cashboxTypeOpen;

  /// No description provided for @cashboxTypeClose.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get cashboxTypeClose;

  /// No description provided for @cashboxTypeSale.
  ///
  /// In ar, this message translates to:
  /// **'مبيعات نقدية'**
  String get cashboxTypeSale;

  /// No description provided for @cashboxTypeRefund.
  ///
  /// In ar, this message translates to:
  /// **'مبالغ مستردة'**
  String get cashboxTypeRefund;

  /// No description provided for @cashboxTypePayment.
  ///
  /// In ar, this message translates to:
  /// **'مقبوضات عملاء'**
  String get cashboxTypePayment;

  /// No description provided for @cashboxTypeDeposit.
  ///
  /// In ar, this message translates to:
  /// **'إيداعات'**
  String get cashboxTypeDeposit;

  /// No description provided for @cashboxTypeWithdraw.
  ///
  /// In ar, this message translates to:
  /// **'سحوبات'**
  String get cashboxTypeWithdraw;

  /// No description provided for @cashboxTypeExpense.
  ///
  /// In ar, this message translates to:
  /// **'مصروفات'**
  String get cashboxTypeExpense;

  /// No description provided for @cashboxTypeAdjustment.
  ///
  /// In ar, this message translates to:
  /// **'تسويات'**
  String get cashboxTypeAdjustment;

  /// No description provided for @cashboxInflows.
  ///
  /// In ar, this message translates to:
  /// **'المقبوضات'**
  String get cashboxInflows;

  /// No description provided for @cashboxOutflows.
  ///
  /// In ar, this message translates to:
  /// **'المدفوعات'**
  String get cashboxOutflows;

  /// No description provided for @cashboxNetMoves.
  ///
  /// In ar, this message translates to:
  /// **'صافي الحركة'**
  String get cashboxNetMoves;

  /// No description provided for @cashboxHistoryTitle.
  ///
  /// In ar, this message translates to:
  /// **'سجل حركة الصندوق'**
  String get cashboxHistoryTitle;

  /// No description provided for @cashboxHistoryEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد حركات مسجلة'**
  String get cashboxHistoryEmpty;

  /// No description provided for @cashboxFilterAll.
  ///
  /// In ar, this message translates to:
  /// **'كل الأنواع'**
  String get cashboxFilterAll;

  /// No description provided for @cashboxColTime.
  ///
  /// In ar, this message translates to:
  /// **'الوقت'**
  String get cashboxColTime;

  /// No description provided for @cashboxColType.
  ///
  /// In ar, this message translates to:
  /// **'النوع'**
  String get cashboxColType;

  /// No description provided for @cashboxColAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get cashboxColAmount;

  /// No description provided for @cashboxColRemaining.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد'**
  String get cashboxColRemaining;

  /// No description provided for @cashboxColOperator.
  ///
  /// In ar, this message translates to:
  /// **'الموظف'**
  String get cashboxColOperator;

  /// No description provided for @cashboxColNote.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة'**
  String get cashboxColNote;

  /// No description provided for @cashboxNotOpened.
  ///
  /// In ar, this message translates to:
  /// **'الصندوق غير مفتوح'**
  String get cashboxNotOpened;

  /// No description provided for @cashboxNotOpenedHint.
  ///
  /// In ar, this message translates to:
  /// **'افتح الصندوق لبدء نوبة العمل وتسجيل الحركات'**
  String get cashboxNotOpenedHint;

  /// No description provided for @cashboxNotOpenedReadOnly.
  ///
  /// In ar, this message translates to:
  /// **'الصندوق غير مفتوح — راجع مدير الصيدلية لفتحه'**
  String get cashboxNotOpenedReadOnly;

  /// No description provided for @cashboxOpeningLabel.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد الافتتاحي'**
  String get cashboxOpeningLabel;

  /// No description provided for @cashboxNoteOptional.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة (اختياري)'**
  String get cashboxNoteOptional;

  /// No description provided for @cashboxDeclaredLabel.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد النقدي المعدود عند الإغلاق'**
  String get cashboxDeclaredLabel;

  /// No description provided for @cashboxReason.
  ///
  /// In ar, this message translates to:
  /// **'السبب'**
  String get cashboxReason;

  /// No description provided for @cashboxAmountLabel.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get cashboxAmountLabel;

  /// No description provided for @cashboxAdjustHint.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ الموجب إيداع، والسالب سحب'**
  String get cashboxAdjustHint;

  /// No description provided for @cashboxOpeningRequired.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الرصيد الافتتاحي'**
  String get cashboxOpeningRequired;

  /// No description provided for @cashboxOpeningInvalid.
  ///
  /// In ar, this message translates to:
  /// **'قيمة افتتاح غير صالحة'**
  String get cashboxOpeningInvalid;

  /// No description provided for @cashboxClosingRequired.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الرصيد المعدود عند الإغلاق'**
  String get cashboxClosingRequired;

  /// No description provided for @cashboxClosingInvalid.
  ///
  /// In ar, this message translates to:
  /// **'قيمة إغلاق غير صالحة'**
  String get cashboxClosingInvalid;

  /// No description provided for @cashboxMoveRequired.
  ///
  /// In ar, this message translates to:
  /// **'أدخل المبلغ'**
  String get cashboxMoveRequired;

  /// No description provided for @cashboxMoveInvalid.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ يجب أن يكون أكبر من صفر'**
  String get cashboxMoveInvalid;

  /// No description provided for @cashboxReasonRequired.
  ///
  /// In ar, this message translates to:
  /// **'السبب مطلوب'**
  String get cashboxReasonRequired;

  /// No description provided for @navExpenses.
  ///
  /// In ar, this message translates to:
  /// **'المصروفات'**
  String get navExpenses;

  /// No description provided for @expensesTitle.
  ///
  /// In ar, this message translates to:
  /// **'المصروفات'**
  String get expensesTitle;

  /// No description provided for @expensesAdd.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل مصروف'**
  String get expensesAdd;

  /// No description provided for @expensesAddTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل مصروف جديد'**
  String get expensesAddTitle;

  /// No description provided for @expensesEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مصروفات مسجلة'**
  String get expensesEmpty;

  /// No description provided for @expensesTotalCount.
  ///
  /// In ar, this message translates to:
  /// **'عدد السجلات'**
  String get expensesTotalCount;

  /// No description provided for @expensesPageTotal.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي هذه الصفحة'**
  String get expensesPageTotal;

  /// No description provided for @expensesSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'بحث بالوصف أو رقم المصروف'**
  String get expensesSearchHint;

  /// No description provided for @expensesFilterAllCategories.
  ///
  /// In ar, this message translates to:
  /// **'كل الفئات'**
  String get expensesFilterAllCategories;

  /// No description provided for @expensesFilterAllPayments.
  ///
  /// In ar, this message translates to:
  /// **'كل طرق الدفع'**
  String get expensesFilterAllPayments;

  /// No description provided for @expensesFilterAllStatus.
  ///
  /// In ar, this message translates to:
  /// **'كل الحالات'**
  String get expensesFilterAllStatus;

  /// No description provided for @expensesFilterActiveOnly.
  ///
  /// In ar, this message translates to:
  /// **'النشطة فقط'**
  String get expensesFilterActiveOnly;

  /// No description provided for @expensesFilterVoidedOnly.
  ///
  /// In ar, this message translates to:
  /// **'الملغاة فقط'**
  String get expensesFilterVoidedOnly;

  /// No description provided for @expensesStatusActive.
  ///
  /// In ar, this message translates to:
  /// **'نشط'**
  String get expensesStatusActive;

  /// No description provided for @expensesStatusVoided.
  ///
  /// In ar, this message translates to:
  /// **'ملغى'**
  String get expensesStatusVoided;

  /// No description provided for @expensesReadOnly.
  ///
  /// In ar, this message translates to:
  /// **'عرض فقط — لا تملك صلاحية لإدارة المصروفات'**
  String get expensesReadOnly;

  /// No description provided for @expensesColNumber.
  ///
  /// In ar, this message translates to:
  /// **'الرقم'**
  String get expensesColNumber;

  /// No description provided for @expensesColDate.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get expensesColDate;

  /// No description provided for @expensesColDescription.
  ///
  /// In ar, this message translates to:
  /// **'الوصف'**
  String get expensesColDescription;

  /// No description provided for @expensesColCategory.
  ///
  /// In ar, this message translates to:
  /// **'الفئة'**
  String get expensesColCategory;

  /// No description provided for @expensesColPayment.
  ///
  /// In ar, this message translates to:
  /// **'الدفع'**
  String get expensesColPayment;

  /// No description provided for @expensesColAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get expensesColAmount;

  /// No description provided for @expensesColOperator.
  ///
  /// In ar, this message translates to:
  /// **'المستخدم'**
  String get expensesColOperator;

  /// No description provided for @expensesColStatus.
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get expensesColStatus;

  /// No description provided for @expensesCash.
  ///
  /// In ar, this message translates to:
  /// **'نقدي'**
  String get expensesCash;

  /// No description provided for @expensesCard.
  ///
  /// In ar, this message translates to:
  /// **'بطاقة'**
  String get expensesCard;

  /// No description provided for @expensesShowReceipt.
  ///
  /// In ar, this message translates to:
  /// **'عرض الإيصال'**
  String get expensesShowReceipt;

  /// No description provided for @expensesAttachReceipt.
  ///
  /// In ar, this message translates to:
  /// **'إرفاق إيصال'**
  String get expensesAttachReceipt;

  /// No description provided for @expensesCancelAction.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء المصروف'**
  String get expensesCancelAction;

  /// No description provided for @expenseAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get expenseAmount;

  /// No description provided for @expenseAmountRequired.
  ///
  /// In ar, this message translates to:
  /// **'أدخل المبلغ'**
  String get expenseAmountRequired;

  /// No description provided for @expenseAmountInvalid.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ يجب أن يكون أكبر من صفر'**
  String get expenseAmountInvalid;

  /// No description provided for @expenseDescription.
  ///
  /// In ar, this message translates to:
  /// **'الوصف'**
  String get expenseDescription;

  /// No description provided for @expenseDescriptionRequired.
  ///
  /// In ar, this message translates to:
  /// **'أدخل وصف المصروف'**
  String get expenseDescriptionRequired;

  /// No description provided for @expenseCategory.
  ///
  /// In ar, this message translates to:
  /// **'فئة المصروف'**
  String get expenseCategory;

  /// No description provided for @expenseCategoryRequired.
  ///
  /// In ar, this message translates to:
  /// **'اختر فئة المصروف'**
  String get expenseCategoryRequired;

  /// No description provided for @expenseSupplier.
  ///
  /// In ar, this message translates to:
  /// **'المورد (اختياري)'**
  String get expenseSupplier;

  /// No description provided for @expenseNoSupplier.
  ///
  /// In ar, this message translates to:
  /// **'بدون مورد'**
  String get expenseNoSupplier;

  /// No description provided for @expensePaymentNote.
  ///
  /// In ar, this message translates to:
  /// **'يُسجَّل الدفع هنا ويُعكس نقدًا أو بطاقة عند الإلغاء'**
  String get expensePaymentNote;

  /// No description provided for @expenseDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ المصروف'**
  String get expenseDate;

  /// No description provided for @expenseNotesOptional.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات (اختياري)'**
  String get expenseNotesOptional;

  /// No description provided for @expenseReceiptUnreadable.
  ///
  /// In ar, this message translates to:
  /// **'تعذر عرض الملف — قد يكون تالفاً أو بصيغة غير مدعومة'**
  String get expenseReceiptUnreadable;

  /// No description provided for @expenseEditDescription.
  ///
  /// In ar, this message translates to:
  /// **'تعديل المصروف'**
  String get expenseEditDescription;

  /// No description provided for @expenseAmountImmutableHint.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن تعديل المبلغ أو الفئة أو طريقة الدفع بعد القيد'**
  String get expenseAmountImmutableHint;

  /// No description provided for @expenseCancelTitle.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء المصروف'**
  String get expenseCancelTitle;

  /// No description provided for @expenseCancelReason.
  ///
  /// In ar, this message translates to:
  /// **'سبب الإلغاء'**
  String get expenseCancelReason;

  /// No description provided for @expenseCancelReasonRequired.
  ///
  /// In ar, this message translates to:
  /// **'أدخل سبب الإلغاء'**
  String get expenseCancelReasonRequired;

  /// Cancel/void an expense — confirmation message
  ///
  /// In ar, this message translates to:
  /// **'سيتم عكس مصروف {number} نقديًا ودفترًا بالكامل. لا يمكن التراجع عن هذا الإجراء.'**
  String expenseCancelConfirmMessage(String number);

  /// No description provided for @expenseCategoryEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الفئة'**
  String get expenseCategoryEditTitle;

  /// No description provided for @expenseCategoryAddTitle.
  ///
  /// In ar, this message translates to:
  /// **'فئة مصروف جديدة'**
  String get expenseCategoryAddTitle;

  /// No description provided for @expenseCategoryCode.
  ///
  /// In ar, this message translates to:
  /// **'كود الفئة'**
  String get expenseCategoryCode;

  /// No description provided for @expenseCategoryCodeHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: utilities, transport…'**
  String get expenseCategoryCodeHint;

  /// No description provided for @expenseCategoryName.
  ///
  /// In ar, this message translates to:
  /// **'اسم الفئة'**
  String get expenseCategoryName;

  /// No description provided for @expenseCategoryNameEn.
  ///
  /// In ar, this message translates to:
  /// **'الاسم بالإنجليزية (اختياري)'**
  String get expenseCategoryNameEn;

  /// No description provided for @expenseCategoryAccount.
  ///
  /// In ar, this message translates to:
  /// **'الحساب (بالدليل مثل 5100)'**
  String get expenseCategoryAccount;

  /// No description provided for @expenseCategorySystemBlock.
  ///
  /// In ar, this message translates to:
  /// **'الفئات النظامية لا يمكن تعديلها أو تعطيلها'**
  String get expenseCategorySystemBlock;

  /// No description provided for @expenseCategoriesTitle.
  ///
  /// In ar, this message translates to:
  /// **'فئات المصروفات'**
  String get expenseCategoriesTitle;

  /// No description provided for @expenseNoCategories.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد فئات مصروفات'**
  String get expenseNoCategories;

  /// No description provided for @expenseCategoryAdd.
  ///
  /// In ar, this message translates to:
  /// **'فئة جديدة'**
  String get expenseCategoryAdd;

  /// No description provided for @expenseCreatedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل المصروف'**
  String get expenseCreatedMessage;

  /// No description provided for @expenseUpdatedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث المصروف'**
  String get expenseUpdatedMessage;

  /// No description provided for @expenseCancelledMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم عكس المصروف'**
  String get expenseCancelledMessage;

  /// No description provided for @expenseReceiptAttached.
  ///
  /// In ar, this message translates to:
  /// **'تم إرفاق الإيصال'**
  String get expenseReceiptAttached;

  /// No description provided for @expenseCategoryCreatedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء الفئة'**
  String get expenseCategoryCreatedMessage;

  /// No description provided for @expenseCategoryUpdatedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث الفئة'**
  String get expenseCategoryUpdatedMessage;

  /// No description provided for @expenseCategoryActivated.
  ///
  /// In ar, this message translates to:
  /// **'تم تفعيل الفئة'**
  String get expenseCategoryActivated;

  /// No description provided for @expenseCategoryDeactivated.
  ///
  /// In ar, this message translates to:
  /// **'تم تعطيل الفئة'**
  String get expenseCategoryDeactivated;
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
